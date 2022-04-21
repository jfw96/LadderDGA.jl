# ==================================================================================================== #
#                                                                                                      #
#                                          Helper Functions                                            #
#                                                                                                      #
# ==================================================================================================== #
#TODO: document, file is missleading, can also be a string
#TODO: many of the fortran functions have the old axis layout (omega axis first instead of last, update that
function readConfig(cfg_in)
    @info "Reading Inputs..."

    cfg_is_file = true
    try 
        cfg_is_file = isfile(cfg_in)
    catch e
        cfg_is_file = false
    end
    tml = if cfg_is_file
        TOML.parsefile(cfg_in)
    else
        TOML.parse(cfg_in)
    end
    sim = tml["Simulation"]
    χfill = nothing
    rr = r"^fixed:(?P<start>\N+):(?P<stop>\N+)"
    tc_type_f = Symbol(lowercase(tml["Simulation"]["fermionic_tail_correction"]))
    if !(tc_type_f in [:nothing, :richardson, :shanks])
        error("Unrecognized tail correction type \"$(tc_type_f)\"")
    end
    tc_type_b = Symbol(lowercase(tml["Simulation"]["bosonic_tail_correction"]))
    if !(tc_type_b in [:nothing, :richardson, :shanks, :coeffs])
        error("Unrecognized tail correction type \"$(tc_type_b)\"")
    end
    ωsum_inp = lowercase(tml["Simulation"]["bosonic_sum_range"])
    m = match(rr, ωsum_inp)
    ωsum_type = if m !== nothing
        tuple(parse.(Int, m.captures)...)
    elseif ωsum_inp in ["common", "individual", "full"]
        Symbol(ωsum_inp)
    else
        error("Could not parse bosonic_sum. Allowed input is: common, individual, full, fixed:N:M")
    end
    smoothing = Symbol(lowercase(tml["Simulation"]["omega_smoothing"]))
    if !(smoothing in [:nothing, :range, :full])
        error("Unrecognized smoothing type \"$(smoothing)\"")
    end
    λrhs_type = Symbol(lowercase(tml["Simulation"]["rhs"]))
    !(λrhs_type in [:native, :fixed, :error_comp]) && error("Could not parse rhs type for lambda correction. Options are native, fixed, error_comp.")
    dbg_full_eom_omega = (haskey(tml["Debug"], "full_EoM_omega") && tml["Debug"]["full_EoM_omega"]) ? true : false

    if haskey(tml["Environment"], "nthread")
        tml["Environment"]["nthreads"] != "nlogical" && @warn "number of threads config not implemented yet!"
    end

    env = EnvironmentVars(   tml["Environment"]["inputDataType"],
                             tml["Environment"]["writeFortran"],
                             tml["Environment"]["inputDir"],
                             tml["Environment"]["freqFile"],
                             tml["Environment"]["inputVars"],
                             tml["Environment"]["cast_to_real"],
                             String([(i == 1) ? uppercase(c) : lowercase(c)
                                     for (i, c) in enumerate(tml["Environment"]["loglevel"])]),
                             lowercase(tml["Environment"]["logfile"]),
                             tml["Environment"]["progressbar"]
                            )

    mP, χsp_asympt, χch_asympt, χpp_asympt = jldopen(env.inputDir*"/"*env.inputVars, "r") do f
        EPot_DMFT = 0.0
        EKin_DMFT = 0.0
        if haskey(f, "E_kin_DMFT")
            EPot_DMFT = f["E_pot_DMFT"]
            EKin_DMFT = f["E_kin_DMFT"]
        else
            @warn "Could not find E_kin_DMFT, E_pot_DMFT key in input"
        end
        U, μ, β, nden, Vk = if haskey(f, "U")
            @warn "Found Hubbard Parameters in input .jld2, ignoring config.toml"
            f["U"], f["μ"], f["β"], f["nden"], f["Vₖ"]
        else
            @warn "reading Hubbard Parameters from config. These should be supplied through the input jld2!"
            tml["Model"]["U"], tml["Model"]["mu"], tml["Model"]["beta"], tml["Model"]["nden"], f["Vₖ"]
        end
        ModelParameters(U, μ, β, nden, sum(Vk.^2), EPot_DMFT, EKin_DMFT), 
        f["χ_sp_asympt"] ./ f["β"]^2, f["χ_ch_asympt"] ./ f["β"]^2, f["χ_pp_asympt"] ./ f["β"]^2
    end
    nBose, nFermi, shift = if !isfile(env.freqFile)
        @warn "Frequency file not found, reconstructing grid from config."
        m = match(r"b(?<bf>\d+)f(?<ff>\d+)s(?<s>\d)",env.freqFile)
        parse(Int, m[:bf]), parse(Int, m[:ff]), parse(Int, m[:s])
    else
        freqFilePath = env.freqFile
        load(freqFilePath, "nBose"), load(freqFilePath, "nFermi"), load(freqFilePath, "shift")
    end
    #TODO: BSE inconsistency between direct and SC
    asympt_sc = lowercase(tml["Simulation"]["chi_asympt_method"]) == "asympt" ? 1 : 0
    Nν_shell  = tml["Simulation"]["chi_asympt_shell"]
    Nν_full = nFermi + asympt_sc*Nν_shell
    sh_f = get_sum_helper(default_fit_range(-Nν_full:Nν_full-1), tml["Simulation"]["fermionic_tail_coeffs"], tc_type_f)
    freq_r = 2*(Nν_full+nBose)#+shift*ceil(Int, nBose)
    fft_range = -freq_r:freq_r
    lo = npartial_sums(sh_f)
    up = 2*Nν_full - lo + 1 

    # chi asymptotics

    χ_helper = if lowercase(tml["Simulation"]["chi_asympt_method"]) == "asympt"
                    BSE_SC_Helper(χsp_asympt, χch_asympt, χpp_asympt, 2*Nν_full, Nν_shell, nBose, Nν_full, shift)
                elseif lowercase(tml["Simulation"]["chi_asympt_method"]) == "direct"
                    BSE_Asym_Helper(χsp_asympt, χch_asympt, χpp_asympt, Nν_shell, mP.U, mP.β, nBose, nFermi, shift)
                elseif lowercase(tml["Simulation"]["chi_asympt_method"]) == "direct_approx2"
                    BSE_Asym_Helper_Approx2(Nν_shell)
                elseif lowercase(tml["Simulation"]["chi_asympt_method"]) == "nothing"
                    nothing
                else
                    @error "could not parse chi_asympt_method $(tml["Simulation"]["chi_asympt_method"]). Options are: asympt/direct/nothing"
                    nothing
                end

    sEH = if ((tc_type_f == :richardson) || (tc_type_b == :richardson)) 
        SumExtrapolationHelper(
                           tml["Simulation"]["bosonic_tail_coeffs"],
                           tml["Simulation"]["fermionic_tail_coeffs"],
                           smoothing,
                           sh_f,
                           lo,
                           up,
                           Array{Float64, 1}(undef, lo),
                           Array{ComplexF64, 1}(undef, lo))
    else
        nothing
    end

    sP = SimulationParameters(nBose,nFermi,Nν_shell,shift,
                               tc_type_f,
                               tc_type_b,
                               χ_helper,
                               ωsum_type,
                               λrhs_type,
                               tml["Simulation"]["force_full_bosonic_chi"],
                               fft_range,
                               tml["Simulation"]["usable_prct_reduction"],
                               dbg_full_eom_omega,
                               sEH
    )
    kGrids = Array{Tuple{String,Int}, 1}(undef, length(tml["Simulation"]["Nk"]))
    for i in 1:length(tml["Simulation"]["Nk"])
        Nk = tml["Simulation"]["Nk"][i]
        kGrids[i] = (tml["Model"]["kGrid"], Nk)
    end
    return mP, sP, env, kGrids
