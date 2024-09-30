
_length_units = [
        :meter,
        :m,
        :centimeter,
        :cm,
        :inch,
        :in,
        :feet,
        :ft,
]

# append to list of units
_available_units = [_available_units; _length_units]

function latin_si(::Union{Val{:meter}, Val{:m}})
    return 1.0
end

function latin_si(::Union{Val{:centimeter}, Val{:cm}})
    return 0.01
end

function latin_si(::Union{Val{:inch}, Val{:in}})
    cm = latin_si(:cm)
    return 2.540*cm
end

function latin_si(::Union{Val{:feet}, Val{:ft}})
    return 0.3048
end
