# ==================================================================================================== #
#                                          BSE_Tools.jl                                                #
# ---------------------------------------------------------------------------------------------------- #
#   Author          : Julian Stobbe                                                                    #
# ----------------------------------------- Description ---------------------------------------------- #
#   Functions related to the solution of the Bethe Salpeter Equation                                   #                                                                       #
# -------------------------------------------- TODO -------------------------------------------------- #
# ==================================================================================================== #


# ========================================== Transformations =========================================
"""
    λ_from_γ(type::Symbol, γ::γT, χ::χT, U::Float64)

TODO: documentation
"""
function λ_from_γ(type::Symbol, γ::γT, χ::χT, U::Float64)
    s = (type == :d) ? -1 : 1
    res = similar(γ.data)
    for ωi in 1:size(γ,3)
        for qi in 1:size(γ,1)
            res[qi,:,ωi] = s .* view(γ,qi,:,ωi) .* (1 .+ s*U .* χ.data[qi, ωi]) .- 1
        end
    end
    return res
end


"""
    F_from_χ(type::Symbol, h::lDΓAHelper; diag_term=true)
    F_from_χ(χ::AbstractArray{ComplexF64,3}, G::AbstractArray{ComplexF64,1}, sP::SimulationParameters, β::Float64; diag_term=true)

TODO: documentation
"""
function F_from_χ(type::Symbol, h::lDΓAHelper; diag_term=true)
    type != :m && error("only F_m tested!")
    F_from_χ(h.χDMFT_m, h.gImp[1,:], h.sP, h.mP.β; diag_term=diag_term)
end

function F_from_χ(χ::AbstractArray{ComplexF64,3}, G::AbstractVector{ComplexF64}, sP::SimulationParameters, β::Float64; diag_term=true)
    F = similar(χ)
    for ωi in 1:size(F,3)
    for νpi in 1:size(F,2)
        ωn, νpn = OneToIndex_to_Freq(ωi, νpi, sP)
        for νi in 1:size(F,1)
            _, νn = OneToIndex_to_Freq(ωi, νi, sP)
            F[νi,νpi,ωi] = -(χ[νi,νpi,ωi] + (νn == νpn && diag_term) * β * G[νn] * G[ωn+νn])/(
                                          G[νn] * G[ωn+νn] * G[νpn] * G[ωn+νpn])
        end
        end
    end
    return F
end

"""
    F_from_χ_gen(χ₀::χ₀T, χr::Array{ComplexF64,4})::Array{ComplexF64,4}

Calculates the full vertex from the generalized susceptibility ``\\chi^{\\nu\\nu'\\omega}_r`` and the bubble term ``\\chi_0`` via
``F^{\\nu\\nu'\\omega}_{r,\\mathbf{q}} 
     =
     \\beta^2 \\left( \\chi^{\\nu\\nu'\\omega}_{0,\\mathbf{q}} \\right)^{-1} 
     - \\left( \\chi^{\\nu\\omega}_{0,\\mathbf{q}} \\right)^{-1}  \\chi^{\\nu\\nu'\\omega}_{r,\\mathbf{q}} \\left( \\chi^{\\nu'\\omega}_{0,\\mathbf{q}} \\right)^{-1}``

For a version using the physical susceptibilities see [`F_from_χ_gen`](@ref F_from_χ_gen).
"""
function F_from_χ_gen(χ₀::χ₀T, χr::Array{ComplexF64,4})::Array{ComplexF64,4}
    F = similar(χr)
    for ωi in 1:size(χr,4)
        for qi in 1:size(χr,3)
            F[:,:,qi,ωi] = Diagonal(χ₀.β^2 ./ core(χ₀)[qi,:,ωi]) .- χ₀.β^2 .* χr[:,:,qi,ωi] ./ ( core(χ₀)[qi,:,ωi] .* transpose(core(χ₀)[qi,:,ωi]))
        end
    end
    return F
end


