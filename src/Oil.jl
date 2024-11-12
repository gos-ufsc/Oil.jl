module Oil

include("units/units.jl")
include("curves/curves.jl")
include("components.jl")
include("pwl.jl")

using .curves

export Platform, Well, Manifold, VLP, IPR, all_wells

end # module Oil
