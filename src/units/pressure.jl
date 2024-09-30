
_pressure_units = [
    :kgf,
    :bar,
    :psi,
    :a,
    :absolute,
    :g,
    :gauge,
    :kPa,
]

# append to list of units
_available_units = [_available_units; _pressure_units]

function latin_si(::Val{:kgf})
    return 1.0
end

function latin_si(::Val{:psi})
    return 0.070307 * latin_si(:kgf)
end

function latin_si(::Val{:bar})
    kgf = latin_si(:kgf)
    return 1.01971621298 * kgf
end

function latin_si(::Union{Val{:a}, Val{:absolute}})
    return 0.0
end

function latin_si(::Union{Val{:g}, Val{:gauge}})
    return 1.0333
end

function latin_si(::Val{:kPa})
    return 0.010197 * latin_si(:kgf)
end