"""
    F_from_χ_star_gen(χ₀::χ₀T, χstar_r::Array{ComplexF64,4}, χr::χT, γr::γT, Ur::Float64)

Calculates the full vertex from the generalized susceptibility ``\\chi^{\\nu\\nu'\\omega}_r``, the physical susceptibility ``\\chi^{\\omega}_r`` and the triangular vertex ``\\gamma^{\\nu\\omega}_r``.
This is usefull to calculate a ``\\lambda``-corrected full vertex. 

``F^{\\nu\\nu'\\omega}_{r,\\mathbf{q}} 
     =
     \\beta^2 \\left( \\chi^{\\nu\\nu'\\omega}_{0,\\mathbf{q}} \\right)^{-1} 
     - \\beta^2 (\\chi^{\\nu\\omega}_{0,\\mathbf{q}})^{-1} \\chi^{*,\\nu\\nu'\\omega}_{r,\\mathbf{q}} (\\chi^{\\nu'\\omega}_{0,\\mathbf{q}})^{-1} 
    + U_r (1 - U_r \\chi^{\\omega}_{r,\\mathbf{q}}) \\gamma^{\\nu\\omega}_{r,\\mathbf{q}} \\gamma^{\\nu'\\omega}_{r,\\mathbf{q}}``
For a version using the physical susceptibilities see [`F_from_χ_gen`](@ref F_from_χ_gen).
"""
function F_from_χ_star_gen(χ₀::χ₀T, χstar_r::Array{ComplexF64,4}, χr::χT, γr::γT, Ur::Float64)
    F = similar(χstar_r)
    for ωi in 1:size(χstar_r,4)
        for qi in 1:size(χstar_r,3)
            F[:,:,qi,ωi] = Diagonal(χ₀.β^2 ./ core(χ₀)[qi,:,ωi]) .- χ₀.β^2 .* χstar_r[:,:,qi,ωi] ./ (core(χ₀)[qi,:,ωi] .* transpose(core(χ₀)[qi,:,ωi]))
            F[:,:,qi,ωi] +=  Ur * (1 - Ur * χr[qi,ωi]) .* (γr[qi,:,ωi] .* transpose(γr[qi,:,ωi]))
        end
    end
    return F
end

# ========================================== Correction Term =========================================
"""
    calc_λ0(χ₀::χ₀T, h::lDΓAHelper)
    calc_λ0(χ₀::χ₀T, Fr::FT, h::lDΓAHelper)
    calc_λ0(χ₀::χ₀T, Fr::FT, χ::χT, γ::γT, mP::ModelParameters, sP::SimulationParameters)

Correction term, TODO: documentation
"""
function calc_λ0(χ₀::χ₀T, h::lDΓAHelper)
    F_m   = F_from_χ(:m, h);
    calc_λ0(χ₀, F_m, h)
end

function calc_λ0(χ₀::χ₀T, Fr::FT, h::lDΓAHelper)
    calc_λ0(χ₀, Fr, h.χ_m_loc, h.γ_m_loc, h.mP, h.sP)
end

function calc_λ0(χ₀::χ₀T, Fr::FT, χ::χT, γ::γT, mP::ModelParameters, sP::SimulationParameters; improved_sums::Bool=true)
    #TODO: store nu grid in sP?
    Niν = size(Fr,1)
    Nq  = size(χ₀.data, χ₀.axis_types[:q])
    ω_range = 1:size(χ₀.data, χ₀.axis_types[:ω])
    λ0 = Array{ComplexF64,3}(undef,size(χ₀.data, χ₀.axis_types[:q]),Niν,length(ω_range))

    if improved_sums && typeof(sP.χ_helper) <: BSE_Asym_Helpers
       λ0[:] = calc_λ0_impr(:m, -sP.n_iω:sP.n_iω, Fr, χ₀.data, χ₀.asym, view(γ.data,1,:,:), view(χ.data,1,:),
                            mP.U, mP.β, sP.χ_helper)
    else
        #TODO: this is not well optimized, but also not often executed
        @warn "Using plain summation for λ₀, check Σ_ladder tails!"
        fill!(λ0, 0.0)
        for ωi in ω_range
            for νi in 1:Niν
                #TODO: export realview functions?
                v1 = view(Fr,νi,:,ωi)
                for qi in 1:Nq
                    v2 = view(χ₀.data,qi,(sP.n_iν_shell+1):(size(χ₀.data,2)-sP.n_iν_shell),ωi)
                    λ0[qi,:,ωi] = λ0[qi,:,ωi] .+ v1 .* v2 ./ mP.β^2
                end
            end
        end
    end
    return λ0
