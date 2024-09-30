
_time_units = [
    :day,
    :minute,
    :hour,
    :year,
    :second,
    :s,
]

# append to list of units
_available_units = [_available_units; _time_units]

function latin_si(::Val{:day})
    return 1.0
end

function latin_si(::Val{:hour})
    return latin_si(:day) / 24.0
end

function latin_si(::Val{:minute})
    return latin_si(:hour) / 60.0
end

function latin_si(::Val{:year})
    return 365.2425 * latin_si(Val(:day))
end

function latin_si(::Union{Val{:second}, Val{:s}})
    return latin_si(:minute) / 60.0
end