# This file is part of StochasticGene.jl
#
# transition_rate_matrices_transpose.jl
#
# Functions to compute the transpose of the transition rate matrix for Stochastic transitions
# Matrices are the transpose to the convention for Kolmogorov forward equations
# i.e. reaction directions go from column to row,
# Notation:  M = transpose of transition rate matrix of full (countably infinite) stochastic process including mRNA kinetics
# Q = finite transition rate matrix for GRS continuous Markov process
# T = Q'
# transpose of Q is more convenient for solving chemical master equation
#


"""
	struct Element

structure for transition matrix elements
fields: 
`a`: row, 
`b`: column
`index`: rate vector index
`pm`: sign of elements

"""
struct Element
    a::Int
    b::Int
    index::Int
    pm::Int
end


"""
	struct MComponents

structure for matrix components for matrix M
"""
struct MComponents
    elementsT::Vector{Element}
    elementsB::Vector{Element}
    nT::Int
    U::SparseMatrixCSC
    Uminus::SparseMatrixCSC
    Uplus::SparseMatrixCSC
end

"""
	AbstractTComponents

abstract type for components of transition matrices 
"""
abstract type AbstractTComponents end

"""
	struct TComponents

fields:
nT, elementsT

"""
struct TComponents <: AbstractTComponents
    nT::Int
    elementsT::Vector
end

"""
	struct TAIComponents

fields:
nT, elementsT, elementsTA, elementsTI

"""
struct TAIComponents <: AbstractTComponents
    nT::Int
    elementsT::Vector{Element}
    elementsTA::Vector{Element}
    elementsTI::Vector{Element}
end
"""
	struct TDComponents

fields:
nT, elementsT, elementsTD:: Vector{Vector{Element}}

"""
struct TDComponents <: AbstractTComponents
    nT::Int
    elementsT::Vector{Element}
    elementsTD::Vector{Vector{Element}}
end


"""
 	MTComponents

 structure for M and T components

fields:
mcomponents::MComponents
tcomponents::TComponents
"""
struct MTComponents
    mcomponents::MComponents
    tcomponents::TComponents
end
"""
 	MTComponents

 structure for M and TAI components

fields:
mcomponents::MComponents
tcomponents::TAIComponents
"""
struct MTAIComponents
    mcomponents::MComponents
    tcomponents::TAIComponents
end
"""
 	MTDComponents

 structure for M and TD components

fields:
mcomponents::MComponents
tcomponents::TDComponents
"""
struct MTDComponents
    mcomponents::MComponents
    tcomponents::TDComponents
end
"""
	struct Indices

index ranges for rates
"""
struct Indices
    gamma::Vector{Int}
    nu::Vector{Int}
    eta::Vector{Int}
    decay::Int
end
"""
    make_components(transitions, G, R, S, r, total::Int, indices::Indices, rnatype::String="")

return MTAI Component structure
"""
function make_components(transitions, G, R, S, startstep, r, total::Int, indices::Indices, onstates=[], rnatype::String="")
    if S > 0
        return make_components(transitions, G, R, S, startstep, r, total, indices, rnatype, onstates)
        U, Um, Up = make_mat_U(total, r[indices.decay])
        return MTAIComponents(MComponents(set_elements_T(transitions, G, R, 0, indices, rnatype), set_elements_B(G, R, indices.nu[R+1]), G * 2^R, U, Um, Up), make_components_TAI(set_elements_T(transitions, G, R, S, indices, rnatype), G, R, 3))
    elseif R > 0
        return make_components(transitions, G, R, startstep, r, total, indices, onstates)
    else
        return make_components(transitions, G, r, total, indices, onstates)
    end
end
function make_components(transitions, G, R, S::Int, r::Vector, total::Int, indices::Indices, rnatype::String="")
    # if rnatype == "offeject"
    #      elementsT = set_elements_T(transitions, G, R, 2, set_elements_R_offeject!, indices)
    #      set_elements_T(transitions, G, R, S, indices, R,S,rnatype)
    # else
    #      elementsT = set_elements_T(transitions, G, R, 2, set_elements_R!, indices)
    # end
    U, Um, Up = make_mat_U(total, r[indices.decay])
    MTAIComponents(MComponents(set_elements_T(transitions, G, R, 0, indices, rnatype), set_elements_B(G, R, indices.nu[R+1]), G * 2^R, U, Um, Up), make_components_TAI(set_elements_T(transitions, G, R, S, indices, rnatype), G, R, 3))
