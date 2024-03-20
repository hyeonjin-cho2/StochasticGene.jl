# This file is part of StochasticGene.jl   

# io.jl
### Files for saving and reading mh results

abstract type Fields end

struct Result_Fields <: Fields
    name::String
    label::String
    cond::String
    gene::String
    model::String
    nalleles::String
end

struct Summary_Fields <: Fields
    name::String
    label::String
    cond::String
    model::String
end

"""
struct BurstMeasures <: Results

Structure for Burst measures
"""
struct BurstMeasures <: Results
    mean::Float64
    std::Float64
    median::Float64
    mad::Float64
    quantiles::Array
end

"""
    decompose_model(model::String)

return G, R, S, insertstep given model string
"""
function decompose_model(model::String)
    m = parse(Int, model)
    d = digits(m)
    return d[4], d[3], d[2], d[1]
end

# raterow_dict() = Dict([("ml", 1), ("mean", 2), ("median", 3), ("last", 4)])
# statrow_dict() = Dict([("mean", 1), ("SD", 2), ("median", 3), ("MAD", 4)])

"""
    write_dataframes(resultfolder::String, datapath::String; measure::Symbol=:AIC, assemble::Bool=true, fittedparams=Int[])

  write_dataframes(resultfolder::String,datapath::String;measure::Symbol=:AIC,assemble::Bool=true)

  collates run results into a csv file

Arguments
- `resultfolder`: name of folder with result files
- `datapath`: name of folder where data is stored
- `measure`: measure used to assess winner
- `assemble`: if true then assemble results into summary files
"""
function write_dataframes(resultfolder::String, datapath::String; measure::Symbol=:AIC, assemble::Bool=true, fittedparams=Int[])
    write_dataframes_only(resultfolder, datapath, assemble=assemble, fittedparams=fittedparams)
    write_winners(resultfolder, measure)
end

function write_dataframes_only(resultfolder::String, datapath::String; assemble::Bool=true, fittedparams=Int[])
    dfs = make_dataframes(resultfolder, datapath, assemble, fittedparams)
    for df in dfs
        for dff in dfs
            for dfff in dff
                csvfile = joinpath(resultfolder, dfff[1])
                CSV.write(csvfile, dfff[2])
            end
        end
    end
    nothing
end

"""
write_winners(resultfolder,measure)

Write best performing model for measure

"""
function write_winners(resultfolder, measure)
    df = best_measure(resultfolder, measure)
    if ~isempty(df)
        for i in eachindex(df)
            csvfile = joinpath(resultfolder, df[i][1])
            CSV.write(csvfile, df[i][2])
        end
    end
    nothing
end

"""
    write_augmented(summaryfile::String, resultfolder::String)

write_augmented(summaryfile::String,resultfolder,datapath)

Augment summary file with G=2 burst size, model predicted moments, and fit measures


"""
function write_augmented(summaryfile::String, resultfolder::String)
    if ~ispath(summaryfile)
        summaryfile = joinpath(resultfolder, summaryfile)
    end
    CSV.write(summaryfile, augment_dataframe(read_dataframe(summaryfile), resultfolder))
end

"""
read_dataframe(csvfile::String)
"""
read_dataframe(csvfile::String) = DataFrame(CSV.File(csvfile))

"""
get_suffix(file::String)

"""
get_suffix(file::String) = chop(file, tail=4), last(file, 3)

# does not account for csv files with less than 4 fields
function fields(file::String)
    file, suffix = get_suffix(file)
    v = split(file, "_")
    if suffix == "csv"
        if length(v) == 4
            s = Summary_Fields(v[1], v[2], v[3], v[4])
        else
            println(file)
            throw("Incorrect file name format")
        end
    else
        if length(v) == 6
            s = Result_Fields(v[1], v[2], v[3], v[4], v[5], v[6])
        elseif length(v) == 5
            s = Result_Fields(v[1], v[2], "", v[3], v[4], v[5])
        else
            println(file)
            throw("Incorrect file name format")
        end
    end
    return s
end

function isratefile(folder::String)
    files = readdir(folder)
    any(occursin.(".csv", files) .& occursin.("rates", files))
end

isfish(string::String) = occursin("FISH", string)

function get_genes(file::String)
    r, header = readdlm(file, ',', header=true)
    return r[:, 1]
end

get_genes(root, cond, datapath) = get_genes(cond, joinpath(root, datapath))

