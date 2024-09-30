using DataFrames
using Interpolations


function get_interpolator(df::DataFrame, output::AbstractString)
    df_ = copy(df)

    inputs = [col for col in names(df_) if col != output]

    function stack_col(df, col)
        new_df = unstack(df, col, output)
        dropmissing!(new_df)

        breakpoints = sort(unique(df[!, col]))
        m = Matrix(new_df[!, [Symbol(bp) for bp in breakpoints]])

        d = ndims(df[!,output][1]) + 1

        new_df[!,output] = [cat(m[i,:]..., dims=d) for i in 1:size(m, 1)]

        select!(new_df, Not([Symbol(bp) for bp in breakpoints]))

        return new_df
    end

    for col in inputs
        df_ = stack_col(df_, col)
    end

    out_values = df_[!,output][1]

    nodes = [sort(unique(df[!, col])) for col in inputs]
    itp = interpolate(Tuple(nodes), out_values, Gridded(Linear()))

    return itp, nodes
end

function interpolate_at_inputs(df::DataFrame, output::AbstractString; kwargs...)
    @assert string.(keys(kwargs)) ⊆ names(df)

    itp, nodes = get_interpolator(df, output)

    inputs = [col for col in names(df) if col != output]

    interp_x = nodes
    for i in eachindex(interp_x)
        if Symbol(inputs[i]) in keys(kwargs)
            interp_x[i] = [kwargs[Symbol(inputs[i])],]
        end
    end

    interpolated_output = itp(interp_x...)

    filter_new = ones(Bool, length(kwargs), length(inputs))
    for (i,k) in enumerate(keys(kwargs))
        filter_new[i,:] = inputs .!= string(k)
    end
    filter_new = prod(filter_new, dims=1)[1,:]

    new_expanded_bps = collect(Iterators.product(interp_x...))
    new_expanded_bps = reshape(reinterpret(Float64, vcat(new_expanded_bps)), length(interp_x), :)

    bps = Dict(i => n for (i, n) in zip(inputs, eachrow(new_expanded_bps)))

    new_df = DataFrame(bps)
    new_df[!,output] = reshape(interpolated_output, :)
    return new_df
end

function interpolate_vlp_at_gor_wct(vlp::VLP, gor::Real, wct::Real)
    kwargs = Dict()
    if length(unique(vlp.df[!, "GOR"])) == 1
        @assert vlp.df[1, "GOR"] == gor
    else
        kwargs[:GOR] = gor
    end

    if length(unique(vlp.df[!, "WCT"])) == 1
        @assert vlp.df[1, "WCT"] == wct
    else
        kwargs[:WCT] = wct
    end

    if length(kwargs) > 0
        new_df = interpolate_at_inputs(vlp.df, "BHP"; kwargs...)

        return VLP(new_df)
    else
        return copy(vlp)
    end
end

function interpolate_vlp_at_thp(vlp::VLP, thp::Real)
    if length(unique(vlp.df[!, "THP"])) == 1
        @assert vlp.df[1, "THP"] == thp

        return copy(vlp)
    else
        new_df = interpolate_at_inputs(vlp.df, "BHP", THP=thp)
     
        return VLP(new_df)
    end
end
