using DataFrames
using StringEncodings
using CSV


tpd_columns_names = Dict(
    5000 => "Flowing Bottom Hole Pressure",
    5001 => "Flowing Wellhead Temperature",
    5108 => "GASLIFT - Injection Depth",
    5142 => "GASLIFT - Top Node Depth",
    5143 => "GASLIFT - Bottom Node Depth",
    5144 => "GASLIFT - Valve Tubing Pressure",
    5145 => "GASLIFT - Valve Tubing Temperature",
    5146 => "GASLIFT - Valve Casing Pressure",
    5147 => "GASLIFT - Casing Head Pressure",
    5148 => "GASLIFT - Gas Injection Rate",
    5149 => "GASLIFT - Critical Gas Injection Rate",
    5150 => "GASLIFT - Critical Casing Head Pressure",
    5151 => "GASLIFT - Orifice Diameter",
    5152 => "GASLIFT - Thornhill-Craver DeRating Value",
    5153 => "GASLIFT - GasLift Gas Gravity",
    5022 => "C Factor",
    5100 => "Mixture Velocity",
    5101 => "Erosional Velocity",
    5102 => "Maximum Grain Diameter",
    5104 => "Erosion Flag",
    5157 => "Cumulative Transit Time"
)
tpd_variables_names = Dict(
    4000 => "Liquid Rate",
    23 => "GLR Injected",
    16 => "Water Cut",
    17 => "Gas Oil Ratio",
    27 => "Top Node Pressure",
)


function mask_line(line::AbstractString, mask::AbstractString, delim::Char)
    upfront = split(mask, delim)[1]

    line = line[length(upfront)+1:end]
    mask = mask[length(upfront)+1:end]

    values = String[]
    p = 1
    for i = findall(' ', mask)
        push!(values, strip(line[p:i-1]))
        p = i + 1
    end

    return values
end

function parse_metadata_lines(lines::Vector{String})
    metadata = Dict{String, String}()

    for line in lines
        line = lstrip(line, ['#', '-', ' '])
        if length(line) > 0
            key, value = split(line, " : ")
            metadata[key] = value
        end
    end

    return metadata
end

function parse_equipment_lines(lines::Vector{String})
    header_lines = String[]
    body_lines = Vector{Vector{String}}()
    column_mask = ""

    header = true
    for line in lines
        if header
            if count('_', line) > 5  # arbitrary threshold
                header = false
                column_mask = line
                header_lines = [mask_line(l, column_mask, '_') for l in header_lines]   
            else
                if length(line) > 3
                    push!(header_lines, line)
                end
            end
        else
            if length(line) > 3
                push!(body_lines, mask_line(line, column_mask, '_'))
            end
        end
    end

    header = collect(eachrow(reduce(hcat, header_lines)))
    header = [join(map(strip, h), ' ') for h in header]
    header = map(strip, header)

    body = collect(eachrow(reduce(hcat, body_lines)))

    equip_summary = DataFrame(body, header)

    for col in header
        if endswith(col, ')')
            equip_summary[equip_summary[!, col] .== "", col] .= "0"
            equip_summary[!, col] = parse.(Float64, equip_summary[!, col])
        end
    end

    return equip_summary
end

function parse_breakpoints_lines(lines::Vector{String})
    breakpoints = Vector{Vector{Float64}}()
    names = String[]

    for line in lines
        m = match(r"-- (?<name>.+) units - (?<unit>.+)  \( (?<n>.+) value", line)
        variable_name = "$(m[:name]) ($(m[:unit]))"

        values = split(line, ')')[end][1:end-1]  # remove trailing '/'
        values = split(values, ' ', keepempty=false)

        push!(names, variable_name)
        push!(breakpoints, parse.(Float64, values))
    end

    return names, breakpoints
end

