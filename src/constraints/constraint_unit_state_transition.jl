#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

"""
    constraint_unit_state_transition_indices()

Form the stochastic index set for the `:unit_state_transition` constraint.

Uses stochastic path indices due to potentially different stochastic scenarios between `t_after` and `t_before`.
"""
function constraint_unit_state_transition_indices()
    unique(
        (unit=u, stochastic_path=path, t_before=t_before, t_after=t_after)
        for (u, n) in units_on_resolution()
        for t_after in time_slice(temporal_block=node__temporal_block(node=n))
        for t_before in t_before_t(t_after=t_after)
        for path in active_stochastic_paths(
            unique(ind.stochastic_scenario for ind in units_on_indices(unit=u, t=[t_before, t_after]))
        )
    )
end

"""
    add_constraint_unit_state_transition!(m::Model)

Ensure consistency between the variables `units_on`, `units_started_up` and `units_shut_down`.
"""
function add_constraint_unit_state_transition!(m::Model)
    @fetch units_on, units_started_up, units_shut_down = m.ext[:variables]
    # TODO: add support for units that start_up over multiple timesteps?
    # TODO: use :integer, :binary, :linear as parameter values -> reusable for other pruposes
    m.ext[:constraints][:unit_state_transition] = Dict(
        (u, stochastic_path, t_before, t_after) => @constraint(
            m,
            expr_sum(
                + units_on[u, s, t_after]
                - units_started_up[u, s, t_after]
                + units_shut_down[u, s, t_after]
                for (u, s, t_after) in units_on_indices(unit=u, stochastic_scenario=stochastic_path, t=t_after);
                init=0
            )
            ==
            expr_sum(
                + units_on[u, s, t_before]
                for (u, s, t_before) in units_on_indices(unit=u, stochastic_scenario=stochastic_path, t=t_before);
                init=0
            )
        )
        for (u, stochastic_path, t_before, t_after) in constraint_unit_state_transition_indices()
        if online_variable_type(unit=u) !== :unit_online_variable_type_linear
    )
end
