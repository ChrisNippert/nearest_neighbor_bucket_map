include("nearest_neighbor_bucket_map.jl")
using .NNStructs

using Test
fit_key(k::Int, n::Int) = fld(k, n)
delta(k1::Int, k2::Int) = k2 - k1

# Very monolithic test but it does the job for now
function testall()
    m = NNBucketMap{Int, Int}(255, fit_key, delta)

    m[-31] = 3
    @test haskey(m, -31)

    m[-121] = 4
    @test haskey(m, -121)

    m[1] = 1
    m[2] = 1
    m[244] = 23
    m[144] = 212

    nn(m, 243)
    @test nn(m, 243) |> collect == [23] # should resolve to 23 as closest
    delete!(m, 244) # removes key
    @test nn(m, 243) |> collect == [212] # should resolve to 212

    @test m[2] == 1
    @test m[243] === nothing # doesn't exist
    @test m[144] == 212

    @test m[-31] == 3 # I guess it works somewhat for negative numbers?
    nn(m, -1) # looks like it buckets down to -1 and 0 as the biggest buckets

    @test keys(m) == Set([-121, -31, 1, 2, 144])
    @test collect(m) == [ 2 => Set([1]), -31 => Set([3]), -121 => Set([4]),  144 => Set([212]),   1 => Set([1]) ]
end

testall()