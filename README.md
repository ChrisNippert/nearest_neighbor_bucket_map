# Nearest Neighbor Bucket Map
This is a data structure designed to get a near neighbor given some key that doesn't exist in the structure. It utilizes a logarithmically sized stack of bucket maps.

## Use Case
The use case that I had when making this structure is an easy and time-efficient way to get a nearest neighbor of some integer or vector of integers. Essentially a nearest neighbor structure.

## Insertion
The following visual example is generating random keys from 0-255 and they resolve to grayscale values between 0-255.

![Visual insertion](nn_insertion.gif)

Insertion climbs up the bucket layers, adding itself to the buckets and creating a new set in the bucket if there isn't already one. This means that - assuming average map operations and insertion into a set as O(1) - the average time complexity of an insertion is `O(log(s))` where `s` would be equivalent to the size of the key space. This structure could be dynamically sized in the future by checking the size of each key upon insertion and adjusting it accordingly.

## Deletion
Deletion is similar to insertion as it climbs the bucket layers, removing itself from the sets and removing the keys and set objects if the set is empty. This would also be on average `O(log(s))` similarly to insertion.

## Nearest Neighbor Search
Pseudocode
```pseudocode
Begin at the lowest bucket layer index (finest accuracy)

Check the current layer and check if the key exists.
If true
    return the value associated (set of values pointing to the bucket)
else
    Increment the bucket layer index to search
    fit the key to the new bucket size

repeat until found or no more buckets
```

This search takes a worst case of `O(log(s))` like most of the other operations on this structure. In the future this could be expanded such that we check buckets to the left and right of our found bucket to see which values are actually the closest. In this case, the average case would be something like `O(log(s) + 3b)` where `b` is the size of the bucket at the layer you reached. The worst case would be `O(log(s) + n)` for our traversal up the bucket layers into the very top bucket containing every data point (n). With sparse datasets this may not be ideal, however with increasing density, this time complexity lowers exponentially.

## Empirical results
Here I make a use case of finding the nearest named color from some subset of all colors, given any hex color.

Given this code section of [results.jl](results.jl):
```julia
@benchmark color = nn(map, c) |> first
@benchmark color2 = getClosestNameLinear(c)
```
We find that for this specific hex color looking in a list of 17,000 other colors, the NNBucketMap has more than an order of magnitude better performance than linear.
```
BenchmarkTools.Trial: 10000 samples with 930 evaluations per sample.
 Range (min … max):  108.551 ns …  24.362 μs  ┊ GC (min … max): 0.00% … 99.42%
 Time  (median):     111.540 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   117.462 ns ± 261.609 ns  ┊ GC (mean ± σ):  3.70% ±  2.18%

     ▆█▃                                                         
  ▂▃████▆▄▄▄▄▄▃▃▃▂▂▂▂▂▂▁▁▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁▁▁▂▁▂▁▂▂▁▂▁▁▁▁▂▁▁▁▂▂▁▂ ▃
  109 ns           Histogram: frequency by time          147 ns <

 Memory estimate: 48 bytes, allocs estimate: 2.

BenchmarkTools.Trial: 1555 samples with 1 evaluation per sample.
 Range (min … max):  2.630 ms … 23.364 ms  ┊ GC (min … max):  0.00% … 87.04%
 Time  (median):     2.718 ms              ┊ GC (median):     0.00%
 Time  (mean ± σ):   3.213 ms ±  1.405 ms  ┊ GC (mean ± σ):  14.58% ± 18.89%

  █▇                                                          
  ██▆▇▃▂▂▃▂▂▂▁▁▁▁▁▁▁▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▂▃▃▃▃▃▂ ▂
  2.63 ms        Histogram: frequency by time        6.58 ms <

 Memory estimate: 6.87 MiB, allocs estimate: 179964.
```

# Notes
Using named colors from This repo: https://github.com/meodai/color-names
