
"""
genetrap.jl

Fit GRSM models to live cell and smFISH data
"""

"""
Gene information
"""
const genes = ["CANX";"DNAJC5";"ERRFI1";"KPNB1";"MYH9";"Rab7a";"RHOA";"RPAP3";"Sec16A";"SLC2A1"]
const genelength = Dict([("Sec16A", 42960);("SLC2A1", 33802);("ERRFI1", 14615);("RHOA", 52948);("KPNB1", 33730);("MYH9", 106741);("DNAJC5", 40930);("CANX", 32710);("Rab7a", 88663);("RPAP3", 44130)])
const MS2end = Dict([("Sec16A", 5220);("SLC2A1", 26001);("ERRFI1", 5324);("RHOA", 51109);("KPNB1", 24000);("MYH9", 71998);("DNAJC5", 14857);("CANX", 4861);("Rab7a", 83257);("RPAP3", 38610)])
const halflife = Dict([("CANX", 50.),("DNAJC5", 5.),("ERRFI1", 1.35),("KPNB1", 9.),("MYH9", 10.),("Rab7a", 50.),("RHOA", 50.),("RPAP3", 7.5),("Sec16A", 8.),("SLC2A1", 5.)])


"""
    fit_genetrap()

"""

# fittedparam=collect(1:num_rates(G,R)-1)
function makeswarm_genetrap(sfile,juliafile,nchains,genes::Vector,G::Int,R::Int,nalleles::Int,root::String,folder::String,maxtime::Float64,samplesteps::Int)
write_swarmfile(sfile,nchains,juliafile,genes)
write_fitfile(juliafile,nchains,G,R,nalleles,root,folder,maxtime,samplesteps)
end

function write_fitfile(fitfile,nchains,G::Int,R::Int,nalleles::Int,root::String,folder::String,maxtime::Float64,samplesteps::Int)
        f = open(fitfile,"w")
        s =   '"'
        write(f,"@everywhere using StochasticGene\n")
        write(f,"@time fit_genetrap($nchains,ARGS[1],$G,$R,$nalleles,$s$root$s,$s$folder$s,$maxtime,$samplesteps)\n")
        close(f)
end

function fit_genetrap(nchains,maxtime,gene::String,transitions,G::Int,R::Int,infolder::String,folder::String,samplesteps::Int=1000,nalleles::Int=2,type="",fittedparam=collect(1:num_rates(G,R)-1),root::String=".",warmupsteps=0,annealsteps=0,temp=1.,tempanneal=1.,tempfish=1.)
    println(now())
    data,model,options = genetrap(root,gene,fittedparam,transitions,G,R,2,type,infolder,folder,"gt","median",maxtime,samplesteps,warmupsteps,annealsteps,temp,tempanneal,tempfish)
    println("size of histogram: ",data.nRNA)
    print_ll(data,model)
    fit,stats,measures = run_mh(data,model,options,nchains)
    finalize(data,model,fit,stats,measures,1.,folder,0,root)
    println(now())
    get_rates(stats.medparam,model)
end


"""
genetrap()

Load data, model and option structures for metropolis-hastings fit
root is the folder containing data and results

FISH counts is divided by tempfish to adjust relative weights of data
set tempfish = 0 to equalize FISH and live cell counts
"""
function genetrap(root,gene::String,fittedparam::Vector,transitions::Tuple,G::Int,R::Int,nalleles,type::String,infolder::String,resultfolder::String,label::String,rtype::String="median",maxtime::Float64=60.,samplesteps::Int=100000,warmupsteps=0,annealsteps=0,temp=1.,tempanneal=100.,tempfish=1.)
    # r = readrates_genetrap(root,infolder,rtype,gene,"$G$R",type)
    r = readrates_genetrap(joinpath(root,infolder),rtype,gene,label,G,R,nalleles,type)
    println(r)
    genetrap(root,r,label,gene,G,R,transitions,2,fittedparam,type,maxtime,samplesteps,warmupsteps,annealsteps)
end

function genetrap(root,r,label::String,gene::String,G::Int,R::Int,transitions,nalleles::Int,fittedparam,type::String,maxtime::Float64,samplesteps::Int,warmupsteps=0,annealsteps=0,method=1,temp=1.,tempanneal=1.,tempfish=1.)
    data = iszero(R) || iszero(tempfish) ? data_genetrap_FISH(root,label,gene) : data_genetrap(root,label,gene,tempfish)
    model = model_genetrap(r,gene,G,R,nalleles,fittedparam,type,method,transitions,data)
    options = MHOptions(samplesteps,warmupsteps,annealsteps,maxtime,temp,tempanneal)
    return data,model,options
