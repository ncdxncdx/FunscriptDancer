using FunscriptDancer, Test
import FunscriptDancer: AudioData, Actions, Action, Parameters
import FunscriptDancer: transform_file, base_name, calculate_offsets, int_at, peak, is_in_time_range, default_normalised_pitch_to_offset, create_actions, calculate_speed

@testset "FunscriptDancer.jl" begin end

@testset "AudioAnalysis.jl" begin
    @test transform_file("path", "name", "vamp:vamp-aubio:aubiotempo:beats") == "path/name_vamp_vamp-aubio_aubiotempo_beats.csv"
    @test base_name("foo/bar/baz.mp4") == "baz"
end

@testset "Actions.jl" begin
    @test calculate_offsets([10, 20, 30, 20, 10], default_normalised_pitch_to_offset) == [0, 50, 100, 50, 0]
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
        Action(0, 115),
        Action(75, 150),
        Action(0, 188),
        Action(25, 200),
        Action(0, 209),
        Action(100, 244),
        Action(83, 250),
        Action(100, 275),
        Action(83, 300),
        Action(83, 450),
        Action(17, 600)
    ]
end

@testset "Plotting.jl" begin
    @test calculate_speed(Action(0, 0), Action(100, 200)) == 500
end