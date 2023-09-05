###  common.jl


# Data types
"""
    AbstractExperimentalData

abstract type for experimental data
"""
abstract type AbstractExperimentalData end
"""
    AbstractSampleData

abstract type for data in the form of samples
"""
abstract type AbstractSampleData <: AbstractExperimentalData end
"""
    AbstractHistogramData

abstract type for data in the form of a histogram (probability distribution)
"""
abstract type AbstractHistogramData <: AbstractExperimentalData end

"""
    AbstractRNAData{hType}

abstract type for steady state RNA histogram data
"""
abstract type AbstractRNAData{hType} <: AbstractHistogramData end
"""
    AbstractTraceData
    
abstract type for intensity time series data
"""
abstract type AbstractTraceData <: AbstractExperimentalData end

"""
    AbstractTraceHistogramData
    
abstract type for combined time series and histogram data
"""
abstract type AbstractTraceHistogramData <: AbstractExperimentalData end

# Data structures 

"""
    Data structures

Do not use underscore "_" in name

arguments:
name: label for the data set
gene: gene name (case sensitive)
nRNA: length of histogram
histRNA: RNA histograms
bins: number of live cell recording time bins
OFF:  OFF time probability density
ON:: ON time probability density
"""
struct RNAData{nType,hType} <: AbstractRNAData{hType}
    name::String
    gene::String
    nRNA::nType
    histRNA::hType
end
struct TransientRNAData{nType,tType,hType} <: AbstractRNAData{hType}
    name::String
    gene::String
    nRNA::nType
    time::tType
    histRNA::hType
end
struct RNAMixedData{hType} <: AbstractRNAData{hType}
    name::String
    gene::String
    nRNA::Array
    fish::Array{Bool,1}
    histRNA::hType
end
struct OnOffData <: AbstractHistogramData
    name::String
    gene::String
    bins::Array
    OFF::Array
    ON::Array
end
struct RNALiveCellData <: AbstractHistogramData
    name::String
    gene::String
    nRNA::Int
    histRNA::Array
    bins::Array
    OFF::Array
    ON::Array
end
struct RNADwellTimeData <: AbstractHistogramData
    name::String
    gene::String
    nRNA::Int
    histRNA::Array
    bins::Array
    DwellTimes::Array
    DTtypes::Array
end
struct TraceData <: AbstractTraceData
    name::String
    gene::String
    interval::Float64
    trace::Vector
end
struct TraceRNAData{hType} <: AbstractTraceHistogramData
    name::String
    gene::String
    trace::Vector
    nRNA::Int
    histRNA::hType
end

"""
    Abstract model types
"""
abstract type AbstractModel end
abstract type AbstractGRmodel <: AbstractModel end
abstract type AbstractGMmodel <: AbstractGRmodel end
abstract type AbstractGRMmodel <: AbstractGRmodel end
abstract type AbstractGMfixedeffectsmodel <: AbstractGMmodel end

"""
    Model structures

fields:
G: number of G steps
R: number of R steps
S: indicator for splicing, 0 no splicing, > 1 splicing
insertstep: R step where reporter is inserted (first step where reporter is visible)
nalleles: number of alleles producing RNA
rnatype: choices are "", "offeject", "offdecay"
rates: transition rates
rateprior: prior for rates
proposal: MCMC proposal distribution
fittedparam: indices of rates to be fitted
    randomeffects: indices of rates that are fixed to each other, in the form of a 2tuple of vectors
    with index 1 the tied index vector and 2 the corresponding fitted index vector
fixedeffects: tuple of vectors of rates that are locked together
method: numerical method for solving Master equation
-`Gtransitions`:  tuple of vectors of G state transitions
-`reporters`: vector of reporters or sojorn states (onstates) or vectors of vectors depending on model and data
"""
struct GMmodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGMmodel
    G::Int
    nalleles::Int
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end
struct GMfixedeffectsmodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGMfixedeffectsmodel
    G::Int
    nalleles::Int
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    fixedeffects::Tuple
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end
struct GMdelaymodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGMmodel
    G::Int
    nalleles::Int
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end
struct GMmultimodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGMmodel
    G::Int
    nalleles::Int
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end
struct GMtransientmodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGMmodel
    G::Int
    nalleles::Int
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end
struct GMrescaledmodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGMmodel
    G::Int
    nalleles::Int
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end
struct GRMmodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGRMmodel
    G::Int
    R::Int
    insertstep::Int
    nalleles::Int
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end
struct GRSMmodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGRMmodel
    G::Int
    R::Int
    S::Int
    insertstep::Int
    nalleles::Int
    rnatype::String
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end