end

function data_genetrap(root,label,gene,tempfish=1.)
    LC = readLCPDF_genetrap(root,gene)
    if tempfish == 0
        counts = Int(div(sum(LC[:,2]+LC[:,3]),2))
        println(counts)
        # set FISH counts to mean of live cell counts
        histFISH = readFISH_genetrap(root,gene,counts)
    else
        histFISH = readFISH_genetrap(root,gene,tempfish)
    end
    RNALiveCellData(label,gene,length(histFISH),histFISH,LC[:,1],LC[:,3],LC[:,2])
end

function data_genetrap_FISH(root,label,gene)
    histFISH = readFISH_genetrap(root,gene,1.)
    RNAData(label,gene,length(histFISH),histFISH)
end

"""
model_genetrap

load model structure
"""
function model_genetrap(r,gene::String,G::Int,R::Int,nalleles::Int,fittedparam,type::String,method,transitions,data)
    if R == 0
        decayrate = get_decay(halflife[gene])
        if r == 0
            r = setrate(G,1,decayrate,.1)[1]
        end
        d = prior_rna(r,G,1,fittedparam,decayrate,1.)
        components = make_components(transitions,G,r,data)
        return GMmodel{typeof(r),typeof(d),Float64,typeof(fittedparam),typeof(method),typeof(components)}(G,nalleles,r,d,0.05,fittedparam,method,transitions,components)
    else
        propcv=[.05*ones(2*(G-1));.05;0.05*ones(R);.05*ones(R)]
        propcv = .001
        Gprior=(.1,10.)
        Sprior=(.1,10.)
        Rcv=10.
        rm,rcv = prior_rates_genetrap(G,R,gene,Gprior,Sprior,Rcv,true)
        if r == 0
            r = rm
        end
        # d = priordistributionLogNormal_genetrap(rm,rcv,G,R)
        # d = priordistributionLogNormal_genetrap(rm,rcv,G,R)
        d = distribution_array(rm[fittedparam],rcv[fittedparam],LogNormal)
        components = make_components(transitions,G,R,r,data,type)
        return GRSMmodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),typeof(method),typeof(components)}(G,R,nalleles,type,r,d,propcv,fittedparam,method,transitions,components)
    end
end

"""
setpriorrate(G,R,gene,Gprior::Tuple,Sprior::Tuple,Rcv::Float64)
Set prior distribution for mean and cv of rates
"""
function prior_rates_genetrap(G,R,gene,Gprior::Tuple,Sprior::Tuple,Rcv::Float64,free::Bool)
    if free
        rm = [fill(Gprior[1],2*G-2);.1;fill(Sprior[1], R);fill(Sprior[1], R);log(2.)/(60 .* halflife[gene])]
    else
        rm = [fill(Gprior[1],2*G-2);2000/(genelength[gene]-MS2end[gene]);fill(2000/MS2end[gene]*R,R);fill(Sprior[1], R);log(2.)/(60 .* halflife[gene])]
    end
    rcv = [fill(Gprior[2],2*G-2);Rcv;fill(Sprior[2],R);fill(Sprior[2], R);.01]
    return rm,rcv
end


"""
priordistributionLogNormal_genetrap(r,cv,G,R)

LogNormal Prior distribution
"""
function priordistributionLogNormal_genetrap(r,cv,G,R)
    sigma = sigmalognormal(cv)
    d = []
    j = 1
    #  G rates
    for i in Grange(G)
        push!(d,Distributions.LogNormal(log(r[i]),sigma[j]))
        j += 1
    end
    # initiation rate
    i = initiation(G)
    push!(d,Distributions.LogNormal(log(r[i]),sigma[j]))
    j += 1
    # Step rates are bounded by length of insertion site to end of gene, i.e sum of reciprocal rates is bounded
    t = sum(1 ./ r[Rrange(G,R)])
    push!(d,Distributions.LogNormal(-log(t),sigma[j]))
    j += 1
    # priors for splice rates
    rs = 0.
    for i in Srange(G,R)
        rs += r[i]
        push!(d,Distributions.LogNormal(log(rs),sigma[j]))
        j += 1
    end
    return d
end

