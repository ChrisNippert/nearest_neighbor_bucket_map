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

using Plots

struct BucketHighlight
    layer::Int
    bucket_key::Int
    color::Symbol
    alpha::Float64
end

const VIS_ACTIVE = Ref(false)
const VIS_FRAMES = IdDict()

function record_frame(map, highlights)
    frames = get!(VIS_FRAMES, map, BucketHighlight[][])
    push!(frames, highlights)
end

macro step(bucket_expr, args...)
    # defaults
    color = :yellow
    alpha = 0.35

    # parse extra args
    for arg in args
        if arg.head == :(=)
            lhs, rhs = arg.args
            if lhs == :color
                color = rhs
            elseif lhs == :alpha
                alpha = rhs
            else
                error("Unknown keyword $(lhs) in @step")
            end
        else
            error("Malformed @step argument: $arg")
        end
    end

    return esc(quote
        if VIS_ACTIVE[]
            _bucket = $(bucket_expr)
            _map = map
            _layer = findfirst(b -> b === _bucket, _map.bucket_layers)

            if _layer === nothing
                error("@step: bucket not found in map.bucket_layers")
            end

            highs = BucketHighlight[]
            for (bk, _) in _bucket
                push!(highs, BucketHighlight(_layer, bk, $color, $alpha))
            end

            @info "Recording frame" _layer highs
            record_frame(_map, highs)
        end
    end)
end

macro visualize(expr)
    return esc(quote
        NNStructs.VIS_ACTIVE[] = true
        local _result = $(expr)
        _result
    end)
end

function resize_needed(map::NNBucketMap{K,V,F1,F2}, key::K) where {K,V,F1,F2}
    max(abs.(key)) >= map.max_size
end

function resize(map::NNBucketMap{K,V,F1, F2}) where {K,V,F1,F2}
    # Increase the size of the map
    map.max_size *= 2
end

function Base.setindex!(map::NNBucketMap{K,V,F1,F2}, value, key) where {K,V,F1,F2}
    # return unedited of has key
    haskey(map, key) && return map # Probably should update the key's value instead but :shrug:

    # Iterate through buckets
    for (i,bucket) in enumerate(map.bucket_layers)
        fitted_key = map.fit_key(key, map.bucket_sizes[i])
        # Add a new set if it doesn't exist
        if !haskey(bucket, fitted_key)
            bucket[fitted_key] = Set{V}()  # initialize the Set if not exists
            @step bucket color=:lightgrey
        end
    end

    # Iterate through buckets and push to set corresponding to the bucketed value
    for (i,bucket) in enumerate(map.bucket_layers)
        @step bucket color=:green
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
            @step bucket color=:green
            break
        end
        @step bucket color=:yellow
    end

    return candidates
end

function Base.delete!(map::NNBucketMap{K,V,F1,F2}, key::K) where {K,V,F1,F2}
    value = map[key]
    if value === nothing
        return map
    end

    println("Value: $value")

    # Iterate through buckets and delete the value from each bucket's set
    for (i,bucket) in enumerate(map.bucket_layers)
        fitted_key = map.fit_key(key, map.bucket_sizes[i])
        @step bucket color=:yellow
        if haskey(bucket, fitted_key)
            println("Found key for $key in bucket at layer $i. Current set in this bucket:\n$(bucket[fitted_key])")
            @step bucket color=:red
            delete!(bucket[fitted_key], value)
            println("Post delete bucket:\n$(bucket[fitted_key])")
            # If the set becomes empty, remove the key from the dictionary
            if isempty(bucket[fitted_key])
                println("Set empty, removing key")
                @step bucket color=:red
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
 

### VISUALIZATION
bucket_repr(vals::Set) = isempty(vals) ? missing : first(vals)
bucket_repr(_) = missing

function render_frames(map)
    frames = get!(VIS_FRAMES, map, BucketHighlight[][])
    return [render_frame(map; highlights=h) for h in frames]
