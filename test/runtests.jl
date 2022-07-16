using FunscriptDancer
using Test

@testset "audioscripter.jl" begin
    @test audioscripter.transform_file("path","name","vamp:vamp-aubio:aubiotempo:beats") == "path/name_vamp_vamp-aubio_aubiotempo_beats.csv"
    @test audioscripter.base_name("foo/bar/baz.mp4") == "baz"
    @test audioscripter.calculate_offsets([10,20,30,20,10]) == [0,63,100,63,0]
    @test audioscripter.int_at(110, 20, 90, 10, 100) == 15
    @test audioscripter.int_at(120, 40, 90, 10, 100) == 20
    @test audioscripter.int_at(-20, 40, 10, 10, 0) == 20
    @test audioscripter.peak( 110, 50, 90, 40 ) == [("pos" => 100,"at" => 45),("pos" => 90,"at" => 50)]
end