end

function convertGF!(GF, storedInverse, storeFull)
    if storedInverse
        GF = 1 ./ GF
    end
    if storeFull
        NH = size(GF, 1)
        tmp = copy(GF)
        GF = Array{eltype(GF)}(undef, 2*NH - 1)
        GF[1:(NH-1)] = reverse(conj.(tmp[2:NH]))
        GF[NH:end] = tmp[1:NH]
    end
end

function print_chi_bubble(qList, res, simParams)
    for j in 1:size(res,1)
        print(" ========== ω = $(j-(simParams.n_iω + 1)) =============== \n")
        for k in 1:size(res,2)
            print(" ---------- ν = $(k-1) -------------- \n")
            for (qi,q) in enumerate(qList)
                @printf("   q = (%.2f,%.2f): %.2f + %.2fi\n", q[1],q[2], real(res[j, k, qi]), imag(res[j, k, qi]))
            end
        end
    end
end

function reduce_3Freq(inp, freqBox, simParams)
    n_iω = simParams.n_iω
    n_iν = simParams.n_iν
    start_ωₙ =  -(freqBox[1,1] + n_iω) + 1
    start_νₙ =  -(freqBox[2,1] + n_iν) + 2

    if (length(start_ωₙ:(start_ωₙ+2*n_iω)) != size(inp,1)) ||
       (length(start_νₙ:(start_νₙ + 2*n_iν - 1)) != size(inp,2))
        @error "Input frequency range does not match input data. This can lead to wrong results! Input size: ", size(inp),
        " got ", length(start_ωₙ:(start_ωₙ+2*n_iω)), ",", length(start_νₙ:(start_νₙ + 2*n_iν - 1))
    end
    # This selects the range of [-ωₙ, ωₙ] and [-νₙ, νₙ-1] from gamma
    return inp[start_ωₙ:(start_ωₙ+2*n_iω), start_νₙ:(start_νₙ + 2*n_iν - 1), start_νₙ:(start_νₙ +2*n_iν - 1)]
