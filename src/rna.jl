"""
rna.jl

Fit G state models (generalized telegraph models) to RNA abundance data
For single cell RNA (scRNA) technical noise is included as a yieldfactor
single molecule FISH (smFISH) is treated as loss less
"""

# Functions necessary for metropolis_hastings.jl
"""
datahistogram(data)
Return the RNA histogram data as one vector
"""
datahistogram(data::RNAData) = data.histRNA
function datahistogram(data::AbstractRNAData{Array{Array,1}})
# function datahistogram(data::TransientRNAData)
    v = data.histRNA[1]
    for i in 2:length(data.histRNA)
        v = vcat(v,data.histRNA[i])
    end
    return v
end
datahistogram(data::AbstractRNAData{Array{Float64,1}}) = data.histRNA
"""
logprior(param,model::AbstractGMmodel)

compute log of the prior
"""
function logprior(param,model::AbstractGMmodel)
    d = model.rateprior
    p=0
    for i in eachindex(d)
        p -= logpdf(d[i],param[i])
    end
    return p
end
"""
likelihoodfn(param,data,model)
model likelihoodfn
"""
function likelihoodfn(param,data::RNAData,model::GMmodel)
    r = get_rates(param,model)
    n = model.G-1
    steady_state(r[1:2*n+2],n,data.nRNA,model.nalleles)
end
function likelihoodfn(param,data::RNAData,model::GMlossmodel)
    r = get_rates(param,model)
    yieldfactor = r[end]
    n = model.G-1
    steady_state(r[1:2*n+2],yieldfactor,n,data.nRNA,model.nalleles)
end
function likelihoodfn(param,data::AbstractRNAData{Array{Array,1}},model::AbstractGMmodel)
    h = likelihoodarray(param,data,model)
    hconcat = Array{Float64,1}(undef,0)
    for h in h
        hconcat = vcat(hconcat,h)
    end
    return hconcat
end

######
"""
likelihoodarray(param,data,model::AbstractGmodel)

Compute time dependent GM model likelihoods
first set of parameters gives the initial histogram
2nd set gives the new parameters at time 0
data.histRNA holds array of histograms for time points given by data.time
transient computes the time evolution of the histogram
model.method=1 specifies finite difference solution otherwise use eigendecomposition solution,
"""
function likelihoodarray(param,data::TransientRNAData,model::GMlossmodel)
    yieldfactor = get_rates(param,model)[end]
    h = likelihoodarray(param,data::TransientRNAData,model,maximum(data.nRNA))
    technical_loss!(h,yieldfactor)
    trim(h,data.nRNA)
end
function likelihoodarray(param,data::TransientRNAData,model,maxdata)
    r = get_rates(param,model)
    G = model.G
    h0 = initial_distribution(param,r,G,model,maxdata)
    transient(r,G,data.time,model,h0)
end
function likelihoodarray(param,data::TransientRNAData,model::AbstractGMmodel)
    h=likelihoodarray(param,data,model,maximum(data.nRNA))
    # r = get_rates(param,model)
    # G = model.G
    # h0 = initial_distribution(param,r,G,model,maximum(data.nRNA))
    # h = transient(r,G,data.time,model,h0)
    trim(h,data.nRNA)
end
function likelihoodarray(param,data::RNAData,model::GMmultimodel)
    r = get_rates(param,model)
    G = model.G
    h = Array{Array{Float64,1},1}(undef,length(data.nRNA))
    for i in eachindex(data.nRNA)
        g = steady_state(r[1:2*G],G-1,data.nRNA[i],model.nalleles)
        h[i] = threshold_noise(g,r[2*G+1],r[2*G+1+i],data.nRNA[i])
    end
    return h
end
function likelihoodarray(param,data::RNAMixedData,model::AbstractGMmodel)
    r = get_rates(param,model)
    G = model.G
    h = Array{Array{Float64,1},1}(undef,length(data.nRNA))
    j = 1
    for i in eachindex(data.fish)
        g = steady_state(r[1:2*G],G-1,maximum(data.nRNA),model.nalleles)
        if data.fish[i]
            h[i] = threshold_noise(g,r[2*G+j],r[2*G+j+1],data.nRNA[i])
            j += 2
        else
            h[i] = technical_loss(g,r[2*G+j],data.nRNA[i])
            j += 1
        end
    end
    return h