function read_ecl(fpath::AbstractString; get_meta = false)
    metadata_lines = String[]
    equipment_summary_lines = String[]
    breakpoints_lines = String[]

    bhp_indices = Vector{Vector{Int}}()
    bhp_values = Vector{Vector{Float64}}()

    n_variables = 1
    header_skip = 0

    section = :Metadata
    for line in eachline(fpath, enc"WINDOWS-1252")
        if section == :Metadata
            # Transition
            if endswith(line, "EQUIPMENT SUMMARY START")
                section = :EquipmentSummary
                header_skip = 0
                continue
            end

            # Filter
            if startswith(line, "--") & contains(line, ':')
                push!(metadata_lines, line)
                if contains(line, "Sensitivity Variable")
                    n_variables += 1
                end
            end
        elseif section == :EquipmentSummary
            # Transition
            if endswith(line, "EQUIPMENT SUMMARY END")
                section = :Units
                global units_group = String[]
                continue
            end

            # Filter
            if header_skip >= 4
                push!(equipment_summary_lines, line)
            else
                header_skip += 1
            end
        elseif section == :Units
            # Transition
            if length(breakpoints_lines) >= n_variables
                section = :Data
                global data_group = String[]
            end

            # Filter
            if contains(line, " units - ") | length(units_group) > 0
                push!(units_group, line)

                if endswith(line, '/')
                    push!(breakpoints_lines, join(units_group, ' '))
                    global units_group = String[]
                end
            end
        elseif section == :Data
            push!(data_group, line)

            if endswith(line, "/")
                data_strings = split(join(data_group), ' ', keepempty=false)
                data_strings = data_strings[1:end-1]  # drop trailing '/'

                indices = Vector{Int}([parse(Int, s) for s in data_strings[1:n_variables-1]])
                values = Vector{Float64}([parse(Float64, s) for s in data_strings[n_variables:end]])

                push!(bhp_indices, indices)
                push!(bhp_values, values)

                global data_group = String[]
            end
        end
    end

    metadata = parse_metadata_lines(metadata_lines)
    equipment = parse_equipment_lines(equipment_summary_lines)
    variables, breakpoints = parse_breakpoints_lines(breakpoints_lines)

    ### Build DataFrame

    # Transpose bhps
    bhp_indices = collect(eachrow(reduce(hcat, bhp_indices)))
    bhp_values = collect(eachrow(reduce(hcat, bhp_values)))

    df_indices = DataFrame(bhp_indices, variables[2:end])  # temp column naming
    df_values = DataFrame(bhp_values, string.(breakpoints[1]))
    df = hcat(df_indices, df_values)

    df = stack(df, length(variables):size(df)[2])
    df[!,"variable"] = parse.(Float64, df[!,"variable"])
    rename!(df, "variable" => variables[1], "value" => "BHP")

    for (var, bps) in zip(variables[2:end], breakpoints[2:end])
        df[!,var] = map(j -> bps[j], df[!,var])
    end

    if get_meta
        return df, metadata, equipment, breakpoints
    else
        return df
    end
end

function read_ipr(fpath::AbstractString)
    df = DataFrame(CSV.File(fpath))
    df = parse.(Float64, replace.(df, ',' => '.'))
    rename!(df, ["LIQ", "BHP"])

    return df
end

