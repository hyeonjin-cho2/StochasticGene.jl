# biowulf.jl
# functions for use on the NIH Biowulf super computer



"""
    makeswarm(;G::Int=2,cell="HCT116",swarmfile::String="fit",label="label",inlabel=label,nsets=1,datafolder::String="data/HCT116_testdata",fish= false,cycle=true,thresholdlow::Float64=0.,thresholdhigh::Float64=1e8,conds::String="DMSO",resultfolder::String= "fit_result",infolder=resultfolder,batchsize=1000,maxtime = 60.,nchains::Int = 2,transient::Bool=false,fittedparam=[1],fixedeffects=(),juliafile::String="fitscript",root="../",samplesteps::Int=100000,warmupsteps=20000,annealsteps=0,temp=1.,tempanneal=100.,modulepath = "/Users/carsonc/github/StochasticGene/src/StochasticGene.jl",cv = 0.02)

    makeswarm(genes::Vector;G::Int=2,cell="HCT116",swarmfile::String="fit",label="label",inlabel=label,nsets=1,datafolder::String="data/HCT116_testdata",fish=false,cycle=true,conds::String="DMSO",resultfolder::String="fit_result",infolder=resultfolder,batchsize=1000,maxtime=60.,nchains::Int=2,transient::Bool=false,fittedparam=[1],fixedeffects=(),juliafile::String="fitscript",root="../",samplesteps::Int=100000,warmupsteps=20000,annealsteps=0,temp=1.,tempanneal=100.,modulepath = "../StochasticGene/src/StochasticGene.jl",cv=0.02)

Arguments
    - `G`: number of gene states
    - `cell': cell type for halflives and allele numbers
    - `infolder`: name of folder for initial parameters
    - `swarmfile`: name of swarmfile to be executed by swarm
    - `label`: label of output files produced
    - `inlabel`: label of files used for initial conditions
    - `nsets`: number of histograms to be fit (e.g. one for wild type and one for perturbation)
    - `datafolder`: folder holding histograms, if two folders use `-` (hyphen) to separate, e.g.  "data\folder1-data\folder2"
    - `thresholdlow`: lower threshold for halflife for genes to be fit
    - `threhsoldhigh`: upper threshold
    - `conds`: string describing conditions to be fit with `-` to separate if two conditions, e.g. "WT-AUXIN"
    - `result`: folder for results
    - `batchsize`: number of jobs per swarmfile, default = 1000
    - `maxtime`: maximum wall time for run, default = 2 hrs
    - `nchains`: number of MCMC chains, default = 2
    - `transient::Bool`: true means fit transient model (T0, T30, T120)
    - `fittedparam`: vector of rate indices to be fit, e.g. [1,2,3,5,6,7]
    - `fixedeffects`: tuple of vectors of rates that are fixed between control and treatment where first index is fit and others are fixed to first, e.g. ([3,8],) means  index 8 is fixed to index 3
         (each vector in tuple is a fixed rate set)
    - `juliafile`: name of file to be called by julia in swarmfile
    - `root`: name of root directory for project, e.g. "scRNA\"
    - `samplesteps`: number of MCMC sampling steps
    - `warmupsteps`: number of MCMC warmup steps to find proposal distribution covariance
    - `annealsteps`: number of annealing steps (during annealing temperature is dropped from tempanneal to temp)
    - `temp`: MCMC temperature
    - `tempanneal`: annealing temperature
    - `cv`: coefficient of variation (mean/std) of proposal distribution


returns swarmfile that calls a julia file that is executed on biowulf

"""

