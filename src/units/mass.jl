
_mass_units = [
    :kilogram,
    :kg,
    :pound,
    :lb,
    :gram,
    :ton
]

# append to list of units
_available_units = [_available_units; _mass_units]

# Mass
function latin_si(::Union{Val{:kilogram}, Val{:kg}})
    return 1.0
end

function latin_si(::Union{Val{:pound}, Val{:lb}})
    return 0.45359237 # kg
end

function latin_si(::Val{:gram})
    return 1e-3
end

function latin_si(::Val{:ton})
    return 1000.0
end