using FunscriptDancer
using Test

@testset "FunscriptDancer.jl" begin end

@testset "AudioAnalysis.jl" begin
    @test FunscriptDancer.transform_file("path", "name", "vamp:vamp-aubio:aubiotempo:beats") == "path/name_vamp_vamp-aubio_aubiotempo_beats.csv"
    @test FunscriptDancer.base_name("foo/bar/baz.mp4") == "baz"
end

@testset "Actions.jl" begin
    @test FunscriptDancer.calculate_offsets([10, 20, 30, 20, 10], FunscriptDancer.default_normalised_pitch_to_offset) == [0, 63, 100, 63, 0]
    @test FunscriptDancer.int_at(110, 20, 90, 10, 100) == 15
    @test FunscriptDancer.int_at(120, 40, 90, 10, 100) == 20
    @test FunscriptDancer.int_at(-20, 40, 10, 10, 0) == 20
    @test FunscriptDancer.peak(110, 50, 90, 40) == [Dict("pos" => 100, "at" => 45), Dict("pos" => 90, "at" => 50)]
    @test FunscriptDancer.create_is_in_time_range(0, 0)(0) == true
    @test FunscriptDancer.create_is_in_time_range(0, 0)(100) == true
    @test FunscriptDancer.create_is_in_time_range(1000, 0)(0) == false
    @test FunscriptDancer.create_is_in_time_range(0, 1000)(2000) == false
end
