include("nearest_neighbor_bucket_map.jl")
using .NNStructs

using Colors
using JSON3

to_color(c::String)::RGB = parse(RGB24, "$c")
vec(c::RGB) = [c.r, c.g, c.b]
vec(c::Lab)::Vector = [c.l, c.a, c.b]

ΔE76(c1::RGB, c2::RGB) = (vec(convert(Lab,c1)) .- vec(convert(Lab,c2))).^2 |> sum |> sqrt
fit_key(c::RGB, n::Int) = RGB(
        round((c.r*255)/n), 
        round((c.g*255)/n), 
        round((c.b*255)/n)
    )

# From https://github.com/meodai/color-names
const COLORS = JSON3.read(read("colornames.json", String)) # [{"name": "<colorname>", "hex": "<24_bit_hexcode_str>"}, ...]
const COLOR2NAME = Dict(c.hex |> to_color => c.name for c in COLORS)
const NAME2COLOR = Dict(c.name => c.hex |> to_color for c in COLORS)

map = NNBucketMap{RGB, String}(255, fit_key, ΔE76)

for (c,h) in COLOR2NAME
    map[c] = h
end

function getClosestNameLinear(c::RGB)
    min_dist = Inf
    closest_name = nothing
    for (cc, h) in COLOR2NAME
        dist = ΔE76(c, cc)
        if dist < min_dist
            min_dist = dist
            closest_name = h
        end
    end
    return closest_name
end

using BenchmarkTools

c = colorant"RGB(150, 5, 80)"

@benchmark color = nn(map, c) |> first
@benchmark color2 = getClosestNameLinear(c)

NAME2COLOR[color]
NAME2COLOR[color2] |> vec |> x-> x.*255