function makeswarm(;G::Int=2,cell="HCT116",swarmfile::String="fit",label="label",inlabel=label,nsets=2,datafolder::String="data/HCT116_testdata",fish= false,cycle=true,thresholdlow::Float64=0.,thresholdhigh::Float64=1e8,conds::String="DMSO-AUXIN",resultfolder::String= "fit_result",infolder=resultfolder,batchsize=1000,maxtime = 60.,nchains::Int = 2,transient::Bool=false,fittedparam=[1],fixedeffects=(),juliafile::String="fitscript",root="../",samplesteps::Int=100000,warmupsteps=20000,annealsteps=0,temp=1.,tempanneal=100.,cv = 0.02)
    if occursin.("-",conds)
        cond = string.(split(conds,"-"))
    else
        cond = conds
    end
    genes = checkgenes(root,cond,datafolder,cell,thresholdlow,thresholdhigh)
    makeswarm(genes,G=G,cell=cell,infolder=infolder,swarmfile=swarmfile,label=label,inlabel=inlabel,nsets=nsets,datafolder=datafolder,fish=fish,cycle=cycle,conds=conds,resultfolder=resultfolder,batchsize=batchsize,maxtime=maxtime,nchains=nchains,transient=transient,fittedparam=fittedparam,fixedeffects=fixedeffects,juliafile=juliafile,root=root,samplesteps=samplesteps,warmupsteps=warmupsteps,annealsteps=annealsteps,temp=temp,tempanneal=tempanneal,cv=cv)
end

function makeswarm(genes::Vector;G::Int=2,cell="HCT116",swarmfile::String="fit",label="label",inlabel=label,nsets=2,datafolder::String="data/HCT116_testdata",fish=false,cycle=true,conds::String="DMSO-AUXIN",resultfolder::String="fit_result",infolder=resultfolder,batchsize=1000,maxtime=60.,nchains::Int=2,transient::Bool=false,fittedparam=[1],fixedeffects=(),juliafile::String="fitscript",root="../",samplesteps::Int=100000,warmupsteps=20000,annealsteps=0,temp=1.,tempanneal=100.,cv=0.02)
    if label == "label"
        if fish
            label = "FISH-ss-" * conds
        else
            label = "scRNA-ss-" * conds
        end
    end
    ngenes = length(genes)
    println("number of genes: ",ngenes)
    juliafile = juliafile * "_" * label * "_" * "$G" * ".jl"
    if ngenes > batchsize
        batches = getbatches(genes,ngenes,batchsize)
        for batch in eachindex(batches)
            sfile = swarmfile * "_" * "$G" * "$batch" * ".swarm"
            write_swarmfile(sfile,nchains,juliafile,batches[batch])
        end
    else
        sfile = swarmfile * "_" * label * "_" * "$G" * ".swarm"
        f = open(sfile,"w")
        write_swarmfile(sfile,nchains,juliafile,genes)
    end
    write_fitfile(juliafile,nchains,cell,conds,G,maxtime,fittedparam,fixedeffects,infolder,resultfolder,datafolder,fish,cycle,inlabel,label,nsets,transient,samplesteps,warmupsteps,annealsteps,temp,tempanneal,root,cv)
end

"""
    fix(folder)

    Finds jobs that failed and writes a swarmfile for those genes

"""
fix(folder) = writeruns(fixruns(findjobs(folder)))

"""
    setup(rootfolder = "scRNA")

    Sets up the folder system prior to use
    Defaults to "scRNA"

"""
function rna_setup(root = "scRNA")

    data = joinpath(root,"data")
    results = joinpath(root,"results")
    alleles = joinpath(data,"alleles")
    halflives = joinpath(data,"halflives")
    testdata = joinpath(data,"HCT116_testdata")

    if ~ispath(data)
        mkpath(data)
    end
    if ~ispath(results)
        mkpath(results)
    end
    if ~ispath(alleles)
        mkpath(alleles)
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/alleles/CH12_alleles.txt","$alleles/CH12_alleles.txt")
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/alleles/HCT116_alleles_number.txt","$alleles/HCT116_alleles_number.txt")

    end
    if ~ispath(halflives)
        mkpath(halflives)
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/halflives/ESC_halflife.csv","$halflives/ESC_halflife.csv")
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/halflives/CH12_halflife.csv","$halflives/CH12_halflife.csv")
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/halflives/HCT116_halflife.csv","$halflives/HCT116_halflife.csv")
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/halflives/OcaB_halflife.csv","$halflives/OcaB_halflife.csv")
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/halflives/OcaB_halflife_repa.txt","$halflives/OcaB_halflife_repa.txt")
    end
    if ~ispath(testdata)
        mkpath(testdata)
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/HCT116_testdata/CENPL_MOCK.txt","$testdata/CENPL_MOCK.txt")
        Downloads.download("https://raw.githubusercontent.com/nih-niddk-mbs/StochasticGene.jl/master/test/data/HCT116_testdata/MYC_MOCK.txt","$testdata/MYC_MOCK.txt")
    end

