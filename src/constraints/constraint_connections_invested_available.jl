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

"""
    add_constraint_connections_invested_available!(m::Model)

Limit the connections_invested_available by the number of investment candidate connections.
"""
function add_constraint_connections_invested_available!(m::Model)
    @fetch connections_invested_available = m.ext[:spineopt].variables
    t0 = _analysis_time(m)
    m.ext[:spineopt].constraints[:connections_invested_available] = Dict(
        (connection=conn, stochastic_scenario=s, t=t) => @constraint(
            m,
            + connections_invested_available[conn, s, t]
            <=
            + candidate_connections[(connection=conn, stochastic_scenario=s, analysis_time=t0, t=t)]
        ) for (conn, s, t) in connections_invested_available_indices(m)
    )
end
# TODO: units_invested_available or \sum(units_invested)?
# Candidate units: max amount of units that can be installed over model horizon
# or max amount of units that can be available at a time?
