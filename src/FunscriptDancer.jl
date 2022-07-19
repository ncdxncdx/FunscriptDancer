module FunscriptDancer

include("AudioAnalysis.jl")
using JSON

function transform_file(path, name, transform)
    transform_name = string(name, "_", replace(transform, ":" => "_"), ".csv")
    joinpath(path, transform_name)
end

function base_name(path)
    (_, filename) = splitdir(path)
    (base, _) = splitext(filename)
    base
end

function default_normalised_pitch_to_offset(normalised_pitch)
    range = 100
    normalised_pitch * range + ((100 - range) / 2)
end

function create_normalise_function(values; f=x -> x)
    max = f(maximum(values))
    min = f(minimum(values))
    range = max - min
    value -> (f(value) - min) / range
end

function calculate_offsets(pitch, normalised_pitch_to_offset)
    normalise = create_normalise_function(pitch, f=log)
    function offset(value)
        normalised_pitch = normalise(value)
        offset = normalised_pitch_to_offset(normalised_pitch)
        round(Int, offset)
    end
    map(offset, pitch)
end

function create_default_normanised_energy_to_pos(multiplier)
    normalised_energy -> begin
        normalised_energy * multiplier * 50
    end
end

function create_actions(data::AudioData, normalised_energy_to_pos)
    actions = Vector()
    push!(actions, Dict("pos" => 50, "at" => 0))
    function action(pos, at, last_pos, last_at)
        append!(actions, peak(pos, at, last_pos, last_at))
    end
    offsets = calculate_offsets(data.pitch, default_normalised_pitch_to_offset)
    normalise = create_normalise_function(data.energy)
    last_at = 0
    last_pos = 50
    for (offset, energy, at) in zip(offsets, data.energy, data.at)

        normalised_energy = normalise(energy)

        # up
        int_at2 = round(Int, ((at + last_at) / 2))
        pos = (normalised_energy_to_pos(normalised_energy)) + offset
        action(pos, int_at2, last_pos, last_at)
        last_at = int_at2
        last_pos = pos

        # down
        pos = (normalised_energy_to_pos(normalised_energy) * -1) + offset
        action(pos, at, last_pos, last_at)
        last_at = at
        last_pos = pos
    end
    actions
end

function peak(pos, at, last_pos, last_at)
    actions = Vector()
    function action(pos, at)
        push!(actions, (Dict("pos" => round(Int, pos), "at" => round(Int, at))))
    end
    if (last_pos < 0)
        tmp_at = int_at(pos, at, last_pos, last_at, 0)
        action(0, tmp_at)
    elseif (last_pos > 100)
        tmp_at = int_at(pos, at, last_pos, last_at, 100)
        action(100, tmp_at)
    end

    if (pos > 100)
        tmp_at = int_at(pos, at, last_pos, last_at, 100)
        action(100, tmp_at)
        action(200 - pos, at)
    elseif (pos < 0)
        tmp_at = int_at(pos, at, last_pos, last_at, 0)
        action(0, tmp_at)
        action(-pos, at)
    else
        action(pos, at)
    end
    actions
end

function int_at(pos, at, last_pos, last_at, limit)
    before_ratio = abs(last_pos - limit)
    after_ratio = abs(pos - limit)

    round(Int, (before_ratio * at + after_ratio * last_at) / (after_ratio + before_ratio))
end

function main(video_file::String, multiplier::Float64)
    out_path = "out"
    mkpath(out_path)

    data = analyze(video_file)

    actions = create_actions(data, create_default_normanised_energy_to_pos(multiplier))

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


end # module