end

"""
make_fitfile(fitfile,fittedparam,fixedeffects)

make the file the swarm file calls to execute julia code

"""
function write_fitfile(fitfile,nchains,cell,datacond,G,maxtime,fittedparam,fixedeffects,infolder,resultfolder,datafolder,fish,cycle,inlabel,label,nsets,runcycle,samplesteps,warmupsteps,annealsteps,temp,tempanneal,root,cv)
        f = open(fitfile,"w")
        s =   '"'
        write(f,"@everywhere using StochasticGene\n")
        write(f,"@time fit_rna($nchains,ARGS[1],$s$cell$s,$fittedparam,$fixedeffects,$s$datacond$s,$G,$maxtime,$s$infolder$s,$s$resultfolder$s,$s$datafolder$s,$fish,$cycle,$s$inlabel$s,$s$label$s,$nsets,$cv,$runcycle,$samplesteps,$warmupsteps,$annealsteps,$temp,$tempanneal,$s$root$s)\n")
        close(f)
end

function write_fitfile_include(fitfile,nchains,cell,datacond,G,maxtime,fittedparam,fixedeffects,infolder,resultfolder,datafolder,fish,cycle,inlabel,label,nsets,runcycle,samplesteps,warmupsteps,annealsteps,temp,tempanneal,root,modulepath,cv)
        f = open(fitfile,"w")
        s =   '"'
        write(f,"@everywhere include($s$modulepath$s)\n")
        # write(f,"@everywhere using StochasticGene\n")
        write(f,"@time StochasticGene.fit_rna($nchains,ARGS[1],$s$cell$s,$fittedparam,$fixedeffects,$s$datacond$s,$G,$maxtime,$s$infolder$s,$s$resultfolder$s,$s$datafolder$s,$fish,$cycle,$s$inlabel$s,$s$label$s,$nsets,$cv,$runcycle,$samplesteps,$warmupsteps,$annealsteps,$temp,$tempanneal,$s$root$s)\n")
        close(f)
end

function getbatches(genes,ngenes,batchsize)
    nbatches = div(ngenes,batchsize)
    batches = Vector{Vector{String}}(undef,nbatches+1)
    println(batchsize," ",nbatches)
    for i in 1:nbatches
        batches[i] = genes[batchsize*(i-1)+1:batchsize*(i)]
    end
    batches[end] = genes[batchsize*nbatches+1:end]
    return batches
end

function write_swarmfile(sfile,nchains,juliafile,genes::Vector)
    f = open(sfile,"w")
    for gene in genes
        gene = check_genename(gene,"(")
        writedlm(f,["julia -p" nchains juliafile gene])
        # writedlm(f,["julia -p" nchains juliafile nchains gene cell cond G maxtime infolder resultfolder datafolder fish inlabel label nsets runcycle transient fittedparam fixedeffects])
    end
    close(f)
end

function checkgenes(root,conds::Vector,datafolder,celltype::String,thresholdlow::Float64,thresholdhigh::Float64)
    genes = Vector{Vector}(undef,2)
    if occursin.("-",datafolder)
        datafolder = string.(split(datafolder,"-"))
        for i in 1:2
            genes[i] = checkgenes(root,conds[i],datafolder[i],celltype,thresholdlow,thresholdhigh)
        end
    else
        for i in 1:2
            genes[i] = checkgenes(root,conds[i],datafolder,celltype,thresholdlow,thresholdhigh)
        end
    end
    intersect(genes[1],genes[2])
end

function checkgenes(root,cond::String,datafolder,cell::String,thresholdlow::Float64,thresholdhigh::Float64)
    genes = intersect(get_halflives(root,cell,thresholdlow,thresholdhigh), get_genes(root,cond,datafolder))
    alleles = get_alleles(root,cell)
    if ~isnothing(alleles)
        return intersect(genes,alleles)
    else
        return genes
    end
end