function parse_tpd_info_lines(lines)
    # TPD File Signature
    tpd_signature = lines[3]
    
    # TPD File Version
    tpd_version = parse(Int, lines[5])
    
    # Fluid Type, Well Type, Temperature Model, Lift Type
    fluid_type, well_type, temp_model, lift_type = parse.(Int, split(lines[11], ","))
    
    # First Node Pressure, Temperature
    first_node_pressure, temperature = parse.(Float64, split(lines[13], ","))
    
    # Oil Gravity, Gas Gravity, (WC/WGR), (GOR/CGR/Total GOR), Top TVD, Bottom TVD
    oil_gravity, gas_gravity, wc_wgr, gor_cgr_total_gor, top_tvd, bottom_tvd = parse.(Float64, split(lines[15], ","))
    
    # Number of Sensitivity Variables
    num_sensitivity_vars = parse(Int, lines[17])
    
    # Numbers of :- Rates, GLR Injected values, Water Cut values, Gas Oil Ratio values, Top Node Pressure values
    num_breakpoints_all = split(lines[19])
    @assert length(num_breakpoints_all) == num_sensitivity_vars + 1 
    
    # Number of Calculated Values (columns)
    num_calculated_values = parse(Int, lines[21])

    column_names = lines[22:22+num_calculated_values-1]
    column_order = lines[22+num_calculated_values]

    # parse column names given order
    column_names = Dict(m[1] => m[2] for m in match.(r"^# ([0-9]+) - (.+?)$", column_names))
    columns = [String(column_names[strip(i)]) for i in split(column_order, ",")]
    
    return Dict(
        "tpd_signature" => tpd_signature,
        "tpd_version" => tpd_version,
        "fluid_type" => fluid_type,
        "well_type" => well_type,
        "temp_model" => temp_model,
        "lift_type" => lift_type,
        "first_node_pressure" => first_node_pressure,
        "temperature" => temperature,
        "oil_gravity" => oil_gravity,
        "gas_gravity" => gas_gravity,
        "wc_wgr" => wc_wgr,
        "gor_cgr_total_gor" => gor_cgr_total_gor,
        "top_tvd" => top_tvd,
        "bottom_tvd" => bottom_tvd,
        "num_sensitivity_vars" => num_sensitivity_vars,
        "nums_breakpoints" => num_breakpoints_all,
        "num_calculated_values" => num_calculated_values,
        "columns" => columns,
    )
end

function parse_tpd_breakpoints_lines(lines; num_variables=4)
    r = r"([0-9]+) - (.+)$"
    m = match(r, lines[1])
    rate_variable_num = m[1]
    rate_variable_name = m[2]

    variable_lines = lines[2:2+num_variables-1]
    variables = Dict(
        m[1] => m[2] for m in match.(r, variable_lines)
    )
    variables[rate_variable_num] = rate_variable_name

    variables_order = lines[2+num_variables]
    variables = [String(variables[strip(i)]) for i in split(variables_order, ",")]
    
    breakpoints = Dict{String,Vector{Float64}}()
    i0 = 2+num_variables+1
    for i = i0:2:(i0+2*num_variables+1)
        name = rate_variable_name
        for var_name in variables
            if occursin(var_name, lines[i])
                name = var_name
                break
            end
        end

        breakpoints[name] = parse.(Float64, split(lines[i+1], ","))
    end

    return variables, breakpoints
end

function read_tpd_prosper(fpath::AbstractString; get_meta = false)
    metadata_lines = String[]
    equipment_summary_lines = String[]
    breakpoints_lines = String[]
    vlp_info_lines = String[]
    data_lines = String[]

    bhp_indices = Vector{Vector{Int}}()
    bhp_values = Vector{Vector{Float64}}()

    n_variables = 1
    header_skip = 0

    section = :Metadata
    # for line in eachline(fpath, enc"WINDOWS-1252")
    for line in eachline(fpath)
        if section == :Metadata
            # Transition
            if endswith(line, "EQUIPMENT SUMMARY START")
                section = :EquipmentSummary
                header_skip = 0
                continue
            end

            # Filter
            if startswith(line, "#") & contains(line, ':')
                push!(metadata_lines, line)
                if contains(line, "Sensitivity Variable")
                    n_variables += 1
                end
            end
        elseif section == :EquipmentSummary
            # Transition
            if endswith(line, "EQUIPMENT SUMMARY END")
                section = :VLPInfo
                continue
            end

            # Filter
            if header_skip >= 4
                push!(equipment_summary_lines, line)
            else
                header_skip += 1
            end
        elseif section == :VLPInfo
            # Transition
            if contains(line, "Rate and Variable Types")
                section = :Breakpoints
                continue
            end

            # Filter
            if length(strip(replace(line, "#"=>""))) > 0
                push!(vlp_info_lines, line)
            end
        elseif section == :Breakpoints
            # Transition
            if contains(line, "Variable TPD Results")
                section = :Data
                continue
            end

            # Filter
            push!(breakpoints_lines, line)
        elseif section == :Data
            push!(data_lines, line)
        end
    end

    metadata = parse_metadata_lines(metadata_lines)
    equipment = parse_equipment_lines(equipment_summary_lines)
    tpd_info = parse_tpd_info_lines(vlp_info_lines)
    variables, breakpoints = parse_tpd_breakpoints_lines(breakpoints_lines, num_variables=4)

    data = map(x -> parse.(Float64, split(x, ",")), data_lines)
    df = DataFrame(mapreduce(permutedims, vcat, data), tpd_info["columns"])

    return df

    ### Build DataFrame

    # Transpose bhps
    # bhp_indices = collect(eachrow(reduce(hcat, bhp_indices)))
    # bhp_values = collect(eachrow(reduce(hcat, bhp_values)))

    # df_indices = DataFrame(bhp_indices, variables[2:end])  # temp column naming
    # df_values = DataFrame(bhp_values, string.(breakpoints[1]))
    # df = hcat(df_indices, df_values)

    # df = stack(df, length(variables):size(df)[2])
    # df[!,"variable"] = parse.(Float64, df[!,"variable"])
    # rename!(df, "variable" => variables[1], "value" => "BHP")

    # for (var, bps) in zip(variables[2:end], breakpoints[2:end])
    #     df[!,var] = map(j -> bps[j], df[!,var])
    # end

    if get_meta
        return df, metadata, equipment
    else
        return df
    end
