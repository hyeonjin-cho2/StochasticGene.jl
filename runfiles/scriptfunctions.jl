# functions to run StochasticGene for Bayesian parameter estimation of stochastic Markov models of gene transcription

using Dates
using DelimitedFiles

"""
fit_rna(nchains::Int,gene::String,datacond,G::Int,maxtime::Float64,infolder::String,resultfolder::String,datafolder,inlabel,label,nsets,runcycle::Bool=false,transient::Bool=false,samplesteps::Int=40000,warmupsteps=0,annealsteps=0,temp=100.,tempanneal=100.,root = "/home/carsonc/scrna/")

Fit steady state or transient GM model to RNA data for a single gene

Arguments:
nchains = number of MCMC chains
gene = gene name
datacond = condition, if more than one condition is used enter as a single string separated by underscore, e.g. "DMSO_AUXIN"
maxtime = float maximum time for entire run
infolder = folder pointing to results used as initial conditions
resultfolder = folder where results go
datafolder = folder for data
inlabel = name of input files (not including gene name but including condition)
label = name of output files
nsets = int number of rate sets
runcycle = if true, cycle through all parameters sequentially in MCMC
samplesteps = int number of samples
warmupsteps = int number of warmup steps
annealsteps = in number of annealing steps
temp = MCMC temperature
tempanneal = starting temperature for annealing
root = root folder of data and Results folders

"""
# function fit_rna(nchains::Int,gene::String,G::Int,data::StochasticGene.HistogramData,maxtime::Float64,nsets,fittedparam,infolder,resultfolder,datafolder,inlabel,runcycle::Bool,params::Tuple,root)
function fit_rna(nchains::Int,gene::String,datacond,G::Int,maxtime::Float64,infolder::String,resultfolder::String,datafolder,inlabel,label,nsets,runcycle::Bool=false,transient::Bool=false,samplesteps::Int=40000,warmupsteps=0,annealsteps=0,temp=100.,tempanneal=100.,root = "/home/carsonc/scrna/")
    println(now())
    datacond = string.(split(datacond,"_"))
    fittedparam = make_fittedparam(G,nsets)
    if transient
        data = make_data(gene,datacond,datafolder,label,root,["T0","T30","T120"],[0.,30.,120.])
    else
        data = make_data(gene,datacond,datafolder,label,root)
    end
    initialize(gene,G,datacond,datafolder,infolder,resultfolder,maxtime)
    decayrate = decay(root,gene)
    if decayrate < 0
        throw("error")
    end
    nalleles = alleles(root,gene)
    yieldprior = .1
    r = getr(gene,G,nalleles,decayrate,fittedparam,inlabel,infolder,nsets,root,data)
    cv = getcv(gene,G,nalleles,fittedparam,inlabel,infolder,root)
    if runcycle
        maxtime /= 2
        r = cycle(nchains,data,r,G,nalleles,nsets,.02,fittedparam,decayrate,yieldprior,maxtime,temp,tempanneal)
        cv = .02
        annealsteps = 0
        warmupsteps = 0
    end
    options = StochasticGene.MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp,tempanneal)
    model = StochasticGene.model_rna(r,G,nalleles,nsets,cv,fittedparam,decayrate,yieldprior,0)
    param,_ = StochasticGene.initial_proposal(model)
    initial_ll(param,data,model)
    fit,stats,waic = StochasticGene.run_mh(data,model,options,nchains);
    finalize(data,model,fit,stats,waic,temp,resultfolder,root)
    println(now())
    nothing
end

function initial_ll(param,data,model)
    ll,_ = StochasticGene.loglikelihood(param,data,model)
    println("initial ll: ",ll)
end

function initialize(gene,G,cond,datafolder,infolder,resultfolder,maxtime)
    println(gene," ",G," ",cond)
    println(datafolder)
    println("in: ", infolder," out: ",resultfolder)
    println(maxtime)
end

function finalize(data,model,fit,stats,waic,temp,resultfolder,root)
    writefile = joinpath(root,resultfolder)
    StochasticGene.writeall(writefile,fit,stats,waic,data,temp,model)
    println("final ll: ",fit.llml)
    println(fit.accept," ",fit.total)
    println("Deviance: ",StochasticGene.deviance(fit,data,model))
end

function transient_rna(nchains,gene::String,cond::String,G::Int,maxtime::Float64,infolder::String,resultfolder,datafolder,inlabel,label,nsets,runcycle::Bool=false,samplesteps::Int=40000,warmupsteps=20000,annealsteps=100000,temp=1.,tempanneal=100.,root = "/home/carsonc/scrna/")
    fittedparam = make_fittedparam(G,nsets)
    data = make_data(gene,cond,G,datafolder,label,nsets,root)
    model = make_model(gene,G,fittedparam,inlabel,infolder,nsets,root)
    param,_ = StochasticGene.initial_proposal(model)
    return param, data, model
