var documenterSearchIndex = {"docs":
[{"location":"deps/","page":"Dependencies","title":"Dependencies","text":"There are two functionalities which have been factored out to separate projects: Handeling of frequency sums and operations involving k-grids.","category":"page"},{"location":"deps/#Frequency-Summations","page":"Dependencies","title":"Frequency Summations","text":"","category":"section"},{"location":"deps/","page":"Dependencies","title":"Dependencies","text":"The summation over Matsubara frequencies is defined over a set on infinitely many frequencies. A canonical approach to approximate this sum,","category":"page"},{"location":"deps/#K-Grids","page":"Dependencies","title":"K-Grids","text":"","category":"section"},{"location":"#LadderDGA.jl-Documentation","page":"Home","title":"LadderDGA.jl Documentation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = LadderDGA","category":"page"},{"location":"#Index","page":"Home","title":"Index","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"#List-of-Functions","page":"Home","title":"List of Functions","text":"","category":"section"},{"location":"#LadderDGA","page":"Home","title":"LadderDGA","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Modules = [LadderDGA]\nOrder   = [:module, :constant, :type, :function, :marco]","category":"page"},{"location":"#LadderDGA.EnvironmentVars","page":"Home","title":"LadderDGA.EnvironmentVars","text":"EnvironmentVars <: ConfigStruct\n\nContains various settings, controlling the I/O behaviour of this module. This is typically generated from a config.toml file using the readConfig function.\n\nFields\n\ninputDir        : String, Directory of input files\ninputVars       : String, File name of .jld2 file containing input.\nloglevel        : String, Options: disabled, error, warn, info, debug\nlogfile         : String,    Options: STDOUT, STDERR, filename\n\n\n\n\n\n","category":"type"},{"location":"#LadderDGA.ModelParameters","page":"Home","title":"LadderDGA.ModelParameters","text":"ModelParameters <: ConfigStruct\n\nContains model parameters for the Hubbard model. This is typically generated from a config.toml file using  the readConfig function.\n\nFields\n\nU         : Float64, Hubbard U\nμ         : Float64, chemical potential\nβ         : Float64, inverse temperature\nn         : Float64, filling\nsVk       : Float64, ∑_k Vₖ^2\nEpot_DMFT : Float64, DMFT potential energy\nEkin_DMFT : Float64, DMFT kinetic intergy\n\n\n\n\n\n","category":"type"},{"location":"#LadderDGA.SimulationParameters","page":"Home","title":"LadderDGA.SimulationParameters","text":"SimulationParameters <: ConfigStruct\n\nContains simulation parameters for the ladder DGA computations. This is typically generated from a config.toml file using the readConfig function.\n\nFields\n\nn_iω                    : Int, Number of positive bosonic frequencies (full number will be 2*n_iω+1 \nn_iν                    : Int, Number of positive fermionic frequencies (full number will be 2*n_iν \nn_iν_shell              : Int, Number of fermionic frequencies used for asymptotic sum improvement (χ_asym_r arrays with at least these many entries need to be provided)\nshift                   : Bool, Flag specifying if -n_iν:n_iν-1 is shifted by -ωₙ/2 at each ωₙ slice (centering the main features)\nχ_helper                : struct, helper struct for asymptotic sum improvements involving the generalized susceptibility (nothing if n_iν_shell == 0), see also BSE_SC.jl.\nfft_range               : Int, Frequencies used for computations of type f(νₙ + ωₙ). \nusable_prct_reduction   : Float64, percent reduction of usable bosonic frequencies\ndbg_full_eom_omega      : Bool, if true overrides usable ω ranges to n_iω.\n\n\n\n\n\n","category":"type"},{"location":"#LadderDGA.γT","page":"Home","title":"LadderDGA.γT","text":"γT <: MatsubaraFunction\n\nStruct for the non-local triangular vertex. \n\nFields\n\ndata         : Array{ComplexF64,3}, data\naxes         : Dict{Symbol,Int}, Dictionary mapping :q, :ν, :ω to the axis indices.\n\n\n\n\n\n","category":"type"},{"location":"#LadderDGA.χT","page":"Home","title":"LadderDGA.χT","text":"χT <: MatsubaraFunction\n\nStruct for the non-local susceptibilities. \n\nFields\n\ndata         : Array{ComplexF64,3}, data\naxes         : Dict{Symbol,Int}, Dictionary mapping :q, :ω to the axis indices.\nλ            : Float64, λ correction parameter.\nusable_ω     : AbstractArray{Int}, usable indices for which data is assumed to be correct. See also find_usable_interval\n\n\n\n\n\n","category":"type"},{"location":"#LadderDGA.χ₀T","page":"Home","title":"LadderDGA.χ₀T","text":"χ₀T <: MatsubaraFunction\n\nStruct for the bubble term. The q, ω dependent asymptotic behavior is computed from the  t1 and t2 input.\n\nFields\n\ndata         : Array{ComplexF64,3}, data\nasym         : Array{ComplexF64,2}, [q, ω] dependent asymptotic behavior.\naxes         : Dict{Symbol,Int}, Dictionary mapping :q, :ν, :ω to the axis indices.\n\n\n\n\n\n","category":"type"},{"location":"#Base.show-Tuple{IO, ModelParameters}","page":"Home","title":"Base.show","text":"Base.show(io::IO, m::ModelParameters)\n\nCustom output for ModelParameters\n\n\n\n\n\n","category":"method"},{"location":"#Base.show-Tuple{IO, SimulationParameters}","page":"Home","title":"Base.show","text":"Base.show(io::IO, m::SimulationParameters)\n\nCustom output for SimulationParameters\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.EPot1-Tuple{Dispersions.KGrid, AbstractMatrix{ComplexF64}, Matrix{ComplexF64}, Matrix{ComplexF64}, Vector{Float64}, Float64}","page":"Home","title":"LadderDGA.EPot1","text":"Specialized function for DGA potential energy. Better performance than calc_E.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.F_from_χ-Tuple{AbstractArray{ComplexF64, 3}, AbstractVector{ComplexF64}, SimulationParameters, Float64}","page":"Home","title":"LadderDGA.F_from_χ","text":"F_from_χ(χ::AbstractArray{ComplexF64,3}, G::AbstractArray{ComplexF64,1}, sP::SimulationParameters, β::Float64[; diag_term=true])\n\nTODO: documentation\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.G_from_Σ-Tuple{Int64, Vector{ComplexF64}, Union{Base.Generator, Vector{Float64}}, Float64, Float64}","page":"Home","title":"LadderDGA.G_from_Σ","text":"G_from_Σ(ind::Int64, Σ::Array{ComplexF64,[1,2,3]}, ϵkGrid, β, μ)\nG_from_Σ(freq::[Int64 or ComplexF64], β::Float64, μ::Float64, ϵₖ::Float64, Σ::ComplexF64)\n\nConstructs GF from k-independent self energy, using the Dyson equation and the dispersion relation of the lattice.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.OneToIndex_to_Freq-Tuple{Int64, Int64, SimulationParameters, Any}","page":"Home","title":"LadderDGA.OneToIndex_to_Freq","text":"OneToIndex_to_Freq(ωi::Int, νi::Int, sP::SimulationParameters [, Nν_shell])\n\nConverts (1:N,1:N) index tuple for bosonic (ωi) and fermionic (νi) frequency to Matsubara frequency number. If the array has a ν shell (for example for tail improvements) this will also be taken into account by providing Nν_shell.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.calc_E_ED-Tuple{String}","page":"Home","title":"LadderDGA.calc_E_ED","text":"calc_E_ED(ϵₖ::Vector{Float64}, Vₖ::Vector{Float64}, GImp::Vector{ComplexF64}, U, n, μ, β)\ncalc_E_ED(ϵₖ::Vector{Float64}, Vₖ::Vector{Float64}, GImp::Vector{ComplexF64}, mP::ModelParameters)\ncalc_E_ED(fname::String)\n\nComputes kinetic and potential energies from Anderson parameters.\n\nReturns:\n\n(EKin, EPot): Tuple{Float64,Float64}, kinetic and potential energy.\n\nArguments:\n\nfname : jld2-file containing the fields: [gImp, β, ϵₖ, Vₖ, U, nden, μ] (see below)\nϵₖ    : bath levels\nVₖ    : hoppend amplitudes\nGImp  : impurity Green's function. WARNING: the arguments are assumed to by fermionic Matsuabra indices 0:length(GImp)-1!\nU     : Coulomb interaction strength\nn     : number density\nμ     : chemical potential\nβ     : inverse temperature\nmP    : Alternative call with model parameters as Float64. See also ModelParameters.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.calc_bubble_par-Tuple{OffsetArrays.OffsetMatrix{ComplexF64, Matrix{ComplexF64}}, OffsetArrays.OffsetMatrix{ComplexF64, Matrix{ComplexF64}}, Dispersions.KGrid, ModelParameters, SimulationParameters}","page":"Home","title":"LadderDGA.calc_bubble_par","text":"calc_bubble(Gνω::GνqT, Gνω_r::GνqT, kG::KGrid, mP::ModelParameters, sP::SimulationParameters; local_tail=false)\n\nCalculates the bubble, based on two fourier-transformed Greens functions where the second one has to be reversed.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.calc_χγ_par-Tuple{Symbol, Array{ComplexF64, 3}, χ₀T, Dispersions.KGrid, ModelParameters, SimulationParameters}","page":"Home","title":"LadderDGA.calc_χγ_par","text":"calc_χ_trilex(Γr::ΓT, χ₀, kG::KGrid, U::Float64, mP, sP)\n\nSolve χ = χ₀ - 1/β² χ₀ Γ χ ⇔ (1 + 1/β² χ₀ Γ) χ = χ₀ ⇔      (χ⁻¹ - χ₀⁻¹) = 1/β² Γ\n\nwith indices: χ[ω, q] = χ₀[]\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.find_usable_χ_interval-Tuple{Vector{Float64}}","page":"Home","title":"LadderDGA.find_usable_χ_interval","text":"find_usable_χ_interval(χ_ω::Array{Float64,1}; sum_type::Union{Symbol,Tuple{Int,Int}}=:common, reduce_range_prct::Float64 = 0.1)\n\nDetermines usable range for physical susceptibilities chi^omega and additionally cut away reduce_range_prct % of the range. The unusable region is given whenever the susceptibility becomes negative, or the first derivative changes sign.\n\nReturns:\n\nrange::AbstractVector{Float64} : Usable omega range for chi\n\nArguments:\n\nχ_ω                : chi^omega \nsum_type           : Optional, default :common. Can be set to :full to enforce full range, or a ::Tuple{Int,Int} to enforce a specific interval size.\nreduce_range_prct  : Optional, default 0.1. After finding the usable interval it is reduced by an additional percentage given by this value.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.flatten_gLoc-Tuple{AbstractArray}","page":"Home","title":"LadderDGA.flatten_gLoc","text":"flatten_gLoc(kG::KGrid, arr::AbstractArray{AbstractArray})\n\ntransform Array{Array,1}(Nf) of Arrays to Array of dim (Nk,Nk,...,Nf). Number of dimensions depends on grid shape.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.iν_array-Tuple{Real, AbstractVector{Int64}}","page":"Home","title":"LadderDGA.iν_array","text":"iν_array(β::Real, grid::AbstractArray{Int64,1})::Vector{ComplexF64}\niν_array(β::Real, size::Int)::Vector{ComplexF64}\n\nComputes list of fermionic Matsubara frequencies. If length size is given, the grid will have indices 0:size-1. Bosonic arrays can be generated with iω_array.\n\nReturns:\n\nVector of fermionic Matsubara frequencies, given either a list of indices or a length. \n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.iω_array-Tuple{Real, AbstractVector{Int64}}","page":"Home","title":"LadderDGA.iω_array","text":"iω_array(β::Real, grid::AbstractArray{Int64,1})::Vector{ComplexF64}\niω_array(β::Real, size::Int)::Vector{ComplexF64}\n\nComputes list of bosonic Matsubara frequencies. If length size is given, the grid will have indices 0:size-1. Fermionic arrays can be generated with iν_array.\n\nReturns:\n\nVector of bosonic Matsubara frequencies, given either a list of indices or a length. \n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.log_q0_χ_check-Tuple{Dispersions.KGrid, SimulationParameters, AbstractMatrix{ComplexF64}, Symbol}","page":"Home","title":"LadderDGA.log_q0_χ_check","text":"log_q0_χ_check(kG::KGrid, sP::SimulationParameters, χ::AbstractArray{_eltype,2}, type::Symbol)\n\nTODO: documentation\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.par_partition-Tuple{AbstractVector, Int64}","page":"Home","title":"LadderDGA.par_partition","text":"par_partition(set::AbstractVector, N::Int)\n\nReturns list of indices for partition of set into N (almost) equally large segements.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.printr_s-Tuple{ComplexF64}","page":"Home","title":"LadderDGA.printr_s","text":"printr_s(x::ComplexF64)\nprintr_s(x::Float64)\n\nprints 4 digits of (the real part of) x\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.readConfig-Tuple{String}","page":"Home","title":"LadderDGA.readConfig","text":"readConfig(cfg_in::String)\n\nReads a config.toml file either as string or from a file and returns      - workerpool     - ModelParameters     - SimulationParameters     - EnvironmentVars     - kGrid (see Dispersions.jl)\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.readFortranχDMFT-Tuple{String}","page":"Home","title":"LadderDGA.readFortranχDMFT","text":"Returns χ_DMFT[ω, ν, ν']\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.setup_LDGA-Tuple{Tuple{String, Int64}, ModelParameters, SimulationParameters, EnvironmentVars}","page":"Home","title":"LadderDGA.setup_LDGA","text":"setup_LDGA(kGridStr::Tuple{String,Int}, mP::ModelParameters, sP::SimulationParameters, env::EnvironmentVars [; local_correction=true])\n\nComputes all needed objects for DΓA calculations. Returns:     ΣladderLoc, Σloc, impdensity, kGrid, gLocfft, gLocrfft, Γsp, Γch, χDMFTsp, χDMFTch, χsploc, γsploc, χchloc, γch_loc, χ₀Loc, gImp\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.subtract_tail!-Union{Tuple{T}, Tuple{AbstractVector{T}, AbstractVector{T}, Float64, Vector{ComplexF64}}} where T<:Number","page":"Home","title":"LadderDGA.subtract_tail!","text":"subtract_tail!(outp::AbstractArray{T,1}, inp::AbstractArray{T,1}, c::Float64, iω::Array{ComplexF64,1}) where T <: Number\n\nsubtract the c/(iω)^2 high frequency tail from inp and store in outp. See also subtract_tail\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.subtract_tail-Union{Tuple{T}, Tuple{AbstractVector{T}, Float64, Vector{ComplexF64}}} where T<:Number","page":"Home","title":"LadderDGA.subtract_tail","text":"subtract_tail(inp::AbstractArray{T,1}, c::Float64, iω::Array{ComplexF64,1}) where T <: Number\n\nsubtract the c/(iω)^2 high frequency tail from inp.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.to_m_index-Union{Tuple{T}, Tuple{AbstractArray{T, 3}, SimulationParameters}} where T","page":"Home","title":"LadderDGA.to_m_index","text":"to_m_index(arr::AbstractArray{T,2/3}, sP::SimulationParameters)\n\nConverts array with simpel 1:N index to larger array, where the index matches the Matsubara Frequency number. This function is not optimized!\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.Δ-Tuple{Vector{Float64}, Vector{Float64}, Vector{ComplexF64}}","page":"Home","title":"LadderDGA.Δ","text":"Δ(ϵₖ::Vector{Float64}, Vₖ::Vector{Float64}, νₙ::Vector{ComplexF64})::Vector{ComplexF64}\n\nComputes hybridization function Delta(inu_n) = sum_k fracV_k^2nu_n - epsilon_k from Anderson parameters (for example obtained through exact diagonalization).\n\nReturns:\n\nHybridization function  over list of given fermionic Matsubara frequencies.\n\nArguments:\n\nϵₖ : list of bath levels\nVₖ : list of hopping amplitudes\nνₙ : Vector of fermionic Matsubara frequencies, see also: iν_array.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.λ_from_γ-Tuple{Symbol, γT, χT, Float64}","page":"Home","title":"LadderDGA.λ_from_γ","text":"λ_from_γ(type::Symbol, γ::γT, χ::χT, U::Float64)\n\nTODO: documentation\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.ω_tail-Tuple{χT, χT, AbstractVector{Float64}, SimulationParameters}","page":"Home","title":"LadderDGA.ω_tail","text":"ω_tail(ωindices::AbstractVector{Int}, coeffs::AbstractVector{Float64}, sP::SimulationParameters) \nω_tail(χ_sp::χT, χ_ch::χT, coeffs::AbstractVector{Float64}, sP::SimulationParameters)\n\n\n\n\n\n","category":"method"},{"location":"#LambdaCorrection","page":"Home","title":"LambdaCorrection","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This sub-module contains function related to the lambda-correction.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [LambdaCorrection]\nOrder   = [:module, :constant, :type, :function, :marco]","category":"page"},{"location":"#LadderDGA.LambdaCorrection.bisect-NTuple{4, Float64}","page":"Home","title":"LadderDGA.LambdaCorrection.bisect","text":"bisect(λl::T, λm::T, λr::T, Fm::T)::Tuple{T,T} where T <: Union{Float64, Vector{Float64}}\n\nWARNING: Not properly tested! Bisection root finding algorithm. This is a very crude adaption of the 1D case.  The root may therefore lie outside the given region and the search space has to be corrected using correct_margins.\n\nReturns:\n\n(Vector of) new interval borders, according to Fm.\n\nArguments:\n\nλl : (Vector of) left border(s) of bisection area\nλm : (Vector of) central border(s) of bisection area\nλr : (Vector of) right border(s) of bisection area\nFm : (Vector of) Poincare-Miranda condition (s)\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.correct_margins-NTuple{4, Float64}","page":"Home","title":"LadderDGA.LambdaCorrection.correct_margins","text":"correct_margins(λl::T, λm::T, λr::T, Fm::T, Fr::T)::Tuple{T,T} where T <: Union{Float64, Vector{Float64}}\n\nHelper method for bisect.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.dχ_λ-Union{Tuple{T}, Tuple{T, Float64}} where T<:Union{Float64, ComplexF64}","page":"Home","title":"LadderDGA.LambdaCorrection.dχ_λ","text":"dχ_λ(χ::[Float64,ComplexF64,AbstractArray], λ::Float64)\n\nFirst derivative of χ_λ.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.find_lin_interp_root-Tuple{AbstractVector{Float64}, AbstractVector{Float64}}","page":"Home","title":"LadderDGA.LambdaCorrection.find_lin_interp_root","text":"find_lin_interp_root(xdata::AbstractVector{Float64}, ydata::AbstractVector{Float64})\n\nWARNING: this is a specialiazed function which assumes strictly monotonic data! Given sampled xdata and ydata, find the root using linear interpolation. Returns estimated x₀.\n\nReturns:\n\nx₀ : Float64, root of sampled function data.\n\nArguments:\n\nxdata : x-data of samples from strictly monotonic decreasing function.\nydata : y-data of samples from strictly monotonic decreasing function\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.find_root-Tuple{Matrix{Float64}}","page":"Home","title":"LadderDGA.LambdaCorrection.find_root","text":"find_root(c2_data::Array{Float64,2})\n\nDetermines\n\nReturns:\n\nArguments:\n\nc2_data : Matrix{Float64}, data from TODO ref\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.get_λ_min-Tuple{AbstractMatrix{Float64}}","page":"Home","title":"LadderDGA.LambdaCorrection.get_λ_min","text":"get_λ_min(χr::AbstractArray{Float64,2})::Float64\n\nComputes the smallest possible lambda-correction parameter (i.e. first divergence of chi(q)), given as lambda_textmin = - min_q(1  chi^omega_0_q).\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.newton_right-Tuple{Function, Function, Float64}","page":"Home","title":"LadderDGA.LambdaCorrection.newton_right","text":"newton_right(f::Function, df::Function, start::[Float64,Vector{Float64}; nsteps=5000, atol=1e-11)\n\nWARNING: Not properly tested! This is an adaption of the traditional Newton root finding algorithm, searching  only to the right of start.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.χ_λ!-Tuple{χT, χT, Float64}","page":"Home","title":"LadderDGA.LambdaCorrection.χ_λ!","text":"χ_λ!(χ_destination::[AbstractArray,χT], [χ::[AbstractArray,χT], ] λ::Float64)\n\nInplace version of χ_λ. If the second argument is omitted, results are stored in the input data structure.\n\n\n\n\n\n","category":"method"},{"location":"#LadderDGA.LambdaCorrection.χ_λ-Union{Tuple{T}, Tuple{T, Float64}} where T<:Union{Float64, ComplexF64}","page":"Home","title":"LadderDGA.LambdaCorrection.χ_λ","text":"χ_λ(χ::[Float64,ComplexF64,AbstractArray,χT], λ::Float64)\n\nComputes the λ-corrected susceptibility:  chi^lambdaomega_q = frac11  chi^lambdaomega_q + lambda. The susceptibility chi can be either given element wise, or as χT See also χT in LadderDGA.jl.\n\n\n\n\n\n","category":"method"}]
}
