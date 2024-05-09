# This file is part of StochasticGene.jl   

# fit.jl
#
# Fit GRS models (generalized telegraph models) to RNA abundance and live cell imaging data
#
"""
HBEC gene information
"""
genes_hbec() = ["CANX"; "DNAJC5"; "ERRFI1"; "KPNB1"; "MYH9"; "Rab7a"; "RHOA"; "RPAP3"; "Sec16A"; "SLC2A1"]
genelength_hbec() = Dict([("Sec16A", 42960); ("SLC2A1", 33802); ("ERRFI1", 14615); ("RHOA", 52948); ("KPNB1", 33730); ("MYH9", 106741); ("DNAJC5", 40930); ("CANX", 32710); ("Rab7a", 88663); ("RPAP3", 44130); ("RAB7A", 88663); ("SEC16A", 42960)])
MS2end_hbec() = Dict([("Sec16A", 5220); ("SLC2A1", 26001); ("ERRFI1", 5324); ("RHOA", 51109); ("KPNB1", 24000); ("MYH9", 71998); ("DNAJC5", 14857); ("CANX", 4861); ("Rab7a", 83257); ("RPAP3", 38610); ("SEC16A", 5220); ("RAB7A", 83257)])
halflife_hbec() = Dict([("CANX", 50.0), ("DNAJC5", 5.0), ("ERRFI1", 1.35), ("KPNB1", 9.0), ("MYH9", 10.0), ("Rab7a", 50.0), ("RHOA", 50.0), ("RPAP3", 7.5), ("Sec16A", 8.0), ("SLC2A1", 5.0), ("RAB7A", 50.0), ("SEC16A", 8.0)])

"""
    get_transitions(G, Gfamily)

Create transitions tuple
"""
function get_transitions(G, Gfamily)
    typeof(G) <: AbstractString && (G = parse(Int, G))
    if G == 2
        return ([1, 2], [2, 1])
    elseif G == 3
        if occursin("KP", Gfamily)
            return ([1, 2], [2, 1], [2, 3], [3, 1])
        elseif occursin("cyclic", Gfamily)
            return ([1, 2], [2, 3], [3, 1])
        else
            return ([1, 2], [2, 1], [2, 3], [3, 2])
        end
    elseif G == 4
        if occursin("KP", Gfamily)
            return ([1, 2], [2, 1], [2, 3], [3, 2], [3, 4], [4, 2])
        elseif occursin("cyclic", Gfamily)
            return ([1, 2], [2, 3], [3, 4], [4, 1])
        else
            return ([1, 2], [2, 1], [2, 3], [3, 2], [3, 4], [4, 3])
        end
    else
        throw("transition type unknown")
    end
end

