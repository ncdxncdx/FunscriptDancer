using FunscriptDancer, Test, DataFrames, CairoMakie
import FunscriptDancer: AudioData, Actions, Action, Parameters
import FunscriptDancer: transform_file, base_name, calculate_offsets, int_at, create_peak, is_in_time_range, default_normalised_pitch_to_offset, create_actions, calculate_speed, x_to_millis, create_normalised_pitch_to_offset, calculate_segments

@testset "FunscriptDancer.jl" begin
    @test x_to_millis(16, 10000, 1010) == 0
    @test x_to_millis(994, 10000, 1010) == 10000
    @test x_to_millis(505, 10000, 1010) == 5000
end

@testset "AudioAnalysis.jl" begin
    @test transform_file("path", "name", "vamp:vamp-aubio:aubiotempo:beats") == "path/name_vamp_vamp-aubio_aubiotempo_beats.csv"
    @test base_name("foo/bar/baz.mp4") == "baz"
end

@testset "Actions.jl" begin
    @test calculate_offsets([10, 20, 30, 20, 10], create_normalised_pitch_to_offset(100)) == [0, 50, 100, 50, 0]
    @test int_at(110, 20, 90, 10, 100) == 15
    @test int_at(120, 40, 90, 10, 100) == 20
    @test int_at(-20, 40, 10, 10, 0) == 20
    @test create_peak(20, 50, 90, 40) == [Action(50, 20)]
    @test create_peak(110, 50, 90, 40) == [Action(45, 100), Action(50, 90)]
    @test create_peak(140, 50, 110, 40) == [Action(42,100), Action(42,100), Action(50,60)]
    @test is_in_time_range(0, 0, 0) == true
    @test is_in_time_range(100, 0, 0) == true
    @test is_in_time_range(0, 1000, 0) == false
    @test is_in_time_range(2000, 0, 1000) == false
end

@testset "Actions.jl - create actions" begin
    @test create_actions(AudioData(
            DataFrame(
                pitch=[1000.0, 2000.0, 5000.0, 3000.0, 4000.0],
                energy=[4.0, 5.0, 3.0, 4.0, 2.0],
                at=[100, 200, 300, 600, 700]
            ),
            "foobar",
            4
        ),
        Parameters(0, 0, 1, 100)
    ) == [
        Action(0, 50),
        Action(50, 33),
        Action(75, 0),
        Action(100, 33),
        Action(115, 0),
        Action(150, 75),
        Action(188, 0),
        Action(200, 25),
        Action(209, 0),
        Action(244, 100),
        Action(250, 83),
        Action(275, 100),
        Action(300, 83),
        Action(450, 83),
        Action(600, 17),
        Action(650, 75),
        Action(700, 75)
    ]

end

@testset "Plotting.jl" begin
    @test calculate_speed(Action(0, 0), Action(100, 200)) == 500
    @test calculate_segments([Action(0,50),Action(100,100), Action(150,50), Action(200,75)]) ==
    (
        [(Point2f(0,50),Point2f(100,100)),(Point2f(100,100),Point2f(150,50)),(Point2f(150,50),Point2f(200,75))],
        [500,1000,500]
    )
end