large_deviance(measurefile,threshold) = filter_gene(measurefile,"Deviance",threshold)

function filter_gene(measurefile,measure,threshold)
    genes = Vector{String}(undef,0)
    measures,header = readdlm(measurefile,',',header=true)
    println(length(measures[:,1]))
    col = findfirst(header[1,:] .== measure)
    for d in eachrow(measures)
        if d[col] > threshold || isnan(d[col])
            push!(genes,d[1])
        end
    end
    println(length(genes))
    return genes
end

function filter_gene_nan(measurefile,measure)
    genes = Vector{String}(undef,0)
    measures,header = readdlm(measurefile,',',header=true)
    println(length(measures[:,1]))
    col = findfirst(header[1,:] .== measure)
    for d in eachrow(measures)
        if isnan(d[col])
            push!(genes,d[1])
        end
    end
    println(length(genes))
    return genes
end


function deviance(r,cond,n,datafolder,root)
    h,hd = histograms(r,cell,cond,n,datafolder,root)
    deviance(h,hd)
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
        h,hd = histograms(r,cell,cond,n,datafolder,root)
        f = open(joinpath(outfolder,r[1] * ".txt"),"w")
        writedlm(f,h)
        close(f)
    end
end

function write_histograms(outfolder,ratefile,fittedparam,datacond,G::Int,datafolder::String,label,nsets,root)
    rates,head = readdlm(ratefile,',',header=true)
    if ~isdir(outfolder)
        mkpath(outfolder)
    end
    cond = string.(split(datacond,"-"))
    for r in eachrow(rates)
        h = histograms(r,fittedparam,datacond,G,datafolder,label,nsets,root)
        for i in eachindex(cond)
            f = open(joinpath(outfolder,string(r[1]) * cond[i] * ".txt"),"w")
            writedlm(f,h[i])
            close(f)
        end
    end
end

function histograms(r,cell,cond,n,datafolder,root)
    gene = String(r[1])
    datafile = StochasticGene.scRNApath(gene,cond,datafolder,root)
    hd = StochasticGene.read_scrna(datafile)
    h = StochasticGene.steady_state(r[2:2*n+3],r[end],n,length(hd),alleles(root,gene,cell))
    return h,hd
end

function histograms(rin,fittedparam,cond,G::Int,datafolder,label,nsets,root)
    gene = string(rin[1])
    r = float.(rin[2:end])
    param,data,model = steadystate_rna(r,gene,fittedparam,cond,G,datafolder,label,nsets,root)
    StochasticGene.likelihoodarray(r,data,model)
end

function write_burst_stats(outfile,infile::String,G::String,cell,folder,cond,root)
    folder = joinpath(root,folder)
    condarray = split(cond,"-")
    g = parse(Int,G)
    lr = 2*g
    lc = 2*g-1
    freq = Array{Float64,1}(undef,2*length(condarray))
    burst = similar(freq)
    f = open(joinpath(folder,outfile),"w")
    contents,head = readdlm(joinpath(folder,infile),',',header=true)
    label = Array{String,1}(undef,0)
    for c in condarray
        label = vcat(label, "Freq " * c, "sd","Burst Size " * c, "sd")
    end
    writedlm(f,["gene" reshape(label,1,length(label))],',')
    for r in eachrow(contents)
        gene = String(r[1])
        rates = r[2:end]
        rdecay = decay(root,cell,gene)
        cov = StochasticGene.read_covparam(joinpath(folder,getfile("param_stats",gene,G,folder,cond)[1]))
        # mu = StochasticGene.readmean(joinpath(folder,getfile("param_stats",gene,G,folder,cond)[1]))
        if size(cov,2) < 2
            println(gene)
        end
        for i in eachindex(condarray)
            j = i-1
            freq[2*i-1], freq[2*i] = frequency(rates[1+lr*(i-1)],sqrt(cov[1+lc*j,1+lc*j]),rdecay)
            burst[2*i-1], burst[2*i] = burstsize(rates[3+lr*j],rates[2+lr*j],cov[3+lc*j,3+lc*j],cov[2+lc*j,2+lc*j],cov[2+lc*j,3+lc*j])
        end
        writedlm(f,[gene freq[1] freq[2] burst[1] burst[2] freq[3] freq[4] burst[3] burst[4]],',')
        flush(f)
    end
    close(f)
