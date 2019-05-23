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
    constraint_fix_ratio_in_in_flow(m::Model)

Fix delay between the `trans` leaving a connection to a node,
and the `trans` reaching the connection from another node.
"""
@catch_undef function constraint_fix_delay_out_in_trans(m::Model)
    @fetch trans = m.ext[:variables]
    constr_dict = m.ext[:constraints][:fix_delay_out_in_trans] = Dict()
    for (conn, n_out, n_in) in indices(fix_delay_out_in_trans)
        involved_timeslices = [t for (conn, n, c, d, t) in var_trans_indices(connection=conn, node=[n_out, n_in])]
        for t in involved_timeslices
            constr_dict[conn, n_out, n_in, t] = @constraint(
                m,
                + reduce(
                    +,
                    + trans[conn_, n_out_, c, d, t1] * duration(t1)
                    for (conn_, n_out_, c, d, t1) in trans_indices(
                        connection=conn,
                        node=n_out,
                        direction=:to_node,
                        t=t
                    );
                    init=0
                )
                ==
                + reduce(
                    +,
                    + trans[conn_, n_in_, c, d, t1]
                        * overlap_duration(
                            t1,
                            t - fix_delay_out_in_trans(connection=conn, node1=n_out, node2=n_in, t=t)
                        )
                    for (conn_, n_in_, c, d, t1) in trans_indices(
                        connection=conn,
                        node=n_in,
                        direction=:from_node,
                        t=overlap(
                            time_slice,
                            t - fix_delay_out_in_trans(connection=conn, node1=n_out, node2=n_in, t=t)
                        )
                    );
                    init=0
                )
            )
        end
    end
end