end

# ======================================== LadderDGA Functions =======================================
"""
    calc_bubble(Gνω::GνqT, Gνω_r::GνqT, kG::KGrid, mP::ModelParameters, sP::SimulationParameters; local_tail=false)
    calc_bubble(h::lDΓAHelper, kG::KGrid, mP::ModelParameters, sP::SimulationParameters; local_tail=false)

TODO: documentation
"""
function calc_bubble(h::lDΓAHelper; local_tail=false)
    calc_bubble(h.gLoc_fft, h.gLoc_rfft, h.kG, h.mP, h.sP, local_tail=local_tail)
end

function calc_bubble(Gνω::GνqT, Gνω_r::GνqT, kG::KGrid, mP::ModelParameters, sP::SimulationParameters; local_tail=false)
    #TODO: fix the size (BSE_SC inconsistency)
    data = Array{ComplexF64,3}(undef, length(kG.kMult), 2*(sP.n_iν+sP.n_iν_shell), 2*sP.n_iω+1)
    νdim = ndims(Gνω) > 2 ? length(gridshape(kG))+1 : 2 # TODO: this is a fallback for gImp
    for (ωi,ωn) in enumerate(-sP.n_iω:sP.n_iω)
        νrange = ((-(sP.n_iν+sP.n_iν_shell)):(sP.n_iν+sP.n_iν_shell-1)) .- trunc(Int,sP.shift*ωn/2)
        #TODO: fix the offset (BSE_SC inconsistency)
        for (νi,νn) in enumerate(νrange)
            conv_fft!(kG, view(data,:,νi,ωi), selectdim(Gνω,νdim,νn), selectdim(Gνω_r,νdim,νn+ωn))
            data[:,νi,ωi] .*= -mP.β
        end
    end
    #TODO: not necessary after real fft
    data = _eltype === Float64 ? real.(data) : data
    return χ₀T(data, kG, -sP.n_iω:sP.n_iω, sP.n_iν, sP.shift, mP, ν_shell_size=sP.n_iν_shell, local_tail=local_tail) 
end


"""
    calc_χγ(type::Symbol, h::lDΓAHelper, χ₀::χ₀T)
    calc_χγ(type::Symbol, Γr::ΓT, χ₀::χ₀T, kG::KGrid, mP::ModelParameters, sP::SimulationParameters)

Calculates susceptibility and triangular vertex in `type` channel. See [`calc_χγ_par`](@ref calc_χγ_par) for parallel calculation.

This method solves the following equation:
``
\\chi_r = \\chi_0 - \\frac{1}{\\beta^2} \\chi_0 \\Gamma_r \\chi_r \\\\
\\Leftrightarrow (1 + \\frac{1}{\\beta^2} \\chi_0 \\Gamma_r) = \\chi_0 \\\\
\\Leftrightarrow (\\chi^{-1}_r - \\chi^{-1}_0) = \\frac{1}{\\beta^2} \\Gamma_r
``
"""
function calc_χγ(type::Symbol, h::lDΓAHelper, χ₀::χ₀T)
    calc_χγ(type, getfield(h,Symbol("Γ_$(type)")), χ₀, h.kG, h.mP, h.sP)
end