function get_genes(cond, datapath)
    genes = Vector{String}(undef, 0)
    files = readdir(datapath)
    for file in files
        if occursin(cond, file)
            push!(genes, split(file, "_")[1])
        end
    end
    return genes
end
"""
    get_genes(folder,type,label,cond,model)

"""
function get_genes(folder, type, label, cond, model)
    genes = Array{String,1}(undef, 0)
    files = get_files(folder, type, label, cond, model)
    for file in files
        push!(genes, get_gene(file))
    end
    return genes
end

get_files(folder,resultname) = 

get_files(folder::String, resultname, label, cond, model) = get_files(get_resultfiles(folder), resultname, label, cond, model)

file_indices(parts, resultname, label, cond, model) = (getfield.(parts, :name) .== resultname) .& (getfield.(parts, :label) .== label) .& (getfield.(parts, :cond) .== cond) .& occursin.(model,getfield.(parts, :model))

function get_files(files::Vector, resultname, label, cond, model)
    parts = fields.(files)
    files[file_indices(parts, resultname, label, cond, model)]
    # files[(getfield.(parts, :name).==resultname).&(getfield.(parts, :label).==label).&(getfield.(parts, :cond).==cond).&(getfield.(parts, :model).==model)]
end

get_gene(file::String) = fields(file).gene
get_model(file::String) = fields(file).model
get_label(file::String) = fields(file).label
get_cond(file::String) = fields(file).cond
get_nalleles(file::String) = fields(file).nalleles

get_fields(parts::Vector{T}, field::Symbol) where {T<:Fields} = unique(getfield.(parts, field))

get_models(parts::Vector{T}) where {T<:Fields} = get_fields(parts, :model)

get_genes(parts::Vector{T}) where {T<:Fields} = get_fields(parts, :gene)

get_conds(parts::Vector{T}) where {T<:Fields} = get_fields(parts, :cond)

get_labels(parts::Vector{T}) where {T<:Fields} = get_fields(parts, :label)

get_names(parts::Vector{T}) where {T<:Fields} = get_fields(parts, :name)

get_nalleles(parts::Vector{T}) where {T<:Fields} = get_fields(parts, :nalleles)

get_resultfiles(folder::String) = get_resultfiles(readdir(folder))
get_resultfiles(files::Vector) = files[occursin.(".txt", files).&occursin.("_", files)]

get_summaryfiles(folder::String) = get_summaryfiles(readdir(folder))
get_summaryfiles(files::Vector) = files[occursin.(".csv", files).&occursin.("_", files)]
get_summaryfiles(files::Vector, name) = files[occursin.(".csv", files).&occursin.(name, files)]

get_ratesummaryfiles(files::Vector) = get_summaryfiles(files, "rates")
get_ratesummaryfiles(folder::String) = get_ratesummaryfiles(get_summaryfiles(folder))

get_measuresummaryfiles(files::Vector) = get_summaryfiles(files, "measures")
get_measuresummaryfiles(folder::String) = get_measuresummaryfiles(get_summaryfiles(folder))

get_burstsummaryfiles(files::Vector) = get_summaryfiles(files, "burst")
get_burstsummaryfiles(folder::String) = get_burstsummaryfiles(get_summaryfiles(folder))

"""
write_moments(outfile,genelist,cond,datapath,root)

"""
function write_moments(outfile, genelist, cond, datapath, root)
    f = open(outfile, "w")
    writedlm(f, ["Gene" "Expression Mean" "Expression Variance"], ',')
    for gene in genelist
        h = get_histogram_rna(gene, cond, datapath, root)
        writedlm(f, [gene mean_histogram(h) var_histogram(h)], ',')
    end
    close(f)
end

"""
    write_histograms(resultfolder,ratefile,cell,datacond,G::Int,datapath::String,root,outfolder = "histograms")

"""
function write_histograms(resultfolder, ratefile, cell, datacond, G::Int, datapath::String, root, outfolder="histograms")
    ratefile = joinpath(resultfolder, ratefile)
    rates, head = readdlm(ratefile, ',', header=true)
    outfolder = joinpath(resultfolder, outfolder)
    if ~isdir(outfolder)
        mkpath(outfolder)
    end
    cond = string.(split(datacond, "-"))
    for r in eachrow(rates)
        h = histograms(r, cell, cond, G, datapath, root)
        for i in eachindex(cond)
            f = open(joinpath(outfolder, string(r[1]) * cond[i] * ".txt"), "w")
            writedlm(f, h[i])
            close(f)
        end
    end
end