end

frequency(ron,sd,rdecay) = (ron/rdecay, sd/rdecay)

function burstsize(reject::Float64,roff,covee,covoo,coveo::Float64)
        v = StochasticGene.var_ratio(reject,roff,covee,covoo,coveo)
        return reject/roff, sqrt(v)
end

function ratestats(gene,G,folder,cond)
    filestats=joinpath(folder,getfile("param_stats",gene,G,folder,cond)[1])
    filerates = joinpath(folder,getratefile(gene,G,folder,cond)[1])
    rates = StochasticGene.readrates(filerates)
    cov = StochasticGene.read_covparam(filestats)
    # mu = StochasticGene.readmean(filestats)
    # sd = StochasticGene.readsd(filestats)
    return rates, cov
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

function write_moments(outfile,genelist,cond,datafolder,root)
    f = open(outfile,"w")
    writedlm(f,["Gene" "Expression Mean" "Expression Variance"],',')
    for gene in genelist
        datafile = StochasticGene.scRNApath(gene,cond,datafolder,root)
        # data = StochasticGene.data_rna(datafile,label,gene,false)
        len,h = StochasticGene.histograms_rna(datafile,gene,false)
        # h,hd = histograms(r,cond,n,datafolder,root)
        writedlm(f,[gene StochasticGene.mean_histogram(h) StochasticGene.var_histogram(h)],',')
    end
    close(f)
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

function join_files(models::Array,files::Array,outfile::String,addlabel::Bool=true)
    m = length(files)
    contents = Array{Array,1}(undef,m)
    headers = Array{Array,1}(undef,m)
    len = 0
    for i in 1:m
        contents[i],headers[i] = readdlm(files[i],',',header=true)
        len += length(headers[i][2:end])
    end
    f = open(outfile,"w")
    header = Array{String,1}(undef,0)
    for i in 1:m
        if addlabel
            header = vcat(header,String.(headers[i][2:end]) .* "_G$(models[i])")
        else
            header = vcat(header,String.(headers[i][2:end]))
        end
    end
    header = reshape(permutedims(header),(1,len))
    header = hcat(headers[1][1],header)
    println(header)
    writedlm(f,header,',')
    for row in 1:size(contents[1],1)
        content = contents[1][row:row,2:end]
        for i in 1:m-1
            if contents[i][row,1] == contents[i+1][row,1]
                content = hcat(content,contents[i+1][row:row,2:end])
                # content = reshape(permutedims(content),(1,len))
            end
        end
        content = hcat(contents[1][row:row,1],content)
        writedlm(f,[content],',')
    end
    close(f)
end

function best_AIC(outfile,infile)
    contents,head = readdlm(infile,',',header=true)
    head = vec(head)
    ind = occursin.("AIC",string.(head)) .& .~ occursin.("WAIC",string.(head))
    f = open(outfile,"w")
    labels = "Gene"
    for i in 1:sum(ind)
        labels = vcat(labels,"Model $(i)")
    end
    labels = vcat(labels,"Winning Model")
    writedlm(f,[reshape(labels,1,length(labels))],',')
    for row in eachrow(contents)
        writedlm(f,[row[1] reshape(row[ind],1,length(row[ind])) argmin(float.(row[ind]))],',')
    end
    close(f)
end

function sample_non1_genes(infile,n)
    contents,head = readdlm(infile,',',header=true)
    list = Array{String,1}(undef,0)
    for c in eachrow(contents)
        if c[5] != 1
            push!(list,c[1])
        end
    end
    a = sample(list,n,replace=false)
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

