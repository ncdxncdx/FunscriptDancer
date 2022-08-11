using FFMPEG, CSV, Reactive, DataFrames

struct AudioData
    frame::DataFrame
    name::String
    folder::String
    duration::Int64
end
Base.:(==)(a::AudioData, b::AudioData) = a.frame == b.frame && a.name == b.name && a.duration == b.duration

struct LoadStatus
    msg::String
    position::Float64
end

function transform_file(path, name, transform)
    transform_name = string(name, "_", replace(transform, ":" => "_"), ".csv")
    joinpath(path, transform_name)
end

function base_name(path)
    dir, filename = splitdir(path)
    base, _ = splitext(filename)
    dir, base
end

function load_audio_data(video_file::String, load_status::Signal{LoadStatus})::AudioData
    function update_load_status!(msg, progress)
        push!(load_status, LoadStatus(msg, progress / 6))
    end
    dir, name = base_name(video_file)
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
    update_load_status!("Media duration: $total_duration", 1)

    if !(isfile(energy_file) && isfile(pitch_file))
        try
            run(`sonic-annotator -v`)
        catch
            throw("Unable to run sonic-annotator. Is it installed and on the command path?")
        end

        vamp_plugins = readlines(`sonic-annotator -l`)                    
        missing_plugins = setdiff(Set([beat_transform, energy_transform, pitch_transform]), vamp_plugins)
        if !isempty(missing_plugins)
            throw("sonic-annotator does not have plugins $missing_plugins available")
        end

        ffmpeg_exe("-i", video_file, "-vn", audio_file)
        update_load_status!("Extracted audio", 2)
        run(`sonic-annotator -d "$beat_transform" -w csv --csv-force "$audio_file"`)
        update_load_status!("Computed beats", 3)
        energy_task = Threads.@spawn(run(`sonic-annotator -d "$energy_transform" -S sum --summary-only --segments-from "$beat_file"  -w csv --csv-force "$audio_file"`))
        pitch_task = Threads.@spawn(run(`sonic-annotator -d "$pitch_transform" -S mean --summary-only --segments-from "$beat_file"  -w csv --csv-force "$audio_file"`))
        wait(energy_task)
        update_load_status!("Computed RMS energy", 4)
        wait(pitch_task)
        update_load_status!("Computed pitch", 5)
    end

    rm(audio_file, force=true)
    rm(beat_file, force=true)

    headers = [:start_time, :duration, :metric, :value, :metric_description]
    energy = CSV.read(energy_file, DataFrame, header=headers, select=[:value, :start_time, :duration])
    pitch = CSV.read(pitch_file, DataFrame, header=headers, select=[:value, :start_time, :duration])

    joined = outerjoin(energy, pitch, on=[:start_time, :duration], renamecols=(:_energy => :_pitch), validate=(true, true))
    sort!(joined, :start_time)

    end_time::Vector{Int64} = map(joined[!, :start_time], joined[!, :duration]) do time, duration
        round(Int, (time + duration) * 1000)
    end

    finalDataFrame = DataFrames.unique!(
        DataFrame(
            at=end_time,
            pitch=map(log10, coalesce.(joined[!, :value_pitch], 1.0)),
            energy=coalesce.(joined[!, :value_energy], 0.0)
        ),
        :at
    )

    update_load_status!("Loaded audio analysis", 6)

    return AudioData(
        finalDataFrame,
        name,
        dir,
        total_duration)
end
