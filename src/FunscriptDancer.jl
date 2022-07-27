module FunscriptDancer

using Reactive
using JSON
using Gtk

struct Parameters
    start_time
    end_time
    energy_multiplier
end

include("AudioAnalysis.jl")
include("Actions.jl")

struct Signals
    audio_data::Signal{AudioData}
    parameters::Signal{Parameters}
    actions::Signal{Actions}
    load_status::Signal{LoadStatus}
end
function create_signals()
    audio_data = Signal(AudioData(Vector{Float64}(), Vector{Float64}(), Vector{Int64}(), "", 0))
    parameters = Signal(Parameters(0, 0, 1))
    actions = Signal([Action(0, 0)])
    load_status = Signal(LoadStatus("Ready", 0))
    Signals(audio_data, parameters, actions, load_status)
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

function connect_from_ui_to_app(builder::GtkBuilder, signals::Signals)
    signal_connect(builder["open.button"], "file-set") do widget
        val = Gtk.GAccessor.filename(Gtk.GtkFileChooser(widget))
        if val != C_NULL
            open_file(Gtk.bytestring(val), signals)
        end
    end
end

function connect_from_app_to_ui(builder::GtkBuilder, signals::Signals)
    parameters_s = signals.parameters
    actions_s = signals.actions
    audio_data_s = signals.audio_data
    load_status_s = signals.load_status
    function on(func, signal)
        preserve(map(func, signal))
    end
    on(load_status_s) do status
        status_text = builder["open.status"]
        progress_bar = builder["open.progress"]
        set_gtk_property!(status_text, :text, status.msg)
        set_gtk_property!(progress_bar, :fraction, status.position)
        println(status)
        # update UI
    end

    on(audio_data_s) do data
        parameters = value(parameters_s)
        if (data.duration != 0)
            # update UI
            push!(actions_s, create_actions(data, value(parameters)))
        end
    end

    on(parameters_s) do parms
        audio_data = value(audio_data_s)
        if (audio_data.duration != 0)
            push!(actions_s, create_actions(audio_data, parms))
        end
    end

    on(actions_s) do acts
        if (acts !== nothing)
            #update UI
        end
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
        "actions" => actions[]
    )

    funscript_json = JSON.json(funscript)
    funscript_file = open(funscript_filename, "w+")
    write(funscript_file, funscript_json)
    close(funscript_file)
end

function julia_main()::Cint
    # start UI
    glade_file = joinpath(dirname(@__FILE__), "gtk", "FunscriptDancer.glade")
    builder = GtkBuilder(filename=glade_file)
    app_window = builder["appwindow"]
    show(app_window)
    @async Gtk.gtk_main()
    signals = create_signals()
    connect_from_app_to_ui(builder, signals)
    connect_from_ui_to_app(builder, signals)
    Gtk.waitforsignal(app_window, :destroy)
    return 0
end
export julia_main

end # module