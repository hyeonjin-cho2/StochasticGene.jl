# Script executed by Biowulf to run code

@everywhere include("/home/carsonc/StochasticGene/src/StochasticGene.jl")

include("/home/carsonc/StochasticGene/runfiles/scriptfunctions.jl")

@time fit_rna(parse(Int,ARGS[12]),ARGS[1],ARGS[2],parse(Int,ARGS[3]),parse(Float64,ARGS[4]),ARGS[5],ARGS[6],ARGS[7],ARGS[8],ARGS[9],parse(Int,ARGS[10]),parse(Bool,ARGS[11]))

# Arguments
# 1: gene
# 2: cond
# 3: G
# 4: maxtime
# 5: infolder
# 6: resultfolder
# 7: datafolder
# 8: inlabel
# 9: label
# 10: nsets (number of rate sets)
# 11: runcycle (bool)