end

function make_model(gene,G,fittedparam,inlabel,infolder,nsets,root)
    decayrate = decay(root,gene)
    println(decayrate)
    if decayrate < 0
        throw("error")
    end
    nalleles = alleles(root,gene)
    yieldprior = .1
    r = getr(gene,G,nalleles,decayrate,fittedparam,inlabel,infolder,nsets,root)
    cv = getcv(gene,G,nalleles,fittedparam,inlabel,infolder,root)
    model = StochasticGene.model_rna(r,G,nalleles,nsets,cv,fittedparam,decayrate,yieldprior,0)
end

function make_fittedparam(G::Int,nsets)

    if nsets == 1
        if G == 3
            fittedparam = [1,2,3,4,5,7]
        elseif G == 2
            fittedparam = [1,2,3,5]
        elseif G == 1
            fittedparam = [1,3]
        end
    else
        if G == 3
            # fittedparam = [1,2,3,4,5,7,8,9,10,11,13]
            # fittedparam = [7,8,9,10,11,13]
            fittedparam = [7,8,9,10,11]
        elseif G == 2
            # fittedparam = [1,2,3,5,6,7,9]
            # fittedparam = [5,6,7,9]
            fittedparam = [5,6,7]
        elseif G == 1
            fittedparam = [3,5]
        end
    end
    return fittedparam
end

function make_data(gene::String,cond::String,datafolder,label,root)
    if cond == "null"
        cond = ""
    end
    datafile = StochasticGene.scRNApath(gene,cond,datafolder,root)
    StochasticGene.data_rna(datafile,label,gene,false)
end

function make_data(gene::String,cond::Array,datafolder,label,root)
    datafile = Array{String,1}(undef,length(cond))
    for i in eachindex(cond)
        datafile[i] = StochasticGene.scRNApath(gene,cond[i],datafolder,root)
    end
    StochasticGene.data_rna(datafile,label,gene,false)
end

function make_data(gene::String,cond::String,datafolder,label,root,sets::Vector,time::Vector)
    if cond == "null"
        cond = ""
    end
    datafile =[]
    for set in sets
        folder = joinpath(datafolder,set)
        datafile = vcat(datafile,StochasticGene.scRNApath(gene,cond,folder,root))
    end
    StochasticGene.data_rna(datafile,label,times,gene,false)
end

function cycle(nchains,data,r,G,nalleles,nsets,cv,fittedparam,decayrate,yieldprior,maxtime,temp,tempanneal)
    options = StochasticGene.MHOptions(100,0,0,maxtime/10,temp,tempanneal)
    t0 = time()
    while (time() - t0 < maxtime)
        for fp in fittedparam
            model = StochasticGene.model_rna(r,G,nalleles,nsets,cv,[fp],decayrate,yieldprior,0)
            fit,stats,waic = StochasticGene.run_mh(data,model,options,nchains);
            r = StochasticGene.get_rates(fit.parml,model)
        end
    end
    return r
end

function getr(gene,G,nalleles,decayrate,fittedparam,inlabel,infolder,nsets::Int,root,data)
    ratefile = StochasticGene.path_Gmodel("rates",gene,G,nalleles,inlabel,infolder,root)
    if isfile(ratefile)
        r = StochasticGene.readrates(ratefile,1)
        r[end] = clamp(r[end],eps(Float64),1-eps(Float64))
        if length(r) == 2*G*nsets + 1
            println(r)
            return r
        end
    end
    println("No r")
    setr(G,decayrate,nsets,data)
end


function setr(G,decayrate,nsets,data)
    if G == 2
        r = [0.015,0.015,0.5,.01,1.]*decayrate/.01
    elseif G == 3
        r = [0.015,.2,.2,0.015,1.5,.01,1.]*decayrate/.01
    elseif G == 1
        if typeof(data.nRNA) <: Vector
            r = Array{Float64,1}(undef,0)
            for hist in data.histRNA
                mu = StochasticGene.mean_histogram(hist)
                r = vcat([10*mu,1.],r)
            end
            r *= decayrate
            r = [r;1.]
            nsets = 1
        else
            mu=StochasticGene.mean_histogram(data.histRNA)
            r = [10*mu,1.,1.]*decayrate
        end
    end
    if nsets > 1
        r = [r[1:end-1];r]
    end
    r[end] = .1
    println(r)
    return r
end

