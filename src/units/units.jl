# Copy-pasted from Jutul's unit system
# https://github.com/sintefmath/Jutul.jl/tree/main/src/units

export available_units

_available_units = Vector{Symbol}()

include("interface.jl")
include("length.jl")
include("pressure.jl")
include("volume.jl")
include("time.jl")
include("mass.jl")

function available_units()
    return _available_units
end