end
function render_frame(map; highlights=BucketHighlight[], title="BucketMap")
    plt = plot(; legend=false, xlab="Key", ylab="Layer",
               title=title, size=(900,600))

    # 1. Draw all buckets (always visible)
    for (layer_idx, bucket) in enumerate(map.bucket_layers)
        cap = map.bucket_sizes[layer_idx]

        for (bucket_key, vals) in bucket
            x1 = bucket_key * cap
            x2 = x1 + cap
            y1 = layer_idx - 1
            y2 = layer_idx

            # base bucket
            plot!(plt,
                  [x1,x2,x2,x1], [y1,y1,y2,y2],
                  seriestype=:shape,
                  linecolor=:black,
                  fillcolor=:lightgrey,
                  fillalpha=0.3)

            rep = bucket_repr(vals)
            if rep !== missing
                annotate!(plt,
                          (x1+x2)/2,
                          (y1+y2)/2,
                          text(string(rep), 8))
            end
        end
    end

    # 2. Overlay highlights
    for h in highlights
        cap = map.bucket_sizes[h.layer]
        x1 = h.bucket_key * cap
        x2 = x1 + cap
        y1 = h.layer - 1
        y2 = h.layer

        plot!(plt,
              [x1,x2,x2,x1], [y1,y1,y2,y2],
              seriestype=:shape,
              fillcolor=h.color,
              fillalpha=h.alpha,
              linecolor=:black,
              linewidth=2)
    end

    return plt
end

function nn_frames(map, key)
    frames = BucketHighlight[][]

    for (layer_idx, bucket) in enumerate(map.bucket_layers)
        cap = map.bucket_sizes[layer_idx]
        fitted_key = map.fit_key(key, cap)

        h = BucketHighlight(layer_idx, fitted_key,
                            :yellow, 0.35)

        push!(frames, [h])

        if haskey(bucket, fitted_key)
            # found: final highlight in green
            frames[end] = [BucketHighlight(layer_idx, fitted_key,
                                           :green, 0.45)]
            break
        end
    end

    return frames
end

function clear_visualization()
    empty!(VIS_FRAMES)
    VIS_ACTIVE[] = false
end

function save_gif(map; filename="nn.gif", fps=1)
    frames = get!(VIS_FRAMES, map, BucketHighlight[][])

    anim = @animate for (j, h) in enumerate(frames)
        render_frame(map; highlights=h, title="Frame $j")
    end

    gif(anim, filename, fps=fps)
end


export NNBucketMap, nn, save_gif, @visualize
end

using .NNStructs
using Test

fit_key(k::Int, n::Int) = fld(k, n)
delta(k1::Int, k2::Int) = k2 - k1

m = NNBucketMap{Int, Int}(255, fit_key, delta)

m[-31] = 3
m[-121] = 4
@visualize m[1] = 1
save_gif(m, fps=1)
clear_visualization()
m[2] = 1
m[244] = 23
m[144] = 212

@visualize nn(m, 243)
save_gif(m; "nn.gif", fps=1)
clear_visualization()
@test nn(m, 243) |> collect == [23] # should resolve to 23 as closest
@visualize delete!(m, 244) # removes key
save_gif(m; "deletion.gif", fps=1)
clear_visualization()
@test nn(m, 243) |> collect == [212] # should resolve to 212

@test m[2] == 1
@test m[243] === nothing # doesn't exist
@test m[144] == 212

@test m[-31] == 3 # I guess it works somewhat for negative numbers?
nn(m, -1)

@show m

@test keys(m) == Set([-121, -31, 1, 2, 144])
@test collect(m) == [ 2 => Set([1]), -31 => Set([3]), -121 => Set([4]),  144 => Set([212]),   1 => Set([1]) ]


using Plots
function gray_vis()
    anim = Animation()

    g = parse(Gray, "#123456")


    fit_key_int(k::Gray, n::Int) = Gray(fld(k.val*255, n))
    delta(k1::Gray, k2::Gray) = abs(k2.val - k1.val)

    m = TelescopingBucketMap{Gray,String}(255, fit_key_int, delta)

    for i in 1:20
        color = "#$(join(rand(0:9, 6)))"
        println("Adding Color $color")
        key = parse(Gray, color)
        value = "$color"
        m[key] = value

        plot_telescoping(m)  # your plot function
        frame(anim)          # save current state
    end

    m

    gif(anim, "telescoping.gif", fps=2)
end