"""
    assemble_all(folder;fittedparams)

"""
function assemble_all(folder::String; fittedparams=Int[])
    files = get_resultfiles(folder)
    parts = fields.(files)
    labels = get_labels(parts)
    conds = get_conds(parts)
    models = get_models(parts)
    names = get_names(parts)
    if isempty(fittedparams)
        fittedparams = collect(1:num_rates(models[1])-1)
    end
    assemble_all(folder, files, labels, conds, models, names)
end

function assemble_all(folder::String, files::Vector, labels::Vector, conds::Vector, models::Vector, names)
    parts = fields.(files)
    for l in labels, c in conds, g in models
        any(file_indices(parts, "rates", l, c, g) .== 1) && assemble_all(folder, files, l, c, g, names)
    end
end

function assemble_all(folder::String, files::Vector, label::String, cond::String, model::String, names)
    labels = assemble_rates(folder, files, label, cond, model)
    assemble_measures(folder, files, label, cond, model)
    assemble_stats(folder, files, label, cond, model)
    if model != "1" && "burst" ∈ names
        assemble_burst_sizes(folder, files, label, cond, model)
    end
    if "optimized" ∈ names
        assemble_optimized(folder, files, label, cond, model, labels)
    end
end

function assemble_files(folder::String, files::Vector, outfile::String, header, readfunction)
    if ~isempty(files)
        f = open(outfile, "w")
        writedlm(f, header, ',')
        for file in files
            gene = get_gene(file)
            r = readfunction(joinpath(folder, file))
            writedlm(f, [gene r], ',')
        end
        close(f)
    end
end

"""
    assemble_rates(folder::String, files::Vector, label::String, cond::String, model::String)

TBW
"""
function assemble_rates(folder::String, files::Vector, label::String, cond::String, model::String)
    outfile = joinpath(folder, "rates_" * label * "_" * cond * "_" * model * ".csv")
    ratefiles = get_files(files, "rates", label, cond, model)
    labels = readdlm(joinpath(folder, ratefiles[1]), ',', header=true)[2]
    # header = ratelabels(model, split(cond, "-"))
    assemble_files(folder, ratefiles, outfile, ratelabels(labels, split(cond, "-")), readmedian)
    return labels
end

"""
    assemble_measures(folder::String, files, label::String, cond::String, model::String)

write all measures into a single file
"""
function assemble_measures(folder::String, files, label::String, cond::String, model::String)
    outfile = joinpath(folder, "measures_" * label * "_" * cond * "_" * model * ".csv")
    header = ["Gene" "Nalleles" "Deviance" "LogMaxLikelihood" "WAIC" "WAIC SE" "AIC" "Acceptance" "Temperature" "Rhat"]
    # assemble_files(folder,get_files(files,"measures",label,cond,model),outfile,header,readmeasures)
    files = get_files(files, "measures", label, cond, model)
    f = open(outfile, "w")
    writedlm(f, header, ',')
    for file in files
        gene = get_gene(file)
        nalleles = get_nalleles(file)
        r = readmeasures(joinpath(folder, file))
        writedlm(f, [gene nalleles r], ',')
    end
    close(f)
end


function assemble_measures_model(folder::String, label::String, cond::String, gene::String)
    outfile = joinpath(folder, "measures_" * label * "_" * cond * "_" * gene * ".csv")
    header = ["Model" "Nalleles" "normalized LL" "LogMaxLikelihood" "WAIC" "WAIC SE" "AIC" "Acceptance" "Temperature" "Rhat"]
    files = get_files(get_resultfiles(folder), "measures", label, cond, "")
    println(files)
    f = open(outfile, "w")
    writedlm(f, header, ',')
    for file in files
        nalleles = get_nalleles(file)
        r = readmeasures(joinpath(folder, file))
        writedlm(f, [get_model(file) nalleles r], ',')
    end
    close(f)
end


"""
    assemble_optimized(folder::String, files, label::String, cond::String, model::String, labels)

TBW
"""
function assemble_optimized(folder::String, files, label::String, cond::String, model::String, labels)
    outfile = joinpath(folder, "optimized_" * label * "_" * cond * "_" * model * ".csv")
    assemble_files(folder, get_files(files, "optimized", label, cond, model), outfile, labels, read_optimized)
end

