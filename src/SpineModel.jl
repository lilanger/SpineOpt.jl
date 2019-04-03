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
# __precompile__()

module SpineModel

# Load packages
using JuMP
using Clp
using Dates
using SpineInterface
using Suppressor
using Revise

# Export helpers
export value
export pack_trailing_dims
export @butcher

# Export variables
export generate_variable_flow
export generate_variable_trans
export generate_variable_stor_state

# Export objecte
export objective_minimize_production_cost

# Export constraints
export constraint_flow_capacity
export constraint_fix_ratio_out_in_flow
export constraint_max_cum_in_flow_bound
export constraint_fix_ratio_out_in_trans
export constraint_trans_capacity
export constraint_nodal_balance
export constraint_stor_state
export constraint_stor_state_init
export constraint_stor_capacity

# Creating time_slices struct
export generate_time_slice
export generate_time_slice_relationships

include("helpers/util.jl")
include("helpers/butcher.jl")

include("variables/generate_variable_flow.jl")
include("variables/generate_variable_trans.jl")
include("variables/generate_variable_stor_state.jl")

include("objective/objective_minimize_production_cost.jl")

include("constraints/constraint_max_cum_in_flow_bound.jl")
include("constraints/constraint_flow_capacity.jl")
include("constraints/constraint_nodal_balance.jl")
include("constraints/constraint_fix_ratio_out_in_flow.jl")
include("constraints/constraint_fix_ratio_out_in_trans.jl")
include("constraints/constraint_trans_capacity.jl")
include("constraints/constraint_stor_capacity.jl")
include("constraints/constraint_stor_state.jl")
include("constraints/constraint_stor_state_init.jl")

include("temporals/generate_time_slice.jl")
include("temporals/generate_time_slice_relationships.jl")

end