end

reduce_3Freq!(inp, freqBox, simParams) = inp = reduce_3Freq(inp, freqBox, simParams)


function convert_from_fortran(simParams, env, loadFromBak=false)
    @info "Reading Fortran Input, this can take several minutes."
        g0 = readFortranSymmGF(simParams.n_iν+2*simParams.n_iω, env.inputDir*"/g0mand", storedInverse=true)
        gImp = readFortranSymmGF(simParams.n_iν+2*simParams.n_iω, env.inputDir*"/gm_wim", storedInverse=false)
        freqBox, Γch, Γsp = readFortranΓ(env.inputDir*"/gamma_dir")
        @info "Done Reading Gamma"
        χDMFTch, χDMFTsp = readFortranχDMFT(env.inputDir*"/chi_dir")
        @info "Done Reading chi"
    Γch = -1.0 .* reduce_3Freq(Γch, freqBox, simParams)
    Γsp = -1.0 .* reduce_3Freq(Γsp, freqBox, simParams)
    χDMFTch = reduce_3Freq(χDMFTch, freqBox, simParams)
    χDMFTsp = reduce_3Freq(χDMFTsp, freqBox, simParams)
    if env.writeFortran
        @info "Writing HDF5 (vars.jdl) and Fortran (fortran_out/) output."
        writeFortranΓ("fortran_out", "gamma", simParams, Γch, Γsp)
        writeFortranΓ("fortran_out", "chi", simParams, 0.5 .* (χDMFTch .+ χDMFTsp), 0.5 .* (χDMFTch .- χDMFTsp))
    end
    if length(env.inputVars) > 0
        JLD2.@save env.inputVars Γch Γsp χDMFTch χDMFTsp gImp g0
    end
end

# ==================================================================================================== #
#                                                                                                      #
#                                            Text Input                                                #
#                                                                                                      #
# ==================================================================================================== #
function readFortranqωFile(filename, nDims; readq = false, data_cols = 2)
    InString = open(filename, "r") do f
        readlines(f)
    end
    start = if readq 1 else nDims+1  end
    InArr = parse.(Float64,hcat(split.(InString)...)[start:end,:])
    if readq
        qVecArr = InArr[1:3,:]
    else
        qVecArr = []
        nDims = 0
    end
    data_λ = InArr[nDims+1,:] + InArr[nDims+2,:] .* 1im
    data = InArr[nDims+3,:] + InArr[nDims+4,:] .* 1im
    return qVecArr, data_λ, data
end

