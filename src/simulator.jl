# simulator.jl
# Functions to simulate Markov gene transcription models
# Uses hybrid first and next reaction method

"""
	Reaction

structure for reaction type

action: type of reaction
index: rate index for reaction
disabled: reactions that are not possible after reaction
enabled: reactions that are enabled by reaction
initial: initial GR state
final: final GR state
"""
struct Reaction
    action::Int
    index::Int
    disabled::Vector{Int64}
    enabled::Vector{Int64}
    initial::Int
    final::Int
end
"""
	ReactionIndices

structure for rate indices of reaction types
"""
struct ReactionIndices
    grange::UnitRange{Int64}
    irange::UnitRange{Int64}
    rrange::UnitRange{Int64}
    erange::UnitRange{Int64}
    srange::UnitRange{Int64}
    decay::Int
end
"""
	set_actions()

create dictionary for all the possible transitions
"""
set_actions() = Dict("activateG!" => 1, "deactivateG!" => 2, "transitionG!" => 3, "initiate!" => 4, "transitionR!" => 5, "eject!" => 6, "splice!" => 7, "decay!" => 8)
invert_dict(D) = Dict(D[k] => k for k in keys(D))

"""
    simulator(r::Vector{Float64}, transitions::Tuple, G::Int, R::Int, S::Int, nhist::Int, nalleles::Int; insertstep::Int=1, onstates::Vector{Int}=[G], bins::Vector{Float64}=Float64[], totalsteps::Int=1000000000, totaltime::Float64=0.0, tol::Float64=1e-6, reporterfnc=sum, traceinterval::Float64=0.0, par=[50, 20, 250, 75], verbose::Bool=false, offeject::Bool=false)

Simulate any GRSM model. Returns steady state mRNA histogram and if bins not a null vector will return ON and OFF time histograms.
If trace is set to true, it returns a nascent mRNA trace

#Arguments
	- `r`: vector of rates
	- `transitions`: tuple of vectors that specify state transitions for G states, e.g. ([1,2],[2,1]) for classic 2 state telegraph model and ([1,2],[2,1],[2,3],[3,1]) for 3 state kinetic proof reading model
	- `G`: number of gene states
    - `R`: number of pre-RNA steps (set to 0 for classic telegraph models)
    - `S`: number of splice sites (set to 0 for G (classic telegraph) and GR models and R for GRS models)
	- `nhist::Int`: Size of mRNA histogram
	- `nalleles`: Number of alleles

#Named arguments
    - `onstates::Vector`: a vector of ON G states
	- `bins::Vector{Float64}=Float64[]`: vector of time bins for ON and OFF histograms
	- `totalsteps::Int=10000000`: maximum number of simulation steps
	- `tol::Float64=1e-6`: convergence error tolerance for mRNA histogram (not used when traces are made)
    - `traceinterval`: Interval in minutes between frames for intensity traces.  If 0, traces are not made.
	- `par=[30, 14, 200, 75, 0.2]`: Vector of 5 parameters for noise model [background mean, background std, signal mean, signal std, weight of background <= 1]
    - `verbose::Bool=false`: flag for printing state information
    - `offeject`::Bool : true if splice is off pathway


#Examples:

    julia> trace = simulator([.1,.02,.1,.05,.01,.01],([1,2],[2,1],[2,3],[3,1]),3,0,0,100,1,onstates=[2,3],traceinterval=100.,totalsteps = 1000)

 	julia> hoff,hon,mhist = simulator([.1,.02,.1,.05,.01,.01],([1,2],[2,1],[2,3],[3,1]),3,0,0,20,1,onstates=[2,3],bins=collect(1.:100.))

"""
function simulator(r::Vector{Float64}, transitions::Tuple, G::Int, R::Int, S::Int, nhist::Int, nalleles::Int; insertstep::Int=1, onstates::Vector{Int}=[G], bins::Vector{Float64}=Float64[], totalsteps::Int=1000000000, totaltime::Float64=0.0, tol::Float64=1e-6, reporterfnc=sum, traceinterval::Float64=0.0, par=[50, 20, 250, 75], verbose::Bool=false, offeject::Bool=false)
    if length(r) < num_rates(transitions, R, S, insertstep)
        throw("r has too few elements")
    end
    if insertstep > R > 0
        throw("insertstep>R")
    end
    if S > 0
        S = R
    end
    mhist, mhist0, m, steps, t, ts, t0, tsample, err = initialize_sim(r, nhist, tol)
    reactions = set_reactions(transitions, G, R, S, insertstep)
    tau, state = initialize(r, G, R, length(reactions), nalleles)
    tIA = zeros(Float64, nalleles)
    tAI = zeros(Float64, nalleles)
    if length(bins) < 1
        onoff = false
    else
        onoff = true
        ndt = length(bins)
        dt = bins[2] - bins[1]
        histofftdd = zeros(Int, ndt)
        histontdd = zeros(Int, ndt)
    end
    if traceinterval > 0
        tracelog = [(t, state[:, 1])]
    end
    if verbose
        invactions = invert_dict(set_actions())
    end
    if totaltime > 0.0
        err = 0.0
        totalsteps = 0
    end
    while (err > tol && steps < totalsteps) || t < totaltime
        steps += 1
        t, rindex = findmin(tau)
        index = rindex[1]
        allele = rindex[2]
        initial, final, disabled, enabled, action = set_arguments(reactions[index])
        dth = t - t0
        t0 = t
        update_mhist!(mhist, m, dth, nhist)
        if t - ts > tsample && traceinterval == 0
            err, mhist0 = update_error(mhist, mhist0)
            ts = t
        end
        if verbose
            println("---")
            println("m:", m)
            println(state)
            if R > 0
                println(num_reporters(state, allele, G, R, insertstep))
            end
            println(tau)
            println("t:", t)
            println(rindex)
            println(invactions[action], " ", allele)
            println(initial, "->", final)
        end
        if onoff
            if R == 0
                if initial ∈ onstates && final ∉ onstates && final > 0  # turn off
                    firstpassagetime!(histontdd, tAI, tIA, t, dt, ndt, allele)
                elseif initial ∉ onstates && final ∈ onstates && final > 0 # turn on
                    firstpassagetime!(histofftdd, tIA, tAI, t, dt, ndt, allele)
                end
            else
                if num_reporters(state, allele, G, R, insertstep) == 1 && ((action == 6 && state[G+R, allele] == 2) || action == 7)  # turn off
                    firstpassagetime!(histontdd, tAI, tIA, t, dt, ndt, allele)
                    if verbose
                        println("off:", allele)
                    end
                elseif num_reporters(state, allele, G, R, insertstep) == 0 && ((action == 4 && insertstep == 1) || (action == 5 && final == G + insertstep)) # turn on
                    firstpassagetime!(histofftdd, tIA, tAI, t, dt, ndt, allele)
                    if verbose
                        println("on:", allele)
                    end
                end
            end
        end
        m = update!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial, final, action, insertstep)
        if traceinterval > 0
            push!(tracelog, (t, state[:, 1]))
        end
    end  # while
    println(steps)
    counts = max(sum(mhist), 1)
    mhist /= counts
    if onoff
        return histofftdd / max(sum(histofftdd), 1), histontdd / max(sum(histontdd), 1), mhist[1:nhist]
    elseif traceinterval > 0.0
        make_trace(tracelog, G, R, S, onstates, traceinterval, par, reporterfnc)
    else
        return mhist[1:nhist]
    end
