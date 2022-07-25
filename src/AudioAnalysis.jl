using FFMPEG
using CSV
using Observables

struct AudioData
    pitch::Vector{Float64}
    energy::Vector{Float64}
    at::Vector{Int64}
    name::String
    duration::Int64
end

function transform_file(path, name, transform)
    transform_name = string(name, "_", replace(transform, ":" => "_"), ".csv")
    joinpath(path, transform_name)
end

function base_name(path)
    (_, filename) = splitdir(path)
    (base, _) = splitext(filename)
    base
end

function analyze(video_file::String, load_status::Channel{String})::AudioData
    name = base_name(video_file)
    tmp_path = "tmp"
    audio_file = joinpath(tmp_path, string(name, ".wav"))
    beat_transform = "vamp:vamp-aubio:aubiotempo:beats"
    energy_transform = "vamp:bbc-vamp-plugins:bbc-energy:rmsenergy"
    pitch_transform = "vamp:vamp-aubio:aubiopitch:frequency"

    beat_file = transform_file(tmp_path, name, beat_transform)
    energy_file = transform_file(tmp_path, name, energy_transform)
    pitch_file = transform_file(tmp_path, name, pitch_transform)

    mkpath(tmp_path)

    total_duration = begin
        output = FFMPEG.exe("-i", video_file, "-show_entries", "format=duration", "-v", "quiet", "-of", "csv=p=0", command=FFMPEG.ffprobe, collect=true)
        try
            duration_seconds = parse(Float32, output[1])
            round(Int, duration_seconds * 1000)
        catch
            throw("Cannot read file - is it a media file?")
        end
    end
    put!(load_status,"Media duration: $total_duration")

    if !(isfile(energy_file) && isfile(pitch_file))
        ffmpeg_exe("-i", video_file, "-vn", audio_file)
        put!(load_status,"Extracted audio")
        run(`sonic-annotator -d "$beat_transform" -w csv --csv-force "$audio_file"`)
        put!(load_status,"Computed beats")
        run(`sonic-annotator -d "$energy_transform" -S sum --summary-only --segments-from "$beat_file"  -w csv --csv-force "$audio_file"`)
        put!(load_status,"Computed RMS energy")
        run(`sonic-annotator -d "$pitch_transform" -S mean --summary-only --segments-from "$beat_file"  -w csv --csv-force "$audio_file"`)
        put!(load_status,"Computed pitch")
    end

    rm(audio_file, force=true)
    rm(beat_file, force=true)

    headers = [:start_time, :duration, :metric, :value, :metric_description]
    energy = CSV.File(energy_file, header=headers, select=[:value, :start_time, :duration])
    pitch = CSV.File(pitch_file, header=headers, select=[:value])
    end_time = map(energy[:start_time], energy[:duration]) do time, duration
        round(Int, (time + duration) * 1000)
    end
    put!(load_status,"Loaded audio analysis")

    return AudioData(pitch[:value], energy[:value], end_time, name, total_duration)
end