end

"""
    make_components(transitions, G, R, r, total, indices::Indices)


"""
function make_components(transitions, G, R, r::Vector, total::Int, indices::Indices)
    MTAIComponents(make_components_M(transitions, G, R, total, r[indices.decay], 2, indices), make_components_TAI(set_elements_T(transitions, G, R, 2, set_elements_R!, indices), G, R, 2))
end
"""
    make_components(transitions, G, r, total::Int, indices::Indices, onstates::Vector)


"""
function make_components(transitions, G, r, total::Int, indices::Indices, onstates::Vector)
    elementsT = set_elements_T(transitions, indices.gamma)
    U, Um, Up = make_mat_U(total, r[indices.decay])
    MTAIComponents(MComponents(elementsT, set_elements_B(G, indices.nu[1]), G, U, Um, Up), make_components_TAI(elementsT, G, onstates))
end

"""
make_components_M(transitions, nT, total, decay)

return MComponent structure

"""
function make_components_M(transitions, nT, total, decay)
    ntransitions = length(transitions)
    elementsT = set_elements_T(transitions, collect(1:ntransitions))
    elementsB = set_elements_B(nT, ntransitions + 1)
    U, Um, Up = make_mat_U(total, decay)
    MComponents(elementsT, elementsB, nT, U, Um, Up)
end
"""
    make_components_M(transitions, G, R, total, decay, base, indices)


"""
function make_components_M(transitions, G, R, total, decay, base, indices)
    if R == 0
        return make_components_M(transitions, G, total, decay)
    else
        elementsT = set_elements_T(transitions, G, R, base, set_elements_R!, indices)
        elementsB = set_elements_B(G, R, indices.nu[R+1])
        U, Um, Up = make_mat_U(total, decay)
        return MComponents(elementsT, elementsB, G * base^R, U, Um, Up)
    end
end
"""
make_components_TAI(elementsT, G::Int, onstates::Vector)

return TComponent structure
"""
function make_components_TAI(elementsT, nT::Int, onstates::Vector)
    elementsTA = Vector{Element}(undef, 0)
    elementsTI = Vector{Element}(undef, 0)
    set_elements_TA!(elementsTA, elementsT, onstates)
    set_elements_TI!(elementsTI, elementsT, onstates)
    TAIComponents(nT, elementsT, elementsTA, elementsTI)
end
function make_components_TAI(elementsT, G::Int, R::Int, base)
    elementsTA = Vector{Element}(undef, 0)
    elementsTI = Vector{Element}(undef, 0)
    set_elements_TA!(elementsTA, elementsT, G, R, base)
    set_elements_TI!(elementsTI, elementsT, G, R, base)
    TAIComponents(G * base^R, elementsT, elementsTA, elementsTI)
end
"""
    make_components_T(transitions, G, R)

return TComponent structure
"""
function make_components_T(transitions, G, R, S)
    if S > 0
        # elements_T = set_elements_T(transitions, G, R, 3, set_elements_R!, set_indices(length(transitions), R,S))
        elements_T = set_elements_T(transitions, G, R, S, set_indices(length(transitions), R, S), "")
        return TComponents(G * 3^R, elements_T, Element[], Element[])
    elseif R > 0
        return make_components_T(transitions, G, R)
    else
        return make_components_T(transitions, G)
    end
end

function make_components_T(transitions, G, R)
    # elements_T = set_elements_T(transitions, G, R, 2, set_elements_R!, set_indices(length(transitions), R))
    elements_T = set_elements_T(transitions, G, R, 0, set_indices(length(transitions), R), "")
    TComponents(G * 2^R, elements_T)
end
function make_components_T(transitions, G)
    elements_T = set_elements_T(transitions, set_indices(length(transitions)).gamma)
    TComponents(G, elements_T)
end

"""
    state_index(G::Int,i,z)

return state index for state (i,z)
"""
state_index(G::Int,i,z) = i + G * (z - 1)
"""
    on_states(G,R,startstep,base=2)

return vector of on state indices for GR and GRS models
"""
function on_states!(onstates::Vector,G::Int, R::Int,insertstep, base)
	for i in 1:G, z in 1:base^R
		if any(digits(z - 1, base=base, pad=R)[insertstep:end] .== base - 1)
			push!(onstates, state_index(i,z))
		end
	end