end

function read_tpd_gap(fpath::AbstractString; get_meta = false)
    lines = readlines(fpath)
    
    # skip comments
    i = 1
    line_i = lines[i]
    while startswith(line_i, "#")
        i += 1
        line_i = lines[i]
    end

    lines = lines[i:end]

    # TPD File Signature
    tpd_signature = lines[1]

    # TPD File Version
    tpd_version = parse(Int, lines[2])

    # Fluid Type, Well Type, Temperature Model, Lift Type
    # fluid_type, well_type, temp_model, lift_type = parse.(Int, split(lines[11], ","))

    # First Node Pressure, Temperature
    first_node_pressure, temperature = parse.(Float64, split(lines[4], ","))

    # Oil Gravity, Gas Gravity, (WC/WGR), (GOR/CGR/Total GOR), Top TVD, Bottom TVD
    # oil_gravity, gas_gravity, wc_wgr, gor_cgr_total_gor, top_tvd, bottom_tvd = parse.(Float64, split(lines[5], ","))

    # Number of Sensitivity Variables
    num_sensitivity_vars = parse(Int, lines[6])

    # Numbers of :- Rates, GLR Injected values, Water Cut values, Gas Oil Ratio values, Top Node Pressure values
    num_breakpoints_all = split(lines[7],",")
    @assert length(num_breakpoints_all) == num_sensitivity_vars + 1 

    # Number of Calculated Values (columns)
    num_calculated_values = parse(Int, lines[8])

    columns = split(lines[9],",")
    columns_names = [tpd_columns_names[parse(Int, c)] for c in columns]

    variables = split(lines[10],",")
    variables_names = [tpd_variables_names[parse(Int, c)] for c in variables]

    breakpoints = map(x -> parse.(Float64, split(x, ",")), lines[11:11+num_sensitivity_vars])

    data_lines = lines[11+num_sensitivity_vars+1:end]
    data = map(x -> parse.(Float64, split(x, ",")), data_lines)
    df = DataFrame(mapreduce(permutedims, vcat, data), columns_names)

    # increments follow variable order, i.e., first pass all rate values, then all variable n, then variable n-1, etc.

    for variable_name in variables_names
        df[!,variable_name] .= 0.0
    end

    for row in eachrow(df)
        r = rownumber(row) - 1
        for (v_i, v_name) in enumerate(variables_names)
            n_bps = parse(Int, num_breakpoints_all[v_i])
            row[v_name] = breakpoints[v_i][(r % n_bps) + 1]
            r = r ÷ n_bps
        end
    end

    return df
end