end

function testmodel(model,nhist)
    G = model.G
    r = model.rates
    g1 = steady_state(r[1:2*G],G-1,nhist,model.nalleles)
    g2 = telegraph(G-1,r[1:2*G],10000000,1e-5,nhist,model.nalleles)
    return g1,g2
end

# Load data, model, and option structures
"""
transient_rna(nsets::Int,control::String,treatment::String,time::Float64,gene::String,r::Vector,decayprior::Float64,yieldprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
Fit transient G model to time dependent mRNA data
"""
function transient_rna(control::String,treatment::String,name::String,time::Float64,gene::String,r::Vector,decayprior::Float64,yieldprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    data = data_rna([control;treatment],name,time,gene)
    model = model_rna(r,G,nalleles,2,cv,fittedparam,decayprior,yieldprior,method)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return data,model,options
end
function transient_rna(path,name::String,time,gene::String,nsets::Int,r::Vector,decayprior::Float64,yieldprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,time,gene)
    model = model_rna(r,G,nalleles,nsets,cv,fittedparam,decayprior,yieldprior,method)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return data,model,options
end
function transient_fish(path,name::String,time,gene::String,r::Vector,decayprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,time,gene,true)
    model,options = transient_fish(r,decayprior,G,nalleles,fittedparam,cv,maxtime,samplesteps,temp,method,warmupsteps,annealsteps)
    return data,model,options
end
function transient_fish(path,name::String,time,gene::String,r::Vector,decayprior::Float64,delayprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,time,gene,true)
    model,options = transient_fish(r,decayprior,delayprior,G,nalleles,fittedparam,cv,maxtime,samplesteps,temp,method,warmupsteps,annealsteps)
    return data,model,options
end
function transient_fish(r::Vector,decayprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    model = model_rna(r,G,nalleles,2,cv,fittedparam,decayprior,method)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return model,options
end
function transient_fish(r::Vector,decayprior::Float64,delayprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    model = model_delay_rna(r,G,nalleles,2,cv,fittedparam,decayprior,delayprior)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return model,options
end
function transient_rnafish(path,name::String,time,gene::String,nsets::Int,r::Vector,decayprior::Float64,yieldprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,time,gene)
    model,options = transient_rnafish(r,decayprior,yieldprior,G,nalleles,fittedparam,cv,maxtime,samplesteps,temp,method,warmupsteps,annealsteps)
    return data,model,options
end
function transient_rnafish(r::Vector,decayprior::Float64,yieldprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp::Float64=10.,method::Int=1,warmupsteps=0,annealsteps=0)
    model = model_rna(r,G,nalleles,nsets,cv,fittedparam,decayprior,yieldprior,method)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return model,options
end

"""
steadystate_rna(nsets::Int,file::String,gene::String,r::Vector,decayprior::Float64,yieldprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp=10.,warmupsteps=0,annealsteps=0)
Fit G model to steady state data
"""
function steadystate_rna(path,name::String,gene::String,nsets,r::Vector,decayprior::Float64,yieldprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp=10.,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,gene,false)
    model = model_rna(r,G,nalleles,nsets,cv,fittedparam,decayprior,yieldprior,0)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return data,model,options
end
function steadystate_rna(path,name::String,gene::String,nsets,r::Vector,decayprior::Float64,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp=10.,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,gene,false)
    model = model_rna(r,G,nalleles,nsets,cv,fittedparam,decayprior,0)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return data,model,options
end
function steadystate_rnafish(path,name::String,gene::String,fish::Array,r::Vector,decayprior::Float64,noisepriors::Vector,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp=10.,method=1,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,gene,fish)
    model = model_rna(r,G,nalleles,cv,fittedparam,decayprior,noisepriors,method)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return data,model,options
end
function thresholds_fish(path,name::String,gene::String,r::Vector,decayprior::Float64,noisepriors::Vector,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp=10.,warmupsteps=0,annealsteps=0)
    data = data_rna(path,name,gene,true)
    model,options = thresholds_fish(r,decayprior,noisepriors,G,nalleles,fittedparam,cv,maxtime,samplesteps,temp,warmupsteps,annealsteps)
    return data,model,options
end
function thresholds_fish(r::Vector,decayprior::Float64,noisepriors::Vector,G::Int,nalleles::Int,fittedparam::Vector,cv,maxtime::Float64,samplesteps::Int,temp=10.,warmupsteps=0,annealsteps=0)
    model = model_rna(r,G,nalleles,cv,fittedparam,decayprior,noisepriors,0)
    options = MHOptions(samplesteps,annealsteps,warmupsteps,maxtime,temp)
    return model,options
end

#Prepare data structures
"""
data_rna(path,time,gene,time)
data_rna(path,time,gene)
Load data structure
"""
function data_rna(path,name,time,gene::String,fish::Bool)
    len,h = histograms_rna(path,gene,fish)
    TransientRNAData(name,gene,len,time,h)
end
function data_rna(path,name,gene::String,fish::Bool)
    len,h = histograms_rna(path,gene,fish)
    RNAData(name,gene,len,h)
end
function data_rna(path,name,gene::String,fish::Array{Bool,1})
    len,h = histograms_rna(path,gene,fish)
    RNAMixedData(name,gene,len,fish,h)
end
"""
histograms_rna(path,gene)
prepare mRNA histograms
"""
function histograms_rna(path::Array,gene::String,fish::Bool)
    n = length(path)
    h = Array{Array,1}(undef,n)
    lengths = Array{Int,1}(undef,n)
    for i in eachindex(path)
        lengths[i], h[i] = histograms_rna(path[i],gene,fish[i])
    end
    return lengths,h
end
function histograms_rna(path::String,gene::String,fish::Bool)
    if fish
        h = read_fish(path,gene,.98)
    else
        h = read_scrna(path,.99)
    end
    return length(h),h
end
function histograms_rna(path::Array,gene::String,fish::Array{Bool,1})
    n = length(path)
    h = Array{Array,1}(undef,n)
    lengths = Array{Int,1}(undef,n)
    for i in eachindex(path)
        lengths[i], h[i] = histograms_rna(path[i],gene,fish[i])
    end
    return lengths,h
end
# Prepare model structures
"""
model_rna(r,G,nalleles,nsets,propcv,fittedparam,decayprior,yieldprior,method)
model_rna(r,G,nalleles,nsets,propcv,fittedparam,decayprior,method)
model_rna(r,G,nalleles,nsets,propcv,fittedparam,decayprior,noisepriors,method)
Load model structure
"""
function model_rna(r::Vector,G::Int,nalleles::Int,nsets::Int,propcv,fittedparam::Array,decayprior::Float64,yieldprior::Float64,method::Int)
    # propcv = proposal_cv_rna(propcv,fittedparam)
    d = prior_rna(r,G,nsets,fittedparam,decayprior,yieldprior)
    GMlossmodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),typeof(method)}(G,nalleles,r,d,propcv,fittedparam,method)
end
function model_rna(r::Vector,G::Int,nalleles::Int,nsets::Int,propcv,fittedparam::Array,decayprior::Float64,method::Int)
    # propcv = proposal_cv_rna(propcv,fittedparam)
    d = prior_rna(r,G::Int,nsets,fittedparam,decayprior)
    GMmodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),typeof(method)}(G,nalleles,r,d,propcv,fittedparam,method)
