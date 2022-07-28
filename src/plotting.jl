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
    axis = Axis(figure[1, 1], xlabel="s", xticks=MultiplesTicks(num_ticks, 1000, ""), backgroundcolor=:black)
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

function calculate_intensity(actions::Actions)
    function calculate_intensity(first::Action, second::Action)
        if (first.at == second.at)
            0
        else
            speed = 1000 * (abs(second.pos - first.pos) / abs(second.at - first.at))
            intensity = speed / 600
            capped_intensity = minimum([1, intensity])
            capped_intensity
        end
    end

    intensities = Vector{Float64}()
    previous = Action(0, 0)
    for action in actions
        push!(intensities, calculate_intensity(previous, action))
        previous = action
    end
    intensities
end

function draw_funscript(actions::Actions, audio_data::AudioData, w, h)
    (axis, figure) = create_axis(audio_data, w, h)
    ylims!(axis, 0, 100)

    colors = calculate_intensity(actions)

    lines!(axis, map(a -> a.at, actions), map(a -> a.pos, actions), colormap=:neon, color=colors)

    figure
end