struct GRSMfixedeffectsmodel{RateType,PriorType,ProposalType,ParamType,MethodType,ComponentType} <: AbstractGRMmodel
    G::Int
    R::Int
    S::Int
    insertstep::Int
    nalleles::Int
    rnatype::String
    rates::RateType
    rateprior::PriorType
    proposal::ProposalType
    fittedparam::ParamType
    fixedeffects::Tuple
    method::MethodType
    Gtransitions::Tuple
    components::ComponentType
    reporters::Vector
end

"""
    print_model(model::AbstractModel)

print all fields of model
"""
function print_model(model::AbstractModel)
    for fname in fieldnames(model)
        println("$fname =",getfield(model,fname))
    end
end

"""
Abstract Option types for fitting methods
"""
abstract type Options end
abstract type Results end

# Model and Data dependent functions

"""
datahistogram(data)
Return the RNA histogram data as one vector
"""
# datahistogram(data::RNAData) = data.histRNA
function datahistogram(data::AbstractRNAData{Array{Array,1}})
# function datahistogram(data::TransientRNAData)
    v = data.histRNA[1]
    for i in 2:length(data.histRNA)
        v = vcat(v,data.histRNA[i])
    end
    return v
end
datahistogram(data::AbstractRNAData{Array{Float64,1}}) = data.histRNA
datahistogram(data::RNALiveCellData) = [data.OFF;data.ON;data.histRNA]

datapdf(data::AbstractRNAData{Array{Float64,1}}) = normalize_histogram(data.histRNA)
datapdf(data::RNALiveCellData) = [normalize_histogram(data.OFF);normalize_histogram(data.ON);normalize_histogram(data.histRNA)]
# datapdf(data::AbstractRNAData{Array{Array,1}}) = normalize_histogram(datahistogram(data))
function datapdf(data::AbstractRNAData{Array{Array,1}})
# function datahistogram(data::TransientRNAData)
    v = normalize_histogram(data.histRNA[1])
    for i in 2:length(data.histRNA)
        v = vcat(v,normalize_histogram(data.histRNA[i]))
    end
    return v
end

#### Model likelihoods   ####
"""
loglikelihood(param,data::AbstractHistogramData,model)

returns negative loglikelihood of all data and vector of the prediction histogram negative loglikelihood
Calls likelihoodfn and datahistogram
provided for each data and model type
"""
function loglikelihood(param,data::AbstractHistogramData,model::AbstractGRmodel)
    predictions = likelihoodfn(param,data,model)
    hist = datahistogram(data)
    logpredictions = log.(max.(predictions,eps()))
    return crossentropy(logpredictions,hist), -logpredictions
end
"""
    loglikelihood(param,data::AbstractTraceData,model::GMmodel)

return negative loglikelihood of combined time series traces and each trace

assume Gaussian observation probability model with four parameters
"""
function loglikelihood(param, data::AbstractTraceHistogramData, model::AbstractGRMmodel)
    r = get_rates(param, model)
    # reporters = num_reporters(model.G, model.R, model.S)
    llg,llgp = ll_Gaussian(r, Rmodel.components.tcomponents.nT, model.reporters, model.components.tcomponents.elementsT, data.interval, data.trace)
    M = make_mat_M(model.components.mcomponents,r)
    histF = steady_state(M,model.components.mcomponents.nT,model.nalleles,data.nRNA)
    hist = datahistogram(data)
    logpredictions = log.(max.(predictions,eps()))
    return crossentropy(logpredictions,hist)+llg, vcat(-logpredictions,llgp)  # concatenate logpdf of histogram data with loglikelihood of traces
end
"""
    loglikelihood(param,data::AbstractTraceData,model::GMmodel)

return negative loglikelihood of combined time series traces and each trace

assume Gaussian observation probability model with four parameters
"""
# function loglikelihood(param, data::AbstractTraceData, model::GMmodel)
#     r = get_rates(param, model)
#     # reporters = num_reporters(model.G, model.reporters)
#     ll_Gaussian(r, model.G, model.reporters, model.components.elementsT, data.interval, data.trace)
# end

