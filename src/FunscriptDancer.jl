module FunscriptDancer

using Reactive, JSON, Gtk, CairoMakie, DataFrames

struct Parameters
    start_time::Int
    end_time::Int
    energy_multiplier::Real
    pitch_range::Real
end

include("AudioAnalysis.jl")
include("Actions.jl")
include("Plotting.jl")

struct Signals
    audio_data_parameters::Signal{Pair{AudioData,Parameters}}
    actions::Signal{Actions}
    load_status::Signal{LoadStatus}
    heatmap::Signal{Figure}
end
function create_signals()
    audio_data_parameters = Signal(Pair(AudioData(DataFrame(), "", 0), Parameters(0, 0, 1, 50)))
    actions = Signal(Vector{Action}())
    load_status = Signal(LoadStatus("Ready", 0))
    heatmap = Signal(Figure())
    Signals(audio_data_parameters, actions, load_status, heatmap)
end

function open_file(filename::AbstractString, signals::Signals)
    println("Opening $filename")
    adp_s = signals.audio_data_parameters
    load_status_s = signals.load_status
    try
        push!(adp_s, Pair(load_audio_data(filename, load_status_s), value(adp_s).second))
    catch e
        push!(load_status_s, LoadStatus("Error: $e", 0))
    end
end

function redraw_audio_data(audio_canvas::GtkCanvas, data::AudioData, parameters::Parameters)
    if (data.duration != 0)
        h = Gtk.height(audio_canvas)
        w = Gtk.width(audio_canvas)
        figure = draw_audio(data, parameters, w, h)
        drawonto!(audio_canvas, figure)
        show(audio_canvas)
    end
end

# It doesn't seem to be possible to get a plot width
# so assume a margin and use that to map position on widget to position on plot
function x_to_millis(x, duration, width)::Int
    margin = 16
    round(Int, (x - margin) * duration / (width - margin * 2))
end

function connect_ui(builder::GtkBuilder, signals::Signals)
    actions_s = signals.actions
    audio_data_parameters_s = signals.audio_data_parameters
    load_status_s = signals.load_status
    heatmap_s = signals.heatmap

    function on(func, signal)
        preserve(map(func, signal))
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
        audio_data = value(audio_data_parameters_s).first
        ctx = getgc(widget)
        width = Gtk.width(ctx)

        old_parameters = value(audio_data_parameters_s).second
        millis = x_to_millis(event.x, audio_data.duration, width)
        println("Key press event: $(event.x), millis: $millis, width: $width, duration: $(audio_data.duration)")
        new_paramters = if event.x < width / 2
            Parameters(millis, old_parameters.end_time, old_parameters.energy_multiplier, old_parameters.pitch_range)
        else
            Parameters(old_parameters.start_time, millis, old_parameters.energy_multiplier, old_parameters.pitch_range)
        end

        push!(audio_data_parameters_s, Pair(audio_data, new_paramters))
    end

    signal_connect(builder["open.button"], "file-set") do widget
        val = Gtk.GAccessor.filename(Gtk.GtkFileChooser(widget))
        if val != C_NULL
            open_file(Gtk.bytestring(val), signals)
        end
    end

    signal_connect(builder["export.funscript.button"], "clicked") do _
        actions = value(actions_s)
        if !isempty(actions)
            file_name = save_dialog("Save Funscript as...", builder["appwindow"], ["*.funscript"])

            if !isempty(file_name)
                save_funscript(file_name, value(audio_data_parameters_s).first, value(actions_s))
            end
        end
    end

    signal_connect(builder["export.heatmap.button"], "clicked") do _
        actions = value(actions_s)
        if !isempty(actions)
            file_name = save_dialog("Save Heatmap as...", builder["appwindow"], ["*.png"])

            if !isempty(file_name)
                CairoMakie.save(file_name, value(heatmap_s))
            end
        end
    end

    signal_connect(builder["funscript.energy.adjustment"], "value-changed") do widget
        val = get_gtk_property(widget, :value, Float64)
        old_parameters = value(audio_data_parameters_s).second
        new_parameters = Parameters(old_parameters.start_time, old_parameters.end_time, val, old_parameters.pitch_range)
        audio_data = value(audio_data_parameters_s).first
        push!(audio_data_parameters_s, Pair(audio_data, new_parameters))
    end

    signal_connect(builder["funscript.pitch.adjustment"], "value-changed") do widget
        val = get_gtk_property(widget, :value, Float64)
        old_parameters = value(audio_data_parameters_s).second
        new_parameters = Parameters(old_parameters.start_time, old_parameters.end_time, old_parameters.energy_multiplier, val)
        audio_data = value(audio_data_parameters_s).first
        push!(audio_data_parameters_s, Pair(audio_data, new_parameters))
    end

    on(load_status_s) do status
        status_text = builder["open.status"]
        progress_bar = builder["open.progress"]
        set_gtk_property!(status_text, :text, status.msg)
        set_gtk_property!(progress_bar, :fraction, status.position)
        println(status)
        sleep(1) # Yield so the GUI updates, yes this is rubbish
        nothing
    end

    on(audio_data_parameters_s) do adp
        audio_data::AudioData = adp.first
        parameters::Parameters = adp.second
        redraw_audio_data(audio_canvas, audio_data, parameters)
        if (audio_data.duration != 0)
            push!(actions_s, create_actions(audio_data, parameters))
        end
        nothing
    end

    on(actions_s) do acts
        if (!isempty(acts))
            h = Gtk.height(funscript_canvas)
            w = Gtk.width(funscript_canvas)
            figure = draw_funscript(acts, value(audio_data_parameters_s).first, w, h)
            drawonto!(funscript_canvas, figure)
            show(funscript_canvas)
            push!(heatmap_s, figure)
        end
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