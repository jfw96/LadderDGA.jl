# ==================================================================================================== #
#                                        ladderDGATools.jl                                             #
# ---------------------------------------------------------------------------------------------------- #
#   Author          : Julian Stobbe                                                                    #
# ----------------------------------------- Description ---------------------------------------------- #
#   ladder DΓA related functions                                                                       #
# -------------------------------------------- TODO -------------------------------------------------- #
#   Cleanup                                                                                            #
# ==================================================================================================== #


#TODO: THIS NEEDS CLEANUP!
function conv_tmp!(res::AbstractVector{ComplexF64}, kG::KGrid, arr1::Vector{ComplexF64}, GView::AbstractArray{ComplexF64,N})::Nothing where N
    if Nk(kG) == 1 
        res[:] = arr1 .* GView
    else
        expandKArr!(kG, kG.cache1, arr1)
        mul!(kG.cache1, kG.fftw_plan, kG.cache1)
        for i in eachindex(kG.cache1)
            kG.cache1[i] *= GView[i]
        end
        kG.fftw_plan \ kG.cache1
        Dispersions.conv_post!(kG, res, kG.cache1)
    end
    return nothing
end

function calc_Σ_ω!(eomf::Function, Σ_ω::OffsetArray{ComplexF64,3}, Kνωq_pre::Vector{ComplexF64},
            χm::χT, γm::γT, χd::χT, γd::γT,
            Gνω::GνqT, λ₀::AbstractArray{ComplexF64,3}, U::Float64, kG::KGrid, 
            sP::SimulationParameters)

    νdim = ndims(Gνω) > 2 ? length(gridshape(kG))+1 : 2 # TODO: this is a fallback for gIm
    fill!(Σ_ω, zero(ComplexF64))
    for (ωi,ωn) in enumerate(axes(Σ_ω,3))
        νZero = ν0Index_of_ωIndex(ωi, sP)
        νlist = νZero:(sP.n_iν*2)
        length(νlist) > size(Σ_ω,2) && (νlist = νlist[1:size(Σ_ω,2)])
        for (νii,νi) in enumerate(νlist)
            for qi in 1:size(Σ_ω,1)
                Kνωq_pre[qi] = eomf(U, γm[qi,νi,ωi], γd[qi,νi,ωi], χm[qi,ωi], χd[qi,ωi], λ₀[qi,νi,ωi])
            end
            #TODO: find a way to not unroll this!
            conv_tmp!(view(Σ_ω,:,νii-1,ωn), kG, Kνωq_pre, selectdim(Gνω,νdim,(νii-1) + ωn))
        end
    end
end

function calc_Σ_ω!(eomf::Function, Σ_ladder::OffsetMatrix{ComplexF64}, Kνωq_pre::Vector{ComplexF64},
            χm::χT, γm::γT, χd::χT, γd::γT,
            Gνω::GνqT, λ₀::AbstractArray{ComplexF64,3}, U::Float64, kG::KGrid, 
            sP::SimulationParameters)

    νdim = ndims(Gνω) > 2 ? length(gridshape(kG))+1 : 2 # TODO: this is a fallback for gIm
    fill!(Σ_ladder, zero(ComplexF64))
    ω_axis = χm.indices_ω 
    for (ωi,ωn) in enumerate(ω_axis)
        νZero = ν0Index_of_ωIndex(ωi, sP)
        νlist = νZero:(sP.n_iν*2)
        length(νlist) > size(Σ_ladder,2) && (νlist = νlist[1:size(Σ_ladder,2)])
        for (νii,νi) in enumerate(νlist)
            for qi in 1:size(Σ_ladder,1)
                Kνωq_pre[qi] = eomf(U, γm[qi,νi,ωi], γd[qi,νi,ωi], χm[qi,ωi], χd[qi,ωi], λ₀[qi,νi,ωi])
            end
            #TODO: find a way to not unroll this!
            conv_tmp_add!(view(Σ_ladder,:,νii-1), kG, Kνωq_pre, selectdim(Gνω,νdim,(νii-1) + ωn))
        end
    end
end