function readFortranΓ(dirName::String)
    files = readdir(dirName)
    ωₙ, freqBox, Γcharge0, Γspin0 = readFortran3FreqFile(dirName * "/" * files[1], sign=-1.0)
    Γcharge = Array{_eltype}(undef, length(files), size(Γspin0,1), size(Γspin0,2))
    Γspin   = Array{_eltype}(undef, length(files), size(Γspin0,1), size(Γspin0,2))
    Γcharge[1,:,:] = Γcharge0
    Γspin[1,:,:]   = Γspin0
    ω_min = ωₙ
    ω_max = ωₙ

    for (i,file) in enumerate(files[2:end])
        ωₙ, _, Γcharge_new, Γspin_new = readFortran3FreqFile(dirName * "/" * file, sign=-1.0)
        ω_min = if ωₙ < ω_min ωₙ else ω_min end
        ω_max = if ωₙ > ω_max ωₙ else ω_max end
        Γcharge[i+1,:,:] = _eltype == Float64 ? real.(Γcharge_new) : Γcharge_new
        Γspin[i+1,:,:] = _eltype == Float64 ? real.(Γspin_new) : Γspin_new
    end
    freqBox = [ω_min ω_max; freqBox[1,1] freqBox[1,2]; freqBox[2,1] freqBox[2,2]]
    Γcharge = permutedims(Γcharge, [1,3,2])
    Γspin   = permutedims(Γspin, [1,3,2])
    return freqBox, Γcharge, Γspin
end


"""
    Returns χ_DMFT[ω, ν, ν']
"""
function readFortranχDMFT(dirName::String)
    files = readdir(dirName)
    _, _, χupup, χupdo = readFortran3FreqFile(dirName * "/" * files[1], sign=1.0, freqInteger=false)
    for file in files[2:end]
        _, _, χup_new, χupdo_new = readFortran3FreqFile(dirName * "/" * file, sign=1.0, freqInteger=false)
        χupup = cat(χupup, χup_new, dims=3)
        χupdo = cat(χupdo, χupdo_new, dims=3)
    end
    χupup = permutedims(χupup, [3,2,1])
    χupdo   = permutedims(χupdo, [3,2,1])
    χCharge = χupup .+ χupdo
    χSpin   = χupup .- χupdo
    return χCharge, χSpin
end

function readFortranχlDGA(dirName::String, nDims)
    files = readdir(dirName)
    qVecs, data_λ_i, data_i = readFortranqωFile(dirName * "/" * files[1], nDims, readq = true);
    data = Array{Complex{Float64}}(undef, length(files), 2, length(data_i))
    data[1,1,:] = data_λ_i
    data[1,2,:] = data_i
    for (i,file) in enumerate(files[2:end])
        _, data_λ_i, data_i = readFortranqωFile(dirName * "/" * file, nDims, readq = false);
        data[i+1,1,:] = data_λ_i
        data[i+1,2,:] = data_i
    end
    qVecs, data
end


function readFortranBubble(dirName::String, nBose, nFermi, nQ)
    bubble = Array{Complex{Float64}}(undef, nBose, nQ, nFermi)
    files_i = readdir(dirName)
    files = [dirName * "/" * f for f  in files_i]
    iBose = 1
    for file in files[1:end]
        InString = open(file, "r") do f
            readlines(f)
        end
        InArr = parse.(Float64,hcat(split.(InString)...)[4:end,:])
        bubble[iBose, :, :] = reshape(InArr[1,:] .+ InArr[2,:].*1im, (nQ, nFermi))
        iBose += 1
    end

    bubble = permutedims(bubble, [1,3,2])
    return bubble
end
function read_hubb_dat(file)
    content = open(file) do f
        readlines(f)
    end
    U = parse(Float64,split(replace(content[2], "d0" => ""), r"(\s|,)+")[1])
    β = parse(Float64,split(replace(content[4], "d0" => ""), r"(\s|,)+")[1])
    n = parse(Float64,split(replace(content[8], "d0" => ""), r"(\s|,)+")[2])
    return U, β, n
end

function read_anderson_parameters(file)
    content = open(file) do f
        readlines(f)
    end

    in_epsk = false
    in_tpar = false
    ϵₖ = []
    Vₖ = []
    μ = 0
    for line in content
        if "Eps(k)" == strip(line)
            in_epsk = true
            continue
        elseif "tpar(k)" == strip(line)
            in_epsk = false
            in_tpar = true
            continue
        end

        if in_epsk
            push!(ϵₖ, parse(Float64, line))
        elseif in_tpar
            # skip last line, which is mu
            if length(Vₖ) < length(ϵₖ)
                push!(Vₖ, parse(Float64, line))
            else
                if occursin("#", line)
                    μ = parse(Float64, line[1:(findfirst("#", line))[1] - 1])
                else
                    μ = parse(Float64, line)
                end
            end
        end
    end
    return convert(Array{Float64,1}, ϵₖ), convert(Array{Float64,1}, Vₖ), μ
end