"""
    fit(; <keyword arguments> )

Fit steady state or transient GM model to RNA data for a single gene, write the result (through function finalize), and return nothing.

#Arguments
- `nchains::Int=2`: number of MCMC chains = number of processors called by Julia, default = 2
- `datatype::String=""`: String that desecribes data type, choices are "rna", "rnaonoff", "rnadwelltime", "trace", "tracenascent", "tracerna"
- `dttype=String[]`: types are "OFF", "ON", for R states and "OFFG", "ONG" for G states
- `datapath=""`: path to data file or folder or array of files or folders
- `cell::String=""': cell type for halflives and allele numbers
- `datacond=""`: string or vector of strings describing data treatment condition, e.g. "WT", "DMSO" or ["DMSO","AUXIN"]
- `traceinfo=(1.0, 1., 240., .65)`: 4-tuple of frame interval of intensity traces, starting frame time in minutes, ending frame time (use -1 for last index), and fraction of active traces
- `nascent=(1, 2)`: 2-tuple (number of spots, number of locations) (e.g. number of cells times number of alleles/cell)
- `infolder::String=""`: result folder used for initial parameters
- `resultfolder::String=test`: folder for results of MCMC run
- `label::String=""`: label of output files produced
- `inlabel::String=""`: label of files used for initial conditions
- `fittedparam::Vector=Int[]`: vector of rate indices to be fit, e.g. [1,2,3,5,6,7]  (applies to shared rates for hierarchical models)
- `fixedeffects::Tuple=tuple()`: tuple of vectors of rates that are fixed where first index is fit and others are fixed to first, e.g. ([3,8],) means index 8 is fixed to index 3
     (only first parameter should be included in fittedparam) (applies to shared rates for hierarchical models)
- `transitions::Tuple=([1,2],[2,1])`: tuple of vectors that specify state transitions for G states, e.g. ([1,2],[2,1]) for classic 2 state telegraph model and ([1,2],[2,1],[2,3],[3,1]) for 3 state kinetic proof reading model
- `G::Int=2`: number of gene states
- `R::Int=0`: number of pre-RNA steps (set to 0 for classic telegraph models)
- `S::Int=0`: number of splice sites (set to 0 for classic telegraph models and R - insertstep + 1 for GRS models)
- `insertstep::Int=1`: R step where reporter is inserted
- `Gfamily=""`: String describing type of G transition model, e.g. "3state", "KP" (kinetic proofreading), "cyclicory"
- `root="."`: name of root directory for project, e.g. "scRNA"
- `priormean=Float64[]`: mean rates of prior distribution
- 'priorcv=10.`: (vector or number) coefficient of variation(s) for the rate prior distributions, default is 10.
- `nalleles=2`: number of alleles, value in alleles folder will be used if it exists  
- `onstates::Vector{Int}=Int[]`: vector of on or sojourn states, e.g. [[2,3],Int[]], use empty vector for R states, do not use Int[] for R=0 models
- `decayrate=1.0`: decay rate of mRNA, if set to -1, value in halflives folder will be used if it exists
- `splicetype=""`: RNA pathway for GRS models, (e.g. "offeject" =  spliced intron is not viable)
- `probfn=prob_Gaussian`: probability function for hmm observation probability (i.e. noise distribution)
- `noisepriors = []`: priors of observation noise (use empty set if not fitting traces), superceded if priormean is set
- `hierarchical=tuple()`: empty tuple for nonhierarchical; for hierarchical model use 3 tuple of hierchical model parameters (pool.nhyper::Int,individual fittedparams::Vector,individual fixedeffects::Tuple)
- `ratetype="median"`: which rate to use for initial condition, choices are "ml", "mean", "median", or "last"
- `propcv=0.01`: coefficient of variation (mean/std) of proposal distribution, if cv <= 0. then cv from previous run will be used
- `maxtime=Float64=60.`: maximum wall time for run, default = 60 min
- `samplesteps::Int=1000000`: number of MCMC sampling steps
- `warmupsteps=0`: number of MCMC warmup steps to find proposal distribution covariance
- `annealsteps=0`: number of annealing steps (during annealing temperature is dropped from tempanneal to temp)
- `temp=1.0`: MCMC temperature
- `tempanneal=100.`: annealing temperature
- `temprna=1.`: reduce rna counts by temprna compared to dwell times
- `burst=false`: if true then compute burst frequency
- `optimize=false`: use optimizer to compute maximum likelihood value
- `writesamples=false`: write out MH samples if true, default is false
- `method=1`: optional method variable, for hierarchical models method = tuple(Int,Bool) = (numerical method, true if transition rates are shared)


Example:

If you are in the folder where data/HCT116_testdata is installed, then you can fit the mock RNA histogram running 4 mcmc chains with

bash> julia -p 4

julia> fits, stats, measures, data, model, options = fit(nchains = 4)

"""

function fit(; nchains::Int=2, datatype::String="rna", dttype=String[], datapath="HCT116_testdata/", gene="MYC", cell::String="HCT116", datacond="MOCK", traceinfo=(1.0, 1, -1, 0.65), nascent=(1, 2), infolder::String="HCT116_test", resultfolder::String="HCT116_test", inlabel::String="", label::String="", fittedparam::Vector=Int[], fixedeffects=tuple(), transitions::Tuple=([1, 2], [2, 1]), G::Int=2, R::Int=0, S::Int=0, insertstep::Int=1, Gfamily="", root=".", priormean=Float64[], nalleles=2, priorcv=10.0, onstates=Int[], decayrate=-1.0, splicetype="", probfn=prob_Gaussian, noisepriors=[], hierarchical=tuple(), ratetype="median", propcv=0.01, maxtime::Float64=60.0, samplesteps::Int=1000000, warmupsteps=0, annealsteps=0, temp=1.0, tempanneal=100.0, temprna=1.0, burst=false, optimize=false, writesamples=false, method=1)
    label, inlabel = create_label(label, inlabel, datatype, datacond, cell, Gfamily)
    if typeof(fixedeffects) <: AbstractString
        fixedeffects, fittedparam = make_fixedfitted(datatype, fixedeffects, transitions, R, S, insertstep, length(noisepriors))
        println(transitions)
        println(fixedeffects)
        println(fittedparam)
    end
    fit(nchains, datatype, dttype, datapath, gene, cell, datacond, traceinfo, nascent, infolder, resultfolder, inlabel, label, fittedparam, fixedeffects, transitions, G, R, S, insertstep, root, maxtime, priormean, priorcv, nalleles, onstates, decayrate, splicetype, probfn, noisepriors, hierarchical, ratetype,
        propcv, samplesteps, warmupsteps, annealsteps, temp, tempanneal, temprna, burst, optimize, writesamples, method)