end

"""
    initialize(r, G, R, nreactions, nalleles, initstate=1, initreaction=1)

return initial proposed next reaction times and states

"""
function initialize(r, G, R, nreactions, nalleles, initstate=1, initreaction=1)
    tau = fill(Inf, nreactions, nalleles)
    states = zeros(Int, G + max(R, 1), nalleles)
    for n in 1:nalleles
        tau[initreaction, n] = -log(rand()) / r[1]
        states[initstate, n] = 1
    end
    return tau, states
end
"""
    initialize_sim(r, nhist, tol, samplefactor=20.0, errfactor=10.0)

"""
initialize_sim(r, nhist, tol, samplefactor=20.0, errfactor=10.0) = zeros(nhist + 1), ones(nhist + 1), 0, 0, 0.0, 0.0, 0.0, samplefactor / minimum(r), errfactor * tol

"""
    update_error(mhist, mhist0)

TBW
"""
update_error(mhist, mhist0) = (norm(mhist / sum(mhist) - mhist0 / sum(mhist0), Inf), copy(mhist))
"""
    update_mhist!(mhist,m,dt,nhist)

"""
function update_mhist!(mhist, m, dt, nhist)
    if m + 1 <= nhist
        mhist[m+1] += dt
    else
        mhist[nhist+1] += dt
    end
end