function readGImp(filename; only_positive=false)
    GFString = open(filename, "r") do f
        readlines(f)
    end


    tmp = parse.(Float64,hcat(split.(GFString)...)) # Construct a 2xN array of floats (re,im as 1st index)
    tmpG = tmp[2,:] .+ tmp[3,:].*1im
    tmpiνₙ = tmp[1,:] .* 1im
    if only_positive
        GImp = tmpG
        iνₙ  = tmpiνₙ
    else
        N = 2*size(tmpG,1)
        NH = size(tmpG,1)
        GImp = zeros(Complex{Float64}, N)
        iνₙ  = zeros(Complex{Float64}, N)
        GImp[1:(NH)] = reverse(conj.(tmpG[1:NH]))
        GImp[(NH+1):N] = tmpG[1:NH]
        iνₙ[1:(NH)] = conj.(reverse(tmpiνₙ[1:(NH)]))
        iνₙ[(NH+1):N] = tmpiνₙ[1:NH]
    end
    return iνₙ, GImp
end


function readFortranSymmGF(nFreq, filename; storedInverse, storeFull=false)
    GFString = open(filename, "r") do f
        readlines(f)
    end

    if size(GFString, 1)*(1 + 1*storeFull) < nFreq
        throw(BoundsError("nFermFreq in simulation parameters too large!"))
    end

    tmp = parse.(Float64,hcat(split.(GFString)...)[2:end,:]) # Construct a 2xN array of floats (re,im as 1st index)
    tmp = tmp[1,:] .+ tmp[2,:].*1im

    if storedInverse
        tmp = 1 ./ tmp
    end

    GF = Array{Complex{Float64}}(undef, nFreq)
    if storeFull
        NH = Int(nFreq/2)
        GF[1:(NH-1)] = reverse(conj.(tmp[2:NH]))
        GF[NH:nFreq] = tmp[1:NH]
    else
        GF = tmp[1:nFreq]
    end
    return GF
end

function readFortran3FreqFile(filename; sign = 1.0, freqInteger = true)
    InString = open(filename, "r") do f
        readlines(f)
    end
    NCols = 7
    NRows = length(InString)
    lineLen = length(InString[1])
    splitLength = floor(Int64,lineLen/NCols)
    if lineLen%NCols != 0
        @warn "   ---> Warning!! Could not find fixed column width!"
    end
    #InArr = sign .* parse.(Float64,hcat(split.(InString)...)[2:end,:])
    InArr = zeros(Float64, NRows, NCols-1)
    N = Int(sqrt(NRows))
    ErrorLine = []
    for i in 1:NRows
        row =  split_n(InString[i], splitLength, lineLen)[2:end]
        for j in 1:(NCols-1)
            InArr[i,j] = try
                sign * parse(Float64,row[j])
            catch e
                NaN
            end
        end
    end
    if freqInteger
        ωₙ = Int(parse(Float64, split(InString[1])[1]))
        tmpArr1 = filter(!isnan,InArr[:,1])
        tmpArr2 = filter(!isnan,InArr[:,2])
        middleFreqBox = Int64.([minimum(tmpArr1),maximum(tmpArr1)])
        innerFreqBox  = Int64.([minimum(tmpArr2),maximum(tmpArr2)])
        freqBox = permutedims([middleFreqBox innerFreqBox], [2,1])
    else
        #print("\rWarning, non integer frequencies in "*filename*" ignored!")
        ωₙ = 0
        freqBox = []
    end

    InCol1  = reshape(InArr[:,3] .+ InArr[:,4].*1im, (N, N))
    InCol2  = reshape(InArr[:,5] .+ InArr[:,6].*1im, (N, N))
    return ωₙ, freqBox, InCol1, InCol2
end




# ==================================================================================================== #
#                                                                                                      #
#                                            Text Output                                                #
#                                                                                                      #
# ==================================================================================================== #
function writeFortranΓ(dirName::String, fileName::String, simParams, inCol1, inCol2)
    simParams.n_iν+simParams.n_iω
    if !isdir(dirName)
        mkdir(dirName)
    end
    for (ωi,ωₙ) in enumerate(-simParams.n_iω:simParams.n_iω)
        filename = dirName * "/" * fileName * lpad(ωi-1,3,"0")
        open(filename, "w") do f
            for (νi,νₙ) in enumerate(-simParams.n_iν:(simParams.n_iν-1))
                for (ν2i,ν2ₙ) in enumerate(-simParams.n_iν:(simParams.n_iν-1))
                    @printf(f, "  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f\n", ωₙ, νₙ, ν2ₙ,
                            real(inCol1[ωi, νi, ν2i]), imag(inCol1[ωi, νi, ν2i]),
                            real(inCol2[ωi, νi, ν2i]), imag(inCol2[ωi, νi, ν2i]))
                end
            end
        end
    end