end

"""
    fit(nchains::Int, datatype::String, dttype::Vector, datapath, gene::String, cell::String, datacond::String, traceinfo, nascent, infolder::String, resultfolder::String, inlabel::String, label::String, fittedparam::Vector, fixedeffects::String, G::String, R::String, S::String, insertstep::String, Gfamily, root=".", maxtime::Float64=60.0, priormean=Float64[], priorcv=10.0, nalleles=2, onstates=Int[], decayrate=-1.0, splicetype="", probfn=prob_Gaussian, noisepriors =[], hierarchical=tuple(), ratetype="median", propcv=0.01, samplesteps::Int=1000000, warmupsteps=0, annealsteps=0, temp=1.0, tempanneal=100.0, temprna=1.0, burst=false, optimize=false, writesamples=false)

"""
function fit(nchains::Int, datatype::String, dttype::Vector, datapath, gene::String, cell::String, datacond::String, traceinfo, nascent, infolder::String, resultfolder::String, inlabel::String, label::String, fixedeffects::String, G::String, R::String, S::String, insertstep::String, Gfamily, root=".", maxtime::Float64=60.0, priormean=Float64[], priorcv=10.0, nalleles=2, onstates=Int[], decayrate=-1.0, splicetype="", probfn=prob_Gaussian, noisepriors=[], hierarchical=tuple(), ratetype="median", propcv=0.01, samplesteps::Int=1000000, warmupsteps=0, annealsteps=0, temp=1.0, tempanneal=100.0, temprna=1.0, burst=false, optimize=false, writesamples=false, method=1)
    transitions = get_transitions(G, Gfamily)
    fixedeffects, fittedparam = make_fixedfitted(datatype, fixedeffects, transitions, parse(Int, R), parse(Int, S), parse(Int, insertstep), length(noisepriors))
    println(transitions)
    println(fixedeffects)
    println(fittedparam)
    fit(nchains, datatype, dttype, datapath, gene, cell, datacond, traceinfo, nascent, infolder, resultfolder, inlabel, label, fittedparam, fixedeffects, transitions, parse(Int, G), parse(Int, R), parse(Int, S), parse(Int, insertstep), root, maxtime, priormean, priorcv, nalleles, onstates, decayrate, splicetype, probfn, noisepriors, hierarchical, ratetype,
        propcv, samplesteps, warmupsteps, annealsteps, temp, tempanneal, temprna, burst, optimize, writesamples, method)
end