end

function on_states(G,R,S,insertstep) 
	base = S > 0 ? 3 : 2
	onstates = Int[]
	on_states!(onstates,G, R,insertstep, base)
	onstates
end

"""
    off_states(nT,onstates)

return barrier (off) states, complement of sojurn (on) states
"""
off_states(nT,onstates) = setdiff(collect(1:nT), onstates)

"""
    num_reporters(G::Int, R::Int, S::Int=0,insterstep=1,f=sum)

return number of a vector of the number reporters for each state index

if f = sum, returns total number of reporters
if f = any, returns 1 for presence of any reporter
"""
function num_reporters(G::Int, R::Int, S::Int=0,insterstep=1,f=sum)
    base = S > 0 ? 3 : 2
    reporters = Vector{Int}(undef,G*base^R)
    for i in 1:G, z in 1:base^R
		reporters[state_index(i,z)] = f(digits(z - 1, base=base, pad=R)[insterstep:end] .== base - 1)
        # push!(reporters, f(digits(z - 1, base=base, pad=R)[insterstep:end] .== base - 1))
    end
    reporters
end
function num_reporters(G::Int, onstates::Vector)
    reporters = Int[]
    for i in 1:G
        push!(reporters, i ∈ onstates ? 1 : 0)
    end
    reporters
end
"""
	set_indices(ntransitions, R, insertstep)
	set_indices(ntransitions,R)
	set_indices(ntransitions)

	return Indices structure
"""

function set_indices(ntransitions, R, insertstep)
    if S > 0
        Indices(collect(1:ntransitions), collect(ntransitions+1:ntransitions+R+1), collect(ntransitions+R+2:ntransitions+R+R-insertstep+2), ntransitions+R+R-insertstep+3)
    elseif R > 0
        set_indices(ntransitions, R)
    else
        set_indices(ntransitions)
    end
end

set_indices(ntransitions) = Indices(collect(1:ntransitions), [ntransitions + 1], Int[], ntransitions + 2)
set_indices(ntransitions, R) = Indices(collect(1:ntransitions), collect(ntransitions+1:ntransitions+R+1), Int[], ntransitions + R + 2)


"""
	set_elements_G!(elements,transitions,G,R,base,gamma)

	return G transition matrix elements

-`elements`: Vector of Element structures
-`transitions`: tupe of G state transitions
"""
function set_elements_G!(elements, transitions, G, R, base, gamma)
    nT = G * base^R
    k = 1
    for j = 0:G:nT-1
        set_elements_G!(elements, transitions, j, gamma)
    end
end
function set_elements_G!(elements, transitions, j=0, gamma=collect(1:length(transitions)))
    i = 1
    for t in transitions
        push!(elements, Element(t[1] + j, t[1] + j, gamma[i], -1))
        push!(elements, Element(t[2] + j, t[1] + j, gamma[i], 1))
        i += 1
    end
end

# set_elements_R!(elementsT, G, R, indices::Indices) = set_elements_R!(elementsT, G, R, indices.nu)
# set_elements_R!(elementsT, G, R, nu::Vector{Int}) = set_elements_RS!(elementsT, G, R, 0, nu, Int[], 2)
# set_elements_RS!(elementT, G, R, indices::Indices) = set_elements_RS!(elementT, G, R, indices.nu, indices.eta)
# set_elements_RS!(elementsT, G, R, nu::Vector{Int}, eta::Vector{Int}) = set_elements_RS!(elementsT, G, R, R, nu, eta, 3)
# set_elements_R_offeject!(elementsT, G, R, indices::Indices) = set_elements_RS!(elementsT, G, R, R, indices.nu, indices.eta, 2, "offeject")

