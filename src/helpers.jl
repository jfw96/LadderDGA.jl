# ==================================================================================================== #
#                                           helpers.jl                                                 #
# ---------------------------------------------------------------------------------------------------- #
#   Author          : Julian Stobbe                                                                    #
# ----------------------------------------- Description ---------------------------------------------- #
#   General purpose helper functions for the ladder DΓA code.                                          #
# -------------------------------------------- TODO -------------------------------------------------- #
#   Add documentation for all functions                                                                #
#   !!!!Cleanup of setup function!!!!                                                                  #
# ==================================================================================================== #



# ========================================== Index Functions =========================================
"""
    νnGrid(ωn::Int, sP::SimulationParameters)

Calculates grid of fermionic Matsubara frequencies for given bosonic frequency `ωn` (including shift, if set through `sP`).
"""
νnGrid(ωn::Int, sP::SimulationParameters) = ((-sP.n_iν-sP.n_iν_shell):(sP.n_iν+sP.n_iν_shell-1)) .- sP.shift * trunc(Int, ωn / 2)

"""
    q0_index(kG::KGrid)   

Index of zero k-vector.
"""
q0_index(kG::KGrid) = findfirst(x -> all(x .≈ zeros(length(gridshape(kG)))), kG.kGrid)

"""
    ω0_index(sP::SimulationParameters)
    ω0_index(χ::[χT or AbstractMatrix])

Index of ω₀ frequency. 
"""
ω0_index(sP::SimulationParameters) = sP.n_iω + 1
ω0_index(χ::χT) = ω0_index(χ.data)
ω0_index(χ::AbstractMatrix) = ceil(Int64, size(χ, 2) / 2)

"""
    OneToIndex_to_Freq(ωi::Int, νi::Int, sP::SimulationParameters)

Converts `(1:N,1:N)` index tuple for bosonic (`ωi`) and fermionic (`νi`) frequency to
Matsubara frequency number. If the array has a `ν` shell (for example for tail
improvements) this will also be taken into account by providing `Nν_shell`.
"""
function OneToIndex_to_Freq(ωi::Int, νi::Int, sP::SimulationParameters)
    ωn = ωi - sP.n_iω - 1
    νn = (νi - sP.n_iν - 1) - sP.shift * trunc(Int, ωn / 2)
    return ωn, νn
end

"""
    ν0Index_of_ωIndex(ωi::Int[, sP])::Int

Calculates index of zero fermionic Matsubara frequency (which may depend on the bosonic frequency). 
`ωi` is the index (i.e. starting with 1) of the bosonic Matsubara frequency.
"""
ν0Index_of_ωIndex(ωi::Int, sP::SimulationParameters)::Int = sP.n_iν + sP.shift * (trunc(Int, (ωi - sP.n_iω - 1) / 2)) + 1

"""
    νi_νngrid_pos(ωi::Int, νmax::Int, sP::SimulationParameters)

Indices for positive fermionic Matsubara frequencies, depinding on `ωi`, the index of the bosonic Matsubara frequency.
"""
function νi_νngrid_pos(ωi::Int, νmax::Int, sP::SimulationParameters)
    ν0Index_of_ωIndex(ωi, sP):νmax
end

# =========================================== Noise Filter ===========================================
"""
    filter_MA(m::Int, X::AbstractArray{T,1}) where T <: Number
    filter_MA!(res::AbstractArray{T,1}, m::Int, X::AbstractArray{T,1}) where T <: Number

Iterated moving average noise filter for inut data. See also [`filter_KZ`](@ref filter_KZ).
"""
function filter_MA(m::Int, X::AbstractArray{T,1}) where {T<:Number}
    res = deepcopy(X)
    offset = trunc(Int, m / 2)
    res[1+offset] = sum(@view X[1:m]) / m
    for (ii, i) in enumerate((2+offset):(length(X)-offset))
        res[i] = res[i-1] + (X[m+ii] - X[ii]) / m
    end
    return res
end

function filter_MA!(res::AbstractArray{T,1}, m::Int, X::AbstractArray{T,1}) where {T<:Number}
    offset = trunc(Int, m / 2)
    res[1+offset] = sum(@view X[1:m]) / m
    for (ii, i) in enumerate((2+offset):(length(X)-offset))
        res[i] = res[i-1] + (X[m+ii] - X[ii]) / m
    end
    return res
