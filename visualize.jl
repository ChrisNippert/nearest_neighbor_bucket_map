include("nearest_neighbor_bucket_map.jl")
using .NNStructs

using Colors

function plot_map(m::NNBucketMap{Gray,String})
    plt = plot(legend=false, size=(1300,800), dpi=150)

    for (layer_idx, bucket) in enumerate(m.bucket_layers)
        cap = m.bucket_sizes[layer_idx]
        y1, y2 = layer_idx - 1, layer_idx

        for (fitted_key, vals) in bucket
            x1 = fitted_key.val * cap
            x2 = x1 + cap

            fillcol = isempty(vals) ? RGB(1,1,1) : parse(Gray, first(vals))

            xs = [x1, x2, x2, x1]
            ys = [y1, y1, y2, y2]

            plot!(
                plt, xs, ys,
                seriestype=:shape,
                fillcolor=fillcol,
                fillalpha=1.0,
                linecolor=:black
            )
        end
    end

    xlims!(plt, 0, m.max_size)
    ylims!(plt, 0, m.layers)
    xlabel!("key space")
    ylabel!("layer")
    title!("NNBucketMap (real buckets only)")

    return plt
end



# Other Test
using Plots
anim = Animation()

g = parse(Gray, "#123456")


fit_key_int(k::Gray, n::Int) = Gray(fld(k.val*255, n))
delta(k1::Gray, k2::Gray) = abs(k2.val - k1.val)

m = NNBucketMap{Gray,String}(255, fit_key_int, delta)

hexchars = ['0':'9'; 'A':'F']

for i in 1:20
    color = "#" * String(rand(hexchars, 6))
    key = parse(Gray, color)
    println("Adding $color => $key")
    value = "$color"
    m[key] = value

    plt = plot_map(m)
    frame(anim, plt)
end

m

gif(anim, "nn_insertion.gif", fps=2)