module audioscripter
using FFMPEG
using CSV
using JSON

function transform_file( path, name, transform )
    transform_name = string(name,"_",replace(transform, ":" => "_"),".csv")
    joinpath(path,transform_name)
end

function base_name( path )
    (_,filename) = splitdir(path)
    (base,_) = splitext(filename)
    base
end

function offsets( pitch )
    logmax = log(maximum(pitch))
    logmin = log(minimum(pitch))
    range = 100
    factor = range / ( logmax - logmin )
    function offset( value )
        offset = ( log( value ) - logmin ) * factor + ( ( 100 - range ) / 2 )
        trunc(Int, offset)
    end
    map(offset, pitch)
end

function actions(offsets, energies, ats)
    actions = Vector()
    function action(pos, at, last_pos, last_at)
        append!(actions,peak(pos,at,last_pos,last_at))
    end
    multiplier = 1
    factor = multiplier * 50 / ( maximum(energies) - minimum(energies) )
    last_at = 0
    last_pos = 50
    for (offset, energy, at_s) in zip(offsets, energies, ats)
        at = trunc(Int, at_s * 1000)
        println("offset: $offset, energy: $energy, at: $at")
        if ( at != last_at )
            int_at2 = trunc(Int,( ( at + last_at ) / 2 ))
            pos = ( energy * factor ) + offset
            action( pos, int_at2, last_pos, last_at )
            last_at = int_at2
            last_pos = pos
        end
        pos = ( energy * factor * -1 ) + offset
        action( pos, at, last_pos, last_at )
        last_at = at
        last_pos = pos
    end
    actions
end

function peak( pos, at, last_pos, last_at )
    actions = Vector()
    function action(pos, at)
        push!(actions, (Dict("pos" => trunc(Int, pos), "at" => trunc(Int, at))))
    end
    if ( last_pos < 0 )
        tmp_at = int_at( pos, at, last_pos, last_at, 0 )
        action( 0, tmp_at )
    elseif ( last_pos > 100 )
        tmp_at = int_at( pos, at, last_pos, last_at, 100 )
        action( 100, tmp_at )
    end

    if ( pos > 100 )
        tmp_at = int_at( pos, at, last_pos, last_at, 100 )
        action( 100, tmp_at )
        action( 200 - pos, at )
    elseif ( pos < 0 )
        tmp_at = int_at( pos, at, last_pos, last_at, 0 )
        action( 0, tmp_at )
        action( -pos, at )
    else
        action( pos, at )
    end
    actions
end

function int_at( pos, at, last_pos, last_at, limit )
    before_ratio = abs( last_pos - limit )
    after_ratio = abs( pos - limit )

    trunc(Int, ( before_ratio * at + after_ratio * last_at ) / ( after_ratio + before_ratio ) )
end

function main(video_file)
    name = base_name(video_file)
    tmp_path = "tmp_jl"
    out_path = "out_jl"
    audio_file = joinpath(tmp_path,string(name,".wav"))
    beat_transform = "vamp:vamp-aubio:aubiotempo:beats"
    energy_transform = "vamp:bbc-vamp-plugins:bbc-energy:rmsenergy"
    pitch_transform = "vamp:vamp-aubio:aubiopitch:frequency"
    
    beat_file = transform_file(tmp_path,name,beat_transform)
    energy_file = transform_file(tmp_path,name,energy_transform)
    pitch_file = transform_file(tmp_path,name,pitch_transform)
    
    mkpath(tmp_path)
    mkpath(out_path)
    
    duration = begin
        output = FFMPEG.exe("-i",video_file,"-show_entries","format=duration","-v","quiet","-of","csv=p=0",command=FFMPEG.ffprobe, collect=true)
        duration_seconds = parse(Float32, output[1])
        trunc(Int, duration_seconds * 1000)
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
    offsets_v = offsets(pitch[:value])
    actions_v = actions(offsets_v, energy[:value], energy[:start_time])

    funscript = Dict(
        "metadata" => Dict(
            "creator" => "audioscripter",
            "title" => name,
            "description" => "Procedurally generated by audioscripter",
            "duration" => duration,
            "license" => "",
            "notes" => "",
            "performers" => (),
            "script_url" => "",
            "tags" => ("music","audio"),
            "type" => "",
            "video_url" => ""
        ),
        "range" => 100,
        "inverted" => false,
        "version" => 1.0,
        "actions" => actions_v
    )

    funscript_json = JSON.json(funscript)

    funscript_file = open(joinpath(out_path, string(name, ".funscript")), "w")
    write(funscript_file, funscript_json)
    close(funscript_file)
end


end # module