"""
    assemble_stats(folder::String, files, label::String, cond::String, model::String)

TBW
"""
function assemble_stats(folder::String, files, label::String, cond::String, model::String)
    outfile = joinpath(folder, "stats_" * label * "_" * cond * "_" * model * ".csv")
    statfiles = get_files(files, "param-stats", label, cond, model)
    labels = readdlm(joinpath(folder, statfiles[1]), ',', header=true)[2]
    assemble_files(folder, statfiles, outfile, statlabels(labels), readstats)
end

"""
    assemble_burst_sizes(folder, files, label, cond, model)

TBW
"""
function assemble_burst_sizes(folder, files, label, cond, model)
    outfile = joinpath(folder, "burst_" * label * "_" * cond * "_" * model * ".csv")
    assemble_files(folder, get_files(files, "burst", label, cond, model), outfile, ["Gene" "BurstMean" "BurstSD" "BurstMedian" "BurstMAD"], read_burst)
end

"""
    rlabels(model::AbstractGRSMmodel)

TBW
"""
function rlabels(model::AbstractGRSMmodel)
    rlabels_GRSM(model)
end

function rlabels_GRSM(model)
    labels = String[]
    for t in model.Gtransitions
        push!(labels, "Rate$(t[1])$(t[2])")
    end
    push!(labels, "Initiate")
    for i in 1:model.R-1
        push!(labels, "Rshift$i")
    end
    push!(labels, "Eject")
    for i in 1:model.S
        push!(labels, "Splice$i")
    end
    push!(labels, "Decay")
    if typeof(model.reporter) == HMMReporter
        for i in 1:div(model.reporter.weightind - num_rates(model) - 1, 2)
            push!(labels, "noise_mean$i")
            push!(labels, "noise_std$i")
        end
        for i in 1:num_rates(model)+model.reporter.n-model.reporter.weightind+1
            push!(labels, "bias$i")
        end
    end
    reshape(labels, 1, :)
end

function rlabels(model::GRSMhierarchicalmodel)
    labels = String[]
    l = rlabels_GRSM(model)
    for i in 1:model.pool.nsets+model.pool.nindividuals
        append!(labels, l)
    end
    reshape(labels, 1, :)
end


"""
    rlabels(model::AbstractGMmodel)

TBW
"""
function rlabels(model::AbstractGMmodel)
    labels = String[]
    for t in model.Gtransitions
        push!(labels, "Rate$(t[1])$(t[2])")
    end
    push!(labels, "Eject")
    push!(labels, "Decay")
    if typeof(model.reporter) == HMMReporter
        for i in 1:div(model.reporter.weightind - num_rates(model) - 1, 2)
            push!(labels, "noise_mean$i")
            push!(labels, "noise_std$i")
        end
        for i in 1:num_rates(model)+model.reporter.n-model.reporter.weightind+1
            push!(labels, "bias$i")
        end
    end
    reshape(labels, 1, :)
end

function rlabels(model::String)
    G = parse(Int, model)
    n = G - 1
    Grates = Array{String,2}(undef, 1, 2 * n)
    for i = 0:n-1
        Grates[1, 2*i+1] = "Rate$i$(i+1)"
        Grates[1, 2*i+2] = "Rate$(i+1)$i"
    end
    return [Grates "Eject" "Decay"]
end

function rlabels(model::String, conds::Vector)
    nsets = length(conds)
    r = rlabels(model)
    if nsets == 1
        return r
    else
        rates = r .* conds[1]
        for i = 2:nsets
            rates = [rates r .* conds[i]]
        end
        return rates
    end
end

function rlabels(labels::Matrix, conds::Vector)
    nsets = length(conds)
    r = labels
    if nsets == 1
        return r
    else
        rates = r .* conds[1]
        for i = 2:nsets
            rates = [rates r .* reshape(conds[i], 1, length(conds))]
        end
        return rates
    end
end

rlabels(model::String, conds, fittedparams) = rlabels(model, conds)[1:1, fittedparams]


rlabels(labels::Matrix, conds, fittedparams) = rlabels(labels, conds)[1:1, fittedparams]

ratelabels(labels::Matrix, conds) = ["Gene" rlabels(labels, conds)]

"""
    statlabels(model::String, conds, fittedparams)

TBW
"""
function statlabels(model::String, conds, fittedparams)
    label = ["_Mean", "_SD", "_Median", "_MAD", "_CI2.5", "_CI97.5"]
    Grates = rlabels(model, conds, fittedparams)
    rates = Matrix{String}(undef, 1, 0)
    for l in label
        rates = [rates Grates .* l]
    end
    return ["Gene" rates]
end

