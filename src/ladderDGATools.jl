#TODO: define GF type that knows about which dimension stores which variable
using Base.Iterators


function calc_bubble(νGrid::Vector{AbstractArray}, Gνω::SharedArray{Complex{Float64},2}, Nq::Int64, 
                         mP::ModelParameters, sP::SimulationParameters)
    res = SharedArray{Complex{Float64},3}(2*sP.n_iω+1,Nq,2*sP.n_iν)
    gridShape = (Nq == 1) ? [1] : repeat([sP.Nk], mP.D)
    norm = (Nq == 1) ? -mP.β : -mP.β /(sP.Nk^(mP.D));
    transform = (Nq == 1) ? identity : reduce_kGrid ∘ ifft_cut_mirror ∘ ifft ∘ (x->reshape(x, gridShape...))
    @sync @distributed for ωi in 1:length(νGrid)
        for (j,νₙ) in enumerate(νGrid[ωi])
            v1 = view(Gνω, νₙ+sP.n_iω, :)
            v2 = view(Gνω, νₙ+ωi-1, :)
            res[ωi,:,j] .= norm .* transform(v1 .* v2)
        end
    end
    return res#SharedArray(permutedims(reshape(res,(2*sP.n_iν,2*sP.n_iω+1,Nq)),(2,3,1)))
end

"""
Solve χ = χ₀ - 1/β² χ₀ Γ χ
    ⇔ (1 + 1/β² χ₀ Γ) χ = χ₀
    ⇔      (χ⁻¹ - χ₀⁻¹) = 1/β² Γ
    with indices: χ[ω, q] = χ₀[]
"""
function calc_χ_trilex(Γr::SharedArray{Complex{Float64},3}, bubble::SharedArray{Complex{Float64},3}, 
                       qMultiplicity::Array{Float64,1}, νGrid, fitKernels, U::Float64,
                       mP::ModelParameters, sP::SimulationParameters)
    χ = SharedArray{eltype(bubble), 2}((size(bubble)[1:2]...))
    γ = SharedArray{eltype(bubble), 3}((size(bubble)...))
    χ_ω = SharedArray{eltype(bubble), 1}(size(bubble)[1])  # ωₙ (summed over νₙ and ωₙ)


    indh = ceil(Int64, size(bubble,1)/2)
    ωindices = sP.fullChi ? 
        (1:size(bubble,1)) : 
        [(i == 0) ? indh : ((i % 2 == 0) ? indh+floor(Int64,i/2) : indh-floor(Int64,i/2)) for i in 1:size(bubble,1)]

    @sync @distributed for ωi in ωindices
        νIndices = 1:size(bubble,3)
        fitKernel = fitKernels[default_fit_range(length(νIndices))]

        Γview = view(Γr,ωi,νIndices,νIndices)
        UnitM = Matrix{eltype(Γr)}(I, length(νIndices),length(νIndices))
        for qi in 1:size(bubble, 2)
            bubble_i = view(bubble,ωi, qi, νIndices)
            bubbleD = Diagonal(bubble_i)
            χ_full = (bubbleD * Γview + UnitM)\bubbleD
            @inbounds χ[ωi, qi] = sum_freq(χ_full, [1,2], sP.tc_type, mP.β, weights=fitKernel)[1,1]
            @inbounds γ[ωi, qi, νIndices] .= sum_freq(χ_full, [2], :nothing, 1.0, weights=fitKernel)[:,1] ./ (bubble_i * (1.0 + U * χ[ωi, qi]))
        end
        χ_ω[ωi] = sum_q(χ[ωi,:], qMultiplicity)[1]
        if (!sP.fullChi)
            usable = find_usable_interval(real(χ_ω))
            first(usable) > ωi && break
        end
    end
    usable = find_usable_interval(real(χ_ω), reduce_range_prct=0.05)
    # if sP.tc_type != :nothing
    #    γ = convert(SharedArray, mapslices(x -> extend_γ(x, find_usable_γ(x)), γ, dims=[3]))
    # end
    return NonLocalQuantities(χ, γ, usable, 0.0)