function getcv(gene,G,nalleles,fittedparam,inlabel,infolder,root)
    paramfile = StochasticGene.path_Gmodel("param_stats",gene,G,nalleles,inlabel,infolder,root)
    if isfile(paramfile)
        cv = StochasticGene.read_covlogparam(paramfile)
        cv = float.(cv)
        if ~StochasticGene.isposdef(cv) || size(cv)[1] != length(fittedparam)
            cv = .02
        end
    else
        cv = .02
    end
    println(cv)
    return cv
end

function decay(root::String,gene,file="data/HCT116_all_cells_histograms_and_half_lives_March_2021/Starved_Rep7_half_lives.csv",col=2)
    path = joinpath(root,file)
    if isfile(path)
        in = readdlm(path,',')
        a = in[findfirst(in[:,1] .== gene),col]
        println(a)
        return decay(a)
    else
        println(gene," has no decay time")
        return -1.
    end
end

decay(a::Float64) = log(2)/a/60.

function decay(a,gene)
    if typeof(a) <: Number
        return decay(a)
    else
        println(gene," has no decay time")
        return -1.
    end
end

function alleles(root,gene,file="data/HCT116_alleles_number.txt")
    in = readdlm(joinpath(root,"data/HCT116_alleles_number.txt"))
    in[findfirst(in[:,1] .== gene),3]
end

function fix_measures(resultfolder,measurefile,ratefile::String,cond,n,datafolder,root)
    front,back = split(measurefile,".")
    fix = front * "fix" * "." * back
    measurepath = joinpath(resultfolder,measurefile)
    ratepath = joinpath(resultfolder,ratefile)
    rates,_ = readdlm(ratepath,',',header=true)
    println(length(rates[:,1]))
    measures,head = readdlm(measurepath,',',header=true)
    f = open(joinpath(resultfolder,fix),"w")
    writedlm(f,[head "Deviance fixed" "LogML fixed" "AIC fixed"],',')
    for i in eachindex(rates[:,1])
        h,hd = histograms(rates[i,:],cond,n,datafolder,root)
        d = StochasticGene.deviance(h,hd)
        ll = StochasticGene.crossentropy(h,hd)
        a = 4*(n+1) + 2*ll
        writedlm(f,[measures[i:i,:] d ll a],',')
    end
    close(f)
end

function deviance(r,cond,n,datafolder,root)
    h,hd = histograms(r,cond,n,datafolder,root)
    StochasticGene.deviance(h,hd)
end


function compute_deviance(outfile,ratefile::String,cond,n,datafolder,root)
    f = open(outfile,"w")
    rates,head = readdlm(ratefile,',',header=true)
    for r in eachrow(rates)
        d=deviance(r,cond,n,datafolder,root)
        writedlm(f,[gene d],',')
    end
    close(f)
end

function write_histograms(outfolder,ratefile::String,cond,n,datafolder,root)
    rates,head = readdlm(ratefile,',',header=true)
    for r in eachrow(rates)
        h,hd = histograms(r,cond,n,datafolder,root)
        f = open(joinpath(outfolder,r[1] * ".txt"),"w")
        writedlm(f,h)
        close(f)
    end
end

function write_burst_stats(outfile,infile::String,n,root)
    f = open(outfile,"w")
    contents,head = readdlm(infile,',',header=true)
    writedlm(f,["Gene" "Mean OFF Period (min)" "Burst Size"],',')
    for r in eachrow(contents)
        gene = String(r[1])
        off = meanofftime(r[2:2*n+3],n,1)
        # h,hd = histograms(r,cond,n,datafolder,root)
        writedlm(f,[gene off r[2*n+1]/r[2*n]],',')
    end
    close(f)
end

meanofftime(gene::String,infile,n,method,root) = sum(1 .- offtime(gene,infile,n,method,root))

function meanofftime(r::Vector,n::Int,method::Int)
    if n == 1
        return 1/r[1]
    else
        return sum(1 .- offtime(r,n,method))
    end
end

function offtime(r::Vector,n::Int,method::Int)
    _,_,TI = StochasticGene.mat_G_DT(r,n)
    vals,_ = StochasticGene.eig_decompose(TI)
    minval = min(minimum(abs.(vals[vals.!=0])),.2)
    StochasticGene.offtimeCDF(collect(1.:5/minval),r,n,TI,method)
end

function offtime(gene::String,infile,n,method,root)
    contents,head = readdlm(infile,',',header=true)
    r = float.(contents[gene .== contents[:,1],2:end-1])[1,:]
    offtime(r,n,method)

end

