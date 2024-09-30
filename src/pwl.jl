
function drop_infeasible_region_well_vlp(curve::SubDataFrame)
    q_liq_min = last(curve[curve.BHP .== min(curve.BHP...), "LIQ"])

    curve.BHP[curve.LIQ .< q_liq_min] .= -1

    return curve
end

function make_piecewise_linear(df::DataFrame, x_name::AbstractString, y_name)
    breakpoints = sort(unique(df[!, x_name]))

    pwl = Dict(p[x_name] => p[y_name] for p in eachrow(df))

    return pwl, breakpoints
end
function make_piecewise_linear(df::DataFrame, x_names::Vector, y_name)
    breakpoints = Dict(col => sort(unique(df[!, col])) for col in x_names)

    pwl = Dict(values(p[x_names]) => p[y_name] for p in eachrow(df))

    return pwl, breakpoints
end

struct PiecewiseLinearWell <: AbstractWell
    name::String  # TODO: maybe create an AbstractWell so that we can <: AbstractWell. see https://discourse.julialang.org/t/composition-and-inheritance-the-julian-way/11231/16
    gor::Float64
    wct::Float64
    min_q_inj::Union{Nothing, Float64}
    max_q_inj::Union{Nothing, Float64}
    vlp::DataFrame
    Q_liq_vlp::Vector{Float64}
    IGLR::Vector{Float64}
    WHP::Vector{Float64}
    WFP_vlp::Dict{Tuple{Float64, Float64, Float64}, Float64}
    ipr::curves.LinearIPR
end
function PiecewiseLinearWell(well::Well, drop_infeasible_vlp = true)
    vlp = curves.interpolate_vlp_at_gor_wct(well.vlp, well.gor, well.wct)

    df = vlp.df

    if drop_infeasible_vlp
        df = vcat([drop_infeasible_region_well_vlp(df) for df in groupby(df, ["GOR", "WCT", "IGLR", "THP"])]...)
    end

    vlp_pwl, vlp_breakpoints = make_piecewise_linear(df, ["IGLR", "THP", "LIQ"], "BHP")

    return PiecewiseLinearWell(
        well.name,
        well.gor,
        well.wct,
        well.min_q_inj,
        well.max_q_inj,
        df,
        vlp_breakpoints["LIQ"],
        vlp_breakpoints["IGLR"],
        vlp_breakpoints["THP"],
        vlp_pwl,
        well.ipr
    )
end

struct PiecewiseLinearRiser
    Q_liq::Vector{Float64}
    GOR::Vector{Float64}
    WCT::Vector{Float64}
    IGLR::Vector{Float64}
    ΔP::Dict{Tuple{Float64, Float64, Float64, Float64}, Float64}
end

function PiecewiseLinearRiser(riser::Riser, thp::Float64, use_gor_total::Bool = false)
    if ~riser.choke_enabled
        vlp = curves.interpolate_vlp_at_thp(riser.vlp, thp)

        df = copy(vlp.df)
        df[!,"ΔP"] = df[!,"BHP"] .- thp
    else
        vlp = riser.vlp

        df = copy(vlp.df)
        df[!,"ΔP"] = df[!,"BHP"] .- df[!,"THP"]
    end

    if use_gor_total
        df[!,"GOR"] = df[!,"GOR"] .+ df[!,"IGLR"] ./ (1 .- df[!,"WCT"])
        vlp_pwl, vlp_breakpoints = make_piecewise_linear(df, ["LIQ", "GOR", "WCT"], "ΔP")

        riser = PiecewiseLinearRiserGorTotal(
            vlp_breakpoints["LIQ"],
            vlp_breakpoints["GOR"],
            vlp_breakpoints["WCT"],
            vlp_pwl,
        )
        for q_liq_bp in riser.Q_liq
            for gor_bp in riser.GOR
                for wct_bp in riser.WCT
                    if ~haskey(riser.ΔP, (q_liq_bp, gor_bp, wct_bp))
                        riser.ΔP[(q_liq_bp, gor_bp, wct_bp)] = -1.0
                    end
                end
            end
        end
    
        return riser
    end


    vlp_pwl, vlp_breakpoints = make_piecewise_linear(df, ["LIQ", "GOR", "WCT", "IGLR"], "ΔP")

    riser = PiecewiseLinearRiser(
        vlp_breakpoints["LIQ"],
        vlp_breakpoints["GOR"],
        vlp_breakpoints["WCT"],
        vlp_breakpoints["IGLR"],
        vlp_pwl,
    )

    # populate missing places with infeasible (-1)
    for q_liq_bp in riser.Q_liq
        for gor_bp in riser.GOR
            for wct_bp in riser.WCT
                for iglr_bp in riser.IGLR
                    if ~haskey(riser.ΔP, (q_liq_bp, gor_bp, wct_bp, iglr_bp))
                        riser.ΔP[(q_liq_bp, gor_bp, wct_bp, iglr_bp)] = -1.0
                    end
                end
            end
        end
    end

    return riser
end

struct PiecewiseLinearRiserGorTotal
    Q_liq::Vector{Float64}
    GOR::Vector{Float64}
    WCT::Vector{Float64}
    ΔP::Dict{Tuple{Float64, Float64, Float64}, Float64}
end

