module curves

using DataFrames

import ..Oil: latin_si

export VLP, IPR

"""
Vertical Lift Performance (VLP) curve contains the following dimensions [unit]:
    THP [kgf a]: Top-hole pressure, or p_sup. Upstream from the choke valve (if any).
    WCT [sm³/sm³]: Water-cut, or BSW.
    GOR [sm³/sm³]: Gas-oil ratio, considers _only_ the produced gas (no gas-lift).
    IGLR [sm³/sm³]: Injected-gas-liquid ratio, considers only the gas-lift sent upstream.
    LIQ [sm³/day]: Liquid rate.
    BHP [kgf a]: Bottom-hole pressure.

We handle this through a DataFrame object with the same column names.
"""
struct VLP
    df::DataFrame
end
function VLP(fpath::AbstractString)
    ext = splitext(fpath)[2]
    if ext == ".Ecl"
        return VLP(load_vlp_from_ecl(fpath))
    elseif ext == ".tpd"
        return VLP(load_vlp_from_gap_tpd(fpath))
    else
        throw("Not Implemented! Only .Ecl files are supported for VLP curves.")
    end
end
Base.copy(vlp::VLP) = VLP(copy(vlp.df))

"""
The curve is expected to have the following dimensions, under the resp. unit:
    THP [Barsa]: Top-hole pressure, or p_sup. Upstream from the choke valve (if any).
    WCT [sm³/sm³]: Water-cut, or BSW.
    GOR [sm³/sm³]: Gas-oil ratio, considers _only_ the produced gas (no gas-lift).
    IGLR [sm³/sm³]: Injected-gas-liquid ratio, considers only the gas-lift sent upstream.
    LIQ [sm³/day]: Liquid rate.
    BHP [Barsa]: Bottom-hole pressure.
"""
function load_vlp_from_ecl(fpath::AbstractString)
    curve = curves.read_ecl(fpath, get_meta = false)

    curve = rename(curve, map(name -> split(name, ' ')[1], names(curve)))

    # convert pressures from BARa
    bar, a, m3, d = latin_si(:bar), latin_si(:absolute), latin_si(:m3), latin_si(:day)
    curve.THP = curve.THP .* bar .+ a
    curve.BHP = curve.BHP .* bar .+ a
    curve.LIQ = curve.LIQ .* (m3 / d)

    return curve
end
function load_vlp_from_gap_tpd(fpath::AbstractString)
    curve = curves.read_tpd_gap(fpath, get_meta = false)

    curve = rename(curve, Dict(
        "Flowing Bottom Hole Pressure" => :BHP,
        "Liquid Rate" => :LIQ,
        "GLR Injected" => :IGLR,
        "Water Cut" => :WCT,
        "Gas Oil Ratio" => :GOR,
        "Top Node Pressure" => :THP,
    ))

    # this verification should be done further down the line to also change the formulation
    # if all(curve.BHP .<= curve.THP)
    #     # for the riser, the curve is generated backwards
    #     curve = rename(curve, Dict(:BHP => :THP, :THP => :BHP,))
    # end

    # LIQ in STB/day
    # IGLR in scf/STB
    # WCT in %
    # GOR in scf/STB
    # THP in psig
    # BHP in psig
    scf, STB, g, psi, d = latin_si(:cf), latin_si(:STB), latin_si(:gauge), latin_si(:psi), latin_si(:day)
    curve.LIQ = curve.LIQ .* (STB / d)
    curve.IGLR = curve.IGLR .* scf ./ STB
    curve.GOR = curve.GOR .* scf ./ STB
    curve.THP = curve.THP .* psi .+ g
    curve.BHP = curve.BHP .* psi .+ g

    return curve[!, [:THP, :WCT, :GOR, :IGLR, :LIQ, :BHP]]
end

abstract type IPR end
"""
The Inflow Performance Relationship (IPR) curve contains the following dimensions [unit]:
    LIQ [sm³/day]: Liquid rate.
    BHP [kgf a]: Bottom-hole pressure.
"""
struct BlackBoxIPR <: IPR
    df::DataFrame
end
function BlackBoxIPR(fpath::AbstractString)
    if splitext(fpath)[2] == ".txt"
        return BlackBoxIPR(load_ipr_from_csv(fpath))
    else
        throw("Not Implemented! Only .txt files are supported for IPR curves.")
    end
end

struct LinearIPR <: IPR
    p_res::Real
    IP::Real
end
function LinearIPR(p_res::Real, bhp_test::Real, q_liq_test::Real)
    IP = q_liq_test / (p_res - bhp_test)

    return LinearIPR(p_res, IP)
end

function IPR(df::DataFrame)
    return BlackBoxIPR(df)
end
function IPR(fpath::AbstractString)
    return BlackBoxIPR(fpath)
end
function IPR(p_res::Float64, IP::Float64)
    return LinearIPR(p_res, IP)
end
function IPR(p_res::Real, bhp_test::Real, q_liq_test::Real)
    return LinearIPR(p_res, bhp_test, q_liq_test)
end
Base.copy(ipr::IPR) = IPR(copy(ipr.df))

"""
The .txt file must have two dimensions with the resp. units:
    LIQ [sm³/day]: Liquid rate.
    BHP [kgf g]: Bottom-hole pressure.
"""
function load_ipr_from_csv(fpath::AbstractString)
    curve = read_ipr(fpath)

    kgf, g, m3, d = latin_si(:kgf), latin_si(:gauge), latin_si(:m3), latin_si(:day)
    curve.BHP = curve.BHP .* kgf .+ g  # convert from KGFg
    curve.LIQ = curve.LIQ .* (m3 / d)

    return curve
end

include("interpolation.jl")
include("io.jl")

end