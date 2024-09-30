
_volume_units = [
    :m3,
    :cm3,
    :liter,
    :litre,
    :L,
    :l,
    :cf,
    :stb,
    :sTB,
    :STB,
]

# append to list of units
_available_units = [_available_units; _volume_units]

function latin_si(::Val{:m3})
    return 1.0
end

function latin_si(::Val{:cm3})
    return 1e-6 * latin_si(:m3)
end

function latin_si(::Union{Val{:liter}, Val{:litre}, Val{:L}, Val{:l}})
    return 1e-3 * latin_si(:m3)
end

function latin_si(::Val{:cf})
    return 0.028317 * latin_si(:m3)
end

function latin_si(::Union{Val{:stb}, Val{:sTB}, Val{:STB}})
    return 0.003785 * latin_si(:m3)
end
