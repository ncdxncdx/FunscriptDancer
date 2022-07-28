using FunscriptDancer
import FunscriptDancer: AudioDatum, AudioData, Actions, Action, Parameters
import FunscriptDancer: transform_file, base_name, calculate_offsets, int_at, peak, is_in_time_range, default_normalised_pitch_to_offset, create_actions, calculate_intensity
using Test

@testset "FunscriptDancer.jl" begin end

@testset "AudioAnalysis.jl" begin
    @test transform_file("path", "name", "vamp:vamp-aubio:aubiotempo:beats") == "path/name_vamp_vamp-aubio_aubiotempo_beats.csv"
    @test base_name("foo/bar/baz.mp4") == "baz"
    @test AudioDatum(Vector{Float64}()) == AudioDatum(Vector{Float64}(), 0.0, 0.0)
    @test AudioData([1000.0, 10000.0], [4.0, 5.0], [1, 2, 3], "foobar", 4) == AudioData(
        AudioDatum([3.0, 4.0], 4.0, 3.0),
        AudioDatum([4.0, 5.0], 5.0, 4.0),
        AudioDatum([1, 2, 3], 3, 1),
        "foobar",
        4
    )
end

@testset "Actions.jl" begin
    @test calculate_offsets(AudioDatum([10, 20, 30, 20, 10]), default_normalised_pitch_to_offset) == [0, 50, 100, 50, 0]
    @test int_at(110, 20, 90, 10, 100) == 15
    @test int_at(120, 40, 90, 10, 100) == 20
    @test int_at(-20, 40, 10, 10, 0) == 20
    @test peak(110, 50, 90, 40) == [Action(100, 45), Action(90, 50)]
    @test is_in_time_range(0, 0, 0) == true
    @test is_in_time_range(100, 0, 0) == true
    @test is_in_time_range(0, 1000, 0) == false
    @test is_in_time_range(2000, 0, 1000) == false
end

@testset "Actions.jl - create actions" begin
    @test create_actions(AudioData(
            [1000.0, 2000.0, 5000.0, 3000.0],
            [4.0, 5.0, 3.0, 4.0, 2.0],
            [100, 200, 300, 600, 700],
            "foobar",
            4
        ),
        Parameters(0, 0, 1)
    ) == [
        Action(50, 0),
        Action(33, 50),
        Action(0, 75),
        Action(33, 100),
        Action(0, 113),
        Action(93, 150),
        Action(0, 196),
        Action(7, 200),
        Action(0, 203),
        Action(100, 243),
        Action(83, 250),
        Action(100, 275),
        Action(83, 300),
        Action(100, 439),
        Action(99, 450),
        Action(100, 453),
        Action(35, 600)
    ]
end

@testset "Actions.jl - calculate intensity" begin
    actions = [
        Action(50, 0),
        Action(33, 50),
        Action(0, 75),
        Action(33, 100),
        Action(0, 113),
        Action(93, 150),
        Action(0, 196),
        Action(7, 200),
        Action(0, 203),
        Action(100, 243),
        Action(83, 250),
        Action(100, 275),
        Action(83, 300),
        Action(100, 439),
        Action(99, 450),
        Action(100, 453),
        Action(35, 600)
    ]
    @test calculate_intensity(actions) == [
        0.0,
        0.5666666666666667,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        0.2038369304556355,
        0.15151515151515152,
        0.5555555555555555,
        0.7369614512471656
    ]
end