"""
    fit(nchains::Int, datatype::String, dttype::Vector, datapath, gene::String, cell::String, datacond::String, traceinfo, nascent, infolder::String, resultfolder::String, inlabel::String, label::String, fittedparam::Vector, fixedeffects, transitions::Tuple, G::Int, R::Int, S::Int, insertstep::Int, root=".", maxtime::Float64=60.0, priormean=Float64[], priorcv=10.0, nalleles=2, onstates=Int[], decayrate=-1.0, splicetype="", probfn=prob_Gaussian, noisepriors =[], hierarchical=tuple(), ratetype="median", propcv=0.01, samplesteps::Int=1000000, warmupsteps=0, annealsteps=0, temp=1.0, tempanneal=100.0, temprna=1.0, burst=false, optimize=false, writesamples=false)

"""
function fit(nchains::Int, datatype::String, dttype::Vector, datapath, gene::String, cell::String, datacond::String, traceinfo, nascent, infolder::String, resultfolder::String, inlabel::String, label::String, fittedparam::Vector, fixedeffects::Tuple, transitions::Tuple, G::Int, R::Int, S::Int, insertstep::Int, root=".", maxtime::Float64=60.0, priormean=Float64[], priorcv=10.0, nalleles=2, onstates=Int[], decayrate=-1.0, splicetype="", probfn=prob_Gaussian, noisepriors=[], hierarchical=tuple(), ratetype="median", propcv=0.01, samplesteps::Int=1000000, warmupsteps=0, annealsteps=0, temp=1.0, tempanneal=100.0, temprna=1.0, burst=false, optimize=false, writesamples=false, method=1)
    println(now())
    gene = check_genename(gene, "[")
    if S > 0 && S != R - insertstep + 1
        S = R - insertstep + 1
        println("Setting S to ", S)
    end
    printinfo(gene, G, R, S, insertstep, datacond, datapath, infolder, resultfolder, maxtime)
    resultfolder = folder_path(resultfolder, root, "results", make=true)
    infolder = folder_path(infolder, root, "results")
    datapath = folder_path(datapath, root, "data")
    data = load_data(datatype, dttype, datapath, label, gene, datacond, traceinfo, temprna, nascent)
    noiseparams = occursin("trace", lowercase(datatype)) ? length(noisepriors) : zero(Int)
    decayrate < 0 && (decayrate = get_decay(gene, cell, root))
    if isempty(priormean)
        if isempty(hierarchical)
            priormean = prior_ratemean(transitions, R, S, insertstep, decayrate, noisepriors)
        else
            priormean = prior_ratemean(transitions, R, S, insertstep, decayrate, noisepriors, hierarchical[1])
        end
    end
    isempty(fittedparam) && (fittedparam = default_fitted(datatype, transitions, R, S, insertstep, noiseparams))
    r = readrates(infolder, inlabel, gene, G, R, S, insertstep, nalleles, ratetype)
    if isempty(r)
        r = isempty(hierarchical) ? priormean : set_rates(priormean, transitions, R, S, insertstep, noisepriors, length(data.trace[1]))
        println("No rate file")
    end
    println(r)
    model = load_model(data, r, priormean, fittedparam, fixedeffects, transitions, G, R, S, insertstep, nalleles, priorcv, onstates, decayrate, propcv, splicetype, probfn, noisepriors, hierarchical, method)
    options = MHOptions(samplesteps, warmupsteps, annealsteps, maxtime, temp, tempanneal)
    fit(nchains, data, model, options, resultfolder, burst, optimize, writesamples)
end

"""
    fit(nchains, data, model, options, resultfolder, burst, optimize, writesamples)

"""
function fit(nchains, data, model, options, resultfolder, burst, optimize, writesamples)
    print_ll(data, model)
    fits, stats, measures = run_mh(data, model, options, nchains)
    optimized = 0
    if optimize
        try
            optimized = Optim.optimize(x -> lossfn(x, data, model), fits.parml, LBFGS())
        catch
            @warn "Optimizer failed"
        end
    end
    if burst
        bs = burstsize(fits, model)
    else
        bs = 0
    end
    finalize(data, model, fits, stats, measures, options.temp, resultfolder, optimized, bs, writesamples)
    println(now())
    # get_rates(stats.medparam, model, false)
    return fits, stats, measures, data, model, options
end

"""
    load_data(datatype, dttype, datapath, label, gene, datacond, traceinfo, temprna, nascent)

return data structure
"""
function load_data(datatype, dttype, datapath, label, gene, datacond, traceinfo, temprna, nascent)
    if datatype == "rna"
        len, h = read_rna(gene, datacond, datapath)
        return RNAData(label, gene, len, h)
    elseif datatype == "rnaonoff"
        len, h = read_rna(gene, datacond, datapath[1])
        h = div.(h, temprna)
        LC = readfile(gene, datacond, datapath[2])
        return RNAOnOffData(label, gene, len, h, LC[:, 1], LC[:, 2], LC[:, 3])
    elseif datatype == "rnadwelltime"
        len, h = read_rna(gene, datacond, datapath[1])
        h = div.(h, temprna)
        bins, DT = read_dwelltimes(datapath[2:end])
        return RNADwellTimeData(label, gene, len, h, bins, DT, dttype)
    elseif occursin("trace", datatype)
        if typeof(datapath) <: String
            trace = read_tracefiles(datapath, datacond, traceinfo)
            background = Vector[]
        else
            trace = read_tracefiles(datapath[1], datacond, traceinfo)
            background = read_tracefiles(datapath[2], datacond, traceinfo)
        end
        (length(trace) == 0) && throw("No traces")
        println(length(trace))
        println(datapath)
        println(datacond)
        println(traceinfo)
        weight = (1 - traceinfo[4]) / traceinfo[4] * length(trace)
        nf = traceinfo[3] < 0 ? floor(Int, (720 - traceinfo[2] +  traceinfo[1]) / traceinfo[1]) : floor(Int, (traceinfo[3] - traceinfo[2] + traceinfo[1]) / traceinfo[1])
        if datatype == "trace"
            return TraceData(label, gene, traceinfo[1], (trace, background, weight, nf))
        elseif datatype == "tracenascent"
            return TraceNascentData(label, gene, traceinfo[1], (trace, background, weight, nf), nascent)
        elseif datatype == "tracerna"
            len, h = read_rna(gene, datacond, datapath[3])
            return TraceRNAData(label, gene, traceinfo[1], (trace, background, weight, nf), len, h)
        end
    else
        throw("$datatype not included")
    end
