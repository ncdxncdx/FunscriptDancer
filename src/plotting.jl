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

function create_axis(audio_data::AudioData, w, h)
    figure = Figure(resolution=(w, h))
    num_ticks = round(Int, audio_data.duration / 1000 / 60 * 4)
    axis = Axis(figure[1, 1], xlabel="s", xticks=MultiplesTicks(num_ticks, 1000, ""))
    xlims!(axis, 0, audio_data.duration)
    (axis, figure)
end

function draw_audio(audio_data::AudioData, w, h)
    (axis, figure) = create_axis(audio_data, w, h)
    ylims!(
        axis,
        minimum([audio_data.pitch.minimum, audio_data.energy.maximum]),
        maximum([audio_data.pitch.maximum, audio_data.energy.maximum])
    )

    stairs!(axis, audio_data.at.values, audio_data.energy.values)

    stairs!(axis, audio_data.at.values, audio_data.pitch.values)

    figure
end

function draw_funscript(actions::Actions, audio_data::AudioData, w, h)
    (axis, figure) = create_axis(audio_data, w, h)
    ylims!(axis, 0, 100)

    lines!(axis, map(a -> a.at, actions), map(a -> a.pos, actions))

    figure
end
