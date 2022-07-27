using CairoMakie
using Gtk

function drawonto!(canvas, figure)
    @guarded draw(canvas) do _
        scene = figure.scene
        resize!(scene, Gtk.width(canvas), Gtk.height(canvas))
        screen = CairoMakie.CairoScreen(scene, Gtk.cairo_surface(canvas), getgc(canvas), nothing)
        CairoMakie.cairo_draw(screen, scene)
    end
end

function draw_audio(audio_data::AudioData, w, h)
    figure = Figure(resolution=(w, h))
    axis = Axis(figure[1, 1], xlabel="ms")
    xlims!(axis, 0, audio_data.duration)
    ylims!(axis, 0, maximum([maximum(audio_data.pitch), maximum(audio_data.energy)]))


    stairs!(axis, audio_data.at, audio_data.energy)

    stairs!(axis, audio_data.at, audio_data.pitch)

    figure
end