end
function model_rna(r::Vector,G::Int,nalleles::Int,propcv,fittedparam::Array,decayprior::Float64,noisepriors::Array,method::Int)
    # propcv = proposal_cv_rna(propcv,fittedparam)
    d = prior_rna(r,G::Int,1,fittedparam,decayprior,noisepriors)
    if method == 1
        GMrescaledmodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),typeof(method)}(G,nalleles,r,d,propcv,fittedparam,method)
    else
        GMmultimodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),typeof(method)}(G,nalleles,r,d,propcv,fittedparam,method)
    end
end

function model_delay_rna(r::Vector,G::Int,nalleles::Int,nsets::Int,propcv,fittedparam::Array,decayprior,delayprior)
    # propcv = proposal_cv_rna(propcv,fittedparam)
    d = prior_rna(r,G,nsets,fittedparam,decayprior,delayprior)
    GMdelaymodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),Int64}(G,nalleles,r,d,propcv,fittedparam,1)
end


"""
proposal_cv_rna(propcv)
set propcv to a vector or matrix
"""
proposal_cv_rna(cv) = typeof(cv) == Float64 ? propcv*ones(length(fittedparam)) : propcv
"""
prior_rna(r::Vector,G::Int,nsets::Int,propcv,fittedparam::Array,decayprior,yieldprior)
compute prior distribution
r[mod(1:2*G,nsets)] = rates for each model set  (i.e. rates for each set are stacked)
r[2*G*nsets + 1] == yield factor (i.e remaining after loss due to technical noise)
"""
function prior_rna(r::Vector,G::Int,nsets::Int,fittedparam::Array,decayprior::Float64,yieldprior::Float64)
        if length(r) == 2*G * nsets + 1
            rm,rcv = setpriorrate(G,nsets,decayprior,yieldprior)
            return priorLogNormal(rm[fittedparam],rcv[fittedparam])
        else
            throw("rates have wrong length")
        end