end

"""
    load_model(data, r, rm, fittedparam::Vector, fixedeffects::Tuple, transitions::Tuple, G::Int, R::Int, S::Int, insertstep::Int, nalleles, priorcv, onstates, decayrate, propcv, splicetype, probfn, noisepriors, hierarchical)

return model structure
"""
function load_model(data, r, rm, fittedparam::Vector, fixedeffects::Tuple, transitions::Tuple, G::Int, R::Int, S::Int, insertstep::Int, nalleles, priorcv, onstates, decayrate, propcv, splicetype, probfn, noisepriors, hierarchical, method=1)
    if S > 0 && S != R - insertstep + 1
        S = R - insertstep + 1
        println("Setting S to ", S)
    end
    noiseparams = length(noisepriors)
    weightind = occursin("Mixture", "$(probfn)") ? num_rates(transitions, R, S, insertstep) + noiseparams : 0
    if typeof(data) <: AbstractRNAData
        reporter = onstates
        components = make_components_M(transitions, G, 0, data.nRNA, decayrate, splicetype)
    elseif typeof(data) <: AbstractTraceData
        reporter = HMMReporter(noiseparams, num_reporters_per_state(G, R, S, insertstep), probfn, weightind, off_states(G, R, S, insertstep))
        components = make_components_T(transitions, G, R, S, insertstep, splicetype)
    elseif typeof(data) <: AbstractTraceHistogramData
        reporter = HMMReporter(noiseparams, num_reporters_per_state(G, R, S, insertstep), probfn, weightind, off_states(G, R, S, insertstep))
        components = make_components_MT(transitions, G, R, S, insertstep, data.nRNA, decayrate, splicetype)
    elseif typeof(data) <: AbstractHistogramData
        if isempty(onstates)
            onstates = on_states(G, R, S, insertstep)
        else
            for i in eachindex(onstates)
                if isempty(onstates[i])
                    onstates[i] = on_states(G, R, S, insertstep)
                end
                onstates[i] = Int64.(onstates[i])
            end
        end
        reporter = onstates
        if typeof(data) == RNADwellTimeData
            if length(onstates) == length(data.DTtypes)
                components = make_components_MTD(transitions, G, R, S, insertstep, onstates, data.DTtypes, data.nRNA, decayrate, splicetype)
            else
                throw("length of onstates and data.DTtypes not the same")
            end
        else
            components = make_components_MTAI(transitions, G, R, S, insertstep, onstates, data.nRNA, decayrate, splicetype)
        end
    end
    if isempty(hierarchical)
        checklength(r, transitions, R, S, insertstep, reporter)
        priord = prior_distribution(rm, transitions, R, S, insertstep, fittedparam, decayrate, priorcv, noisepriors)
        if propcv < 0
            propcv = getcv(gene, G, nalleles, fittedparam, inlabel, infolder, root)
        end
        if R == 0
            return GMmodel{typeof(r),typeof(priord),typeof(propcv),typeof(fittedparam),typeof(method),typeof(components),typeof(reporter)}(r, transitions, G, nalleles, priord, propcv, fittedparam, fixedeffects, method, components, reporter)
        else
            return GRSMmodel{typeof(r),typeof(priord),typeof(propcv),typeof(fittedparam),typeof(method),typeof(components),typeof(reporter)}(r, transitions, G, R, S, insertstep, nalleles, splicetype, priord, propcv, fittedparam, fixedeffects, method, components, reporter)
        end
    else
        ~isa(method, Tuple) && throw("method not a Tuple")
        load_model(data, r, rm, transitions, G, R, S, insertstep, nalleles, priorcv, decayrate, splicetype, propcv, fittedparam, fixedeffects, method, components, reporter, noisepriors, hierarchical)
    end
end