"""
    set_elements_RS!(elementsT, G, R, S, insertstep, nu::Vector{Int}, eta::Vector{Int}, rnatype="")

set inline matrix elements in elementsT for GRS state transition matrix, do nothing if R == 0

    "offeject" = pre-RNA is completely ejected when spliced
"""
function set_elements_RS!(elementsT, G, R, S, insertstep, nu::Vector{Int}, eta::Vector{Int}, rnatype="")
    if R > 0
        if rnatype == "offeject"
            S = 0
            base = 2
        end
        if S == 0
            base = 2
        else
            base = 3
        end
        for w = 1:base^R, z = 1:base^R
            zdigits = digit_vector(z,base,R)
            wdigits = digit_vector(w,base,R)
            z1 = zdigits[1]
            w1 = wdigits[1]
            zr = zdigits[R]
            wr = wdigits[R]
            zbar1 = zdigits[2:R]
            wbar1 = wdigits[2:R]
            zbarr = zdigits[1:R-1]
            wbarr = wdigits[1:R-1]
            sB = 0
            for l in 1:base-1
                sB += (zbarr == wbarr) * ((zr == 0) - (zr == l)) * (wr == l)
            end
            if S > 0
                sC = (zbarr == wbarr) * ((zr == 1) - (zr == 2)) * (wr == 2)
            end
            for i = 1:G
                # a = i + G * (z - 1)
                # b = i + G * (w - 1)
				a = state_index(G,i,z)
				b = state_index(G,i,w)
                if abs(sB) == 1
                    push!(elementsT, Element(a, b, nu[R+1], sB))
                end
                if S > 0 && abs(sC) == 1
                    push!(elementsT, Element(a, b, eta[R-insertstep+1], sC))
                end
                if rnatype == "offeject"
                    s = (zbarr == wbarr) * ((zr == 0) - (zr == 1)) * (wr == 1)
                    if abs(s) == 1
                        push!(elementsT, Element(a, b, eta[R-insertstep+1], s))
                    end
                end
                for j = 1:R-1
                    zbarj = zdigits[[1:j-1; j+2:R]]
                    wbarj = wdigits[[1:j-1; j+2:R]]
                    zbark = zdigits[[1:j-1; j+1:R]]
                    wbark = wdigits[[1:j-1; j+1:R]]
                    zj = zdigits[j]
                    zj1 = zdigits[j+1]
                    wj = wdigits[j]
                    wj1 = wdigits[j+1]
                    s = 0
                    for l in 1:base-1
                        s += (zbarj == wbarj) * ((zj == 0) * (zj1 == l) - (zj == l) * (zj1 == 0)) * (wj == l) * (wj1 == 0)
                    end
                    if abs(s) == 1
                        push!(elementsT, Element(a, b, nu[j+1], s))
                    end
                    if S > 0
                        s = (zbark == wbark) * ((zj == 1) - (zj == 2)) * (wj == 2)
                        if abs(s) == 1 && i >= insertstep
                            push!(elementsT, Element(a, b, eta[j-insertstep+1], s))
                        end
                    end
                    if rnatype == "offeject"
                        s = (zbark == wbark) * ((zj == 0) - (zj == 1)) * (wj == 1)
                        if abs(s) == 1 && i >= insertstep
                            push!(elementsT, Element(a, b, eta[j-insertstep+1], s))
                        end
                    end
                end
            end
            s = (zbar1 == wbar1) * ((z1 == base - 1) - (z1 == 0)) * (w1 == 0)
            if abs(s) == 1
                push!(elementsT, Element(G * z, G * w, nu[1], s))
            end
        end
    end
end
"""
	set_elements_TA!(elementsTA,elementsT)


"""
function set_elements_TA!(elementsTA, elementsT, onstates::Vector)
    for e in elementsT
        if e.b ∈ onstates
            push!(elementsTA, e)
        end
    end
end
function set_elements_TA!(elementsTA, elementsT, G::Int, R::Int, base::Int=3)
    for e in elementsT
        wdigits = digits(div(e.b - 1, G), base=base, pad=R)
        if any(wdigits .> base - 2)
            push!(elementsTA, e)
        end
    end
end
"""
	set_elements_TI!(elementsTI,elementsT)


"""
function set_elements_TI!(elementsTI, elementsT, onstates::Vector)
    for e in elementsT
        if e.b ∉ onstates
            push!(elementsTI, e)
        end
    end
end
function set_elements_TI!(elementsTI, elementsT, G::Int, R::Int, base::Int=3)
    for e in elementsT
        wdigits = digits(div(e.b - 1, G), base=base, pad=R)
        if ~any(wdigits .> base - 2)
            push!(elementsTI, e)
        end
    end
end


