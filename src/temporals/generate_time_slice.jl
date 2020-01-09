#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of Spine Model.
#
# Spine Model is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Spine Model is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

import Dates: CompoundPeriod

struct TimeSliceSet
    time_slices::Array{TimeSlice,1}
    block_time_slices::Dict{Object,Array{TimeSlice,1}}
end

struct ToTimeSlice
    block_time_slices::Dict{Object,Array{TimeSlice,1}}
    block_time_slice_map::Dict{Object,Array{Int64,1}}
end

"""
    time_slice(;temporal_block=anything, t=anything)

An `Array` of time slices *in the model*.
- `temporal_block` is a temporal block object to filter the result.
- `t` is a `TimeSlice` or collection of `TimeSlice`s *in the model* to filter the result.
"""
(h::TimeSliceSet)(;temporal_block=anything, t=anything) = h(temporal_block, t)
(h::TimeSliceSet)(::Anything, ::Anything) = h.time_slices
(h::TimeSliceSet)(temporal_block::Object, ::Anything) = h.block_time_slices[temporal_block]
(h::TimeSliceSet)(::Anything, s) = s
(h::TimeSliceSet)(temporal_block::Object, s) = (t for t in s if temporal_block in t.blocks)
(h::TimeSliceSet)(temporal_blocks::Array{Object,1}, s) = (t for blk in temporal_blocks for t in h(blk, s))

"""
    to_time_slice(t::TimeSlice...)

An array of time slices *in the model* that overlap `t`
(where `t` may not be in the model).
"""
function (h::ToTimeSlice)(t::TimeSlice...)
    blk_rngs = Array{Tuple{Object,Array{Int64,1}},1}()
    for (blk, time_slice_map) in h.block_time_slice_map
        temp_block_start = start(first(h.block_time_slices[blk]))
        temp_block_end = end_(last(h.block_time_slices[blk]))
        ranges = []
        for s in t
            s_start = max(temp_block_start, start(s))
            s_end = min(temp_block_end, end_(s))
            s_end <= s_start && continue
            first_ind = time_slice_map[Minute(s_start - temp_block_start).value + 1]
            last_ind = time_slice_map[Minute(s_end - temp_block_start).value]
            push!(ranges, first_ind:last_ind)
        end
        isempty(ranges) && continue
        push!(blk_rngs, (blk, union(ranges...)))
    end
    unique(t for (blk, rngs) in blk_rngs for t in h.block_time_slices[blk][rngs])
end

"""
    to_time_slice(t::DateTime...)

An array of time slices *in the model* that overlap `t`.
"""
function (h::ToTimeSlice)(t::DateTime...)
    blk_rngs = Array{Tuple{Object,Array{Int64,1}},1}()
    for (blk, time_slice_map) in h.block_time_slice_map
        temp_block_start = start(first(h.block_time_slices[blk]))
        temp_block_end = end_(last(h.block_time_slices[blk]))
        rngs = [
            time_slice_map[Minute(s - temp_block_start).value + 1]
            for s in t if temp_block_start <= s < temp_block_end
        ]
        push!(blk_rngs, (blk, rngs))
    end
    unique(t for (blk, rngs) in blk_rngs for t in h.block_time_slices[blk][rngs])
end

"""
    _rolling_windows(from::Dates.DateTime, step::Union{Period,CompoundPeriod}, until::DateTime)

An array of tuples of start and end time for each rolling window.
"""
function _rolling_windows(from::Dates.DateTime, step::Union{Period,CompoundPeriod}, until::DateTime)
    interval = Array{Tuple{DateTime,DateTime},1}()
    while from < until
        push!(interval, (from, from + step))
        from += step
    end
    return interval
end


"""
    rolling_windows()

An array of tuples of start and end time for each rolling window.
"""
function rolling_windows()
    instance = first(model())
    m_start = model_start(model=instance)
    m_end = model_end(model=instance)
    m_roll_forward = roll_forward(model=instance, _strict=false)
    m_roll_forward === nothing && return [(m_start, m_end)]
    _rolling_windows(m_start, m_roll_forward, m_end)
end

# Adjuster functions, in case blocks specify their own start and end
adjusted_start(window_start, window_end, ::Nothing) = window_start
adjusted_start(window_start, window_end, blk_start::Union{Period,CompoundPeriod}) = window_start + blk_start
adjusted_start(window_start, window_end, blk_start::DateTime) = max(window_start, blk_start)

adjusted_end(window_start, window_end, ::Nothing) = window_end
adjusted_end(window_start, window_end, blk_end::Union{Period,CompoundPeriod}) = max(window_end, window_start + blk_end)
adjusted_end(window_start, window_end, blk_end::DateTime) = max(window_end, blk_end)