"""
    load_model(data, r, rm, transitions, G::Int, R, S, insertstep, nalleles, priorcv, decayrate, splicetype, propcv, fittedparam, fixedeffects, method, components, reporter, noisepriors, hierarchical)

"""
function load_model(data, r, rm, transitions, G::Int, R, S, insertstep, nalleles, priorcv, decayrate, splicetype, propcv, fittedparam, fixedeffects, method, components, reporter, noisepriors, hierarchical)
    nhyper = hierarchical[1]
    nrates = num_rates(transitions, R, S, insertstep) + reporter.n
    nindividuals = length(data.trace[1])
    nparams = length(hierarchical[2])
    ratestart = nhyper * nrates + 1
    paramstart = length(fittedparam) + nhyper * nparams + 1
    fittedparam, fittedhyper, fittedpriors = make_fitted(fittedparam, hierarchical[1], hierarchical[2], nrates, nindividuals)
    fixedeffects = make_fixed(fixedeffects, hierarchical[3], nrates, nindividuals)
    rprior = rm[1:nhyper*nrates]
    priord = prior_distribution(rprior, transitions, R, S, insertstep, fittedpriors, decayrate, priorcv, noisepriors)
    pool = Pool(nhyper, nrates, nparams, nindividuals, ratestart, paramstart, fittedhyper)
    GRSMhierarchicalmodel{typeof(r),typeof(priord),typeof(propcv),typeof(fittedparam),typeof(method),typeof(components),typeof(reporter)}(r, pool, transitions, G, R, S, insertstep, nalleles, splicetype, priord, propcv, fittedparam, fixedeffects, method, components, reporter)
end

function checklength(r, transitions, R, S, insertstep, reporter)
    n = num_rates(transitions, R, S, insertstep)
    if typeof(reporter) <: HMMReporter
        (length(r) != n + reporter.n) && throw("r has wrong length")
    else
        (length(r) != n) && throw("r has wrong length")
    end
    nothing
end

"""
    default_fitted(datatype, transitions, R, S, insertstep, noiseparams)

create vector of fittedparams that includes all rates except the decay time
"""
function default_fitted(datatype::String, transitions, R, S, insertstep, noiseparams)
    n = num_rates(transitions, R, S, insertstep)
    fittedparam = collect(1:n-1)
    if occursin("trace", datatype)
        fittedparam = vcat(fittedparam, collect(n+1:n+noiseparams))
    end
    fittedparam
end
"""
    make_fixedfitted(fixedeffects::String,transitions,R,S,insertstep)

make default fixedeffects tuple and fittedparams vector from fixedeffects String
"""
function make_fixedfitted(datatype::String, fixedeffects::String, transitions, R, S, insertstep, noiseparams)
    fittedparam = default_fitted(datatype, transitions, R, S, insertstep, noiseparams)
    fixed = split(fixedeffects, "-")
    if length(fixed) > 1
        fixed = parse.(Int, fixed)
        deleteat!(fittedparam, fixed[2:end])
        fixed = tuple(fixed)
    else
        fixed = tuple()
    end
    return fixed, fittedparam
end
"""
    make_fitted(fittedparams,N)

make fittedparams vector for hierarchical model
"""
function make_fitted(fittedshared, nhyper, fittedindividual, nrates, nindividuals)
    f = [fittedshared; fittedindividual] # shared parameters come first followed by hyper parameters and individual parameters
    fhyper = [fittedindividual]
    for i in 1:nhyper-1
        append!(f, fittedindividual .+ i * nrates)
        push!(fhyper, fittedindividual .+ i * nrates)
    end
    fpriors = copy(f)
    for i in 1:nindividuals
        append!(f, fittedindividual .+ (i + nhyper - 1) * nrates)
    end
    f, fhyper, fpriors
end

"""
    make_fixed(fixedpool, fixedindividual, nrates, nindividuals)

make fixed effects tuple for hierarchical model
"""
function make_fixed(fixedshared, fixedindividual, nrates, nindividuals)
    fixed = Vector{Int}[]
    for f in fixedshared
        push!(fixed, f)
    end
    for h in fixedindividual
        push!(fixed, [h + i * nrates for i in 0:nindividuals-1])
    end
    tuple(fixed...)
end


"""
    prior_ratemean(transitions::Tuple, R::Int, S::Int, insertstep, decayrate, noisepriors)

default priors for rates (includes all parameters, fitted or not)
"""
function prior_ratemean(transitions::Tuple, R::Int, S::Int, insertstep, decayrate, noisepriors)
    if S > 0
        S = R - insertstep + 1
    end
    ntransitions = length(transitions)
    nrates = num_rates(transitions, R, S, insertstep)
    rm = fill(.1*max(R,1), nrates)
    rm[collect(1:ntransitions)] .= 0.01
    rm[nrates] = decayrate
    [rm; noisepriors]
end