end

"""
    filter_KZ(m::Int, k::Int, X::AbstractArray{T,1}) where T <: Number

Iterated moving average noise filter for inut data. See also [`filter_MA`](@ref filter_MA).
"""
function filter_KZ(m::Int, k::Int, X::AbstractArray{T,1}) where {T<:Number}
    res = filter_MA(m, X)
    for ki in 2:k
        res = filter_MA!(res, m, res)
    end
    return res
end

# ======================================== Consistency Checks ========================================
"""
    log_q0_χ_check(kG::KGrid, sP::SimulationParameters, χ::AbstractArray{_eltype,2}, type::Symbol)

TODO: documentation
"""
function log_q0_χ_check(kG::KGrid, sP::SimulationParameters, χ::AbstractArray{Float64,2}, type::Symbol)
    q0_ind = q0_index(kG)
    if q0_ind != nothing
        #TODO: adapt for arbitrary ω indices
        ω_ind = setdiff(1:size(χ, 2), sP.n_iω + 1)
        @info "$type channel: |∑χ(q=0,ω≠0)| = $(round(abs(sum(view(χ,q0_ind,ω_ind))),digits=12)) ≟ 0"
    end
end

"""
    νi_health(νGrid::AbstractArray{Int}, sP::SimulationParameters)

Returns a list of available bosonic frequencies for each fermionic frequency, given in `νGrid`.
This can be used to estimate the maximum number of usefull frequencies for the equation of motion.
"""
function νi_health(νGrid::AbstractArray{Int}, sP::SimulationParameters)
    t = gen_ν_part(νGrid, sP, 1)[1]
    return [length(filter(x -> x[4] == i, t)) for i in unique(getindex.(t, 4))]
end
# ============================================== Misc. ===============================================

"""
    reduce_range(range::AbstractArray, red_prct::Float64)

Returns indices for 1D array slice, reduced by `red_prct` % (compared to initial `range`).
Range is symmetrically reduced fro mstart and end.
"""
function reduce_range(range::AbstractArray, red_prct::Float64)
    sub = floor(Int, length(range) / 2 * red_prct)
    lst = maximum([last(range) - sub, ceil(Int, length(range) / 2 + iseven(length(range)))])
    fst = minimum([first(range) + sub, ceil(Int, length(range) / 2)])
    return fst:lst
end

"""
    G_fft(G::GνqT, kG::KGrid, mP::ModelParameters, sP::SimulationParameters)

Calculates fast Fourier transformed lattice Green's functions used for [`calc_bubble`](@ref calc_bubble).
"""
function G_fft(G::GνqT, kG::KGrid, sP::SimulationParameters)

    gs = gridshape(kG)
    kGdims = length(gs)
    G_fft = OffsetArrays.Origin(repeat([1], kGdims)..., first(sP.fft_range))(Array{ComplexF64,kGdims + 1}(undef, gs..., length(sP.fft_range)))
    G_rfft = OffsetArrays.Origin(repeat([1], kGdims)..., first(sP.fft_range))(Array{ComplexF64,kGdims + 1}(undef, gs..., length(sP.fft_range)))
    G_fft!(G_fft, G, kG, sP.fft_range)
    G_rfft!(G_rfft, G, kG, sP.fft_range)
    return G_fft, G_rfft
end

function G_rfft!(G_rfft::GνqT, G::GνqT, kG::KGrid, fft_range::UnitRange)::Nothing
    νdim = length(gridshape(kG)) + 1
    for νn in fft_range
        expandKArr!(kG, G[:, νn].parent)
        reverse!(kG.cache1)
        fft!(kG.cache1)
        selectdim(G_rfft, νdim, νn) .= kG.cache1
    end
    return nothing
end

function G_fft!(G_fft::GνqT, G::GνqT, kG::KGrid, fft_range::UnitRange)::Nothing
    νdim = length(gridshape(kG)) + 1
    for νn in fft_range
        expandKArr!(kG, G[:, νn].parent)
        fft!(kG.cache1)
        selectdim(G_fft, νdim, νn) .= kG.cache1
    end
    return nothing
end
