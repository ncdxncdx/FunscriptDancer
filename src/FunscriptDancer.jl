module FunscriptDancer

using Reactive, JSON, Gtk, CairoMakie, DataFrames

struct Parameters
    start_time::Int
    end_time::Int
    energy_multiplier::Real
end

include("AudioAnalysis.jl")
include("Actions.jl")
include("plotting.jl")

struct Signals
    audio_data::Signal{AudioData}
    parameters::Signal{Parameters}
    actions::Signal{Actions}
    load_status::Signal{LoadStatus}
    heatmap::Signal{Figure}
end
function create_signals()
    audio_data = Signal(AudioData(DataFrame(), "", 0))
    parameters = Signal(Parameters(0, 0, 1))
    actions = Signal(Vector{Action}())
    load_status = Signal(LoadStatus("Ready", 0))
    heatmap = Signal(Figure())
    Signals(audio_data, parameters, actions, load_status, heatmap)
end

function open_file(filename::AbstractString, signals::Signals)
    println("Opening $filename")
    audio_data = signals.audio_data
    load_status = signals.load_status
    try
        push!(audio_data, load_audio_data(filename, load_status))
    catch e
        push!(load_status, LoadStatus("Error: $e", 0))
    end
end

function connect_ui(builder::GtkBuilder, signals::Signals)
    parameters_s = signals.parameters
    actions_s = signals.actions
    audio_data_s = signals.audio_data
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
        ctx = getgc(widget)
        width = Gtk.width(ctx)
        function x_to_millis(x)::Int
            duration = value(audio_data_s).duration
            round(Int,x * duration / width)
        end
        
        old_parameters = value(parameters_s)
        
        new_paramters = if event.x < width /2 
            Parameters(x_to_millis(event.x), old_parameters.end_time, old_parameters.energy_multiplier)
        else
            Parameters(old_parameters.start_time, x_to_millis(event.x), old_parameters.energy_multiplier)
        end
        push!(parameters_s, new_paramters)
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
            file_name = save_dialog("Save Funscript as...", builder["appwindow"],["*.funscript"])

            if !isempty(file_name)
                save_funscript(file_name, value(audio_data_s), value(actions_s))
            end
        end
    end

    signal_connect(builder["export.heatmap.button"], "clicked") do _
        actions = value(actions_s)
        if !isempty(actions)
            file_name = save_dialog("Save Heatmap as...", builder["appwindow"],["*.png"])

            if !isempty(file_name)
                CairoMakie.save(file_name, value(heatmap_s))
            end
        end
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

    on(audio_data_s) do data
        parameters = value(parameters_s)
        if (data.duration != 0)
            h = Gtk.height(audio_canvas)
            w = Gtk.width(audio_canvas)
            figure = draw_audio(data, parameters, w, h)
            drawonto!(audio_canvas, figure)
            show(audio_canvas)
            push!(actions_s, create_actions(data, value(parameters)))
        end
        nothing
    end

    on(parameters_s) do parms
        show(audio_canvas)
        audio_data = value(audio_data_s)
        if (audio_data.duration != 0)
            push!(actions_s, create_actions(audio_data, parms))
        end
        nothing
    end

    on(actions_s) do acts
        if (!isempty(acts))
            h = Gtk.height(funscript_canvas)
            w = Gtk.width(funscript_canvas)
            figure = draw_funscript(acts, value(audio_data_s), w, h)
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