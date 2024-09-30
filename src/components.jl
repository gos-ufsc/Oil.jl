using DataFrames

abstract type AbstractWell end
struct Well <: AbstractWell
    name::String
    gor::Float64
    wct::Float64
    min_q_inj::Union{Nothing, Float64}
    max_q_inj::Union{Nothing, Float64}
    vlp::curves.VLP
    ipr::curves.LinearIPR
end
function Well(name::String, GOR::Float64, WCT::Float64,
              vlp::curves.VLP, ipr::curves.LinearIPR)
    return Well(name, GOR, WCT, nothing, nothing, vlp, ipr)
end

Base.copy(well::Well) = Well(well.name, well.gor, well.wct, well.min_q_inj, well.max_q_inj,
                             copy(well.vlp), copy(well.ipr))
Base.names(wells::Vector{W}) where W <: AbstractWell = [well.name for well in wells]

struct Riser
    vlp::curves.VLP
    manifold_wells::Vector{Well}
    choke_enabled::Bool
end
function Riser(vlp::curves.VLP, manifold_wells::Vector{Well}; choke_enabled::Bool = true)
    return Riser(vlp, manifold_wells, choke_enabled)
end

Base.copy(riser::Riser) = Riser(copy(riser.vlp), copy(riser.manifold_wells), riser.choke_enabled)

struct Platform
    p_sep::Float64
    satellite_wells::Vector{Well}
    riser::Union{Nothing, Riser}
    q_inj_max::Union{Nothing,Float64}
    q_water_max::Union{Nothing,Float64}
    q_gas_max::Union{Nothing,Float64}
    q_liq_max::Union{Nothing,Float64}
end
function Platform(
    p_sep::Float64;
    satellite_wells::Vector{Well} = Vector{Well}(),
    riser::Union{Nothing,Riser} = nothing,
    q_inj_max::Union{Nothing,Float64} = nothing,
    q_water_max::Union{Nothing,Float64} = nothing,
    q_gas_max::Union{Nothing,Float64} = nothing,
    q_liq_max::Union{Nothing,Float64} = nothing,
)
    return Platform(p_sep, satellite_wells, riser, q_inj_max, q_water_max, q_gas_max, q_liq_max)
end

function all_wells(p::Platform)
    if isnothing(p.riser)
        return p.satellite_wells
    else
        return [p.satellite_wells; p.riser.manifold_wells]
    end
end
