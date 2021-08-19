using LinearAlgebra
using TimerOutputs
using Logging


io = open(out_path*"/lDGA.log","w+")
#io = stdout
logger = ConsoleLogger(io, Logging.Info, 
                  meta_formatter=Logging.default_metafmt,
                  show_limited=true, right_justify=0)
#logger = SimpleLogger(io)
global_logger(logger)

cfg_file = ARGS[1]
out_path = ARGS[2]
NProcs = parse(Int,ARGS[3])
BLAS.set_num_threads(NProcs)
println("config path: ", cfg_file)
println("output path: ", out_path)
flush(stdout)
flush(stderr)
include("./run.jl")
include("/scratch/projects/hhp00048/codes/LadderDGA_utils.jl/new_lambda_analysis.jl")

#addprocs(SlurmManager(NProcs), N = ceil(Int, NProcs/96); exeflags=["--project=/scratch/projects/hhp00048/codes/LadderDGA.jl"], job_file_loc="worker_out") 
#ClusterManagers.addprocs_slurm(NProcs; exeflags=["--project=/scratch/projects/hhp00048/codes/LadderDGA.jl", "--color=yes"], job_file_loc="test_loc")

#bubbleLoc, locQ_sp, locQ_ch, bubble, nlQ_ch, nlQ_sp, nlQ_ch_λ, nlQ_sp_λ, Σ_bare, Σ_ladder, Σ_ladderLoc = run_sim(config)
#

run_sim(cfg_file=cfg_file, res_prefix=out_path*"/", save_results=true)
close(io)
