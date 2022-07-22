using Observables
using JSON
using QML
using Qt5QuickControls_jll

struct Parameters
    start_time
    end_time
    normalised_energy_to_pos
end

const Actions = Vector{Dict{String,Int}}

include("AudioAnalysis.jl")
include("Actions.jl")

audio_data = Observable{Union{Nothing,AudioData}}(nothing)
parameters = Observable{Union{Nothing,Parameters}}(nothing)
actions = Observable{Union{Nothing,Actions}}(nothing)

function main(; multiplier::Real=1, start_time::Real=0, end_time::Real=0)
    parameters[] = Parameters(start_time, end_time, create_default_normalised_energy_to_pos(multiplier))
end

function open_file(uri)
    video_file = String(QString(uri))
    audio_data[] = analyze(video_file)
end

onany(audio_data, parameters) do data, parms
    if (data !== nothing && parms !== nothing)
        actions[] = create_actions(data, parms)
    end
end

on(actions) do acts
    if (acts !== nothing)
        write_funscript(audio_data[], acts)
    end
end

function write_funscript(data::AudioData, actions::Actions, out_path::String="out")
    mkpath(out_path)
    funscript = Dict(
        "metadata" => Dict(
            "creator" => "FunscriptDancer",
            "title" => data.name,
            "description" => "Procedurally generated by FunscriptDancer",
            "duration" => data.duration,
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

    funscript_file = open(joinpath(out_path, string(data.name, ".funscript")), "w")
    write(funscript_file, funscript_json)
    close(funscript_file)
end

@qmlfunction open_file

qml_file = joinpath(dirname(Base.source_path()), "qml", "funscript_dancer.qml")

loadqml(qml_file)
exec()
