using FFMPEG
using CSV

struct AudioData
    pitch::Vector{Float64}
    energy::Vector{Float64}
    at::Vector{Int64}
    name::String
    duration::Int64
end

function analyze(video_file::String)::AudioData
    name = base_name(video_file)
    tmp_path = "tmp"
    audio_file = joinpath(tmp_path,string(name,".wav"))
    beat_transform = "vamp:vamp-aubio:aubiotempo:beats"
    energy_transform = "vamp:bbc-vamp-plugins:bbc-energy:rmsenergy"
    pitch_transform = "vamp:vamp-aubio:aubiopitch:frequency"
    
    beat_file = transform_file(tmp_path,name,beat_transform)
    energy_file = transform_file(tmp_path,name,energy_transform)
    pitch_file = transform_file(tmp_path,name,pitch_transform)
    
    mkpath(tmp_path)
    
    total_duration = begin
        output = FFMPEG.exe("-i",video_file,"-show_entries","format=duration","-v","quiet","-of","csv=p=0",command=FFMPEG.ffprobe, collect=true)
        duration_seconds = parse(Float32, output[1])
        round(Int, duration_seconds * 1000)
    end
    
    if !(isfile(beat_file) && isfile(energy_file) && isfile(pitch_file))
        ffmpeg_exe("-i",video_file,"-vn",audio_file)
        run(`sonic-annotator -d "$beat_transform" -w csv --csv-force "$audio_file"`)
        run(`sonic-annotator -d "$energy_transform" -S sum --summary-only --segments-from "$beat_file"  -w csv --csv-force "$audio_file"`)
        run(`sonic-annotator -d "$pitch_transform" -S mean --summary-only --segments-from "$beat_file"  -w csv --csv-force "$audio_file"`)
    end

    rm(audio_file,force=true)

    headers = [:start_time,:duration,:metric,:value,:metric_description]
    energy = CSV.File(energy_file,header=headers,select=[:value,:start_time,:duration])
    pitch = CSV.File(pitch_file,header=headers,select=[:value])
    end_time = map(energy[:start_time], energy[:duration]) do time,duration
        round(Int, (time + duration) * 1000)
    end

    return AudioData(pitch[:value], energy[:value], end_time, name, total_duration)
end