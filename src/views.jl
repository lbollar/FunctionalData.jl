export View, view, next!, trytoview

typealias View Array

view{T<:Real}(a::SharedArray{T}, i::Int) = view(sdata(a), i)
view{T<:Real}(a::SharedArray{T}, i::Int, v::View{T}) = view(sdata(a), i, v)

function view{T<:Real}(a::DenseArray{T}, i::Int)
    s = size(a)
    if length(s)>2
        s = s[1:end-1]
    elseif length(s)==2
        s = (s[1],1)
    else
        s = (1, 1)
    end
    view(a, i, convert(View, pointer_to_array(pointer(a), s)))
end

function view{T<:Real}(a::DenseArray{T}, i::Int, v::View{T})
    p = convert(Ptr{Ptr{T}}, pointer_from_objref(v))
    unsafe_store!(p, pointer(a) + (i-1) * length(v) * sizeof(T), 2)
    v
end

function view{T<:Real}(a::DenseArray{T}, ind::UnitRange)
    s = size(a)[1:end-1]
    p = pointer(a) + (fst(ind)-1) * prod(s) * sizeof(T)
    convert(View, pointer_to_array(p, tuple(s..., length(ind)) ))
end


@compat @inline function next!{T}(v::View{T})
    p = convert(Ptr{Ptr{T}}, pointer_from_objref(v))
    datap = unsafe_load(p, 2)
    unsafe_store!(p, datap + length(v) * sizeof(T), 2)
    v
end

trytoview{T<:Real}(a::DenseArray{T}, i) = view(a, i)
trytoview{T<:Real}(a::DenseArray{T}, i, v) = view(a, i, v)
trytoview(a, i) = at(a, i)
trytoview(a, i, v) = at(a, i)



  




  

