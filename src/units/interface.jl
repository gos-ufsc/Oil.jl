export latin_si, units, all_units

function units(arg...)
    return map(latin_si, arg)
end

function all_units()
    d = Dict{Symbol, Float64}()
    for k in available_units()
        d[k] = latin_si(k)
    end
    return d
end

function latin_si(uname::Symbol)
    return latin_si(Val(uname))::Float64
end

function latin_si(uname::String)
    return latin_si(Symbol(uname))
end

function latin_si(::Val{uname}) where uname
    error("Unknown unit: $uname")
end