end
function prior_rna(r::Vector,G::Int,nsets::Int,fittedparam::Array,decayprior::Float64)
        if length(r) == 2*G*nsets
            rm,rcv = setpriorrate(G,nsets,decayprior)
            return priorLogNormal(rm[fittedparam],rcv[fittedparam])
        else
            throw("rates have wrong length")
        end
end
"""
prior_rna(r::Vector,G::Int,nsets::Int,fittedparam::Array,decayprior::Float64,noisepriors::Array)

prior for multithresholded smFISH data
r[1:2G] = model rates
r[2G+1] = additive noise mean
r[2G + 1 + 1:length(noisepriors)] = remaining fraction after thresholding (i.e. yield)
"""
function prior_rna(r::Vector,G::Int,nsets::Int,fittedparam::Array,decayprior::Float64,noisepriors::Array)
        if length(r) == 2*G * nsets + length(noisepriors)
            rm,rcv = setpriorrate(G,nsets,decayprior,noisepriors)
            return priorLogNormal(rm[fittedparam],rcv[fittedparam])
        else
            throw("rates have wrong length")
        end
end
"""
function setpriorrate(G)
Set prior distribution for mean and cv of rates
"""
function setpriorrate(G::Int,nsets::Int,decayrate::Float64,yieldfactor::Float64)
    rm,rcv = setpriorrate(G,nsets,decayrate)
    return [rm;yieldfactor],[rcv;.1]
end
function setpriorrate(G::Int,nsets::Int,decayrate::Float64)
    r0 = [.01*ones(2*(G-1));1.5;decayrate]
    rc = [ones(2*(G-1));.25;0.05]
    rm = r0
    rcv = rc
    for i in 2:nsets
        rm = vcat(rm,r0)
        rcv = vcat(rcv,rc)
    end
    return rm,rcv
end

function setpriorrate(G::Int,nsets::Int,decayrate::Float64,noisepriors::Array)
    rm,rcv = setpriorrate(G,nsets,decayrate)
    for nm in noisepriors
        rm = vcat(rm,nm)
        rcv = vcat(rcv,.5)
    end
    return rm,rcv
end

"""
proposal_cv_rna(propcv)
set propcv to a vector or matrix
"""
proposal_cv_rna(propcv,fittedparam) = typeof(propcv) == Float64 ? propcv*ones(length(fittedparam)) : propcv

"""
fittedparam_rna(G,nsets,loss)
select all parameters to be fitted except decay rates
yieldfactor is last parameter in loss models
"""
function fittedparam_rna(G,nsets,loss)
    fp = fittedparam_rna(G,nsets)
    if loss == 1
        return vcat(fp,nsets*2*G+1)
    else
        return fp
    end
end
function fittedparam_rna(G,nsets)
    nrates = 2*G  # total number of rates in GM model
    k = nrates - 1  # adjust all rate parameters except decay time
    fp = Array{Int,1}(undef,nsets*k)
    for j in 0:nsets-1
        for i in 1:k
            fp[k*j + i] = nrates*j + i
        end
    end
    return fp