function best_waic(folder,root)
    folder = joinpath(root,folder)
    files =readdir(folder)
    lowest = Inf
    winner = ""
    for file in files
        if occursin("measures",file)
            contents,head = readdlm(joinpath(folder,file),',',header=true)
            waic = mean(float.(contents[:,4]))
            println(mean(float.(contents[:,2]))," ",waic," ",median(float.(contents[:,4]))," ",file)
            if waic < lowest
                lowest = waic
                winner = file
            end
        end
    end
    return winner,lowest
end


function bestmodel(measures2,measures3)
    m2,head = readdlm(infile,',',header=true)
    m3,head = readdlm(infile,',',header=true)
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

function plot_model(r,n,nhist,nalleles)
    h= StochasticGene.steady_state(r[1:2*n+2],r[end],n,nhist,nalleles)
    plot(h)
    return h
end

function prune_file(list,file,outfile,header=true)
    contents,head = readdlm(file,',',header=header)
    f = open(outfile,"w")
    for c in eachrow(contents)
        if c[1] in list
            writedlm(f,[c],',')
        end
    end
    close(f)
end

"""
assemble_r(G,folder1,folder2,cond1,cond2,outfolder)

Combine rates from two separate fits into a single rate vector

"""

function assemble_r(G,folder1,folder2,cond1,cond2,outfolder)
    if typeof(G) <: Number
        G = string(G)
    end
    if ~isdir(outfolder)
        mkpath(outfolder)
    end
    files1 = getratefile(folder1,G,cond1)
    files2 = getratefile(folder2,G,cond2)
    for file1 in files1
        gene = StochasticGene.getgene(file1)
        file2 = getratefile(files2,gene)
        if file2 != 0
            file2=joinpath(folder2,file2)
        else
            file2=joinpath(folder1,file1)
        end
        name = replace(file1, cond1 => cond1 * "-" * cond2)
        outfile = joinpath(outfolder,name)
        assemble_r(joinpath(folder1,file1),file2,outfile)
    end
end


function  assemble_r(ratefile1,ratefile2,outfile)
    r1 = StochasticGene.readrates(ratefile1,2)
    r2 = StochasticGene.readrates(ratefile2,2)
    r1[end] = clamp(r1[end],eps(Float64),1-eps(Float64))
    r = vcat(r1[1:end-1],r2[1:end-1],r1[end])
    f = open(outfile,"w")
    writedlm(f,[r],',')
    writedlm(f,[r],',')
    writedlm(f,[r],',')
    writedlm(f,[r],',')
    close(f)
end

function assemble_r(gene,G,folder1,folder2,cond1,cond2,outfolder)
    file1 = getratefile(gene,G,folder1,cond1)[1]
    file2 = getratefile(gene,G,folder2,cond2)[1]
    name = replace(file1, cond1 => cond1 * "-" * cond2)
    println(name)
    outfile = joinpath(outfolder,name)
    println(outfile)
    assemble_r(joinpath(folder1,file1),joinpath(folder2,file2),outfile)
end


function getratefile(files,gene)
    files = files[occursin.("_"*gene*"_",files)]
    if length(files) > 0
        return files[1]
    else
        # println(gene)
        return 0
    end
end

function getratefile(folder,G,cond)
    files = readdir(folder)
    files = files[occursin.("rates_",files)]
    files = files[occursin.("_"*cond*"_",files)]
    files[occursin.("_"*G*"_",files)]
end


getratefile(gene,G,folder,cond) = getfile("rate",gene,G,folder,cond)

function getfile(type,gene::String,G::String,folder,cond)
    files = readdir(folder)
    files = files[occursin.(type,files)]
    files = files[occursin.("_"*gene*"_",files)]
    files = files[occursin.("_"*G*"_",files)]
    files[occursin.("_"*cond*"_",files)]