end


function Σ_internal2!(tmp, ωindices, bubble::BubbleT, FUpDo, tc_type::Symbol, Wν)
    @sync @distributed for ωi in 1:length(ωindices)
        ωₙ = ωindices[ωi]
        for qi in 1:size(bubble,2)
            for νi in 1:size(tmp,3)
                val = bubble[ωₙ,qi,:] .* FUpDo[ωₙ,νi,:]
                @inbounds tmp[ωi, qi, νi] = sum_freq(val, [1], tc_type, 1.0, weights=Wν)[1]
            end
        end
    end
end

function Σ_internal!(Σ, ωindices, ωZero, νZero, shift, χsp, χch, γsp, γch, Gνω,
                     tmp, U,transformG, transformK, transform)
    @sync @distributed for ωi in 1:length(ωindices)
        ωₙ = ωindices[ωi]
        @inbounds f1 = 1.5 .* (1 .+ U*χsp[ωₙ, :])
        @inbounds f2 = 0.5 .* (1 .- U*χch[ωₙ, :])
        νZerop = νZero + shift*(trunc(Int64,(ωₙ - ωZero - 1)/2) + 1)
        for νi in 1:size(Σ,3)
            @inbounds val = γsp[ωₙ, :, νZerop+νi] .* f1 .- γch[ωₙ, :, νZerop+νi] .* f2 .- 1.5 .+ 0.5 .+ tmp[ωi,:,νZerop+νi]
            Kνωq = transformK(val)
            @inbounds Σ[ωi,:, νi] = transform(Kνωq .* transformG(view(Gνω,νZero + νi + ωₙ - 1,:)))
        end
    end
end

function calc_Σ(Q_sp::NonLocalQuantities, Q_ch::NonLocalQuantities, bubble::BubbleT,
                        Gνω::GνqT, FUpDo::Array{Complex{Float64},3}, qIndices::Vector,
                        Nk::Int64,
                        fitKernels_fermions, fitKernels_bosons,
                        mP::ModelParameters, sP::SimulationParameters)
    gridShape = (Nk == 1) ? [1] : repeat([sP.Nk], mP.D)
    transform = (Nk == 1) ? identity : reduce_kGrid ∘ ifft_cut_mirror ∘ ifft
    transformG(x) = reshape(x, gridShape...)
    transformK(x) = (Nk == 1) ? identity(x) : fft(expand_kGrid(qIndices, x))
    νZero = sP.n_iν
    ωZero = sP.n_iω
    νSize = length(νZero:size(Q_ch.γ,3))
    ωindices = sP.fullωRange_Σ ? (1:size(bubble,1)) : intersect(Q_sp.usable_ω, Q_ch.usable_ω)

    Σ_ladder_ω = SharedArray{Complex{Float64},3}(length(ωindices), length(qIndices), trunc(Int,sP.n_iν-sP.shift*sP.n_iω/2))
    tmp = SharedArray{Complex{Float64},3}(length(ωindices), size(bubble,2), size(bubble,3))

    fk_f = nothing #fitKernels_fermions[default_fit_range(νSize)]
    Σ_internal2!(tmp, ωindices, bubble, FUpDo, :nothing, fk_f)
    Σ_internal!(Σ_ladder_ω, ωindices, ωZero, νZero, sP.shift, Q_sp.χ, Q_ch.χ,
        Q_sp.γ, Q_ch.γ,Gνω, tmp, mP.U, transformG, transformK, transform)
    #fitKernels_bosons[default_fit_range(length(ωindices))]
    res = permutedims( mP.U .* sum_freq(Σ_ladder_ω, [1], :nothing, mP.β, weights=nothing)[1,:,:] ./ (Nk^mP.D), [2,1])
    return  res
end