function write_moments(outfile,infile::String,cond,datafolder,root)
    f = open(outfile,"w")
    contents,head = readdlm(infile,',',header=true)
    writedlm(f,["Gene" "Expression Mean" "Expression Variance"],',')
    for r in eachrow(contents)
        gene = String(r[1])
        datafile = StochasticGene.scRNApath(gene,cond,datafolder,root)
        # data = StochasticGene.data_rna(datafile,label,gene,false)
        len,h = StochasticGene.histograms_rna(datafile,gene,false)
        # h,hd = histograms(r,cond,n,datafolder,root)
        writedlm(f,[gene StochasticGene.mean_histogram(h) StochasticGene.var_histogram(h)],',')
    end
    close(f)
end

function histograms(r,cond,n,datafolder,root)
    gene = String(r[1])
    datafile = StochasticGene.scRNApath(gene,cond,datafolder,root)
    hd = StochasticGene.read_scrna(datafile)
    h = StochasticGene.steady_state(r[2:2*n+3],r[end],n,length(hd),alleles(root,gene))
    return h,hd
end


function bestmodel(measures2,measures3)
    m2,head = readdlm(infile,',',header=true)
    m3,head = readdlm(infile,',',header=true)
end

function join_files(file1::String,file2::String,outfile::String,addlabel::Bool=true)
    contents1,head1 = readdlm(file1,',',header=true)   # model G=2
    contents2,head2 = readdlm(file2,',',header=true)   # model G=3
    f = open(outfile,"w")
    if addlabel
        header = vcat(String.(head1[2:end]) .* "_G2",String.(head2[2:end]) .* "_G3")
    else
        header = vcat(String.(head1[2:end]),String.(head2[2:end]))
    end
    header = reshape(permutedims(header),(1,length(head1)+length(head2)-2))
    header = hcat(head1[1],header)
    println(header)
    writedlm(f,header,',')
    for row in 1:size(contents1,1)
        if contents1[row,1] == contents2[row,1]
            contents = hcat(contents1[row:row,2:end],contents2[row:row,2:end])
            contents = reshape(permutedims(contents),(1,size(contents1,2)+size(contents2,2)-2))
            contents = hcat(contents1[row,1],contents)
            writedlm(f,contents,',')
        end
    end
    close(f)
end

function best_model(file::String)
    contents,head = readdlm(file,',',header=true)
    f = open(file,"w")
    head = hcat(head,"Winning Model")
    writedlm(f,head,',')
    for row in eachrow(contents)
        if abs(row[11] - row[4]) > row[5] + row[12]
            if row[11] < row[4]
                writedlm(f, hcat(permutedims(row),3),',')
            else
                writedlm(f, hcat(permutedims(row),2),',')
            end
        else
            if row[13] < row[6]
                writedlm(f, hcat(permutedims(row),3),',')
            else
                writedlm(f, hcat(permutedims(row),2),',')
            end
        end
    end
    close(f)
end

function add_best_burst(filein,fileout,filemodel2,filemodel3)
    contents,head = readdlm(filein,',',header=true)
    burst2,head2 = readdlm(filemodel2,',',header=true)
    burst3,head3 = readdlm(filemodel3,',',header=true)
    f = open(fileout,"w")
    head = hcat(head,["mean off period" "bust size"])
    writedlm(f,head,',')
    for row in eachrow(contents)
        if Int(row[end]) == 2
            writedlm(f, hcat(permutedims(row),permutedims(burst2[findfirst(burst2[:,1] .== row[1]),2:3])),',')
        else
            writedlm(f, hcat(permutedims(row),permutedims(burst3[findfirst(burst3[:,1] .== row[1]),2:3])),',')
        end
    end
    close(f)
end

function add_best_occupancy(filein,fileout,filemodel2,filemodel3)
    contents,head = readdlm(filein,',',header=true)
    occupancy2,head2 = readdlm(filemodel2,',',header=true)
    occupancy3,head3 = readdlm(filemodel3,',',header=true)
    f = open(fileout,"w")
    head = hcat(head,["Off -2" "Off -1" "On State" ])
    writedlm(f,head,',')
    for row in eachrow(contents)
        if Int(row[end-2]) == 2
            writedlm(f, hcat(permutedims(row),hcat("NA",permutedims(occupancy2[findfirst(occupancy2[:,1] .== row[1]),2:end]))),',')
        else
            writedlm(f, hcat(permutedims(row),permutedims(occupancy3[findfirst(occupancy3[:,1] .== row[1]),2:end])),',')
        end
    end
    close(f)
end


# precompile(fit_rna,(String,String,Int,Float64,String,String,String,String,String,Int,String,Bool))
# fit_rna(nchains,gene::String,cond::String,G::Int,maxtime::Float64,infolder::String,resultfolder,datafolder,inlabel,label,nsets,runcycle::Bool=false,sample::Int=40000,warmup=20000,anneal=100000,temp=1.,tempanneal=100.,root = "/home/carsonc/scrna/")
