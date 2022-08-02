module FunscriptDancer

using Reactive, JSON, Gtk, CairoMakie, DataFrames

struct TimeParameters
    start_time::Int
    end_time::Int
end

struct TransformParameters
    energy_multiplier::Real
    pitch_range::Real
end

include("AudioAnalysis.jl")
include("Actions.jl")
include("Plotting.jl")

struct AudioDataTimeParameters
    audio_data::AudioData
    time_parameters::TimeParameters
end

struct Signals
    audio_data::Signal{AudioDataTimeParameters}
    transform_parameters::Signal{TransformParameters}
    actions::Signal{Actions}
    load_status::Signal{LoadStatus}
    heatmap::Signal{Figure}
end

const empty_audio_data = AudioData(DataFrame(), "", 0)
const empty_actions = Actions()
const default_time_parameters = TimeParameters(0, 0)
const default_transform_parameters = TransformParameters(1, 50)

function create_signals()
    audio_data = Signal(AudioDataTimeParameters(empty_audio_data, default_time_parameters))
    transform_parameters = Signal(default_transform_parameters)
    actions = Signal(empty_actions)
    load_status = Signal(LoadStatus("Ready", 0))
    heatmap = Signal(Figure())
    Signals(audio_data, transform_parameters, actions, load_status, heatmap)
end

function redraw_audio_data(audio_canvas::GtkCanvas, data::AudioData, parameters::TimeParameters)
    h = Gtk.height(audio_canvas)
    w = Gtk.width(audio_canvas)
    figure = if (data.duration != 0)
        draw_audio(data, parameters, w, h)
    else
        draw_blank(w, h)
    end
    drawonto!(audio_canvas, figure)
    show(audio_canvas)
end

# It doesn't seem to be possible to get a plot width
# so assume a margin and use that to map position on widget to position on plot
function x_to_millis(x, duration, width)::Int
    margin = 16
    round(Int, (x - margin) * duration / (width - margin * 2))
end

function connect_ui(builder::GtkBuilder, signals::Signals)
    function on(func, signal)
        preserve(map(func, droprepeats(signal)))
    end
    function make_canvas(anchor)
        canvas = GtkCanvas()
        box = builder[anchor]
        push!(box, canvas)
        set_gtk_property!(box, :expand, canvas, true)
        canvas
    end

    audio_canvas = make_canvas("audio.view")
    funscript_canvas = make_canvas("funscript.view")

    audio_canvas.mouse.button1press = @guarded (widget, event) -> begin
        ad_tp = value(signals.audio_data)
        audio_data = ad_tp.audio_data
        old_parameters = ad_tp.time_parameters
        ctx = getgc(widget)
        width = Gtk.width(ctx)
        millis = x_to_millis(event.x, audio_data.duration, width)
        new_paramters = if event.x < width / 2
            TimeParameters(millis, old_parameters.end_time)
        else
            TimeParameters(old_parameters.start_time, millis)
        end

        push!(signals.audio_data, AudioDataTimeParameters(audio_data, new_paramters))
    end

    signal_connect(builder["open.button"], "file-set") do widget
        val = Gtk.GAccessor.filename(Gtk.GtkFileChooser(widget))
        if val != C_NULL
            try
                push!(signals.audio_data, AudioDataTimeParameters(load_audio_data(Gtk.bytestring(val), signals.load_status), default_time_parameters))
            catch e
                push!(signals.load_status, LoadStatus("Error: $e", 0))
            end
        end
    end

    signal_connect(builder["export.funscript.button"], "clicked") do _
        actions = value(signals.actions)
        if !isempty(actions)
            file_name = save_dialog("Save Funscript as...", builder["appwindow"], ["*.funscript"])

            if !isempty(file_name)
                save_funscript(file_name, value(signals.audio_data).audio_data, value(signals.actions))
            end
        end
    end

    signal_connect(builder["export.heatmap.button"], "clicked") do _
        actions = value(signals.actions)
        if !isempty(actions)
            file_name = save_dialog("Save Heatmap as...", builder["appwindow"], ["*.png"])

            if !isempty(file_name)
                CairoMakie.save(file_name, value(signals.heatmap))
            end
        end
    end

    signal_connect(builder["funscript.energy.adjustment"], "value-changed") do widget
        val = get_gtk_property(widget, :value, Float64)
        old_parameters = value(signals.transform_parameters)
        new_parameters = TransformParameters(val, old_parameters.pitch_range)
        push!(signals.transform_parameters, new_parameters)
    end

    signal_connect(builder["funscript.pitch.adjustment"], "value-changed") do widget
        val = get_gtk_property(widget, :value, Float64)
        old_parameters = value(signals.transform_parameters)
        new_parameters = TransformParameters(old_parameters.energy_multiplier, val)
        push!(signals.transform_parameters, new_parameters)
    end

    on(signals.load_status) do status
        status_text = builder["open.status"]
        progress_bar = builder["open.progress"]
        set_gtk_property!(status_text, :text, status.msg)
        set_gtk_property!(progress_bar, :fraction, status.position)
        sleep(10) # Yield so the GUI updates, yes this is rubbish
        nothing
    end

    on(signals.transform_parameters) do transform_parameters
        ad_tp = value(signals.audio_data)
        audio_data = ad_tp.audio_data
        time_parameters = ad_tp.time_parameters
        if (audio_data.duration != 0)
            actions = create_actions(audio_data, time_parameters, transform_parameters)
            push!(signals.actions, actions)
        end
        nothing
    end

    on(signals.audio_data) do ad_tp
        audio_data = ad_tp.audio_data
        time_parameters = ad_tp.time_parameters
        redraw_audio_data(audio_canvas, audio_data, time_parameters)
        transform_parameters = value(signals.transform_parameters)
        actions = if (audio_data.duration != 0)
            create_actions(audio_data, time_parameters, transform_parameters)
        else
            empty_actions
        end
        push!(signals.actions, actions)
        nothing
    end

    on(signals.actions) do acts
        h = Gtk.height(funscript_canvas)
        w = Gtk.width(funscript_canvas)
        figure = if (!isempty(acts))
            draw_funscript(acts, value(signals.audio_data).audio_data, w, h)
        else
            draw_blank(w, h)
        end
        drawonto!(funscript_canvas, figure)
        show(funscript_canvas)
        push!(signals.heatmap, figure)
        nothing
    end
end

function save_funscript(funscript_filename::String, audio_data::AudioData, actions::Actions)
    funscript = Dict(
        "metadata" => Dict(
            "creator" => "FunscriptDancer",
            "title" => audio_data.name,
            "description" => "Procedurally generated by FunscriptDancer",
            "duration" => audio_data.duration,
            "license" => "",
            "notes" => "",
            "performers" => (),
            "script_url" => "",
            "tags" => ("music", "audio"),
            "type" => "",
            "video_url" => ""
        ),
        "range" => 100,
        "inverted" => false,
        "version" => 1.0,
        "actions" => actions
    )

    funscript_json = JSON.json(funscript)
    funscript_file = open(funscript_filename, "w+")
    write(funscript_file, funscript_json)
    close(funscript_file)
end

function julia_main()::Cint
    glade_file = joinpath(dirname(@__FILE__), "gtk", "FunscriptDancer.glade")
    builder = GtkBuilder(filename=glade_file)
    app_window = builder["appwindow"]
    show(app_window)
    @async Gtk.gtk_main()
    signals = create_signals()
    connect_ui(builder, signals)
    Gtk.waitforsignal(app_window, :destroy)
    return 0
end
export julia_main

end # module