function statlabels(labels::Matrix)
    label = ["_Mean", "_SD", "_Median", "_MAD", "_CI2.5", "_CI97.5"]
    rates = Matrix{String}(undef, 1, 0)
    for l in label
        rates = [rates labels .* l]
    end
    return ["Gene" rates]
end

"""
    optlabels(model::String, conds, fittedparams)

TBW
"""
optlabels(model::String, conds, fittedparams) = ["Gene" rlabels(model, conds, fittedparams) "LL" "Convergence"]

optlabels(labels::Matrix, conds, fittedparams) = ["Gene" rlabels(labels, conds) "LL" "Convergence"]

function get_all_rates(file::String, header::Bool)
    r = readdlm(file, ',', header=header)
    if header
        r = r[1]
    end
    return r
end

"""
    filename(data, model::AbstractGRSMmodel)
    filename(data, model::AbstractGMmodel)

return output file names
"""
filename(data, model::AbstractGRSMmodel) = filename(data.label, data.gene, model.G, model.R, model.S, model.insertstep, model.nalleles)
filename(data, model::AbstractGMmodel) = filename(data.label, data.gene, model.G, model.nalleles)
filename(label::String, gene::String, G::Int, R::Int, S::Int, insertstep::Int, nalleles::Int) = filename(label, gene, "$G" * "$R" * "$S" * "$insertstep", "$(nalleles)")
filename(label::String, gene, G::Int, nalleles::Int) = filename(label, gene, "$G", "$(nalleles)")
filename(label::String, gene::String, model::String, nalleles::String) = "_" * label * "_" * gene * "_" * model * "_" * nalleles * ".txt"

"""
writeall(path::String,fit,stats,measures,data,temp,model::AbstractGmodel;optimized=0,burst=0)
"""
function writeall(path::String, fits, stats, measures, data, temp, model::AbstractGmodel; optimized=0, burst=0, writesamples=false)
    if ~isdir(path)
        mkpath(path)
    end
    name = filename(data, model)
    write_rates(joinpath(path, "rates" * name), fits, stats, model)
    write_measures(joinpath(path, "measures" * name), fits, measures, deviance(fits, data, model), temp)
    write_param_stats(joinpath(path, "param-stats" * name), stats, model)
    if optimized != 0
        write_optimized(joinpath(path, "optimized" * name), optimized)
    end
    if burst != 0
        write_burstsize(joinpath(path, "burst" * name), burst)
    end
    if writesamples
        write_array(joinpath(path, "ll_sampled_rates" * name), fits.ll)
        write_array(joinpath(path, "sampled_rates" * name), permutedims(inverse_transform_rates(fits.param, model)))
    end
end

function writeall(path::String, fits, stats, measures, data, temp, model::GRSMhierarchicalmodel; optimized=0, burst=0, writesamples=false)
    name = filename(data, model)
    write_pool(joinpath(path, "pool" * name), fits, stats, model)
    if ~isdir(path)
        mkpath(path)
    end
    name = filename(data, model)
    write_rates(joinpath(path, "rates" * name), fits, stats, model)
    write_measures(joinpath(path, "measures" * name), fits, measures, deviance(fits, data, model), temp)
    write_param_stats(joinpath(path, "param-stats" * name), stats, model)
    write_pool(joinpath(path, "pool" * name), fits, stats, model)
    if optimized != 0
        write_optimized(joinpath(path, "optimized" * name), optimized)
    end
    if burst != 0
        write_burstsize(joinpath(path, "burst" * name), burst)
    end
    if writesamples
        write_array(joinpath(path, "ll_sampled_rates" * name), fits.ll)
        write_array(joinpath(path, "sampled_rates" * name), permutedims(inverse_transform_rates(fits.param, model)))
    end
end

"""
write_rates(file::String,fits)

Write rate parameters, rows in order are
maximum likelihood
mean
median
last accepted
"""
function write_rates(file::String, fits::Fit, stats, model)
    f = open(file, "w")
    writedlm(f, rlabels(model), ',')  # labels
    writedlm(f, [get_rates(fits.parml, model)], ',')  # max posterior
    writedlm(f, [get_rates(stats.meanparam, model, false)], ',')  # mean posterior
    writedlm(f, [get_rates(stats.medparam, model, false)], ',')  # median posterior
    writedlm(f, [get_rates(fits.param[:, end], model)], ',')  # last sample
    close(f)