end

function writeFortranΣ(dirName::String, Σ_ladder, β)
    res = zeros(size(Σ_ladder,2), 3)
    if !isdir(dirName)
        mkdir(dirName)
    end

    for ki in 1:size(Σ_ladder,1)
        fn = dirName * "/SELF_Q_" * lpad(ki,6,"0") * ".dat"
        open(fn, write=true) do f
            write(f, "header...\n")
            res[:,1] = (2 .*(0:size(Σ_ladder,2)-1) .+ 1) .* π ./ β
            res[:,2] = real.(Σ_ladder[ki,:])
            res[:,3] = imag.(Σ_ladder[ki,:])
            writedlm(f,  rpad.(round.(res; digits=14), 22, " "), "\t")
        end
    end
end

function writeFortranχ(dirName::String, χ, χ_λ, qGrid, usable_ω)
    if !isdir(dirName)
        mkdir(dirName)
    end
    for ωi in 1:size(χ, 1)
        fn = dirName * "/chi" * lpad(ωi-1,3,"0")
        open(fn, write=true) do f
            for qi in 1:size(χ, 2)
                res = ωi in usable_ω ? χ_λ[ωi - first(usable_ω) + 1,1] : 0.0
                if length(qGrid[1]) == 3
                    @printf(f, "  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f\n",
                        qGrid[qi][1], qGrid[qi][2], qGrid[qi][3],
                        real(χ[ωi, qi]), imag(χ[ωi, qi]),
                        real(res), imag(res))
                else
                    @printf(f, "  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f\n",
                        qGrid[qi][1], qGrid[qi][2],
                        real(χ[ωi, qi]), imag(χ[ωi, qi]),
                        real(res), imag(res))
                end
            end
        end
    end
end

function writeFortranEnergies(E_Kin, E_Pot, β, dirName::String)
    res = zeros(size(Σ_ladder, 2), 3)
    if !isdir(dirName)
       mkdir(dirName)
    end
 
    fn = dirName * "/SELF_LOC_parallel.dat"
    open(fn, write=true) do f
        res[:,1] = (2 .*(0:length(Σ_ladder_loc)-1) .+ 1) .* π ./ mP.β
        res[:,2] = real.(Σ_ladder_loc[:])
        res[:,3] = imag.(Σ_ladder_loc[:])
        writedlm(f,  rpad.(round.(res; digits=14), 22, " "), "\t")
    end
    for ki in 1:size(Σ_ladder,1)
        fn = dirName * "/SELF_Q_" * lpad(ki,6,"0") * ".dat"
        open(fn, write=true) do f
            write(f, "header...\n")
            res[:,1] = (2 .*(0:size(Σ_ladder,2)-1) .+ 1) .* π ./ mP.β
            res[:,2] = real.(Σ_ladder[ki,:])
            res[:,3] = imag.(Σ_ladder[ki,:])
            writedlm(f,  rpad.(round.(res; digits=14), 22, " "), "\t")
        end
    end
end

function writeFortranEnergies(E_Kin, E_Pot, E_Kin_ED, E_Pot_ED, β, dirName::String)
    if !isdir(dirName)
        mkdir(dirName)
    end
    @assert size(E_Kin) == size(E_Pot) == size(E_Kin_ED) == size(E_Pot_ED)
    νGrid = 0:(length(E_Kin)-1)
    iν_n = iν_array(β, νGrid)

    writeFortranEnergies(E_Kin, E_Pot, β, dirName)

    fn_DMFT = dirName * "/energiesDMFT.dat"
    open(fn_DMFT, "w") do f
        for i in 1:length(E_Kin)
            @printf(f, "  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f  %18.10f\n",
                    imag(iν_n[i]), 0.0, 0.0, real(E_Kin_ED[i]), 0.0, 0.0, 0.0, real(E_Pot_ED[i]), 0.0)
        end
    end
end

function get_log()
    global LOG
    LOG *= String(take!(LOG_BUFFER))
    return LOG
end

function reset_log()
    global LOG
    LOG = ""
end