end
"""
get_rates(param,model::AbstractGMmodel)
replace fitted rates with new values and return
"""
function get_rates(param,model::AbstractGMmodel)
    r = copy(model.rates)
    r[model.fittedparam] = param
    return r
end
"""
get_rates(param,model::GMrescaledmodel)

gammas are scaled by nu
"""
function get_rates(param,model::GMrescaledmodel)
    r = copy(model.rates)
    n = 2*model.G - 1
    nu = n in model.fittedparam ? param[findfirst(model.fittedparam .== n)] : r[n]
    r[1:n-1] /= r[n]
    r[model.fittedparam] = param
    r[1:n-1] *= nu
    if r[2*model.G + 3] > 1
        r[2*model.G + 3] = 1
    end
    return r
end
"""
get_param(model::GMrescaledmodel)


"""
function get_param(model::GMrescaledmodel)
    r = copy(model.rates)
    n = 2*model.G - 1
    r[1:n-1] /= r[n]
    r[model.fittedparam]
end
get_param(model::AbstractGMmodel) = model.rates[model.fittedparam]
"""
rescale_rate_rna(r,G,decayrate::Float64)

set new decay rate and rescale
transition rates such that steady state distribution is the same
"""
function rescale_rate_rna(r,G,decayrate::Float64)
    rnew = copy(r)
    if mod(length(r),2*G) == 0
        rnew *= decayrate/r[2*G]
    else
        stride = fld(length(r),fld(length(r),2*G))
        for i in 0:stride:length(r)-1
            rnew[i+1:i+2*G] *= decayrate/r[2*G]
        end
    end
    return rnew
end

"""
priorLogNormal(r,cv,G,R)
LogNormal Prior distribution
"""
function priorLogNormal(param,cv)
    sigma = sigmalognormal(cv)
    d = []
    for i in eachindex(param)
        push!(d,Distributions.LogNormal(log(param[i]),sigma[i]))
    end
    return d
end



function transient(r::Vector,G::Int,times::Vector,model::GMmodel,h0::Vector)
    transient(times,r[2*G+1:4*G],G-1,model.nalleles,h0,model.method)
end
function transient(r::Vector,G::Int,times::Vector,model::GMdelaymodel,h0::Vector)
    transient_delay(times,r[1:2*G],r[2*G+1:4*G],r[end],G-1,model.nalleles,h0)
end

function initial_distribution(param,r,G::Int,model::AbstractGMmodel,nRNAmax)
    steady_state_full(r[1:2*G],G-1,nRNAmax)
end

function trim(h::Array,nh::Array)
    for i in eachindex(h)
        h[i] = h[i][1:nh[i]]
    end
    return h
end

# Read in data and construct histograms
"""
read_scrna(filename::String,yield::Float64=.99,nhistmax::Int=1000)
Construct mRNA count per cell histogram array of a gene
"""
function read_scrna(filename::String,threshold::Float64=.98,nhistmax::Int=1000)
    if isfile(filename) && filesize(filename) > 0
        x = readdlm(filename)[:,1]
        x = truncate_histogram(x,threshold,nhistmax)
        if x == 0
            dataFISH = Array{Int,1}(undef,0)
        else
            dataFISH = x
        end
        return dataFISH
    else
        return Array{Int,1}(undef,0)
    end
end

"""
read_fish(path,gene,threshold)
Read in FISH data from 7timepoint type folders

"""
function read_fish(path::String,cond::String,threshold::Float64=.98)
    xr = zeros(1000)
    for (root,dirs,files) in walkdir(path)
        for file in files
            target = joinpath(root, file)
            if occursin(cond,target) && occursin("cellular",target)
                println(target)
                x1 = readdlm(target)[:,1]
                lx = length(x1)
                xr[1:min(lx,1000)] += x1[1:min(lx,1000)]
            end
        end
    end
    truncate_histogram(xr,threshold,1000)
end

function read_fish(path1::String,cond1::String,path2::String,cond2::String,threshold::Float64=.98)
    x1 = read_fish(path1,cond1,threshold)
    x2 = read_fish(path2,cond2,threshold)
    combine_histogram(x1,x2)
end


