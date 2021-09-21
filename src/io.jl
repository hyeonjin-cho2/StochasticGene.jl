### Files for saving and reading mh results

function extractparts(file::String)
    file = split(file,".")[1]
    split(file,"_")
end

function getgene(file::String)
    v = extractparts(file)
    getgene(v)
end

getgene(v) = v[end-2]

getG(v) = v[end-1]

function makestring(v)
    s = ""
    for i in v
        s *= i
    end
    return s
end

function assemble_all(folder::String,label=["scRNA_T0_ss","scRNA_T120_ss"],cond::Vector=["DMSO","AUXIN"],model::Vector=["2","3"],append::String = ".csv",header=false,type=2)
    for l in label, c in cond, g in model
        assemble_rates(folder,l,c,g,append,header,type)
        assemble_measures(folder,l,c,g,append,header)
        assemble_stats("mean",folder,l,c,g,append,header)
    end
end

function assemble_rates(folder::String,label::String,cond::String,model::String,append::String,header::Bool,type=2)
    files = getfiles(folder,"rates",label,cond,model)
    # label = split(files[1],cond)[1]
    outfile = joinpath(folder,"rates_" * label * "_" * cond * "_" * model * append)
    f = open(outfile,"w")
    if header
        writedlm(f,ratelabels(model,false),',')
        # writedlm(f,["Gene" "rate01" "sd" "rate10" "sd" "rate12" "sd" "rate21" "sd" "eject" "sd" "yield"],',')
    end

    for file in files
        gene = getgene(file)
        target = joinpath(folder, file)
        r = readrates(target,type)
        writedlm(f,[gene r'],',')
    end
    close(f)
end

function assemble_measures(folder::String,label::String,cond::String,model::String,append::String,header::Bool)
    files = getfiles(folder,"measures",label,cond,model)
    # label = split(files[1],cond)[1]
    outfile = joinpath(folder,"measures_" * label * "_" * cond * "_" * model * append)
    f = open(outfile,"w")
    if header
        writedlm(f,["Gene" "Deviance" "LogMaxLikelihood" "WAIC" "SD" "AIC" "Acceptance" "Temperature"],',')
    end
    for file in files
        gene = getgene(file)
        target = joinpath(folder, file)
        r = readmeasures(target)
        writedlm(f,[gene r],',')
    end
    close(f)
end

function assemble_stats(stattype,folder::String,label::String,cond::String,model::String,append::String,header::Bool)
    files = getfiles(folder,"stats",label,cond,model)
    # label = split(files[1],cond)[1]
    outfile = joinpath(folder,"stats_" * label * "_" * cond * "_" * model * append)
    f = open(outfile,"w")
    if header
        writedlm(f,ratelabels(model,true),',')
        # writedlm(f,["Gene" "rate01" "sd" "rate10" "sd" "rate12" "sd" "rate21" "sd" "eject" "sd" "yield"],',')
    end
    for file in files
        gene = getgene(file)
        target = joinpath(folder, file)
        r = readstats(target,stattype)
        writedlm(f,[gene r'],',')
    end
    close(f)
end

function ratelabels(model,sd::Bool)
    n = parse(Int,model)
    if sd
        if n == 3
            return ["Gene" "rate01" "sd" "rate10" "sd" "rate12" "sd" "rate21" "sd" "eject" "sd" "yield" "sd"]
        elseif n == 2
            return ["Gene" "rate01" "sd" "rate10" "sd" "eject" "sd" "yield" "sd"]
        else
            return []
        end
    else
        if n == 3
            return ["Gene" "rate01" "rate10" "rate12" "rate21" "eject" "decay" "yield"]
        elseif n == 2
            return ["Gene" "rate01" "rate10" "eject" "decay" "yield"]
        else
            return []
        end
    end
end


function get_all_rates(file::String,header::Bool)
    r = readdlm(file,',',header=header)
    if header
        r = r[1]
    end
    return r
end

function getfiles(folder::String,type::String,label::String,cond::String,model::String)
    allfiles = readdir(folder)
    files = Array{String,1}(undef,0)
    for file in allfiles
        if occursin(type,file) && occursin(label,file)
            file1 = String(split(file,label)[2])
            if occursin(cond,file1)
                v = extractparts(file)
                if getG(v) == model
                    push!(files,file)
                end
            end
        end
    end
    return files
end

"""
path_model(type::String,label::String,gene::String,model::String,nalleles,folder,root)

"""
function path_model(type::String,label::String,gene::String,G::Int,R::Int,nalleles::Int,folder,root)
    file = type * filename(label,gene,G,R,nalleles)
    joinpath(root, joinpath(folder,file))
end
function path_model(type::String,label::String,gene::String,G::Int,nalleles::Int,folder,root)
    file = type * filename(label,gene,G,nalleles)
    joinpath(root, joinpath(folder,file))
end

filename(data,model::AbstractGRMmodel) = filename(data.name,data.gene,model.G,model.R,model.nalleles)
filename(data,model::AbstractGMmodel) = filename(data.name,data.gene,model.G,model.nalleles)

filename(label::String,gene::String,G::Int,R::Int,nalleles::Int) = filename(label,gene,"$G"*"$R","$(nalleles)")
filename(label::String,gene,G::Int,nalleles::Int) = filename(label,gene,"$G","$(nalleles)")
filename(label::String,gene::String,model::String,nalleles::String) = "_" * label  * "_" * gene *  "_" * model * "_" * nalleles * txtstr


"""
write_results(file::String,x)
"""
function writeall(path::String,fit,stats,waic,data,temp,model::StochasticGRmodel)
    if ~isdir(path)
        mkpath(path)
    end
    name = filename(data,model)
    write_rates(joinpath(path,"rates" * name ),fit,stats,model)
    write_measures(joinpath(path,"measures" * name),fit,waic,deviance(fit,data,model),temp)
    write_param_stats(joinpath(path,"param_stats" * name),stats)

end

"""
write_rates(file::String,fit)

Write rate parameters, rows in order are
maximum likelihood
mean
median
last accepted
"""
function write_rates(file::String,fit::Fit,stats,model)
    f = open(file,"w")
    writedlm(f,[get_rates(fit.parml,model)],',')
    writedlm(f,[get_rates(stats.meanparam,model)],',')
    writedlm(f,[get_rates(stats.medparam,model)],',')
    writedlm(f,[get_rates(fit.param[:,end],model)],',')
    close(f)
end
"""
write_measures(file,fit,waic,dev)
"""
function write_measures(file::String,fit::Fit,waic,dev,temp)
    f = open(file,"w")
    writedlm(f,[fit.llml mean(fit.ll) std(fit.ll) quantile(fit.ll,[.025;.5;.975])' waic[1] waic[2] aic(fit)],',')
    writedlm(f,dev,',')
    writedlm(f,[fit.accept fit.total],',')
    writedlm(f,temp,',')
    close(f)
end
"""
write_param_stats(stats,waic,data,model)

"""
function write_param_stats(file,stats::Stats)
    f = open(file,"w")
    writedlm(f,stats.meanparam',',')
    writedlm(f,stats.stdparam',',')
    writedlm(f,stats.medparam',',')
    writedlm(f,stats.madparam',',')
    writedlm(f,stats.qparam,',')
    writedlm(f,stats.corparam,',')
    writedlm(f,stats.covparam,',')
    writedlm(f,stats.covlogparam,',')
    close(f)
end

function read_covlogparam(file)
    in = readdlm(file,',')
    n = sum(in[end,:].!="")
    in[end-n+1:end,1:n]
end

function readmeasures(file::String)
    d = readdeviance(file)
    w = readwaic(file)
    a = readaccept(file)
    t = readtemp(file)
    [d[1] w[1] w[7] w[8] w[9] a t[1]]
end

readdeviance(file::String) = readrow(file,2)

readwaic(file::String) = readrow(file,1)

function readaccept(file::String)
    a = readrow(file,3)
    a[1]/a[2]
end

readtemp(file::String) = readrow(file,4)

function readstats(file::String,stat)
    if stat == "mean"
        m = readmean(file::String)
        return reshape(m,length(m),1)
    else
        return 0
    end
end

function readmean(file::String)
    m = readrow(file,[1,2])
    reshape(m,length(m),1)
end

"""
readrates(file::String,type::Int)

type
1       maximum likelihood
2       mean
3       median
4       last value of previous run
"""

readrates(file::String) = readrates(file,1)
readrates(file::String,type::Int) = readrow(file,type)

function readrow(file::String,row)
    contents = readdlm(file,',')
    if size(contents,1) >= row
        contents[row,:]
    else
        contents[1,:]
    end
end

function write_residency_G(fileout::String,filein::String,G,header)
    rates = get_all_rates(filein,header)
    n = G-1
    f = open(fileout,"w")
    writedlm(f,["gene" collect(0:n)'],',')
    for r in eachrow(rates)
        writedlm(f,[r[1] residenceprob_G(r[2:2*n+1],n)],',')
    end
    close(f)
end


# Functions for saving and loading data and models

"""
write_log(file,datafile,data,model)
write all information necessary for rerunning
"""
function save_data(file::String,data::TransientRNAData)
    f = open(file,"w")
    writedlm(f, [typeof(data)])
    writedlm(f,[data.name])
    writedlm(f,[data.gene])
    writedlm(f,[data.nRNA])
    writedlm(f,[data.time])
    writedlm(f,[data.histRNA])
    close(f)
end

function load_data(file::String,model::AbstractGMmodel)


end

function save_model(file::String,model::AbstractGMmodel)
    f = open(file,"w")
    write(f, model.G)
    writedlm(f,model.nalleles)
    writedlm(f,model.ratepriors)
    writedlm(f,model.proposal)
    writedlm(f,model.fittedparam)
    writedlm(f,model.method)
    close(f)

end

function load_model(file::String,model::AbstractGRMmodel)

end