function loglikelihood(param, data::AbstractTraceData, model::AbstractGRmodel)
    r = get_rates(param, model)
    # reporters = num_reporters(model.G, model.R, 0, sum)
    # base = 2
    ll_Gaussian(r, model.components.nT, model.reporters, model.components.elementsT, data.interval, data.trace)
end

# function loglikelihood(param, data::AbstractTraceData, model::GRSMmodel)
#     r = get_rates(param, model)
#     # reporters = num_reporters(model.G, model.R, model.S)
#     # base = 3
#     ll_Gaussian(r, model.component.nT, model.reporters, model.components.elementsT, data.interval, data.trace)
# end


"""
    likelihoodfn(param,data::RNAData{T1,T2},model::AbstractGMmodel) where {T1 <: Int, T2 <: Array}

return likelihoodfn for single RNA histogram
"""
function likelihoodfn(param,data::RNAData{T1,T2},model::AbstractGMmodel) where {T1 <: Int, T2 <: Array}
    r = get_rates(param,model)
    M = make_mat_M(model.components,r)
    steady_state(M,model.G,model.nalleles,data.nRNA)
end
"""
    likelihoodfn(param,data::AbstractHistogramData,model)

return loglikelihood
"""
function likelihoodfn(param,data::AbstractHistogramData,model)
    h = likelihoodarray(get_rates(param,model),data,model)
    make_array{h}
end
# function likelihoodfn(param,data::RNAData{T1,T2},model::AbstractGMmodel) where {T1 <: Array, T2 <: Array}
#     h = likelihoodarray(get_rates(param,model),data,model)
#     make_array{h}
#     hconcat = Array{Float64,1}(undef,0)
#     for h in h
#         hconcat = vcat(hconcat,h)
#     end
#     return hconcat
# end
# function likelihoodfn(param::Vector,data::RNALiveCellData,model)
#     modelOFF, modelON, histF = likelihoodtuple(get_rates(param,model),data,model)
#     return [modelOFF;modelON;histF]
# end

# function likelihoodfn(param::Vector,data::RNASurvivalData,model)
#     modelOFF, modelON, histF = likelihoodtuple(get_rates(param,model),data,model)
#     return [modelOFF;modelON;histF]
# end


likelihoodfn(param::Vector,data::RNAData,model::AbstractGRMmodel) =
    steady_state(get_rates(param,model),model.G,model.R,data.nRNA,model.nalleles)


"""
likelihoodarray(r,data,model)

Compute likelihoods for multiple distributions

r = full rate vector including yield if it exists
data = data structure
model = model structure


For time dependent model likelihoods
first set of parameters gives the initial histogram
2nd set gives the new parameters at subsequent times
data.histRNA holds array of histograms for time points given by data.time
transient computes the time evolution of the histogram
model.method=1 specifies finite difference solution using DifferentialEquations.jl otherwise use eigendecomposition solution,
"""
function likelihoodarray(r,data::TransientRNAData,model::AbstractGMmodel)
    h=likelihoodarray(r,data,model,maximum(data.nRNA))
    trim_hist(h,data.nRNA)
end
"""
    likelihoodarray(r,data::RNAData{T1,T2},model::AbstractGMmodel) where {T1 <: Array, T2 <: Array}

TBW
"""
function likelihoodarray(r,data::RNAData{T1,T2},model::AbstractGMmodel) where {T1 <: Array, T2 <: Array}
    # n = model.G-1
    h = Array{Array{Float64,1},1}(undef,length(data.nRNA))
    for i in eachindex(data.nRNA)
        M = make_mat_M(model.components[i],r[(i-1)*2*model.G+1 : i*2*model.G])
        h[i] = steady_state(M,model.G,model.nalleles,data.nRNA[i])
        #
        # h[i] =steady_state(r[(i-1)*2*model.G+1 : i*2*model.G],n,data.nRNA[i],model.nalleles)
    end
    trim_hist(h,data.nRNA)
end
"""
    likelihoodarray(r,data::TransientRNAData,model::AbstractGMmodel,maxdata)

TBW
"""
function likelihoodarray(r,data::TransientRNAData,model::AbstractGMmodel,maxdata)
    G = model.G
    h0 = steady_state_full(r[1:2*G],G-1,maxdata)
    transient(data.time,r[2*G+1:4*G],G-1,model.nalleles,h0,model.method)
    # transient(t,r,yieldfactor,n,nalleles,P0::Vector,method)