end
"""
    write_pool(file::String, fits::Fit, stats, model)

write pool parameters into a file for hierarchichal models
"""
function write_pool(file::String, fits::Fit, stats, model)
    f = open(file, "w")
    writedlm(f, rlabels(model)[1:1, 1:model.pool.nrates], ',')  # labels
    writedlm(f, [get_rates(fits.parml, model)[1:model.pool.nrates]], ',')  # max posterior
    writedlm(f, [get_rates(stats.meanparam, model, false)[1:model.pool.nrates]], ',')  # mean posterior
    writedlm(f, [get_rates(stats.medparam, model, false)[1:model.pool.nrates]], ',')  # median posterior
    writedlm(f, [get_rates(fits.param[:, end], model)[1:model.pool.nrates]], ',')  # last sample
    close(f)
end

"""
    write_measures(file::String, fits::Fit, measures::Measures, dev, temp)

write_measures into a file
"""
function write_measures(file::String, fits::Fit, measures::Measures, dev, temp)
    f = open(file, "w")
    writedlm(f, [fits.llml mean(fits.ll) std(fits.ll) quantile(fits.ll, [0.025; 0.5; 0.975])' measures.waic[1] measures.waic[2] aic(fits)], ',')
    writedlm(f, dev, ',')
    writedlm(f, [fits.accept fits.total], ',')
    writedlm(f, temp, ',')
    writedlm(f, measures.rhat', ',')
    writedlm(f, maximum(measures.rhat), ',')
    close(f)
end

"""
    write_param_stats(file, stats::Stats, model)

write parameter statistics into a file
"""
function write_param_stats(file, stats::Stats, model)
    f = open(file, "w")
    writedlm(f, rlabels(model)[1:1, model.fittedparam], ',')
    writedlm(f, stats.meanparam', ',')
    writedlm(f, stats.stdparam', ',')
    writedlm(f, stats.medparam', ',')
    writedlm(f, stats.madparam', ',')
    writedlm(f, stats.qparam, ',')
    writedlm(f, stats.corparam, ',')
    writedlm(f, stats.covparam, ',')
    writedlm(f, stats.covlogparam, ',')
    close(f)
end

"""
write_optimized(file,optimized)
"""
function write_optimized(file::String, optimized)
    f = open(file, "w")
    writedlm(f, exp.(Optim.minimizer(optimized))', ',')
    writedlm(f, Optim.minimum(optimized), ',')
    writedlm(f, Optim.converged(optimized), ',')
    close(f)
end

"""
write_burstsize(file,burstsize)
"""
function write_burstsize(file::String, b::BurstMeasures)
    f = open(file, "w")
    writedlm(f, b.mean, ',')
    writedlm(f, b.std, ',')
    writedlm(f, b.median, ',')
    writedlm(f, b.mad, ',')
    writedlm(f, b.quantiles, ',')
    close(f)
end

"""
write_MHsamples(file::String,samples::Matrix)

"""
write_array(file::String, d::Array) = writedlm(file, d, header=false)

"""
    get_row()


"""
get_row() = Dict([("ml", 1); ("mean", 2); ("median", 3); ("last", 4)])

"""
    get_ratetype()


"""
get_ratetype() = invert_dict(get_row())

"""
    occursin_file(a, b, file)

determine if string a or string b occurs in file (case insensitive)
"""
function occursin_file(a, b, file)
    occursin(Regex("DS_Store", "i"), file) && return false
    if isempty(a)
        return occursin(Regex(b, "i"), file)
    elseif isempty(b)
        return occursin(Regex(a, "i"), file)
    else
        return occursin(Regex(a, "i"), file) && occursin(Regex(b, "i"), file)
    end
end

"""
    read_rna(gene, cond, datapath)

read in rna histograms 
"""
function read_rna(gene, cond, datapath)
    h = readfile(gene, cond, datapath)[:, 1]
    return length(h), h
end
"""
    readfiles(gene::String, cond::String, datapath::Vector)

read in a set of files
"""
function readfiles(gene::String, cond::String, datapath::Vector)
    c = Vector{Vector}(undef, 0)
    for i in eachindex(datapath)
        push!(c, readfile(gene, cond, datapath[i]))
    end
    c
end

"""
    readfile(gene::String, cond::String, path::String)

read file if name includes gene and cond
"""
function readfile(gene::AbstractString, cond::AbstractString, path::AbstractString)
    if isfile(path)
        return readfile(path)
    else
        for (root, dirs, files) in walkdir(path)
            for file in files
                target = joinpath(root, file)
                if occursin_file(gene, cond, target)
                    return readfile(target)
                end
            end
        end
    end
end
"""
    readfile(file::String)

read file accounting for delimiter and headers
"""
function readfile(file::String)
    if occursin("csv", file)
        c = readfile_csv(file)
    else
        c = readdlm(file)
        if typeof(c[1]) <: AbstractString && occursin(",", c[1])
            c = readdlm(file, ',')
        end
    end
    if typeof(c[1, 1]) <: AbstractString
        c = float.(c[2:end, :])
    end
    return c
end

function readfile_csv(file::String)
    c = readdlm(file, ',')
    if typeof(c[1, :]) <: AbstractString
        c = float.(c[2:end, :])
    end
    return c
end
"""
    readfile(file::String, col::Int)

read file and return given column
"""
readfile(file::String, col::Int) = readfile(file)[:, col]


"""
    read_dwelltimes(datapath)

read in a set of dwelltime files and return vector of time bins and values
"""
function read_dwelltimes(datapath)
    bins = Vector{Vector}(undef, 0)
    DT = Vector{Vector}(undef, 0)
    for i in eachindex(datapath)
        c = readfile(datapath[i])
        push!(bins, c[:, 1])
        push!(DT, c[:, 2])
    end
    bins, DT
end

function read_tracefiles(path,cond1,traceinfo::Tuple,cond2="",col=3)
    start = max(round(Int,traceinfo[2]/traceinfo[1]),1)
    stop = traceinfo[3] < 0 ? -1 : max(round(Int,traceinfo[3]/traceinfo[1]),1)
    read_tracefiles(path,cond1,start,stop,cond2,col)
end

"""
    read_tracefiles(path::String, cond1::String, start::Int, cond2::String="", col=3)

read in trace files
"""
function read_tracefiles(path::String, cond1::String, start::Int, stop::Int, cond2::String="", col=3)
    traces = Vector[]
    if isempty(path)
        return traces
    else
        for (root, dirs, files) in walkdir(path)
            for file in files
                target = joinpath(root, file)
                t = readfile(target, col)
                if stop < 0
                    occursin_file(cond1, cond2, target) && push!(traces, t[start:end])
                else
                    occursin_file(cond1, cond2, target) && push!(traces, t[start:stop])
                end
            end
        end
        set = sum.(traces)
        return traces[unique(i -> set[i], eachindex(set))]  # only return unique traces
    end
end

"""
    fix_tracefiles(path::String)

TBW
"""
function fix_tracefiles(path::String)
    for (root, dirs, files) in walkdir(path)
        for file in files
            target = joinpath(root, file)
            t = readdlm(target,header=true)
            writedlm(target,[t[1] t[1][:,2]])
        end
    end
end

"""
    readrates(infolder, label, gene, G, R, S, insertstep, nalleles, ratetype="median")


"""
function readrates(infolder, label, gene, G, R, S, insertstep, nalleles, ratetype="median")
    if R == 0
        name = filename(label, gene, G, nalleles)
    else
        name = filename(label, gene, G, R, S, insertstep, nalleles)
    end
    readrates(joinpath(infolder, "rates" * name), get_row(ratetype))
end
"""
readrates(file::String,row::Int)
readrates(file::String)

row
1       maximum likelihood
2       mean
3       median
4       last value of previous run
"""
readrates(file::String, row::Int) = readrow(file, row)

readrates(file::String) = readrates(file, 3)



"""
    get_row(ratetype)

"""
function get_row(ratetype)
    if ratetype == "ml"
        row = 1
    elseif ratetype == "mean"
        row = 2
    elseif ratetype == "median"
        row = 3
    elseif ratetype == "last"
        row = 4
    else
        row = 3
    end
    row
end

function readrow(file::String, row, delim=',')
    if isfile(file) && ~isempty(read(file))
        contents = readdlm(file, delim, header=false)
        if ~(typeof(contents[1]) <: Number)
            contents = readdlm(file, delim, header=true)[1]
        end
        if row <= size(contents, 1)
            m = contents[row, :]
            return m[.~isempty.(m)]
        else
            println("row too large, returning median")
            return contents[3, :]
        end
    else
        println(file, " does not exist")
        return Float64[]
    end
end

function readrow_flip(file, row)
    m = readrow(file, row)
    reshape(m, 1, length(m))
end

function readmeasures(file::String)
    d = readdeviance(file)
    w = readwaic(file)
    a = readaccept(file)
    t = readtemp(file)
    r = readrhat(file)
    [d[1] w[1] w[7] w[8] w[9] a t[1] r[1]]
end

readdeviance(file::String) = readrow(file, 2)

readwaic(file::String) = readrow(file, 1)

function readaccept(file::String)
    a = readrow(file, 3)
    a[1] / a[2]
end

readtemp(file::String) = readrow(file, 4)

readrhat(file::String) = readrow(file, 6)

function readml(ratefile::String)
    m = readrow(ratefile, 1, true)
    reshape(m, 1, length(m))
end

function readmean(ratefile::String)
    m = readrow(ratefile, 2, true)
    reshape(m, 1, length(m))
end

function readsd(ratefile::String)
    m = readrow(ratefile, 2)
    reshape(m, 1, length(m))
end

function readstats(statfile::String)
    mean = readrow_flip(statfile, 1)
    sd = readrow_flip(statfile, 2)
    median = readrow_flip(statfile, 3)
    mad = readrow_flip(statfile, 4)
    credl = readrow_flip(statfile, 5)
    credh = readrow_flip(statfile, 7)
    [mean sd median mad credl credh]
end

function readmedian(statfile::String)
    m = readrow(statfile, 3)
    reshape(m, 1, length(m))
end

function readmad(statfile::String)
    m = readrow(file, 4)
    reshape(m, 1, length(m))
end

function read_corparam(file::String)
    c = readdlm(file, ',')
    n = length(c[1, :])
    # c[5+n:4+2*n,1:n]
    c[8:7+n, 1:n]
end

function read_covparam(file::String)
    c = readdlm(file, ',')
    read_covparam(c)
end

function read_covparam(c::Matrix)
    n = length(c[1, :])
    # c[5+2*n:4+3*n,1:n]
    c[8+n:7+2*n, 1:n]
end

function read_covlogparam(file::String)
    c = readdlm(file, ',')
    n = length(c[1, :])
    c[8+2*n:7+3*n, 1:n]
end

read_crosscov(statfile::String) = read_crosscov(read_covparam(statfile))

function read_crosscov(C::Matrix)
    c = Float64[]
    N = size(C, 1)
    for i in 1:N
        for j in i+1:N
            push!(c, C[i, j])
        end
    end
    c
end

function read_burst(file::String)
    b = readdlm(file, ',')
    reshape(b[1:4], 1, 4)
end

function read_optimized(file::String)
    rates = readrow_flip(file, 1)
    ll = readrow(file, 2)
    conv = readrow(file, 3)
    [rates ll conv]
end

function write_residency_G(fileout::String, filein::String, G, header)
    rates = get_all_rates(filein, header)
    n = G - 1
    f = open(fileout, "w")
    writedlm(f, ["gene" collect(0:n)'], ',')
    for r in eachrow(rates)
        writedlm(f, [r[1] residenceprob_G(r[2:2*n+1], n)], ',')
    end
    close(f)
end

"""
    change_suffix(old, new, folder)

TBW
"""
function change_suffix(old, new, folder)
    for (root, dirs, files) in walkdir(folder)
        for file in files
            target = joinpath(root, file)
            if endswith(target, old)
                mv(target, replace(target, old => new))
            end
        end
    end
end

"""
    change_pattern(old, new, folder)

TBW
"""
function change_pattern(old, new, folder)
    for (root, dirs, files) in walkdir(folder)
        for file in files
            target = joinpath(root, file)
            if occursin(old, target)
                mv(target, replace(target, old => new))
                println(target)
            end
        end
    end
end
# Functions for saving and loading data and models

# """
# write_log(file,datafile,data,model)
# write all information necessary for rerunning
# """
# function save_data(file::String,data::TransientRNAData)
#     f = open(file,"w")
#     writedlm(f, [typeof(data)])
#     writedlm(f,[data.label])
#     writedlm(f,[data.gene])
#     writedlm(f,[data.nRNA])
#     writedlm(f,[data.time])
#     writedlm(f,[data.histRNA])
#     close(f)
# end

# function load_data(file::String, model::AbstractGMmodel)


# end

function save_model(file::String, model::AbstractGMmodel)
    f = open(file, "w")
    write(f, model.G)
    writedlm(f, model.nalleles)
    writedlm(f, model.ratepriors)
    writedlm(f, model.proposal)
    writedlm(f, model.fittedparam)
    writedlm(f, model.method)
    close(f)
end

# function load_model(file::String, model::AbstractGRSMmodel)

# end

