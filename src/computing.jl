using SHA
export map, map!, map!r, map2!, mapmap, work
export share, unshare, shmap, shmap!, shmap!r, shmap2!
export pmap, lmap
export sort
export fasthash

import Base.sort
sort(a, f; kargs...) = part(a, sortperm(vec(map(a, f)); kargs...))

#######################################
## map, pmap


import Base.map
map(a::String, f::Function) = flatten(map(unstack(a),f))
function map{T,N}(a::AbstractArray{T,N}, f::Function)
    isempty(a) && return Any[]

    r1 = f(fst(a))
    r = arraylike(r1, len(a), a)

    setat!(r,1,r1)
    map_(f,a,r)                         
    return r
end

@compat @inline function map_{Tin,Nin,Tout,Nout}(f::Function,a::AbstractArray{Tin,Nin},r::Array{Tout,Nout})
    for i = 2:len(a)
        b = f(at(a,i))
        setat!(r,i,b)
    end
end

map(a::Dict, f::AbstractArray) = error("Calling map with no function does not make sense")
map(a::Dict, f::Function) = @compat Dict(Base.map((x) -> (x[1], f(x[2])), a))
function mapmap(a, f)
    isempty(a) && return Any[]
    g = x -> map(x,f)
    map(a, g)
end

function map{T<:Real,N}(a::DenseArray{T,N},f::Function)
    v = view(a,1)
    r1 = f(v)
    r = arraylike(r1, len(a), a)
    rv = view(r,1)
    rv[:] = r1
    next!(v)
    next!(rv)
    for i = 2:len(a)
        rv[:] = f(v) 
        next!(v)
        next!(rv)
    end
    r
end

function map2!{T<:Real,N}(a::DenseArray{T,N}, f1::Function, f2::Function)
    v = view(a,1)
    r1 = f1(v)
    r = arraylike(r1, len(a), a)
    rv = view(r,1)
    rv[:] = r1
    map2!(view(a, 2:len(a)), view(r, 2:len(a)), f2)
    r
end

function map2!{T<:Real,N,T2<:Real,M}(a::DenseArray{T,N}, r::DenseArray{T2,M}, f::Function)
    v = view(a,1)
    rv = view(r,1)
    for i = 1:len(a)
        f(rv, v) 
        next!(v)
        next!(rv)
    end
    r
end
function map!r{T<:Real,N}(a::DenseArray{T,N},f::Function)
    v = view(a,1)
    for i = 1:len(a)
        v[:] = f(v)
        next!(v)
    end
    a
end
function map!{T<:Real,N}(a::DenseArray{T,N},f::Function)
    v = view(a,1)
    for i = 1:len(a)
        f(v)
        next!(v)
    end
    a
end
 
work(a,f::Function) = ([(f(at(a,i));nothing) for i in 1:len(a)]; nothing)
function work{T<:Real,N}(a::DenseArray{T,N},f::Function)
    v = view(a,1)
    for i = 1:len(a)
        f(v) 
        next!(v)
    end
end
 
share{T<:Real,N}(a::DenseArray{T,N}) = convert(SharedArray, a)
share(a::SharedArray) = a
unshare(a::SharedArray) = sdata(a)

function loopovershared(r::View, a::View, f::Function)
    v = view(a,1)
    rv = view(r,1)
    for i = 1:len(a)
        rv[:] = f(v)
        next!(v)
        next!(rv)
    end
end

function loopovershared!(a::View, f::Function)
    v = view(a, 1)
    for i = 1:len(a)
        f(v)
        next!(v)
    end
end

function loopovershared!r(a::View, f::Function)
    v = view(a, 1)
    for i = 1:len(a)
        v[:] = f(v)
        next!(v)
    end
end

function loopovershared2!(r::View, a::View, f::Function)
    v = view(a,1)
    rv = view(r,1)
    for i = 1:len(a)
        f(rv, v)
        next!(v)
        next!(rv)
    end
end

function shsetup(a::SharedArray; withfirst = false)
    pids = procs(a)
    if length(pids) > 1
        pids = pids[pids .!= 1]
    end
    ind = (withfirst ? 1 : 2):len(a)
    n = min(length(pids), len(ind))
    inds = partition(ind, n)
    pids, inds, n
end

shmap{T<:Real,N}(a::DenseArray{T,N}, f::Function) = shmap(share(a), f)
function shmap{T<:Real,N}(a::SharedArray{T,N}, f::Function)
    pids, inds, n = shsetup(a)

    r1 = f(view(a,1))
    r = sharraylike(r1, len(a))
    rv = view(r,1)
    rv[:] = r1

    @sync for i in 1:n
        @spawnat pids[i] loopovershared(view(r, inds[i]), view(a, inds[i]), f)
    end
    r
end

shmap!{T<:Real,N}(a::DenseArray{T,N}, f::Function) = shmap!(share(a), f)
function shmap!{T<:Real,N}(a::SharedArray{T,N}, f::Function)
    pids, inds, n = shsetup(a; withfirst = true)

    @sync for i in 1:n
        @spawnat pids[i] loopovershared!(view(a, inds[i]), f)
    end
    a
end

shmap!r{T<:Real,N}(a::DenseArray{T,N}, f::Function) = shmap!r(share(a), f)
function shmap!r{T<:Real,N}(a::SharedArray{T,N}, f::Function)
    pids, inds, n = shsetup(a; withfirst = true)

    @sync for i in 1:n
        @spawnat pids[i] loopovershared!r(view(a, inds[i]), f)
    end
    a
end

shmap2!{T<:Real, N}(a::DenseArray{T,N}, f1::Function, f2::Function) = shmap2!(share(a), f1, f2)
function shmap2!{T<:Real, N}(a::SharedArray{T,N}, f1::Function, f2::Function)
    r1 = f1(view(a,1))
    r = sharraylike(r1, len(a))
    rv = view(r,1)
    rv[:] = r1
    shmap2!(a, r, f2, withfirst = false)
    r
end

shmap2!{T<:Real,N, T2<:Real, M}(a::DenseArray{T,N}, r::SharedArray{T2,M}, f::Function) = shmap2!(share(a), r, f)
function shmap2!{T<:Real,N, T2<:Real, M}(a::SharedArray{T,N}, r::SharedArray{T2,M}, f::Function; withfirst = true)
    pids, inds, n = shsetup(a, withfirst = withfirst)
    @sync for i in 1:n
        @spawnat pids[i] loopovershared2!(view(r, inds[i]), view(a, inds[i]), f)
    end
    r
end

###############################
#  pmap

function pmapsetup(a; pids = workers())
    if length(pids) > 1
        pids = pids[pids .!= 1]
    end
    n = min(length(pids)*10, len(a))
    inds = partition(1:len(a), n)
    pids, inds, n
end


import Base.pmap
function pmap(a, f::Function; kargs...)
    pids, inds, n = pmapsetup(a; kargs...)
    
    if isa(a, DenseArray)
        parts = [view(a, inds[i]) for i in 1:n]
    else
        parts = [part(a, inds[i]) for i in 1:n]
    end

    mapper(a) = map(a,f)
    if VERSION.minor >= 4
        r = pmap(mapper, parts, pids = pids)
    else
        r = pmap(mapper, parts)
    end

    flatten(r)
end

lmap(a, f::Function) = pmap(a, f, pids = procs(myid()))