"""
    set_elements_T(transitions, G, R, S, indices::Indices, rnatype::String)

return T matrix elements (Element structure)
"""
function set_elements_T(transitions, G, R, S, indices::Indices, rnatype::String)
	if R > 0
    	elementsT = Vector{Element}(undef, 0)
    	base = S > 0 ? 3 : 2
    	set_elements_G!(elementsT, transitions, G, R, base, indices.gamma)
   		set_elements_RS!(elementsT, G, R, S, indices.nu, indices.eta, rnatype)
    	return elementsT
	else
		return set_elements_T(transitions, gamma::Vector)
	end
end
function set_elements_T(transitions, gamma::Vector)
    elementsT = Vector{Element}(undef, 0)
    set_elements_G!(elementsT, transitions, 0, gamma)
    elementsT
end
"""
    set_elements_B(G, ejectindex)

return B matrix elements
"""
set_elements_B(G, ejectindex) = [Element(G, G, ejectindex, 1)]

function set_elements_B(G, R, ejectindex, base=2)
    elementsB = Vector{Element}(undef, 0)
    for w = 1:base^R, z = 1:base^R, i = 1:G
        a = i + G * (z - 1)
        b = i + G * (w - 1)
        zdigits = digits(z - 1, base=base, pad=R)
        wdigits = digits(w - 1, base=base, pad=R)
        zr = zdigits[R]
        wr = wdigits[R]
        zbarr = zdigits[1:R-1]
        wbarr = wdigits[1:R-1]
        s = (zbarr == wbarr) * (zr == 0) * (wr == 1)
        if abs(s) == 1
            push!(elementsB, Element(a, b, ejectindex, s))
        end
    end
    return elementsB
end
"""
make_mat!(T::AbstractMatrix,elements::Vector,rates::Vector)

set matrix elements of T to those in vector argument elements
"""
function make_mat!(T::AbstractMatrix, elements::Vector, rates::Vector)
    for e in elements
        T[e.a, e.b] += e.pm * rates[e.index]
    end
end
"""
make_mat(elements,rates,nT)

return an nTxnT sparse matrix T
"""
function make_mat(elements::Vector, rates::Vector, nT::Int)
    T = spzeros(nT, nT)
    make_mat!(T, elements, rates)
    return T
end
"""
make_S_mat

"""
function make_mat_U(total::Int, mu::Float64)
    U = spzeros(total, total)
    Uminus = spzeros(total, total)
    Uplus = spzeros(total, total)
    # Generate matrices for m transitions
    Uplus[1, 2] = mu
    for m = 2:total-1
        U[m, m] = -mu * (m - 1)
        Uminus[m, m-1] = 1
        Uplus[m, m+1] = mu * m
    end
    U[total, total] = -mu * (total - 1)
    Uminus[total, total-1] = 1
    return U, Uminus, Uplus
end
"""
make_M_mat

return M matrix used to compute steady state RNA distribution
"""
function make_mat_M(T::SparseMatrixCSC, B::SparseMatrixCSC, mu::Float64, total::Int)
    U, Uminus, Uplus = make_mat_U(total, mu)
    make_mat_M(T, B, U, Uminus, Uplus)
end
function make_mat_M(T::SparseMatrixCSC, B::SparseMatrixCSC, U::SparseMatrixCSC, Uminus::SparseMatrixCSC, Uplus::SparseMatrixCSC)
    nT = size(T, 1)
    total = size(U, 1)
    M = kron(U, sparse(I, nT, nT)) + kron(sparse(I, total, total), T - B) + kron(Uminus, B) + kron(Uplus, sparse(I, nT, nT))
    M[end-size(B, 1)+1:end, end-size(B, 1)+1:end] .+= B  # boundary condition to ensure probability is conserved
    return M
end

function make_mat_M(components::MComponents, rates::Vector)
    T = make_mat(components.elementsT, rates, components.nT)
    B = make_mat(components.elementsB, rates, components.nT)
    make_mat_M(T, B, components.U, components.Uminus, components.Uplus)
end

"""
make_T_mat


"""
make_mat_T(components::AbstractTComponents, rates) = make_mat(components.elementsT, rates, components.nT)

make_mat_TA(components::TAIComponents, rates) = make_mat(components.elementsTA, rates, components.nT)

make_mat_TI(components::TAIComponents, rates) = make_mat(components.elementsTI, rates, components.nT)