"""
    update!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial, final, action)

updates proposed next reaction time and state given the selected action and returns updated number of mRNA

(uses if-then statements because that executes faster than an element of an array of functions)

Arguments are same as defined in simulator

"""
function update!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial, final, action, insertstep)
    if action < 5
        if action < 3
            if action == 1
                activateG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
            else
                deactivateG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
            end
        else
            if action == 3
                transitionG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
            else
                initiate!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial, final,insertstep)
            end
        end
    else
        if action < 7
            if action == 5
                transitionR!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial, final,insertstep)
            else
                m = eject!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial)
            end
        else
            if action == 7
                splice!(tau, state, index, t, m, r, allele, G, R, initial)
            else
                m = decay!(tau, index, t, m, r)
            end
        end
    end
    return m
end

"""
    make_trace(tracelog, G, R, onstates, interval=100.0)

Return array of frame times and intensities

- `tracelog`: Vector if Tuples of (time,state of allele 1)
- `interval`: Number of minutes between frames
- `onstates`: Vector of G on states
- `G` and `R` as defined in simulator

"""
function make_trace(tracelog, G, R, S, onstates, interval, par, reporterfnc=sum)
    n = length(tracelog)
    trace = Matrix(undef, 0, 2)
    state = tracelog[1][2]
    frame = interval
    if R > 0
        reporters = num_reporters(G, R, S, reporterfnc)
    else
        reporters = num_reporters(G, onstates)
    end
    i = 2
    d = prob_Gaussian(par, reporters, G * 2^R)
    while i < n
        while tracelog[i][1] <= frame && i < n
            state = tracelog[i][2]
            i += 1
        end
        trace = vcat(trace, [frame intensity(state, G, R, d)])
        frame += interval
    end
    return trace
end

"""
    intensity(state,onstates,G,R)

Returns the trace intensity given the state of a system

For R = 0, the intensity is occupancy of any onstates
For R > 0, intensity is the number of reporters in the nascent mRNA

"""
function intensity(state, G, R, d)
    stateindex = state_index(state, G, R)
    max(rand(d[stateindex]), 0)
end

"""
    state_index(state::Array, G, R, S=0)

TBW
"""
function state_index(state::Array, G, R, S=0)
    Gstate = argmax(state[1:G, 1])
    if R == 0
        return Gstate
    else
        if S > 0
            base = 3
            Rstates = state[G+1:end, 1]
        else
            base = 2
            Rstates = Int.(state[G+1:end, 1] .> 0)
        end
        return (Gstate - 1) * base^R + decimal(Rstates, base) + 1
    end
end

"""
    num_reporters(state::Matrix, allele, G, R, insertstep=1)

TBW
"""
function num_reporters(state::Matrix, allele, G, R, insertstep)
    d = 0
    for i in G+insertstep:G+max(R, 1)
        d = d + Int(state[i, allele] > 1)
    end
    d
end

"""
    firstpassagetime!(hist, t1, t2, t, dt, ndt, allele)

TBW
"""
function firstpassagetime!(hist, t1, t2, t, dt, ndt, allele)
    t1[allele] = t
    t12 = (t - t2[allele]) / dt
    if t12 <= ndt && t12 > 0 && t2[allele] > 0
        hist[ceil(Int, t12)] += 1
    end
end

set_arguments(reaction) = (reaction.initial, reaction.final, reaction.disabled, reaction.enabled, reaction.action)


# function set_reactionindicesold(Gtransitions, R, S, insertstep)
#     g = 1:length(Gtransitions)
#     r = length(Gtransitions)+1:length(Gtransitions)+1+R
#     s = length(Gtransitions)+1+R+1:length(Gtransitions)+1+R+S-insertstep+1
#     d = length(Gtransitions) + 1 + R + S + 1 - insertstep + 1
#     ReactionIndices(g, 2:1, r, 2:1, s, d)
# end
# """
#     set_reactions(Gtransitions, G, R, S, insertstep)

