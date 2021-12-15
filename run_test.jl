#using Profile, ProfileSVG, FlameGraphs, Plots
#using JLD2, FileIO
#using Logging
using Distributed
using Base.GC
using TimerOutputs

#addprocs(2)

using Pkg
Pkg.activate(@__DIR__)
using LadderDGA

cfg_file =  "/home/julian/Hamburg/ED_data/asympt_tests/config_14.toml";
 mP, sP, env, kGridsStr = readConfig(cfg_file);
@timeit LadderDGA.to "setup" Σ_ladderLoc, Σ_loc, imp_density, kG, gLoc_fft, Γsp, Γch, FUpDo = setup_LDGA(kGridsStr[1], mP, sP, env);

# ladder quantities
@info "bubble"
@timeit LadderDGA.to "nl bblt" bubble = calc_bubble(gLoc_fft, kG, mP, sP);
@info "chi"
@timeit LadderDGA.to "nl xsp" nlQ_sp = calc_χ_γ(:sp, Γsp, bubble, kG, mP, sP);
@timeit LadderDGA.to "nl xch" nlQ_ch = calc_χ_γ(:ch, Γch, bubble, kG, mP, sP);

λsp_old = λ_correction(:sp, imp_density, FUpDo, Σ_loc, Σ_ladderLoc, nlQ_sp, nlQ_ch,bubble, gLoc_fft, kG, mP, sP)

@info "Σ"
@timeit LadderDGA.to "nl Σ" Σ_ladder = calc_Σ(nlQ_sp, nlQ_ch, bubble, gLoc_fft, FUpDo, kG, mP, sP)
Σ_ladder = Σ_loc_correction(Σ_ladder, Σ_ladderLoc, Σ_loc);
#G_λ = G_from_Σ(Σ_ladder)
#@timeit LadderDGA.to "nl Σ" Σ_ladder = calc_Σ(nlQ_sp, nlQ_ch, bubble, fft(G_λ), FUpDo, kG, mP, sP)
#Σ_ladder = Σ_loc_correction(Σ_ladder, Σ_ladderLoc, Σ_loc);