"""
plot_histogram()

functions to plot data and model predicted histograms

"""
function plot_histogram(gene::String,datapaths::Array,modelfile::String,time=[0.;30.;120.],fittedparam=[7;8;9;10;11])
    r = read_rates(modelfile,1)
    data,model,_ = transient_fish(datapaths,"",time,gene,r,1.,3,2,fittedparam,1.,1.,10)
    r = read_rates(modelfile,1)
    h=likelihoodarray(r[fittedparam],data,model)
    figure(gene)
    for i in eachindex(h)
        plot(h[i])
        plot(normalize_histogram(data.histRNA[i]))
    end
    return h
end

function plot_histogram(data::AbstractRNAData{Array{Array,1}},model)
    h=likelihoodarray(get_param(model),data,model)
    figure(data.gene)
    for i in eachindex(h)
        plot(h[i])
        plot(normalize_histogram(data.histRNA[i]))
    end
    return h
end

function plot_histogram(data::RNALiveCellData,model)
    h=likelihoodtuple(get_param(model),data,model)
    figure(data.gene)
    plot(h[1])
    plot(normalize_histogram(data.OFF))
    plot(h[2])
    plot(normalize_histogram(data.ON))
    figure("FISH")
    plot(h[3])
    plot(normalize_histogram(data.histRNA))
    return h
end

function plot_histogram(data::AbstractRNAData{Array{Float64,1}},model)
    h=likelihoodfn(get_param(model),data,model)
    figure(data.gene)
    plot(h)
    plot(normalize_histogram(data.histRNA))
    return h
end

function plot_histogram(r::Array,n,nhist,nalleles)
    h = steady_state(r,n,nhist,nalleles)
    plot(h)
    return h
end

"""
read_fish_scrna(scRNAfolder::String,FISHfolder::String,genein::String,cond::String)
Create a 2D data array of mRNA count/cell histograms for FISH and scRNA for same gene
"""
# function read_fish_scrna(scRNAfolder::String,FISHfolder::String,genein::String,cond::String)
#     histfile = "/cellular RNA histogram.csv"
#     data = Array{Array{Int,1},1}(undef,2)
#     scRNAfile = scRNAfolder * genein * ".txt"
#     data[1] = readRNA_scrna(scRNAfile)
#     rep = ["rep1/","rep2/"]
#     x = Array{Array{Float64,1},1}(undef,2)
#     for r in eachindex(rep)
#         repfolder = FISHfolder * genein * "/" * cond * "/" * rep[r]
#         FISHfiles = readdir(repfolder)
#         FISH = FISHfiles[.~occursin.(".",FISHfiles)]
#         xr = zeros(1000)
#         for folder in FISH
#             x1 = readdlm(repfolder * folder * histfile)[:,1]
#             lx = length(x1)
#             xr[1:min(lx,1000)] += x1[1:min(lx,1000)]
#         end
#         xr /= length(FISH)
#         xr = round.(Int,xr)
#         x[r] = truncate_histogram(xr,.99,1000)
#     end
#     l = min(length(x[1]),length(x[2]))
#     data[2] = x[1][1:l] + x[2][1:l]
#     return data
# end
"""
read_rates_srna(infile,rinchar,inpath)
read in saved rates
"""
# function read_rates_scrna(infile::String,rinchar::String,inpath="/Users/carsonc/Box/scrna/Results/")
#     infile = inpath * infile
#     if isfile(infile) && ~isempty(read(infile))
#         readdlm(infile)[:,1]
#     else
#         return 0
#     end
# end
#
# function read_rates_scrna(infile::String,rinchar::String,gene::String,inpath="/Users/carsonc/Box/scrna/Results/")
#     if rinchar == "rml" || rinchar == "rlast"
#         rskip = 1
#         rstart = 1
#     elseif rinchar == "rmean"
#         rskip = 2
#         rstart = 1
#     elseif rinchar == "rquant"
#         rskip = 3
#         rstart = 2
#     end
#     if isfile(infile) && ~isempty(read(infile))
#         rall = readdlm(infile)
#         rind = findfirst(rall[:,1] .== gene)
#         if ~isnothing(rind)
#             return convert(Array{Float64,1},rall[rind,rstart:rskip:end])
#         else
#             return 0
#         end
#     else
#         return 0
#     end
# end
