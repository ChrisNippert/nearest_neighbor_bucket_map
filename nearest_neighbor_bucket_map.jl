module NNStructs
mutable struct NNBucketMap{K,V,F1,F2}
    layers::Int # Count of levels
    max_size::Int
    bucket_layers::Vector{Dict{K,Set{V}}} # Vector storing dicts at each level
    bucket_sizes::Vector{Int} # Corresponding sizes of buckets based for each bucket level

    fit_key::F1 # Function able to compress a key K to some other key K
    delta::F2 # Returns the distance from two keys

    function NNBucketMap{K, V}(fit_key::F1, delta::F2) where {K,V,F1,F2}
        return NNBucketMap{K, V}(256, fit_key, delta)
    end
    
    
    function NNBucketMap{K, V}(max_size::Int, fit_key::F1, delta::F2) where {K,V,F1,F2}
        ### Computes bucket sizes for each layer
        ns = Int[]
        n = max_size
        while n >= 1
            push!(ns, n)
            n = fld(n, 2)
        end
        reverse!(ns)

        ### Create empty dictionaries for each layer
        levels = [Dict{K, Set{V}}() for _ in 1:length(ns)]

        new{K,V,F1,F2}(length(ns), max_size, levels, ns, fit_key, delta)
    end
end

function resize_needed(map::NNBucketMap{K,V,F1,F2}, key::K) where {K,V,F1,F2}
    max(abs.(key)) >= map.max_size
end

function Base.setindex!(map::NNBucketMap{K,V,F1,F2}, value, key) where {K,V,F1,F2}
    # return unedited of has key
    haskey(map, key) && return map # Probably should update the key's value instead but :shrug:

    # Here, resize if a key is inserted

    # Iterate through buckets
    for (i,bucket) in enumerate(map.bucket_layers)
        fitted_key = map.fit_key(key, map.bucket_sizes[i])
        # Add a new set if it doesn't exist
        if !haskey(bucket, fitted_key)
            bucket[fitted_key] = Set{V}()  # initialize the Set if not exists
        end
    end

    # Iterate through buckets and push to set corresponding to the bucketed value
    for (i,bucket) in enumerate(map.bucket_layers)
        push!(bucket[map.fit_key(key, map.bucket_sizes[i])], value)
    end
    return map
end

function Base.getindex(map::NNBucketMap{K,V,F1,F2}, key::K) where {K,V,F1,F2}
    return haskey(map, key) ? first(map.bucket_layers[1][key]) : nothing
end

function nn(map::NNBucketMap{K,V,F1,F2}, key::K) where {K,V,F1,F2}
    # Find smallest scope bucket set for input key
    candidates = K[]
    for (i,bucket) in enumerate(map.bucket_layers)
        fitted_key = map.fit_key(key, map.bucket_sizes[i])
        if haskey(bucket, fitted_key)
            candidates = bucket[fitted_key]
            break
        end
    end

    return candidates
end

function Base.delete!(map::NNBucketMap{K,V,F1,F2}, key::K) where {K,V,F1,F2}
    value = map[key]
    if value === nothing
        return map
    end

    # Iterate through buckets and delete the value from each bucket's set
    for (i,bucket) in enumerate(map.bucket_layers)
        fitted_key = map.fit_key(key, map.bucket_sizes[i])
        if haskey(bucket, fitted_key)
            delete!(bucket[fitted_key], value)
            # If the set becomes empty, remove the key from the dictionary
            if isempty(bucket[fitted_key])
                delete!(bucket, fitted_key)
            end
        end
    end
    return map
end

Base.haskey(map::NNBucketMap{K,V,F1,F2}, key::K) where {K,V,F1,F2} = haskey(map.bucket_layers[1], key)
Base.keys(map::NNBucketMap{K,V,F1,F2}) where {K,V,F1,F2} = keys(map.bucket_layers[1])
Base.values(map::NNBucketMap{K,V,F1,F2}) where {K,V,F1,F2} = values(map.bucket_layers[1]) # This returns some garbage at the moment
Base.collect(map::NNBucketMap{K,V,F1,F2}) where {K,V,F1,F2} = collect(map.bucket_layers[1])
Base.vcat(map::NNBucketMap{K,V,F1,F2}) where {K,V,F1,F2} = vcat(map.bucket_layers[1])

function Base.show(io::IO, map::NNBucketMap)
    for (i, bucket) in enumerate(map.bucket_layers)
        println(io, "Layer $i (bucket-size=$(map.bucket_sizes[i])):")
        for (k, vals) in bucket
            println(io, "  $k => $(collect(vals))")
        end
    end
end

export NNBucketMap, nn
end
