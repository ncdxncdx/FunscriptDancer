using CairoMakie, Gtk

function drawonto!(canvas, figure)
    @guarded draw(canvas) do _
        scene = figure.scene
        resize!(scene, Gtk.width(canvas), Gtk.height(canvas))
        screen = CairoMakie.CairoScreen(scene, Gtk.cairo_surface(canvas), getgc(canvas), nothing)
        CairoMakie.cairo_draw(screen, scene)
    end
end

function draw_blank(w, h)
    axis, figure = create_axis(180_000, w, h)
    text!(axis, 90_000, 5, text="Awaiting data", align=(:center, :top), textsize = 20, color=:white, strokewidth=0.5, strokecolor=:yellow, glowwidth=1.5, glowcolor=:red)
    figure
end

function create_axis(duration, w, h)
    figure = Figure(resolution=(w, h), backgroundcolor=RGBf(0.937, 0.941, 0.945))
    num_ticks = round(Int, duration / 1000 / 60 * 4)
    axis = Axis(
        figure[1, 1],
        xticks=MultiplesTicks(num_ticks, 1000, ""),
        xminorticksvisible=true,
        yticklabelsvisible=false,
        yticksvisible=false,
        backgroundcolor=:black
    )
    xlims!(axis, 0, duration)
    (axis, figure)
end

function draw_audio(audio_data::AudioData, parameters::TimeParameters, w, h)
    pitch = audio_data.frame[!, :pitch]
    energy = audio_data.frame[!, :energy]
    at = audio_data.frame[!, :at]
    axis, figure = create_axis(audio_data.duration, w, h)

    stairs!(axis, at, energy, label="energy")

    stairs!(axis, at, pitch, label="log pitch")

    end_time = if parameters.end_time == 0
        audio_data.duration
    else
        parameters.end_time
    end

    vlines!(axis, [parameters.start_time, end_time], color=:green, linewidth=1, label="crop")

    axislegend(axis)

    figure
end

function calculate_speed(first::Action, second::Action)
    calculate_speed(Point2f(first.pos, first.at), Point2f(second.pos, second.at))
end

function calculate_speed(first::Point2f, second::Point2f)
    1000 * (abs(second[2] - first[2]) / abs(second[1] - first[1]))
end

function draw_funscript(actions::Actions, audio_data::AudioData, w, h)
    axis, figure = create_axis(audio_data.duration, w, h)
    ylims!(axis, 0, 100)

    segments, speeds = calculate_segments(actions)

    linesegments!(
        axis,
        segments,
        colormap=:turbo, colorrange=(0, 600), color=speeds
    )
    figure
end

function calculate_segments(actions::Actions)
    segments = Vector{Tuple{Point2f,Point2f}}()
    for i in 1:length(actions)-1
        push!(segments, (Point2f(actions[i].at, actions[i].pos), Point2f(actions[i+1].at, actions[i+1].pos)))
    end
    speeds = map(segments) do tuple
        calculate_speed(tuple[1], tuple[2])
    end
    (segments, speeds)
end