function get_genes(root,cond,datafolder)
    genes = Vector{String}(undef,0)
    files = readdir(joinpath(root,datafolder))
    for file in files
        if occursin(cond,file)
            push!(genes,split(file,"_")[1])
        end
    end
    return genes
end

function get_halflives(root,cell,thresholdlow::Float64,thresholdhigh::Float64)
    file = get_file(root,"data/halflives",cell)
    get_halflives(file,thresholdlow,thresholdhigh)
end

function get_halflives(file,thresholdlow::Float64,thresholdhigh::Float64)
    genes = Vector{String}(undef,0)
    halflives = readdlm(file,',')
    for row in eachrow(halflives)
        if typeof(row[2]) <: Number
            if thresholdlow <= row[2] < thresholdhigh
                push!(genes,string(row[1]))
            end
        end
    end
    return genes
end

function get_alleles(root,cell)
    file = get_file(root,"data/alleles",cell)
    if ~isnothing(file)
        return readdlm(file)[2:end,1]
    else
        return nothing
    end
end

function get_file(root,folder,type)
    folder = joinpath(root,folder)
    files = readdir(folder)
    for file in files
        if occursin(type,file)
            path = joinpath(folder,file)
            return path
        end
    end
    nothing
end



function findjobs(folder)
    files = readdir(folder)
    files = files[occursin.("swarm_",files)]
    for (i,file) in enumerate(files)
        files[i] = split(file,"_")[2]
    end
    unique(files)
end

function fixruns(jobs,message="FAILED")
    runlist = Vector{String}(undef,0)
    for job in jobs
        if occursin(message,read(`jobhist $job`,String))
            swarmfile = findswarm(job)
            list = readdlm(swarmfile,',')
            runs =  chomp(read(pipeline(`jobhist $job`, `grep $message`),String))
            runs = split(runs,'\n')
            println(job)
            for run in runs
                linenumber = parse(Int,split(split(run," ")[1],"_")[2]) + 1
                while linenumber < length(list)
                    a = String(list[linenumber])
                    linenumber += 1000
                    println(a)
                    push!(runlist,a)
                end
            end
        end
    end
    return runlist
end

function writeruns(runs,outfile="fitfix.swarm")

    f = open(outfile,"w")
    for run in runs
        writedlm(f,[run],quotes=false)
    end
    close(f)

end

function findswarm(job)
    sc = "Swarm Command"
    line = read(pipeline(`jobhist $job`, `grep $sc`),String)
    list = split(line," ")
    list[occursin.(".swarm",list)][1]
end

function collate(folders,type="rates_scRNA_T120")
    genes = Vector{Vector}(undef,0)
    for folder in folders
        files = readdir(folder)
        for file in files
            if occursin(type,file)
                contents=readdlm(file,',')
                for row in eachrow(contents)
                    row[1] .== genes
                end
            end
        end
    end
end


function get_missing_genes(folder::String,cell,type,label,cond,model)
    genes = checkgenes(root,cond,folder,cell,0.,100000000.)
    genes1=StochasticGene.getgenes(folder,type,label,cond,model)
    union(setdiff(genes1,genes),setdiff(genes,genes1))
end

function get_missing_genes(genes::Vector,folder,type,label,cond,model)
    genes1=StochasticGene.getgenes(folder,type,label,cond,model)
    union(setdiff(genes1,genes),setdiff(genes,genes1))
end

function scan_swarmfiles(jobid,folder=".")
    if ~(typeof(jobid) <: String)
        jobid = string(jobid)
    end
    genes = Array{String,1}(undef,0)
    files = readdir(folder)
    files = files[occursin.(jobid,files)]
    for file in files
        genes = vcat(genes,scan_swarmfile(file))
    end
    return genes
end

function scan_swarmfile(file)
    genes = Array{String,1}(undef,0)
    contents = readdlm(file,'\t')
    lines = contents[occursin.("[\"",string.(contents))]
    for line in lines
        push!(genes,split.(string(line)," ")[1])
    end
    return genes
end

function scan_fitfile(file,folder=".")
    genes = Array{String,1}(undef,0)
    joinpath(folder,file)
    file = readdlm(file,'\t')
    for line in eachrow(file)
        push!(genes,line[4])
    end
    return genes
end