end


function change_name(folder,oldname,newname)
    files = readdir(folder)
    files = files[occursin.(oldname,files)]
    for file in files
        newfile = replace(file, oldname => newname)
        mv(joinpath(folder,file),joinpath(folder,newfile),force=true)
    end
end

function make_halflife(infile,outfile,col=4)
    f = open(outfile,"w")
    writedlm(f,["Gene" "Halflife"],',')
    contents,rows = readdlm(infile,',',header=true)
    for row = eachrow(contents)
        gene = string(row[1])
        gene = strip(gene,'*')
        h1 = float(row[col])
        h2 = float(row[col+1])
        if h1 > 0 || h2 > 0
            h = (h1 + h2)/(float(h1>0) + float(h2>0))
            writedlm(f,[gene h],',')
        end
    end
    nothing
end

function make_datafiles(infolder,outfolder,label)
    histograms = readdir(infolder)
    if ~isdir(outfolder)
        mkpath(outfolder)
    end
    for file in histograms
        newfile = replace(file,label => "")
        cp(joinpath(infolder,file),joinpath(outfolder,newfile))
    end
end

function make_dataframe(folder,models::Vector=[1,2])
    files = readdir(folder)
    mfiles = Vector{String}(undef,0)
    rfile = ""
    for file in files
        if occursin("measures",file)  && ~occursin("all",file)
            push!(mfiles,joinpath(folder,file))
        elseif occursin("rates",file) && occursin("2.csv",file)
            rfile = joinpath(folder,file)
        end
    end
    mfile = joinpath(folder,split("2.csv",mfiles[2])[1] * "all.csv")
    println(rfile)
    join_files(models,mfiles,mfile)
    winnerfile = joinpath(folder,"Winner.csv")
    best_AIC(winnerfile,mfile)
    r,head = readdlm(rfile,',',header=true)
    winner = get_winners(winnerfile,length(models))
    cond = [zeros(length(r[:,1]));ones(length(r[:,1]))];
    rs = [vcat(r[:,[1,2,3,4,5,10]], r[:,[1,6,7,8,9,10]])  cond winner];
    DataFrame(Gene = rs[:,1],on = float.(rs[:,2]),off=float.(rs[:,3]),eject=float.(rs[:,4]),decay=float.(rs[:,5]),yield=float.(rs[:,6]),cond = Int.(rs[:,7]),winner = Int.(rs[:,8]));
end

function make_dataframe_transient(folder::String,winners::String = "")
    rs = Array{Any,2}(undef,0,8)
    files =readdir(folder)
    n = 0
    for file in files
        if occursin("rate",file)
            t = parse(Float64,split(split(file,"T")[2],"_")[1])
            r,head = readdlm(joinpath(folder,file),',',header=true)
            r = [vcat(r[:,[1,2,3,4,5,10]], r[:,[1,6,7,8,9,10]])  [zeros(size(r)[1]); ones(size(r)[1])]  t*ones(2*size(r)[1])/60.]
            rs = vcat(rs,r)
            n += 1
        end
    end
    if winners != ""
        w = get_winners(winners,2*n)
        return DataFrame(Gene = rs[:,1],on = float.(rs[:,2]),off=float.(rs[:,3]),eject=float.(rs[:,4]),decay=float.(rs[:,5]),yield=float.(rs[:,6]),cond = Int.(rs[:,7]),time = float.(rs[:,8]),winner = w)
    else
        return DataFrame(Gene = rs[:,1],on = float.(rs[:,2]),off=float.(rs[:,3]),eject=float.(rs[:,4]),decay=float.(rs[:,5]),yield=float.(rs[:,6]),cond = Int.(rs[:,7]),time = float.(rs[:,8]))
    end
end

function get_winners(winners::String,n::Int)
    m,h = readdlm(winners,',',header=true)
    winner = repeat(m[:,end],n)
end