function calc_Σ!(Σ_ladder::OffsetMatrix{ComplexF64}, Kνωq_pre::Vector{ComplexF64},
                χm::χT, γm::γT, χd::χT, γd::γT, 
                χ_m_sum::Union{Float64,ComplexF64}, λ₀::AbstractArray{_eltype,3},
                Gνω::GνqT, kG::KGrid,
                mP::ModelParameters, sP::SimulationParameters; tc::Bool=true)::Nothing
    Σ_hartree = mP.n * mP.U/2.0;
    calc_Σ_ω!(eom, Σ_ladder, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    tail_correction = (tc ? - mP.U .* (sum_kω(kG, χm) - χ_m_sum) : 0) ./ iν_array(mP.β, collect(axes(Σ_ladder)[2]))
    Σ_ladder.parent[:,:] = Σ_ladder.parent[:,:] ./ mP.β .+ reshape(tail_correction, 1, length(tail_correction)) .+ Σ_hartree
    return nothing
end

function calc_Σ!(Σ_ladder::OffsetMatrix{ComplexF64}, Σ_ladder_ω::OffsetArray{ComplexF64,3}, Kνωq_pre::Vector{ComplexF64},
                χm::χT, γm::γT, χd::χT, γd::γT, 
                χ_m_sum::Union{Float64,ComplexF64}, λ₀::AbstractArray{_eltype,3},
                Gνω::GνqT, kG::KGrid,
                mP::ModelParameters, sP::SimulationParameters; tc::Bool=true)::Nothing

    Σ_hartree = mP.n * mP.U/2.0;
    calc_Σ_ω!(eom, Σ_ladder_ω, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    sum!(Σ_ladder, Σ_ladder_ω)
    tail_correction = (tc ? - mP.U .* (sum_kω(kG, χm) - χ_m_sum) : 0) ./ iν_array(mP.β, collect(axes(Σ_ladder)[2]))
    Σ_ladder.parent[:,:] = Σ_ladder.parent[:,:] ./ mP.β .+ reshape(tail_correction, 1, length(tail_correction)) .+ Σ_hartree
    return nothing
end

"""
    calc_Σ(χm::χT, γm::γT, χd::χT, γd::γT, λ₀::AbstractArray{_eltype,3}, h::lDΓAHelper;
                νmax::Int = h.sP.n_iν, λm::Float64=0.0, λd::Float64=0.0, tc::Bool=true)
    calc_Σ(χm::χT, γm::γT, χd::χT, γd::γT, χ_m_sum::Union{Float64,ComplexF64}, λ₀::AbstractArray{_eltype,3},
                Gνω::GνqT, kG::KGrid, mP::ModelParameters, sP::SimulationParameters; 
                νmax::Int = sP.n_iν, λm::Float64=0.0, λd::Float64=0.0, tc::Bool=true)
                
Calculates the self-energy from ladder quantities.

This is the single core variant, see [`calc_Σ_par`](@ref calc_Σ_par) for the parallel version.
"""
function calc_Σ(χm::χT, γm::γT, χd::χT, γd::γT, 
                λ₀::AbstractArray{_eltype,3}, h::lDΓAHelper;
                νmax::Int = h.sP.n_iν, λm::Float64=0.0, λd::Float64=0.0, tc::Bool=true)
    calc_Σ(χm, γm, χd, γd, h.χloc_m_sum, λ₀, h.gLoc_rfft, h.kG, h.mP, h.sP, νmax=νmax, λm=λm, λd=λd, tc=tc)
end

function calc_Σ(χm::χT, γm::γT, χd::χT, γd::γT, 
                χ_m_sum::Union{Float64,ComplexF64}, λ₀::AbstractArray{_eltype,3},
                Gνω::GνqT, kG::KGrid,
                mP::ModelParameters, sP::SimulationParameters; 
                νmax::Int = sP.n_iν,
                λm::Float64=0.0, λd::Float64=0.0, tc::Bool=true)
    χm.λ != 0 && λm != 0 && error("Stopping self energy calculation: λm = $λm AND χm.λ = $(χm.λ)")
    χd.λ != 0 && λd != 0 && error("Stopping self energy calculation: λd = $λd AND χd.λ = $(χd.λ)")
    Nq, Nω = size(χm)
    ωrange::UnitRange{Int}   = -sP.n_iω:sP.n_iω

    Kνωq_pre::Vector{ComplexF64} = Vector{ComplexF64}(undef, length(kG.kMult))
    Σ_ladder   = OffsetArray(Array{Complex{Float64},2}(undef,Nq, νmax), 1:Nq, 0:νmax-1)
    
    λm != 0.0 && χ_λ!(χm, λm)
    λd != 0.0 && χ_λ!(χd, λd)

    calc_Σ!(Σ_ladder, Kνωq_pre, χm, γm, χd, γd, χ_m_sum, λ₀, Gνω, kG, mP, sP, tc=tc)

    λm != 0.0 && reset!(χm)
    λd != 0.0 && reset!(χd)
    return Σ_ladder
end


"""
    calc_Σ_parts(χm::χT,γm::γT,χd::χT,γd::γT,h::lDΓAHelper,λ₀::AbstractArray{ComplexF64,3};λm::Float64=0.0, λd::Float64=0.0)
    calc_Σ_parts(χm::χT,γm::γT, χd::χT, γd::γT, χ_m_sum::Union{Float64,ComplexF64}, λ₀::AbstractArray{_eltype,3},
                 Gνω::GνqT, kG::KGrid,mP::ModelParameters, sP::SimulationParameters;
                 λm::Float64=0.0, λd::Float64=0.0)

Calculates the ``lD\\GammaA`` self-energy (see also [`calc_Σ`](@ref calc_Σ)),
but split into `7` contributions from: `χm`, `γm`, `χd`, `γd`, `U`, `Fm` + `Σ_hartree`, `tail_correction`.

"""
function calc_Σ_parts(χm::χT,γm::γT,χd::χT,γd::γT,λ₀::AbstractArray{ComplexF64,3},h::lDΓAHelper; tc::Bool=true, λm::Float64=0.0, λd::Float64=0.0)
    calc_Σ_parts(χm,γm,χd,γd,h.χloc_m_sum,λ₀,h.gLoc_rfft,h.kG,h.mP,h.sP;tc=tc,λm=λm,λd=λd)
end

function calc_Σ_parts(χm::χT,γm::γT,χd::χT,γd::γT,χ_m_sum::Union{Float64,ComplexF64},λ₀::AbstractArray{_eltype,3},
                      Gνω::GνqT, kG::KGrid,mP::ModelParameters, sP::SimulationParameters;
                      tc::Bool=true,λm::Float64=0.0, λd::Float64=0.0)
    Σ_hartree = mP.n * mP.U/2.0;
    Nq, Nω = size(χm)
    ωrange::UnitRange{Int} = -sP.n_iω:sP.n_iω
    ωindices::UnitRange{Int} = (sP.dbg_full_eom_omega) ? (1:Nω) : intersect(χm.usable_ω, χd.usable_ω)

    Kνωq_pre::Vector{ComplexF64} = Vector{ComplexF64}(undef, length(kG.kMult))
    Σ_ladder_ω = OffsetArray(Array{Complex{Float64},3}(undef,Nq, sP.n_iν, length(ωrange)),
                              1:Nq, 0:sP.n_iν-1, ωrange)
    Σ_ladder = OffsetArray(Array{Complex{Float64},3}(undef,Nq, sP.n_iν, 7), 1:Nq, 0:sP.n_iν-1, 1:7)

    λm != 0.0 && χ_λ!(χm, λm)
    λd != 0.0 && χ_λ!(χd, λd)

    tail_correction = (tc ? - mP.U .* (sum_kω(kG, χm) - χ_m_sum) : 0) ./ iν_array(mP.β, collect(axes(Σ_ladder)[2]))
    calc_Σ_ω!(eom_χ_m, Σ_ladder_ω, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    Σ_ladder.parent[:,:,1] = dropdims(sum(Σ_ladder_ω, dims=[3]),dims=3) ./ mP.β
    calc_Σ_ω!(eom_γ_m, Σ_ladder_ω, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    Σ_ladder.parent[:,:,2] = dropdims(sum(Σ_ladder_ω, dims=[3]),dims=3) ./ mP.β
    calc_Σ_ω!(eom_χ_d, Σ_ladder_ω, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    Σ_ladder.parent[:,:,3] = dropdims(sum(Σ_ladder_ω, dims=[3]),dims=3) ./ mP.β 
    calc_Σ_ω!(eom_γ_d, Σ_ladder_ω, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    Σ_ladder.parent[:,:,4] = dropdims(sum(Σ_ladder_ω, dims=[3]),dims=3) ./ mP.β 
    calc_Σ_ω!(eom_rest_01, Σ_ladder_ω, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    Σ_ladder.parent[:,:,5] = dropdims(sum(Σ_ladder_ω, dims=[3]),dims=3) ./ mP.β
    calc_Σ_ω!(eom_rest, Σ_ladder_ω, Kνωq_pre, χm, γm, χd, γd, Gνω, λ₀, mP.U, kG, sP)
    Σ_ladder.parent[:,:,6] = dropdims(sum(Σ_ladder_ω, dims=[3]),dims=3) ./ mP.β .+ Σ_hartree
    for qi in 1:size(Σ_ladder,1)
        Σ_ladder.parent[qi,:,7] .= tail_correction 
    end
    λm != 0.0 && reset!(χm)
    λd != 0.0 && reset!(χd)

    return  Σ_ladder
end