"""
    prior_ratemean(transitions::Tuple, R::Int, S::Int, insertstep, decayrate, noisepriors, nindividuals, nhyper, cv=1.0)

default priors for hierarchical models, arranged into a single vector, shared and hyper parameters come first followed by individual parameters
"""
function prior_ratemean(transitions::Tuple, R::Int, S::Int, insertstep, decayrate, noisepriors, nhyper, cv=1.0)
    rm = prior_ratemean(transitions::Tuple, R::Int, S::Int, insertstep, decayrate, noisepriors)
    r = copy(rm)
    for i in 2:nhyper
        append!(r, cv .* rm)
    end
    # for i in 1:nindividuals
    #     append!(r, rm)
    # end
    r
end

function set_rates(rm, transitions::Tuple, R::Int, S::Int, insertstep, noisepriors, nindividuals)
    r = copy(rm)
    nrates = num_rates(transitions, R, S, insertstep) + length(noisepriors)
    for i in 1:nindividuals
        append!(r, rm[1:nrates])
    end
    r
end
"""
    prior_distribution(rm, transitions, R::Int, S::Int, insertstep, fittedparam::Vector, decayrate, priorcv, noiseparams, weightind)


"""
function prior_distribution(rm, transitions, R::Int, S::Int, insertstep, fittedparam::Vector, decayrate, priorcv, noisepriors, factor=10)
    if isempty(rm)
        throw("No prior mean")
        # rm = prior_ratemean(transitions, R, S, insertstep, decayrate, noisepriors)
    end
    if priorcv isa Number
        n = num_rates(transitions, R, S, insertstep)
        rcv = fill(priorcv, length(rm))
        rcv[n] = 0.1
        rcv[n+1:n+length(noisepriors)] /= factor
    else
        rcv = priorcv
    end
    if length(rcv) == length(rm)
        return distribution_array(log.(rm[fittedparam]), sigmalognormal(rcv[fittedparam]), Normal)
    else
        throw("priorcv not the same length as prior mean")
    end
end

"""
lossfn(x,data,model)

Compute loss function

"""
lossfn(x, data, model) = loglikelihood(x, data, model)[1]

"""
burstsize(fits,model::AbstractGMmodel)

Compute burstsize and stats using MCMC chain

"""
function burstsize(fits, model::AbstractGMmodel)
    if model.G > 1
        b = Float64[]
        for p in eachcol(fits.param)
            r = get_rates(p, model)
            push!(b, r[2*model.G-1] / r[2*model.G-2])
        end
        return BurstMeasures(mean(b), std(b), median(b), mad(b), quantile(b, [0.025; 0.5; 0.975]))
    else
        return 0
    end
end
function burstsize(fits::Fit, model::GRSMmodel)
    if model.G > 1
        b = Float64[]
        L = size(fits.param, 2)
        rho = 100 / L
        println(rho)
        for p in eachcol(fits.param)
            r = get_rates(p, model)
            if rand() < rho
                push!(b, burstsize(r, model))
            end
        end
        return BurstMeasures(mean(b), std(b), median(b), mad(b), quantile(b, [0.025; 0.5; 0.975]))
    else
        return 0
    end
end

burstsize(r, model::AbstractGRSMmodel) = burstsize(r, model.R, length(model.Gtransitions))

function burstsize(r, R, ntransitions)
    total = min(Int(div(r[ntransitions+1], r[ntransitions])) * 2, 400)
    M = make_mat_M(make_components_M([(2, 1)], 2, R, total, r[end], ""), r)
    # M = make_components_M(transitions, G, R, nhist, decay, splicetype)
    nT = 2 * 2^R
    L = nT * total
    S0 = zeros(L)
    S0[2] = 1.0
    s = time_evolve_diff([1, 10 / minimum(r[ntransitions:ntransitions+R+1])], M, S0)
    mean_histogram(s[2, collect(1:nT:L)])
end

"""
check_genename(gene,p1)

Check genename for p1
if p1 = "[" change to "("
(since swarm cannot parse "(")

"""
function check_genename(gene, p1)
    if occursin(p1, gene)
        if p1 == "["
            gene = replace(gene, "[" => "(")
            gene = replace(gene, "]" => ")")
        elseif p1 == "("
            gene = replace(gene, "(" => "]")
            gene = replace(gene, ")" => "]")
        end
    end
    return gene
end

"""
    print_ll(param, data, model, message)

compute and print initial loglikelihood
"""
function print_ll(param, data, model, message)
    ll, _ = loglikelihood(param, data, model)
    println(message, ll)
end
function print_ll(data, model, message="initial ll: ")
    ll, _ = loglikelihood(get_param(model), data, model)
    println(message, ll)