"""
    _block_time_intervals(window_start, window_end)

A `Dict` mapping temporal blocks to a sorted `Array` of time intervals, i.e., (start, end) tuples.
"""
function _block_time_intervals(window_start, window_end)
    d = Dict{Object,Array{Tuple{DateTime,DateTime},1}}()
    for block in temporal_block()
        time_intervals = Array{Tuple{DateTime,DateTime},1}()
        block_start_ = adjusted_start(window_start, window_end, block_start(temporal_block=block, _strict=false))
        block_end_ = adjusted_end(window_start, window_end, block_end(temporal_block=block, _strict=false))
        time_slice_start = block_start_
        i = 1
        while time_slice_start < block_end_
            duration = resolution(temporal_block=block, i=i)
            time_slice_end = time_slice_start + duration
            if time_slice_end > block_end_
                time_slice_end = block_end_
                @warn(
                    """
                    the last time slice of temporal block $block has been cut to fit within the optimisation window
                    """
                )
            end
            push!(time_intervals, (time_slice_start, time_slice_end))
            time_slice_start = time_slice_end
            i += 1
        end
        d[block] = time_intervals
    end
    d
end

"""
    initialize_time_slice_history()

Initializes the `TimeSlice` history for rolling optimization.
"""
function initialize_time_slice_history()
    empty_history = Array{TimeSlice,1}()
    block_empty_history = Dict{Object,Array{TimeSlice,1}}()
    block_empty_history[Object("time_slice_history")] = empty_history
    time_slice_history = TimeSliceSet(empty_history, block_empty_history)
    @eval begin
        time_slice_history = $time_slice_history
        export time_slice_history
    end
end

"""
    earliest_necessary_timestep()

Determines the earliest necessary historical time step.
"""
function earliest_necessary_timestep(window_start::Dates.DateTime)
    ts = window_start - Minute(first(current_time_slice()).duration)
    # Transfer delay parameters
    for (c,n1,n2) in indices(trans_delay)
        delay = trans_delay(connection=c, node1=n1, node2=n2)
        if isa(delay, TimeSeries)
            ts = min(ts, fill(window_start, size(delay.values)) - delay.values)
        else
            ts = min(ts, window_start)
        end
    end
    # Minimum uptime parameters
    for u in indices(min_up_time)
        ts = min(ts, window_start - min_up_time(unit=u))
    end
    # Minimum downtime parameters
    for u in indices(min_down_time)
        ts = min(ts, window_start - min_down_time(unit=u))
    end
    return ts
end


function _block_time_slices(block_time_intervals)
    inv_block_time_intervals = Dict{Tuple{DateTime,DateTime},Array{Object,1}}()
    for (block, time_intervals) in block_time_intervals
        for t in time_intervals
            push!(get!(inv_block_time_intervals, t, Array{Object,1}()), block)
        end
    end
    instance = first(model())
    d = Dict(:minute => Minute, :hour => Hour)
    duration_unit_ = get(d, duration_unit(model=instance, _strict=false), Minute)
    Dict(
        block => [
            TimeSlice(t..., inv_block_time_intervals[t]...; duration_unit=duration_unit_)
            for t in time_intervals
        ]
        for (block, time_intervals) in block_time_intervals
    )
end


function _block_time_slice_map(block_time_slices)
    d = Dict{Object,Array{Int64,1}}()
    for (block, time_slices) in block_time_slices
        temp_block_start = start(first(time_slices))
        temp_block_end = end_(last(time_slices))
        d[block] = time_slice_map = Array{Int64,1}(undef, Minute(temp_block_end - temp_block_start).value)
        for (ind, t) in enumerate(time_slices)
            first_minute = Minute(start(t) - temp_block_start).value + 1
            last_minute = Minute(end_(t) - temp_block_start).value
            time_slice_map[first_minute:last_minute] .= ind
        end
    end
    d
end

"""
    generate_time_slice(window_start, window_end)

Generate and export a convenience functor called `time_slice`, that can be used to retrieve
time slices in the model between `window_start` and `window_end`. See [@TimeSliceSet()](@ref).
"""
function generate_time_slice(window_start, window_end)
    block_time_intervals = _block_time_intervals(window_start, window_end)
    block_time_slices = _block_time_slices(block_time_intervals)
    block_time_slice_map = _block_time_slice_map(block_time_slices)
    history = first(keys(time_slice_history.block_time_slices))
    merge!(block_time_slices, copy(time_slice_history.block_time_slices))
    block_current_time_slices = filter(x -> x.first != history, block_time_slices)
    all_time_slices = sort(unique(t for v in values(block_time_slices) for t in v))
    current_time_slices = sort(unique(t for v in values(block_current_time_slices) for t in v))

    # Create and export the function-like objects
    time_slice = TimeSliceSet(all_time_slices, block_time_slices)
    current_time_slice = TimeSliceSet(current_time_slices, block_current_time_slices)
    to_time_slice = ToTimeSlice(block_time_slices, block_time_slice_map)
    @eval begin
        time_slice = $time_slice
        to_time_slice = $to_time_slice
        current_time_slice = $current_time_slice
        export time_slice
        export to_time_slice
        export current_time_slice
    end
    # Update time_slice_history
    append!(time_slice_history(), filter(x -> x.end_ <= window_end, current_time_slice()))
    t = earliest_necessary_timestep(window_end)
    filter!(x -> x.start >= t, time_slice_history())
end