"""
plot_histogram_rna()

functions to plot data and model predicted rna histograms

"""
function plot_histogram_rna(gene::String,cond::String,datapath::String)
    file = joinpath(datapath,gene * "_" * cond * ".txt")
    h = read_scrna(file)
    plot(normalize_histogram(h))
    return h
end

function plot_histogram_fish(gene::String,datapaths::Array,modelfile::String,time=[0.;30.;120.],fittedparam=[7;8;9;10;11])
    r = readrates(modelfile,1)
    data,model,_ = transient_fish(datapaths,"",time,gene,r,1.,3,2,fittedparam,1.,1.,10)
    h=likelihoodarray(r[fittedparam],data,model)
    figure(gene)
    for i in eachindex(h)
        plot(h[i])
        plot(normalize_histogram(data.histRNA[i]))
    end
    return h
end

function plot_histogram_rna(gene,cond,G,nalleles,label,datafolder,folder,root)
    hn = get_histogram_rna(gene,cond,datafolder,root)
    ratepath = ratepath_Gmodel(gene,cond,G,nalleles,label,folder,root)
    println(ratepath)
    r = readrates(ratepath)
    m  = steady_state(r[1:2*G],r[end],G-1,length(hn),nalleles)
    plot(m)
    plot(hn)
    return r,hn,m,deviance(m,h),deviance(m,mediansmooth(h,3))
end

function get_histogram_rna(gene,cond,datafolder,root)
    datapath = scRNApath(gene,cond,datafolder,root)
    h = read_scrna(datapath,.99)
    normalize_histogram(h)
end

function plot_transient_rna(gene,cond,G,nalleles,label,datafolders::Vector,folder,root)
    ratepath = ratepath_Gmodel(gene,cond,G,nalleles,label,folder,root)
    println(ratepath)
    r = readrates(ratepath)
    maxdata = nhist_loss(10,r[end])
    h0 = steady_state_full(r[1:2*G],G-1,maxdata)
    h = transient([0.,30.,120.],r[2*G+1:4*G],r[end],G-1,nalleles,h0,1)
    i = 0
    for datafolder in datafolders
        i += 1
        figure()
        plot(h[i])
        plot(get_histogram_rna(gene,cond,datafolder,root))
    end
    return r,h
end
"""
plot_histogram()

functions to plot data and model predicted histograms

"""
function plot_histogram(data::RNAData{Vector{Int64}, Vector{Array}},model::GMlossmodel)
    h=likelihoodarray(model.rates,data,model)
    for i in eachindex(h)
        figure()
        plot(h[i])
        plot(normalize_histogram(data.histRNA[i]))
        savefig(string(i))
    end
    return h
end
function plot_histogram(data::AbstractRNAData{Array{Array,1}},model)
    h=likelihoodarray(model.rates,data,model)
    figure(data.gene)
    for i in eachindex(h)
        plot(h[i])
        plot(normalize_histogram(data.histRNA[i]))
        savefig(string(i))
    end
    return h
end
function plot_histogram(data::AbstractRNAData{Array{Float64,1}},model)
    h=likelihoodfn(get_param(model),data,model)
    figure(data.gene)
    plot(h)
    plot(normalize_histogram(data.histRNA))
    return h
end

function plot_histogram(data::RNALiveCellData,model)
    h=likelihoodtuple(model.rates,data,model)
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

function plot_histogram(data::TransientRNAData,model::AbstractGMmodel)
    h=StochasticGene.likelihoodarray(model.rates,data,model)
    for i in eachindex(h)
        figure(data.gene *":T" * "$(data.time[i])")
        plot(h[i])
        plot(normalize_histogram(data.histRNA[i]))
    end
    return h
end

function plot_histogram(data::RNAData,model::AbstractGMmodel)
    h=StochasticGene.likelihoodfn(get_param(model),data,model)
    figure(data.gene)
    plot(h)
    plot(normalize_histogram(data.histRNA))
    return h
end