end

"""
printinfo(gene,G,datacond,datapath,infolder,resultfolder,maxtime)

print out run information
"""
function printinfo(gene, G, datacond, datapath, infolder, resultfolder, maxtime)
    println("Gene: ", gene, " G: ", G, " Treatment:  ", datacond)
    println("data: ", datapath)
    println("in: ", infolder, " out: ", resultfolder)
    println("maxtime: ", maxtime)
end

function printinfo(gene, G, R, S, insertstep, datacond, datapath, infolder, resultfolder, maxtime)
    if R == 0
        printinfo(gene, G, datacond, datapath, infolder, resultfolder, maxtime)
    else
        println("Gene: ", gene, " G R S insertstep: ", G, R, S, insertstep)
        println("in: ", infolder, " out: ", resultfolder)
        println("maxtime: ", maxtime)
    end
end

"""
    finalize(data,model,fits,stats,measures,temp,resultfolder,optimized,burst,writesamples,root)

write out run results and print out final loglikelihood and deviance
"""
function finalize(data, model, fits, stats, measures, temp, writefolder, optimized, burst, writesamples)
    println("final max ll: ", fits.llml)
    print_ll(transform_rates(vec(stats.medparam), model), data, model, "median ll: ")
    println("Median fitted rates: ", stats.medparam[:, 1])
    println("ML rates: ", inverse_transform_rates(fits.parml, model))
    println("Acceptance: ", fits.accept, "/", fits.total)
    if typeof(data) <: AbstractHistogramData
        println("Deviance: ", deviance(fits, data, model))
    end
    println("rhat: ", maximum(measures.rhat))
    if optimized != 0
        println("Optimized ML: ", Optim.minimum(optimized))
        println("Optimized rates: ", exp.(Optim.minimizer(optimized)))
    end
    writeall(writefolder, fits, stats, measures, data, temp, model, optimized=optimized, burst=burst, writesamples=writesamples)
end

function getcv(gene, G, nalleles, fittedparam, inlabel, infolder, root, verbose=true)
    paramfile = path_Gmodel("param-stats", gene, G, nalleles, inlabel, infolder, root)
    if isfile(paramfile)
        cv = read_covlogparam(paramfile)
        cv = float.(cv)
        if ~isposdef(cv) || size(cv)[1] != length(fittedparam)
            cv = 0.02
        end
    else
        cv = 0.02
    end
    if verbose
        println("cv: ", cv)
    end
    return cv
end
"""
    get_decay(gene::String,cell::String,root::String,col::Int=2)
    get_decay(gene::String,path::String,col::Int)

    Get decay rate for gene and cell

"""
function get_decay(gene::String, cell::String, root::String, col::Int=2)
    if uppercase(cell) == "HBEC"
        if uppercase(gene) ∈ uppercase.(genes_hbec())
            # return log(2.0) / (60 .* halflife_hbec()[gene])
            return get_decay(halflife_hbec()[gene])
        else
            println(gene, " has no decay time")
            return 1.0
        end
    else
        path = get_file(root, "data/halflives", cell, "csv")
        if isnothing(path)
            println(gene, " has no decay time")
            return -1.0
        else
            return get_decay(gene, path, col)
        end
    end
end
function get_decay(gene::String, path::String, col::Int)
    a = nothing
    in = readdlm(path, ',')
    ind = findfirst(in[:, 1] .== gene)
    if ~isnothing(ind)
        a = in[ind, col]
    end
    get_decay(a, gene)
end

function get_decay(a, gene::String)
    if typeof(a) <: Number
        return get_decay(float(a))
    else
        println(gene, " has no decay time")
        return 1.0
    end
end
get_decay(a::Float64) = log(2) / a / 60.0

"""
    alleles(gene::String,cell::String,root::String,col::Int=3)
    alleles(gene::String,path::String,col::Int=3)

    Get allele number for gene and cell
"""
function alleles(gene::String, cell::String, root::String; nalleles::Int=2, col::Int=3)
    path = get_file(root, "data/alleles", cell, "csv")
    if isnothing(path)
        return 2
    else
        alleles(gene, path, nalleles=nalleles, col=col)
    end
end

function alleles(gene::String, path::String; nalleles::Int=2, col::Int=3)
    a = nothing
    in, h = readdlm(path, ',', header=true)
    ind = findfirst(in[:, 1] .== gene)
    if isnothing(ind)
        return nalleles
    else
        a = in[ind, col]
        return isnothing(a) ? nalleles : Int(a)
    end
end