# create a vector of Reaction structures all the possible reactions
# """
# function set_reactionsold(Gtransitions, G, R, S, insertstep)
#     actions = set_actions()
#     indices = set_reactionindicesold(Gtransitions, R, S, insertstep)
#     reactions = Reaction[]
#     nG = length(Gtransitions)
#     for g in eachindex(Gtransitions)
#         u = Int[]
#         d = Int[]
#         ginitial = Gtransitions[g][1]
#         gfinal = Gtransitions[g][2]
#         for s in eachindex(Gtransitions)
#             if ginitial == Gtransitions[s][1] && gfinal != Gtransitions[s][2]
#                 push!(u, s)
#             end
#             if gfinal == Gtransitions[s][1]
#                 push!(d, s)
#             end
#         end
#         if gfinal == G
#             push!(d, length(Gtransitions) + 1)
#             push!(reactions, Reaction(actions["activateG!"], g, u, d, ginitial, gfinal))
#         elseif ginitial == G
#             push!(u, length(Gtransitions) + 1)
#             push!(reactions, Reaction(actions["deactivateG!"], g, u, d, ginitial, gfinal))
#         else
#             push!(reactions, Reaction(actions["transitionG!"], g, u, d, ginitial, gfinal))
#         end
#     end
#     if R > 0
#         # set enabled to splice reaction
#         if insertstep == 1
#             push!(reactions, Reaction(actions["initiate!"], indices.rrange[1], Int[], [nG + 2 + S], G, G + 1))
#         else
#             push!(reactions, Reaction(actions["initiate!"], indices.rrange[1], Int[], Int[], G, G + 1))
#         end
#     end
#     i = G
#     for r in indices.rrange
#         if r < length(Gtransitions) + R
#             i += 1
#             push!(reactions, Reaction(actions["transitionR!"], r + 1, [r], [r + 2], i, i + 1))
#         end
#     end
#     push!(reactions, Reaction(actions["eject!"], indices.rrange[end], Int[nG+R], Int[indices.decay], G + R, 0))
#     j = G + insertstep - 1
#     for s in indices.srange
#         j += 1
#         push!(reactions, Reaction(actions["splice!"], s, Int[], Int[], j, 0))
#     end
#     push!(reactions, Reaction(actions["decay!"], indices.decay, Int[], Int[], 0, 0))
#     return reactions
# end
"""
    set_reactionindices(Gtransitions, R, S, insertstep)

TBW
"""
function set_reactionindices(Gtransitions, R, S, insertstep)
    if S > 0
        S = R
    else
        insertstep = 1
    end
    nG = length(Gtransitions)
    g = 1:nG
    i = nG+1:nG+Int(R > 0)
    r = nG+2:nG+R
    e = nG+R+1:nG+R+1
    s = nG+1+R+1:nG+1+R+S-insertstep+1
    d = nG + 1 + R + S + 1 - insertstep + 1
    ReactionIndices(g, i, r, e, s, d)
end
"""
	Reaction

structure for reaction type

action: type of reaction
index: rate index for reaction
disabled: reactions disabled by reaction
enabled: reactions enabled by reaction
initial: initial GR state
final: final GR state
"""
function set_reactions(Gtransitions, G, R, S, insertstep)
    actions = set_actions()
    indices = set_reactionindices(Gtransitions, R, S, insertstep)
    reactions = Reaction[]
    nG = length(Gtransitions)
    Sstride = R - insertstep + 1
    for g in eachindex(Gtransitions)
        u = Int[]
        d = Int[]
        ginitial = Gtransitions[g][1]
        gfinal = Gtransitions[g][2]
        for s in eachindex(Gtransitions)
            # if ginitial == Gtransitions[s][1] && gfinal != Gtransitions[s][2]
            if ginitial == Gtransitions[s][1]
                push!(u, s)
            end
            if gfinal == Gtransitions[s][1]
                push!(d, s)
            end
        end
        if gfinal == G
            push!(d, nG + 1)
            push!(reactions, Reaction(actions["activateG!"], g, u, d, ginitial, gfinal))
        elseif ginitial == G
            push!(u, nG + 1)
            push!(reactions, Reaction(actions["deactivateG!"], g, u, d, ginitial, gfinal))
        else
            push!(reactions, Reaction(actions["transitionG!"], g, u, d, ginitial, gfinal))
        end
    end
    for i in indices.irange
        if S > 0 && insertstep == 1
            push!(reactions, Reaction(actions["initiate!"], i, [], [nG + 2; nG + 2 + S], G, G + 1))
        else
            push!(reactions, Reaction(actions["initiate!"], i, [], [nG + 2], G, G + 1))
        end
    end
    i = G
    for r in indices.rrange
        i += 1
        if S > 0
            if i >= G + insertstep 
                push!(reactions, Reaction(actions["transitionR!"], r, Int[r; r + Sstride], [r - 1; r + 1; r + 1 + Sstride], i, i + 1))
            else
                push!(reactions, Reaction(actions["transitionR!"], r, Int[r], [r - 1; r + 1; r + 1 + Sstride], i, i + 1))
            end
        else
            push!(reactions, Reaction(actions["transitionR!"], r, Int[r], [r - 1; r + 1], i, i + 1))
        end
    end
    for e in indices.erange
        if S > 0
            push!(reactions, Reaction(actions["eject!"], e, Int[e, e+Sstride], Int[e-1, indices.decay], G + R, 0))
        elseif R > 0
            push!(reactions, Reaction(actions["eject!"], e, Int[e], Int[e-1, indices.decay], G + R, 0))
        else
            push!(reactions, Reaction(actions["eject!"], e, Int[], Int[e, indices.decay], G + 1, 0))
        end
    end
    j = G + insertstep - 1
    for s in indices.srange
        j += 1
        push!(reactions, Reaction(actions["splice!"], s, Int[], Int[], j, 0))
    end
    push!(reactions, Reaction(actions["decay!"], indices.decay, Int[], Int[indices.decay], 0, 0))
    return reactions
