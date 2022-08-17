struct Action
    at::Int
    pos::Int
    Action(at, pos) = begin
        actual_pos = if pos < 0
            0
        elseif pos > 100
            100
        else
            pos
        end
        new(round(Int, at), round(Int, actual_pos))
    end
end
const Actions = Vector{Action}

function create_normalise_function(datum::Vector{T}) where {T<:Real}
    min, max = extrema(datum)
    range = max - min
    value -> (value - min) / range
end

function calculate_offsets(pitch, normalised_pitch_to_offset)
    normalise = create_normalise_function(pitch)
    function offset(value)
        normalised_pitch = normalise(value)
        offset = normalised_pitch_to_offset(normalised_pitch)
        round(Int, offset)
    end
    map(offset, pitch)
end

function create_default_normalised_energy_to_pos(multiplier)
    normalised_energy -> normalised_energy * multiplier * 50
end

function create_normalised_pitch_to_offset(range)
    normalised_pitch -> normalised_pitch * range + ((100 - range) / 2)
end

function is_in_time_range(at, start_time, end_time)
    at >= start_time && (end_time == 0 || at <= end_time)
end

function create_actions(data::AudioData, time_parameters::TimeParameters, transform_parameters::TransformParameters)::Actions
    cropped_data = create_cropped_data_frame(data, time_parameters, transform_parameters)
    normalise = create_normalise_function(cropped_data[!, :energy])
    normalised_energy_to_pos = create_default_normalised_energy_to_pos(transform_parameters.energy_multiplier)

    actions = create_actions_barrier(
        Tables.namedtupleiterator(cropped_data[:, [:offset, :energy, :at]]),
        energy -> normalised_energy_to_pos(normalise(energy)),
        time_parameters,
        transform_parameters.overflow
    )

    unique!(act -> act.at, actions)
end

function create_cropped_data_frame(data::AudioData, time_parameters::TimeParameters, transform_parameters::TransformParameters)::DataFrame
    cropped_data = subset(data.frame, :at => a -> is_in_time_range.(a, time_parameters.start_time, time_parameters.end_time))
    offsets = calculate_offsets(cropped_data[!, :pitch], create_normalised_pitch_to_offset(transform_parameters.pitch_range))
    insertcols!(cropped_data, :offset => offsets, copycols=false)
end

function create_actions_barrier(iterator, energy_to_pos, time_parameters, overflow)::Actions
    actions = [Action(time_parameters.start_time, 50)]
    function action(pos, at, last_pos, last_at)
        append!(actions, create_peak(overflow, pos, at, last_pos, last_at))
    end

    last_at = time_parameters.start_time
    last_pos = 50

    for (offset, energy, at) in iterator
        unoffset_pos = energy_to_pos(energy)

        # up
        intermediate_at = round(Int, (at + last_at) / 2)
        pos = unoffset_pos + offset
        action(pos, intermediate_at, last_pos, last_at)
        last_at = intermediate_at
        last_pos = pos

        # down
        pos = (unoffset_pos * -1) + offset
        action(pos, at, last_pos, last_at)
        last_at = at
        last_pos = pos
    end
    actions
end

function create_peak(::Crop, pos, at, last_pos, last_at)::Actions
    [Action(at, pos)]
end

function create_peak(::Bounce, pos, at, last_pos, last_at)::Actions
    actions = Actions()
    function action(pos, at)
        push!(actions, Action(at, pos))
    end
    if last_pos < 0
        tmp_at = int_at(pos, at, last_pos, last_at, 0)
        action(0, tmp_at)
    elseif last_pos > 100
        tmp_at = int_at(pos, at, last_pos, last_at, 100)
        action(100, tmp_at)
    end

    if pos > 100
        tmp_at = int_at(pos, at, last_pos, last_at, 100)
        action(100, tmp_at)
        action(200 - pos, at)
    elseif pos < 0
        tmp_at = int_at(pos, at, last_pos, last_at, 0)
        action(0, tmp_at)
        action(-pos, at)
    else
        action(pos, at)
    end
end

function create_peak(::Fold, pos, at, last_pos, last_at)::Actions
    actions = Actions()
    function action(pos, at)
        push!(actions, Action(at, pos))
    end

    int_at = (last_at + at) / 2
    travel = abs(last_pos - pos) / 2
    if last_pos < 0
        action(last_pos + travel, int_at)
    elseif last_pos > 100
        action(last_pos - travel, int_at)
    end

    if pos < 0
        action(last_pos - travel, int_at)
        action(last_pos, at)
    elseif pos > 100
        action(last_pos + travel, int_at)
        action(last_pos, at)
    else
        action(pos, at)
    end
end

function int_at(pos, at, last_pos, last_at, limit)
    before_ratio = abs(last_pos - limit)
    after_ratio = abs(pos - limit)

    round(Int, (before_ratio * at + after_ratio * last_at) / (after_ratio + before_ratio))
end