"""
priordistributionGamma_genetrap(r,cv,G,R)

Gamma Prior distribution
"""
function priordistributionGamma_genetrap(rm,cv,G,R)
    n = G-1
    zet = R
    d = []
    rsig = cv .^ 2
    j = 1
    # priors for G rates
    for i in Grange(G)
        theta = rsig[j]*rm[i]
        alpha = 1/rsig[j]
        push!(d,Distributions.Gamma(alpha,theta))
        j += 1
    end
    # prior for nu1 is upper bounded by rm, i.e. distance is bounded by distance to insertion site
    theta = rsig[j]*rm[initiation(G)]
    alpha = 1/rsig[j]
    push!(d,Distributions.Gamma(alpha,theta))
    j += 1
    # priors for nu rates are bounded by length of insertion site to end of gene, i.e sum of reciprocal rates is bounded
    tm = sum(1 ./ rm[Rrange(G,R)])
    # for i in 2*n + 2 : 2*n + zet + 1
    #     tm += 1/rm[i]
    # end
    theta = rsig[j]/tm
    alpha = 1/rsig[j]
    push!(d,Distributions.Gamma(alpha,theta))
    j += 1
    # priors for ejection rates
    rs = 0
    for i in Srange(G,R)
        rs += rm[i]
        theta = rsig[j]*rs
        alpha = 1/rsig[j]
        push!(d,Distributions.Gamma(alpha,theta))
        j += 1
    end
    return d
end


"""
readLCPDF_genetrap(root,gene)

Read in dwell time PDF
"""
function readLCPDF_genetrap(root,gene)
    infile = joinpath(root,"DwellTimePDF/$(gene)_PDF.csv")
    if isfile(infile)
        LC = readdlm(infile,',')
        x = truncate_histogram(LC[:,2],.999,1000)
        LC[1:length(x),:]
    else
        println("No data for gene: ", gene)
    end
end

"""
readFISH_genetrap(root,gene,temp=1.,clone=true)

Read and assemble smFISH data
"""
function readFISH_genetrap(root::String,gene::String,temp::Float64=1.,clone=true)
    counts = countsFISH_genetrap(root,gene,clone)
    readFISH_genetrap(root,gene,Int(div(counts,temp)),clone)
end

function readFISH_genetrap(root::String,gene::String,counts::Int,clone=true)
    fishfile=joinpath(root,"Fish_4_Genes/$(gene)_steady_state_mRNA.csv")
    col = clone ? 3 : 2
    # Get smFISH RNA histograms
    if isfile(fishfile)
        x = readdlm(fishfile,',')[3:end,col]
        x = x[x .!= ""]
        x = truncate_histogram(x,.99,1000)
        x /= sum(x)
        x *= counts
        return x
    else
        println("No smFISH data for gene: ", gene)
    end
    nothing
end

"""
countsFISH_genetrap(root,gene,x,counts,clone=true)

read in smFISH counts
"""
function countsFISH_genetrap(root,gene,clone=true)
    countfile = joinpath(root,"counts/total_counts.csv")
    wttext = "WT_"
    clonetext = "_clone"
    if isfile(countfile)
        countsdata = readdlm(countfile,',')[:,:]
        if clone
            counts=(countsdata[findall(uppercase("$(gene)$clonetext") .== uppercase.(countsdata[:,1])),2])[1]
        else
            counts=(countsdata[findall("$wttext$(gene)" .== countsdata[:,1]),2])[1]
        end
    else
        counts = 1000
    end
    return counts
end

"""
readrates_genetrap(infolder::String,rtype::String,gene::String,model::String,type::String)

Read in initial rates from previous runs
"""

function readrates_genetrap(infolder::String,rtype::String,gene::String,label,G,R,nalleles,type::String)
    if rtype == "ml"
        row = 1
    elseif rtype == "mean"
        row = 2
    elseif rtype == "median"
        row = 3
    elseif rtype == "last"
        row = 4
    else
        row = 2
    end
    if type == "offeject" || type == "on"
        type = ""
    end
    infile = getratefile_genetrap(infolder,rtype,gene,label,G,R,nalleles,type)
    println(gene," ","$G$R"," ",type)
    readrates_genetrap(infile,row)
end

function readrates_genetrap(infile::String,row::Int)
    if isfile(infile) && ~isempty(read(infile))
        return readrates(infile,row)
    else
        println(" no prior")
        return 0
    end
end


function getratefile_genetrap(infolder::String,rtype::String,gene::String,label,G,R,nalleles,type::String)
    model = R == 0 ? "$G" : "$G$R"
    file = "rates" * "_" * label * "_" * gene * "_" * model * "_"  * "$(nalleles)" * ".txt"
    joinpath(infolder,file)
end