end
"""
    likelihoodarray(r,data::RNAData,model::GMmultimodel)

TBW
"""
function likelihoodarray(r,data::RNAData,model::GMmultimodel)
    G = model.G
    h = Array{Array{Float64,1},1}(undef,length(data.nRNA))
    for i in eachindex(data.nRNA)
        g = steady_state(r[1:2*G],G-1,data.nRNA[i],model.nalleles)
        h[i] = threshold_noise(g,r[2*G+1],r[2*G+1+i],data.nRNA[i])
    end
    return h
end
"""
    likelihoodarray(r,data::RNAMixedData,model::AbstractGMmodel)

TBW
"""
function likelihoodarray(r,data::RNAMixedData,model::AbstractGMmodel)
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
"""
    likelihoodarray(r,data::RNALiveCellData,model::GMmodel)

TBW
"""
function likelihoodarray(r,data::RNALiveCellData,model::GMmodel)
    TA = make_mat_TA(model.components.tcomponents,r)
    TI = make_mat_TI(model.components.tcomponents,r)
    modelOFF, modelON = offonPDF(TA,TI,data.bins,r,model.G,model.Gtransitions,model.reporters)
    M = make_mat_M(model.components.mcomponents,r)
    histF = steady_state(M,model.components.mcomponents.nT,model.nalleles,data.nRNA)
return [modelOFF, modelON, histF]
end
"""
    likelihoodarray(rin,data::RNALiveCellData,model::AbstractGRMmodel)

TBW
"""
function likelihoodarray(rin,data::RNALiveCellData,model::AbstractGRMmodel)
        r = copy(rin)
        if model.type == "offdecay"
            r[end-1] *= survival_fraction(nu,eta,model.R)
        end
        T = make_mat_T(model.components.tcomponents,r)
        TA = make_mat_TA(model.components.tcomponents,r)
        TI = make_mat_TI(model.components.tcomponents,r)
        modelOFF, modelON = offonPDF(T,TA,TI,data.bins,r,model.G,model.R,model.method)
        M = make_mat_M(model.components.mcomponents,r)
        histF = steady_state(M,model.components.mcomponents.nT,model.nalleles,data.nRNA)
    return [modelOFF, modelON, histF]
end

"""
    likelihoodarray(rin,data::RNADwellTimeData,model::AbstractGRMmodel)

TBW
"""
function likelihoodarray(rin,data::RNADwellTimeData,model::AbstractGRMmodel)
    r = copy(rin)
    tcomponents = model.components.tcomponents
    T = make_mat(tcomponents.elementsT, r, tcomponents.nT)
    pss = normalized_nullspace(T)
    hists = Vector{Vector}(undef,length(data.DTtypes))
    for (i,Dtype) in enumerate(data.DTtypes)
        TD = make_mat(tcomponents.elementsTD[i], r, tcomponents.nT)
        S = Dtype == "ON" ? ontimeCDF(data.bins[i], model.G, model.R, TD, pss, 1) : offtimeCDF(data.bins[i], r, model.G, model.R, TD, pss, 1)
        hists[i] = pdf_from_cdf(data.bins[i],S)
    end
    M = make_mat_M(model.components.mcomponents,r)
    histF = steady_state(M,model.components.mcomponents.nT,model.nalleles,data.nRNA)
    push!(hists,histF)
    return hists
end


"""
transform_rates(r,model::AbstractGRmodel)

transform rates to real domain
"""
transform_rates(r,model::AbstractGRmodel) = log.(r)

"""
inverse_transform_rates(x,model::AbstractGRmodel)

transform MH parameters on real domain back to rate domain

"""
inverse_transform_rates(p,model::AbstractGRmodel) = exp.(p)

"""
get_rates(param,model)
replace fitted rates with new values and return
"""
function get_rates(param,model::AbstractGRmodel;inverse=true)
    r = get_r(model)
    if inverse
        r[model.fittedparam] = inverse_transform_rates(param,model)
    else
        r[model.fittedparam] = param
    end
    return r
end
# function get_rates(param,model::GRSMmodel)
#     r = get_r(model)
#     r[model.fittedparam] = inverse_transform_rates(param,model)
#     # setr(r,model)
#     return r
# end
get_rates(param,model::GMtransientmodel) = inverse_transform_rates(param[1:2*model.G],model)

