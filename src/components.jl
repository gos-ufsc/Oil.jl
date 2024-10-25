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

__manifold_id = 0
struct Manifold
    name::String
    vlp::curves.VLP
    wells::Vector{Well}
    choke_enabled::Bool
end
function Manifold(vlp::curves.VLP, wells::Vector{Well}; choke_enabled::Bool = true)
    global __manifold_id
    name = "M" * string(__manifold_id)
    __manifold_id += 1
    return Manifold(name, vlp, wells, choke_enabled)
end
function Manifold(name::String, vlp::curves.VLP, wells::Vector{Well}; choke_enabled::Bool = true)
    return Manifold(name, vlp, wells, choke_enabled)
end

Base.copy(manifold::Manifold) = Manifold(copy(manifold.name), copy(manifold.vlp), copy(manifold.wells), manifold.choke_enabled)

struct Platform
    p_sep::Float64
    satellite_wells::Vector{Well}
    manifolds::Vector{Manifold}
    q_inj_max::Union{Nothing,Float64}
    q_water_max::Union{Nothing,Float64}
    q_gas_max::Union{Nothing,Float64}
    q_liq_max::Union{Nothing,Float64}
end
function Platform(
        p_sep::Float64;
        satellite_wells::Vector{Well} = Vector{Well}(),
        manifolds::Vector{Manifold} = Vector{Manifold}(),
        q_inj_max::Union{Nothing,Float64} = nothing,
        q_water_max::Union{Nothing,Float64} = nothing,
        q_gas_max::Union{Nothing,Float64} = nothing,
        q_liq_max::Union{Nothing,Float64} = nothing,
    )
    return Platform(p_sep, satellite_wells, manifolds, q_inj_max, q_water_max, q_gas_max, q_liq_max)
end

function all_wells(p::Platform)
    wells = p.satellite_wells
    for manifold in p.manifolds
        wells = [wells ; manifold.wells]
    end
    return wells
end