end

"""
    transitionG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)

update tau and state for G transition

"""
function transitionG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
    for e in enabled
        tau[e, allele] = -log(rand()) / r[e] + t
    end
    for d in disabled
        tau[d, allele] = Inf
    end
    state[final, allele] = 1
    state[initial, allele] = 0
end
"""
	activateG!(tau,state,index,t,m,r,allele,G,R,disabled,enabled,initial,final)

"""
function activateG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
    transitionG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
    if R > 0 && state[G+1, allele] > 0
        tau[enabled[end], allele] = Inf
    end
end
"""
    deactivateG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)


"""
function deactivateG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
    transitionG!(tau, state, index, t, m, r, allele, G, R, disabled, enabled, initial, final)
end
"""
    initiate!(tau, state, index, t, m, r, allele, G, R, S, enabled)


"""
function initiate!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial, final,insertstep)
    if final + 1 > G + R || state[final+1, allele] == 0
        tau[enabled[1], allele] = -log(rand()) / (r[enabled[1]]) + t
    end
    if insertstep == 1
        state[final, allele] = 2
        if S > 0
            tau[enabled[end], allele] = -log(rand()) / (r[enabled[end]]) + t
        end
    else
        state[final, allele] = 1
    end
    tau[index, allele] = Inf
end
"""
    transitionR!(tau, state, index, t, m, r, allele, G, R, S, u, d, initial, final)


"""
function transitionR!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial, final,insertstep)
    if state[initial-1, allele] > 0
        tau[enabled[1], allele] = -log(rand()) / r[enabled[1]] + t
    end
    if final + 1 > G + R || state[final+1, allele] == 0
        tau[enabled[2], allele] = -log(rand()) / r[enabled[2]] + t
    end
    if S > 0
        if final == insertstep + G
            tau[enabled[3], allele] = -log(rand()) / r[enabled[3]] + t
        elseif state[initial, allele] > 1
            tau[enabled[3], allele] = r[enabled[3]-1] / r[enabled[3]] * (tau[enabled[3]-1, allele] - t) + t
        end
    end
    for d in disabled
        tau[d, allele] = Inf
    end
    if final == insertstep + G
        state[final, allele] = 2
    else
        state[final, allele] = state[initial, allele]
    end
    state[initial, allele] = 0
end

"""
    eject!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled)

"""
function eject!(tau, state, index, t, m, r, allele, G, R, S, disabled, enabled, initial)
    if state[initial-1, allele] > 0
        tau[enabled[1], allele] = -log(rand()) / (r[enabled[1]]) + t
    end
    for d in disabled
        tau[d, allele] = Inf
    end
    if R > 0
        state[initial, allele] = 0
    end
    set_decay!(tau, enabled[end], t, m, r)
end
"""
    splice!(tau, state, index, t, m, r, allele, G, R, initial)

"""
function splice!(tau, state, index, t, m, r, allele, G, R, initial)
    state[initial, allele] = 1
    tau[index, allele] = Inf
end
"""
    decay!(tau, index, t, m, r)

"""
function decay!(tau, index, t, m, r)
    m -= 1
    if m == 0
        tau[index, 1] = Inf
    else
        tau[index, 1] = -log(rand()) / (m * r[index]) + t
    end
    m
end

"""
    set_decay!(tau, index, t, m, r)

update tau matrix for decay rate

"""
function set_decay!(tau, index, t, m, r)
    m += 1
    if m == 1
        tau[index, 1] = -log(rand()) / r[index] + t
    else
        tau[index, 1] = (m - 1) / m * (tau[index, 1] - t) + t
    end
    m
end