"""
get_rates(param,model::GMrescaledmodel)

gammas are scaled by nu
"""
function get_rates(param,model::GMrescaledmodel)
    param = inverse_transform_rates(param,model)
    r = get_r(model)
    n = get_n(model)
    nu = n in model.fittedparam ? param[findfirst(model.fittedparam .== n)] : r[n]
    r[1:n-1] /= r[n]
    r[model.fittedparam] = param
    r[1:n-1] *= nu
    if r[2*model.G + 3] > 1
        r[2*model.G + 3] = 1
    end
    return r
end

get_rates(param,model::AbstractGMfixedeffectsmodel) = fixed_rates(param,model)

# get_rates(param,model::GMfixedeffectslossmodel) = fixed_rates(param,model)

function fixed_rates(param,model)
    r = get_r(model)
    n = get_n(model)
    r[model.fittedparam] = inverse_transform_rates(param,model)
    for effect in model.fixedeffects
        for ind in 2: length(effect)
            r[effect[ind]] = r[effect[1]]
        end
    end
    return r
end

get_r(model) = copy(model.rates)
get_n(model::AbstractGMmodel) = 2*model.G - 1

"""
get_param(model)

get fitted parameters from model
"""
get_param(model::AbstractGRmodel) = transform_rates(model.rates[model.fittedparam],model)

function get_param(model::GMrescaledmodel)
    r = copy(model.rates)
    n = 2*model.G - 1
    r[1:n-1] /= r[n]
    transform_rates(r[model.fittedparam],model)
end

"""
setr(r,model)

"""
function setr(r,model::GRSMmodel)
    n = model.G-1
    nr = model.R
    eta = get_eta(r,n,nr)
    r[2*n + 1 + nr + 1:2*n + 1 + nr + nr] = eta
    r
end
"""
logprior(param,model::AbstractGMmodel)

compute log of the prior
"""
function logprior(param,model::AbstractGRmodel)
    d = model.rateprior
    p=0
    for i in eachindex(param)
        p -= logpdf(d[i],param[i])
    end
    return p
end

"""
get_gamma(r,n,nr)
G state forward and backward transition rates
for use in transition rate matrices of Master equation
(different from gamma used in Gillespie algorithms)
"""
function get_gamma(r,n)
    gammaf = zeros(n+2)
    gammab = zeros(n+2)
    for i = 1:n
        gammaf[i+1] = r[2*(i-1)+1]
        gammab[i+1] = r[2*i]
    end
    return gammaf, gammab
end
"""
get_nu(r,n,nr)
R step forward transition rates
"""
get_nu(r,n,nr) =r[2*n+1 : 2*n+nr+1]
"""
get_eta(r,n,nr)
Intron ejection rates at each R step
"""
get_eta(r,n,nr) = r[2*n+1+nr+1:2*n+1+nr+nr]

function num_rates(transitions,R,S,insertstep) 
    if R > 0
        if insertstep > R
            throw("insertstep>R")
        end
        if S == 0
            insertstep = 1
        end
         return length(transitions) + 1 + R + S + 1 - insertstep + 1
    else
        return length(transitions) + 2
    end
end

# function get_eta(r,n,nr)
#     eta = zeros(nr)
#     if length(r) > 2*n + 2*nr
#         eta[1] = r[2*n + 1 + nr + 1]
#         for i = 2:nr
#             eta[i] = eta[i-1] + r[2*n + 1 + nr + i]
#         end
#     end
#     return eta
# end


# """
# logprior(param,model::GRSModel)
# Compute log prior using distributions in Model.rateprior
# called by mhstep() in metropolis_hastings.jl
# """
# function logprior(param,model::GRSMmodel)
#     r = get_rates(param,model)
#     d = model.rateprior
#     G = model.G
#     R = model.R
#     p=0
#     j = 1
#     #  G rates
#     for i in Grange(G)
#         p -= logpdf(d[j],r[i])
#         j += 1
#     end
#     # initiation rate
#     i = initiation(G)
#     p -= logpdf(d[j],r[i])
#     j += 1
#     # sum of R Step rates are bounded by length of insertion site to end of gene, i.e sum of reciprocal rates is bounded
#     t = sum(1 ./ r[Rrange(G,R)])
#     p -= logpdf(d[j],1/t)
#     j += 1
#     # priors for splice rates
#     rs = 0
#     for i in Srange(G,R)
#         rs = r[i]
#         p -= logpdf(d[j],rs)
#         j += 1
#     end
#     return p
# end