function calc_χγ(type::Symbol, Γr::ΓT, χ₀::χ₀T, kG::KGrid, mP::ModelParameters, sP::SimulationParameters)
    #TODO: find a way to reduce initialization clutter: move lo,up to sum_helper
    #TODO: χ₀ should know about its tail c2, c3
    s = if type == :d 
        -1 
    elseif type == :m
        1
    else
        error("Unkown type")
    end

    Nν = 2*sP.n_iν
    Nq  = length(kG.kMult)
    Nω  = size(χ₀.data,χ₀.axis_types[:ω])
    #TODO: use predifened ranks for Nq,... cleanup definitions
    γ = Array{ComplexF64,3}(undef, Nq, Nν, Nω)
    χ = Array{Float64,2}(undef, Nq, Nω)

    νi_range = 1:Nν
    qi_range = 1:Nq

    χ_ω = Array{_eltype, 1}(undef, Nω)
    χννpω = Matrix{_eltype}(undef, Nν, Nν)
    ipiv = Vector{Int}(undef, Nν)
    work = _gen_inv_work_arr(χννpω, ipiv)
    λ_cache = Array{eltype(χννpω),1}(undef, Nν)
    
    for (ωi,ωn) in enumerate(-sP.n_iω:sP.n_iω)
        for qi in qi_range
            χννpω[:,:] = deepcopy(Γr[:,:,ωi])
            for l in νi_range
                χννpω[l,l] += 1.0/χ₀.data[qi,χ₀.ν_shell_size+l,ωi]
            end
            inv!(χννpω, ipiv, work)
            if typeof(sP.χ_helper) <: BSE_Asym_Helpers
                χ[qi, ωi] = real(calc_χλ_impr!(λ_cache, type, ωn, χννpω, view(χ₀.data,qi,:,ωi), 
                                               mP.U, mP.β, χ₀.asym[qi,ωi], sP.χ_helper));
                γ[qi, :, ωi] = (1 .- s*λ_cache) ./ (1 .+ s*mP.U .* χ[qi, ωi])
            else
                if typeof(sP.χ_helper) === BSE_SC_Helper
                    improve_χ!(type, ωi, view(χννpω,:,:,ωi), view(χ₀,qi,:,ωi), mP.U, mP.β, sP.χ_helper);
                end
                χ[qi,ωi] = real(sum(χννpω))/mP.β^2
                for νk in νi_range
                    γ[qi,νk,ωi] = sum(view(χννpω,:,νk))/(χ₀.data[qi,νk,ωi] * (1.0 + s*mP.U * χ[qi,ωi]))
                end
            end
        end
        #TODO: write macro/function for ths "real view" beware of performance hits
        #v = _eltype === Float64 ? view(χ,:,ωi) : @view reinterpret(Float64,view(χ,:,ωi))[1:2:end]
        v = view(χ,:,ωi)
        χ_ω[ωi] = kintegrate(kG, v)
    end
    log_q0_χ_check(kG, sP, χ, type)

    return χT(χ, mP.β, tail_c=[0,0,mP.Ekin_DMFT]), γT(γ)
end


"""
    calc_gen_χ(Γr::ΓT, χ₀::χ₀T, kG::KGrid)

Calculates generalized susceptibility from `Γr` by solving the Bethe Salpeter Equation. 
See [`calc_χγ`](@ref calc_χγ) for direct (and more efficient) calculation of physical susceptibility and triangular vertex.

Returns: ``\\chi^{\\nu\\nu'\\omega}_q`` as 4-dim array with axis: `νi, νpi, qi, ωi`.
"""
function calc_gen_χ(Γr::ΓT, χ₀::χ₀T, kG::KGrid)
    χννpω = similar(Γr, size(Γr,1), size(Γr,2), size(kG.kMult,1), size(Γr,3))
    ipiv = Vector{Int}(undef, size(Γr,1))
    work = _gen_inv_work_arr(χννpω[:,:,1,1], ipiv)
    
    for ωi in 1:size(Γr,3)
        for qi in 1:length(kG.kMult)
            χννpω[:,:,qi,ωi] = inv(deepcopy(Γr[:,:,ωi]) + 
                                    Diagonal(1.0 ./ χ₀.data[qi,
                                                                χ₀.ν_shell_size+1:end-χ₀.ν_shell_size,
                                                                ωi]
                                            ))
        end
    end

    return χννpω
end
