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

@testset "connection-based constraints" begin
    url_in = "sqlite://"
    test_data = Dict(
        :objects => [
            ["model", "instance"],
            ["model", "master"],
            ["temporal_block", "hourly"],
            ["temporal_block", "investments_hourly"],
            ["temporal_block", "two_hourly"],
            ["stochastic_structure", "deterministic"],
            ["stochastic_structure", "investments_deterministic"],
            ["stochastic_structure", "stochastic"],
            ["connection", "connection_ab"],
            ["connection", "connection_bc"],
            ["connection", "connection_ca"],
            ["node", "node_a"],
            ["node", "node_b"],
            ["node", "node_c"],
            ["stochastic_scenario", "parent"],
            ["stochastic_scenario", "child"],
        ],
        :relationships => [
            ["model__temporal_block", ["instance", "hourly"]],
            ["model__temporal_block", ["instance", "two_hourly"]],
            ["model__temporal_block", ["master", "investments_hourly"]],
            ["model__stochastic_structure", ["instance", "deterministic"]],
            ["model__stochastic_structure", ["instance", "stochastic"]],
            ["model__stochastic_structure", ["master", "investments_deterministic"]],
            ["connection__from_node", ["connection_ab", "node_a"]],
            ["connection__to_node", ["connection_ab", "node_b"]],
            ["connection__from_node", ["connection_bc", "node_b"]],
            ["connection__to_node", ["connection_bc", "node_c"]],
            ["connection__from_node", ["connection_ca", "node_c"]],
            ["connection__to_node", ["connection_ca", "node_a"]],
            ["node__temporal_block", ["node_a", "hourly"]],
            ["node__temporal_block", ["node_b", "two_hourly"]],
            ["node__temporal_block", ["node_c", "hourly"]],
            ["node__stochastic_structure", ["node_a", "stochastic"]],
            ["node__stochastic_structure", ["node_b", "deterministic"]],
            ["node__stochastic_structure", ["node_c", "stochastic"]],
            ["stochastic_structure__stochastic_scenario", ["deterministic", "parent"]],
            ["stochastic_structure__stochastic_scenario", ["stochastic", "parent"]],
            ["stochastic_structure__stochastic_scenario", ["stochastic", "child"]],
            ["stochastic_structure__stochastic_scenario", ["investments_deterministic", "parent"]],
            ["parent_stochastic_scenario__child_stochastic_scenario", ["parent", "child"]],
        ],
        :object_parameter_values => [
            ["model", "instance", "model_start", Dict("type" => "date_time", "data" => "2000-01-01T00:00:00")],
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2000-01-01T02:00:00")],
            ["model", "instance", "duration_unit", "hour"],
            ["model", "instance", "model_type", "spineopt_standard"],
            ["model", "master", "model_start", Dict("type" => "date_time", "data" => "2000-01-01T00:00:00")],
            ["model", "master", "model_end", Dict("type" => "date_time", "data" => "2000-01-01T02:00:00")],
            ["model", "master", "duration_unit", "hour"],
            ["model", "master", "model_type", "spineopt_other"],
            ["model", "master", "max_gap", "0.05"],
            ["model", "master", "max_iterations", "2"],
            ["temporal_block", "hourly", "resolution", Dict("type" => "duration", "data" => "1h")],
            ["temporal_block", "two_hourly", "resolution", Dict("type" => "duration", "data" => "2h")],
            ["model", "instance", "db_mip_solver", "Cbc.jl"],
            ["model", "instance", "db_lp_solver", "Clp.jl"],
        ],
        :relationship_parameter_values => [
            [
                "stochastic_structure__stochastic_scenario",
                ["stochastic", "parent"],
                "stochastic_scenario_end",
                Dict("type" => "duration", "data" => "1h")
            ]
        ],
    )
    @testset "constraint_connection_flow_capacity" begin
        connection_capacity = 200
        _load_test_data(url_in, test_data)
        relationship_parameter_values =
            [["connection__from_node", ["connection_ab", "node_a"], "connection_capacity", connection_capacity]]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        constraint = m.ext[:spineopt].constraints[:connection_flow_capacity]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (connection(:connection_ab), node(:node_a), direction(:from_node), s, t)
            var_conn_flow = var_connection_flow[key...]
            expected_con = @build_constraint(var_conn_flow <= connection_capacity)
            con_key = (connection(:connection_ab), node(:node_a), direction(:from_node), [s], t)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_connection_flow_gas_capacity" begin
        bigm = Dict("instance" => 10000)
        binary = Dict("connection_ca" => true)
        relationships = [["connection__node__node", [ "connection_ca", "node_c", "node_a"]]]
        fixed_pressure_constant_1_ = Dict(("connection_ca", "node_c","node_a") => 0)
        _load_test_data(url_in, test_data)
        object_parameter_values = [
            ["connection", "connection_ca", "has_binary_gas_flow", binary["connection_ca"]],
            ["model", "instance", "big_m", bigm["instance"]],
        ]
        relationship_parameter_values =
            [["connection__node__node", ["connection_ca", "node_c","node_a"], "fixed_pressure_constant_1", fixed_pressure_constant_1_[("connection_ca", "node_c","node_a")]]]
        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values, relationship_parameter_values=relationship_parameter_values, relationships=relationships
        )
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        var_binary_flow = m.ext[:spineopt].variables[:binary_gas_connection_flow]
        var_pressure = m.ext[:spineopt].variables[:node_pressure]
        constraint = m.ext[:spineopt].constraints[:connection_flow_gas_capacity]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        bigm = 10000
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for ((conn,n_from,n_to), val) in fixed_pressure_constant_1_
                if binary["connection_ca"]
                    conn = connection(Symbol(conn))
                    n_from = node(Symbol(n_from))
                    n_to = node(Symbol(n_to))
                    var_conn_flow_key1 = (conn, n_from, direction(:from_node), s, t)
                    var_conn_flow_key2 = (conn, n_to, direction(:to_node), s, t)
                    var_conn1 = var_connection_flow[var_conn_flow_key1...]
                    var_conn2 = var_connection_flow[var_conn_flow_key2...]
                    var_bin = var_binary_flow[var_conn_flow_key2...]
                    con_key = (conn, n_from, n_to, [s], t)
                    expected_con = @build_constraint((var_conn1 + var_conn2)/2 <= bigm * var_bin)
                    con = constraint[con_key...]
                    observed_con = constraint_object(con)
                    @test _is_constraint_equal(observed_con, expected_con)
                end
            end
        end
    end
    @testset "constraint_fix_node_pressure_point" begin
        bigm = Dict("instance" => 10000)
        binary = Dict("connection_ca" => true)
        has_pressure = Dict("node_a" => true, "node_c" => true)
        relationships = [["connection__node__node", [ "connection_ca", "node_c", "node_a"]]]
        fixed_pressure_constant_1_raw = [60.315, 64.993, 69.359, 0.0, 42.783, 37.252, 0.0, 0.0, 45.406]
        fixed_pressure_constant_0_raw = [53.422, 58.652, 63.456, 0.0, 32.348, 24.57, 0.0, 0.0, 35.745]
        fixed_pressure_constant_1_ = Dict(("connection_ca", "node_c","node_a") => Dict("type" => "array", "value_type" => "float", "data" => PyVector(fixed_pressure_constant_1_raw)))
        fixed_pressure_constant_0_ = Dict(("connection_ca", "node_c","node_a") => Dict("type" => "array", "value_type" => "float", "data" => PyVector(fixed_pressure_constant_0_raw)))
        _load_test_data(url_in, test_data)
        object_parameter_values = [
            ["node", "node_a", "has_pressure", has_pressure["node_a"]],
            ["node", "node_c", "has_pressure", has_pressure["node_c"]],
            ["connection", "connection_ca", "has_binary_gas_flow", binary["connection_ca"]],
            ["model", "instance", "big_m", bigm["instance"]],
        ]
        relationship_parameter_values =
            [["connection__node__node", ["connection_ca", "node_c","node_a"], "fixed_pressure_constant_1", fixed_pressure_constant_1_[("connection_ca", "node_c","node_a")]],
            ["connection__node__node", ["connection_ca", "node_c","node_a"], "fixed_pressure_constant_0", fixed_pressure_constant_0_[("connection_ca", "node_c","node_a")]]
            ]
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values, relationship_parameter_values=relationship_parameter_values, relationships=relationships)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        var_binary_flow = m.ext[:spineopt].variables[:binary_gas_connection_flow]
        var_node_pressure = m.ext[:spineopt].variables[:node_pressure]
        constraint = m.ext[:spineopt].constraints[:fix_node_pressure_point]
        @test length(constraint) == 12
        scenarios = (stochastic_scenario(:parent),)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        bigm = 10000
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for ((conn,n_from,n_to), val) in fixed_pressure_constant_1_
                if binary["connection_ca"]
                    conn = connection(Symbol(conn))
                    n_from = node(Symbol(n_from))
                    n_to = node(Symbol(n_to))
                    var_conn_flow_key1 = (conn, n_from, direction(:from_node), s, t)
                    var_conn_flow_key2 = (conn, n_to, direction(:to_node), s, t)
                    var_node_pr_keys1 = (n_from, s, t)
                    var_node_pr_keys2 = (n_to, s, t)
                    var_conn1 = var_connection_flow[var_conn_flow_key1...]
                    var_conn2 = var_connection_flow[var_conn_flow_key2...]
                    var_bin = var_binary_flow[var_conn_flow_key2...]
                    var_pr1 = var_node_pressure[var_node_pr_keys1...]
                    var_pr2 = var_node_pressure[var_node_pr_keys2...]
                    @testset for i in length(fixed_pressure_constant_1_raw)
                            if fixed_pressure_constant_1_raw[i] !=0
                            con_key = (conn, n_from, n_to, [s], t, i)
                            expected_con = @build_constraint(
                                (var_conn1 + var_conn2)/2 <=
                                (fixed_pressure_constant_1_raw[i]*var_pr1)
                                - (fixed_pressure_constant_0_raw[i]*var_pr2)
                                + bigm * (1-var_bin)
                                )
                            con = constraint[con_key...]
                            observed_con = constraint_object(con)
                            @test _is_constraint_equal(observed_con, expected_con)
                        end
                    end
                end
            end
        end
    end
    @testset "constraint_connection_unitary_gas_flow" begin
        binary = Dict("connection_ca" => true)
        bigm = Dict("instance" => 10000)
        relationships = [
            ["connection__node__node", [ "connection_ca", "node_c", "node_a"]],
            ["connection__to_node", [ "connection_ca", "node_c"]]
            ]
        fixed_pr_constant_1_ = Dict(("connection_ca", "node_c","node_a") => 0)
        _load_test_data(url_in, test_data)
        object_parameter_values = [
            ["connection", "connection_ca", "has_binary_gas_flow", binary["connection_ca"]],
            ["model", "instance", "big_m", bigm["instance"]],
        ]
        relationship_parameter_values = [
            [
                "connection__node__node",
                ["connection_ca", "node_c","node_a"],
                "fixed_pressure_constant_1",
                fixed_pr_constant_1_[("connection_ca", "node_c","node_a")]
            ]
        ]
        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
            relationships=relationships
        )
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_binary_flow = m.ext[:spineopt].variables[:binary_gas_connection_flow]
        constraint = m.ext[:spineopt].constraints[:connection_unitary_gas_flow]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for ((conn,n_from,n_to), val) in fixed_pr_constant_1_
                if binary["connection_ca"]
                    conn = connection(Symbol(conn))
                    n_from = node(Symbol(n_from))
                    n_to = node(Symbol(n_to))
                    var_conn_flow_key1 = (conn, n_from, direction(:to_node), s, t)
                    var_conn_flow_key2 = (conn, n_to, direction(:to_node), s, t)
                    var_bin1 = var_binary_flow[var_conn_flow_key1...]
                    var_bin2 = var_binary_flow[var_conn_flow_key2...]
                    con_key = (conn, n_from, n_to, [s], t)
                    expected_con = @build_constraint(var_bin1 == 1- var_bin2)
                    con = constraint[con_key...]
                    observed_con = constraint_object(con)
                    @test _is_constraint_equal(observed_con, expected_con)
                end
            end
        end
    end
    @testset "constraint_node_voltage_angle" begin
        conn_react = Dict("connection_ca" => 0.17)
        conn_react_p_u = Dict("connection_ca" => 250)
        has_volt_ang = Dict("node_c" => true,"node_a" => true,)
        fix_ratio_out_in = Dict(("connection_ca", "node_a","node_c") => 1)
        relationships = [
            ["connection__node__node", [ "connection_ca", "node_a", "node_c"]],
            ["connection__from_node", [ "connection_ca", "node_a"]],
        ]
        object_parameter_values = [
            ["connection", "connection_ca", "connection_reactance", conn_react["connection_ca"]],
            ["connection", "connection_ca", "connection_reactance_base", conn_react_p_u["connection_ca"]],
            ["node", "node_c", "has_voltage_angle", has_volt_ang["node_c"]],
            ["node", "node_a", "has_voltage_angle", has_volt_ang["node_a"]],
        ]
        relationship_parameter_values =
            [
            ["connection__node__node", ["connection_ca", "node_a","node_c"], "fix_ratio_out_in_connection_flow", fix_ratio_out_in[("connection_ca", "node_a","node_c")]],
            ]
        _load_test_data(url_in, test_data)
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values, relationship_parameter_values=relationship_parameter_values, relationships=relationships)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        var_voltage_angle = m.ext[:spineopt].variables[:node_voltage_angle]
        constraint = m.ext[:spineopt].constraints[:node_voltage_angle]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for ((conn,n_to,n_from), val) in fix_ratio_out_in
                    react = conn_react[conn]
                    react_p_u = conn_react_p_u[conn]
                    conn = connection(Symbol(conn))
                    n_from = node(Symbol(n_from))
                    n_to = node(Symbol(n_to))
                    var_conn_flow_key1 = (conn, n_from, direction(:from_node), s, t)
                    var_conn_flow_key2 = (conn, n_to, direction(:from_node), s, t)
                    var_volt_ang_key1  = (n_from , s, t)
                    var_volt_ang_key2  = (n_to, s, t)
                    var_conn_flow1 = var_connection_flow[var_conn_flow_key1...]
                    var_conn_flow2 = var_connection_flow[var_conn_flow_key2...]
                    var_volt_ang1 = var_voltage_angle[var_volt_ang_key1...]
                    var_volt_ang2 = var_voltage_angle[var_volt_ang_key2...]
                    con_key = (conn, n_to, n_from, [s], t)
                    expected_con = @build_constraint(var_conn_flow1 - var_conn_flow2 == (var_volt_ang1-var_volt_ang2)/react*react_p_u)
                    con = constraint[con_key...]
                    observed_con = constraint_object(con)
                    @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_connection_flow_capacity_investments" begin
        connection_capacity = 200
        _load_test_data(url_in, test_data)

        object_parameter_values = [
            ["connection", "connection_ab", "candidate_connections", 1],
            [
                "connection",
                "connection_ab",
                "connection_investment_lifetime",
                Dict("type" => "duration", "data" => "60m"),
            ],
        ]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
        ]
        relationship_parameter_values =
            [["connection__from_node", ["connection_ab", "node_a"], "connection_capacity", connection_capacity]]

        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values,
            relationships=relationships,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]

        constraint = m.ext[:spineopt].constraints[:connection_flow_capacity]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (connection(:connection_ab), node(:node_a), direction(:from_node), s, t)
            invest_key = (connection(:connection_ab), s, t)
            var_conn_flow = var_connection_flow[key...]
            var_conn_inv_a = var_connections_invested_available[invest_key...]
            expected_con = @build_constraint(var_conn_flow <= connection_capacity * var_conn_inv_a)
            con_key = (connection(:connection_ab), node(:node_a), direction(:from_node), [s], t)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_connection_intact_flow_ptdf" begin
        # TODO: node_ptdf_threshold
        conn_r = 0.9
        conn_x = 0.1
        _load_test_data(url_in, test_data)
        objects = [["commodity", "electricity"]]
        relationships = [
            ["connection__from_node", ["connection_ab", "node_b"]],
            ["connection__to_node", ["connection_ab", "node_a"]],
            ["connection__from_node", ["connection_bc", "node_c"]],
            ["connection__to_node", ["connection_bc", "node_b"]],
            ["connection__from_node", ["connection_ca", "node_a"]],
            ["connection__to_node", ["connection_ca", "node_c"]],
            ["node__commodity", ["node_a", "electricity"]],
            ["node__commodity", ["node_b", "electricity"]],
            ["node__commodity", ["node_c", "electricity"]],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"]],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"]],
        ]
        object_parameter_values = [
            ["connection", "connection_ab", "connection_monitored", true],
            ["connection", "connection_ab", "connection_reactance", conn_x],
            ["connection", "connection_ab", "connection_resistance", conn_r],
            ["connection", "connection_bc", "connection_monitored", true],
            ["connection", "connection_bc", "connection_reactance", conn_x],
            ["connection", "connection_bc", "connection_resistance", conn_r],
            ["connection", "connection_ca", "connection_monitored", true],
            ["connection", "connection_ca", "connection_reactance", conn_x],
            ["connection", "connection_ca", "connection_resistance", conn_r],
            ["commodity", "electricity", "commodity_physics", "commodity_physics_ptdf"],
            ["node", "node_a", "node_opf_type", "node_opf_type_reference"],
        ]
        relationship_parameter_values = [
            ["connection__node__node", ["connection_ab", "node_b", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
        ]
        SpineInterface.import_data(
            url_in;
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connection_flow = m.ext[:spineopt].variables[:connection_intact_flow]
        var_node_injection = m.ext[:spineopt].variables[:node_injection]
        constraint = m.ext[:spineopt].constraints[:connection_intact_flow_ptdf]
        @test length(constraint) == 5
        # NOTE: always pick the second (last) node in `connection__from_node` as 'to' node
        # And they are ordered alphabetically from spinedb_api.export_functions.export_relationships
        @testset for (conn_name, n_to_name, n_inj_name, scen_names, t_block) in (
            (:connection_ab, :node_b, :node_b, (:parent,), :two_hourly),
            (:connection_bc, :node_c, :node_c, (:parent, :child), :hourly),
            (:connection_ca, :node_c, :node_c, (:parent, :child), :hourly),
        )
            conn = connection(conn_name)
            n_to = node(n_to_name)
            n_inj = node(n_inj_name)
            scenarios = (stochastic_scenario(s) for s in scen_names)
            time_slices = time_slice(m; temporal_block=temporal_block(t_block))
            @testset for (s, t) in zip(scenarios, time_slices)
                var_conn_flow_to = var_connection_flow[conn, n_to, direction(:to_node), s, t]
                var_conn_flow_from = var_connection_flow[conn, n_to, direction(:from_node), s, t]
                var_n_inj = var_node_injection[n_inj, s, t]
                ptdf_val = SpineOpt.ptdf(connection=conn, node=n_inj)
                expected_con = @build_constraint(var_conn_flow_to - var_conn_flow_from == ptdf_val * var_n_inj)
                observed_con = constraint_object(constraint[conn, n_to, [s], t])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_connection_flow_lodf" begin
        conn_r = 0.9
        conn_x = 0.1
        conn_emergency_cap_ab = 80
        conn_emergency_cap_bc = 100
        conn_emergency_cap_ca = 150
        _load_test_data(url_in, test_data)
        objects = [["commodity", "electricity"]]
        relationships = [
            ["connection__from_node", ["connection_ab", "node_b"]],
            ["connection__to_node", ["connection_ab", "node_a"]],
            ["connection__from_node", ["connection_bc", "node_c"]],
            ["connection__to_node", ["connection_bc", "node_b"]],
            ["connection__from_node", ["connection_ca", "node_a"]],
            ["connection__to_node", ["connection_ca", "node_c"]],
            ["node__commodity", ["node_a", "electricity"]],
            ["node__commodity", ["node_b", "electricity"]],
            ["node__commodity", ["node_c", "electricity"]],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"]],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"]],
        ]
        object_parameter_values = [
            ["connection", "connection_ab", "connection_monitored", true],
            ["connection", "connection_ab", "connection_reactance", conn_x],
            ["connection", "connection_ab", "connection_resistance", conn_r],
            ["connection", "connection_bc", "connection_monitored", true],
            ["connection", "connection_bc", "connection_reactance", conn_x],
            ["connection", "connection_bc", "connection_resistance", conn_r],
            ["connection", "connection_ca", "connection_monitored", true],
            ["connection", "connection_ca", "connection_reactance", conn_x],
            ["connection", "connection_ca", "connection_resistance", conn_r],
            ["commodity", "electricity", "commodity_physics", "commodity_physics_lodf"],
            ["node", "node_a", "node_opf_type", "node_opf_type_reference"],
            ["connection", "connection_ca", "connection_contingency", true],
        ]
        relationship_parameter_values = [
            ["connection__node__node", ["connection_ab", "node_b", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
            [
                "connection__from_node",
                ["connection_ab", "node_a"],
                "connection_emergency_capacity",
                conn_emergency_cap_ab,
            ],
            [
                "connection__from_node",
                ["connection_bc", "node_b"],
                "connection_emergency_capacity",
                conn_emergency_cap_bc,
            ],
            [
                "connection__from_node",
                ["connection_ca", "node_c"],
                "connection_emergency_capacity",
                conn_emergency_cap_ca,
            ],
        ]
        SpineInterface.import_data(
            url_in;
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        constraint = m.ext[:spineopt].constraints[:connection_flow_lodf]
        @test length(constraint) == 3
        conn_cont = connection(:connection_ca)
        n_cont_to = node(:node_c)
        d_to = direction(:to_node)
        d_from = direction(:from_node)
        s_parent = stochastic_scenario(:parent)
        s_child = stochastic_scenario(:child)
        t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
        t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
        # connection_ab
        conn_mon = connection(:connection_ab)
        n_mon_to = node(:node_b)
        expected_con = @build_constraint(
            -1 <=
            (
                + var_connection_flow[conn_mon, n_mon_to, d_to, s_parent, t2h]
                - var_connection_flow[conn_mon, n_mon_to, d_from, s_parent, t2h]
                + SpineOpt.lodf(connection1=conn_cont, connection2=conn_mon) * (
                    + var_connection_flow[conn_cont, n_cont_to, d_to, s_parent, t1h1]
                    + var_connection_flow[conn_cont, n_cont_to, d_to, s_child, t1h2]
                    - var_connection_flow[conn_cont, n_cont_to, d_from, s_parent, t1h1]
                    - var_connection_flow[conn_cont, n_cont_to, d_from, s_child, t1h2]
                )
            ) / conn_emergency_cap_ab <=
            +1
        )
        observed_con = constraint_object(constraint[conn_cont, conn_mon, [s_parent, s_child], t2h])
        @test _is_constraint_equal(observed_con, expected_con)
        # connection_bc -- t1h1
        conn_mon = connection(:connection_bc)
        n_mon_to = node(:node_c)
        expected_con = @build_constraint(
            -1 <=
            (
                + var_connection_flow[conn_mon, n_mon_to, d_to, s_parent, t1h1]
                - var_connection_flow[conn_mon, n_mon_to, d_from, s_parent, t1h1]
                + SpineOpt.lodf(connection1=conn_cont, connection2=conn_mon) * (
                    + var_connection_flow[conn_cont, n_cont_to, d_to, s_parent, t1h1]
                    - var_connection_flow[conn_cont, n_cont_to, d_from, s_parent, t1h1]
                )
            ) / conn_emergency_cap_bc <=
            +1
        )
        observed_con = constraint_object(constraint[conn_cont, conn_mon, [s_parent], t1h1])
        @test _is_constraint_equal(observed_con, expected_con)
        # connection_bc -- t1h2
        expected_con = @build_constraint(
            -1 <=
            (
                + var_connection_flow[conn_mon, n_mon_to, d_to, s_child, t1h2]
                - var_connection_flow[conn_mon, n_mon_to, d_from, s_child, t1h2]
                + SpineOpt.lodf(connection1=conn_cont, connection2=conn_mon) * (
                    + var_connection_flow[conn_cont, n_cont_to, d_to, s_child, t1h2]
                    - var_connection_flow[conn_cont, n_cont_to, d_from, s_child, t1h2]
                )
            ) / conn_emergency_cap_bc <=
            +1
        )
        observed_con = constraint_object(constraint[conn_cont, conn_mon, [s_child], t1h2])
        @test _is_constraint_equal(observed_con, expected_con)
    end
    @testset "constraint_ratio_out_in_connection_flow" begin
        flow_ratio = 0.8
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T04:00:00")
        class = "connection__node__node"
        relationship = ["connection_ab", "node_b", "node_a"]
        object_parameter_values = [["model", "instance", "model_end", model_end]]
        relationships = [[class, relationship]]
        senses_by_prefix = Dict("min" => >=, "fix" => ==, "max" => <=)
        @testset for conn_flow_minutes_delay in (150, 180, 225)
            connection_flow_delay = Dict("type" => "duration", "data" => string(conn_flow_minutes_delay, "m"))
            h_delay = div(conn_flow_minutes_delay, 60)
            rem_minutes_delay = (conn_flow_minutes_delay % 60) / 60
            @testset for p in ("min", "fix", "max")
                _load_test_data(url_in, test_data)
                sense = senses_by_prefix[p]
                ratio = string(p, "_ratio_out_in_connection_flow")
                relationship_parameter_values = [
                    [class, relationship, "connection_flow_delay", connection_flow_delay],
                    [class, relationship, ratio, flow_ratio],
                ]
                SpineInterface.import_data(
                    url_in;
                    relationships=relationships,
                    object_parameter_values=object_parameter_values,
                    relationship_parameter_values=relationship_parameter_values,
                )

                m = run_spineopt(url_in; log_level=0, optimize=false)
                var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
                constraint = m.ext[:spineopt].constraints[Symbol(ratio)]
                @test length(constraint) == 2
                conn = connection(:connection_ab)
                n_from = node(:node_a)
                n_to = node(:node_b)
                d_from = direction(:from_node)
                d_to = direction(:to_node)
                scenarios_from = [repeat([stochastic_scenario(:child)], 3); repeat([stochastic_scenario(:parent)], 5)]
                time_slices_from = [
                    reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                    reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
                ]
                s_to = stochastic_scenario(:parent)
                @testset for (j, t_to) in enumerate(reverse(time_slice(m; temporal_block=temporal_block(:two_hourly))))
                    coeffs = (1 - rem_minutes_delay, 1, rem_minutes_delay)
                    i = 2 * j - 1
                    a = i + h_delay
                    b = min(a + 2, length(time_slices_from))
                    s_set = scenarios_from[a:b]
                    t_set = time_slices_from[a:b]
                    vars_conn_flow_from = (
                        var_connection_flow[conn, n_from, d_from, s_from, t_from] for (s_from, t_from) in
                                                                                      zip(s_set, t_set)
                    )
                    var_conn_flow_to = var_connection_flow[conn, n_to, d_to, s_to, t_to]
                    expected_con_ref = SpineOpt.sense_constraint(
                        m,
                        2 * var_conn_flow_to,
                        sense,
                        flow_ratio * sum(c * v for (c, v) in zip(coeffs, vars_conn_flow_from)),
                    )
                    expected_con = constraint_object(expected_con_ref)
                    path = reverse(unique(s_set))
                    con_key = (conn, n_to, n_from, path, t_to)
                    observed_con = constraint_object(constraint[con_key...])
                    @test _is_constraint_equal(observed_con, expected_con)
                end
            end
        end
    end
    @testset "constraint_connections_invested_transition" begin
        _load_test_data(url_in, test_data)
        candidate_connections = 1
        object_parameter_values = [["connection", "connection_ab", "candidate_connections", candidate_connections]]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]
        var_connections_invested = m.ext[:spineopt].variables[:connections_invested]
        var_connections_decommissioned = m.ext[:spineopt].variables[:connections_decommissioned]
        constraint = m.ext[:spineopt].constraints[:connections_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (connection(:connection_ab), s1, t1)
            var_c_inv_av1 = var_connections_invested_available[var_key1...]
            var_c_inv_1 = var_connections_invested[var_key1...]
            var_c_decom_1 = var_connections_decommissioned[var_key1...]
            @testset for (c, t0, t1) in connection_investment_dynamic_time_indices(
                m;
                connection=connection(:connection_ab),
                t_after=t1,
            )
                var_key0 = (c, s0, t0)
                var_c_inv_av0 = get(var_connections_invested_available, var_key0, 0)
                con_key = (c, path, t0, t1)
                expected_con = @build_constraint(var_c_inv_av1 - var_c_inv_1 + var_c_decom_1 == var_c_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_connections_invested_transition_mp" begin
        _load_test_data(url_in, test_data)
        candidate_connections = 4
        object_parameter_values = [
            ["connection", "connection_ab", "candidate_connections", candidate_connections],
            ["model", "master", "model_type", "spineopt_benders_master"],
            ["model", "instance", "model_type", "spineopt_standard"],
        ]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "hourly"]],
            ["connection__investment_temporal_block", ["connection_ab", "investments_hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "investments_deterministic"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m, mp = run_spineopt(url_in; log_level=0, optimize=false)
        var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]
        var_connections_invested = m.ext[:spineopt].variables[:connections_invested]
        var_connections_decommissioned = m.ext[:spineopt].variables[:connections_decommissioned]
        constraint = m.ext[:spineopt].constraints[:connections_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (connection(:connection_ab), s1, t1)
            var_c_inv_av1 = var_connections_invested_available[var_key1...]
            var_c_inv_1 = var_connections_invested[var_key1...]
            var_c_decom_1 = var_connections_decommissioned[var_key1...]
            @testset for (c, t0, t1) in connection_investment_dynamic_time_indices(
                m;
                connection=connection(:connection_ab),
                t_after=t1,
            )
                var_key0 = (c, s0, t0)
                var_c_inv_av0 = get(var_connections_invested_available, var_key0, 0)
                con_key = (c, path, t0, t1)
                expected_con = @build_constraint(var_c_inv_av1 - var_c_inv_1 + var_c_decom_1 == var_c_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end

        var_connections_invested_available = mp.ext[:spineopt].variables[:connections_invested_available]
        var_connections_invested = mp.ext[:spineopt].variables[:connections_invested]
        var_connections_decommissioned = mp.ext[:spineopt].variables[:connections_decommissioned]
        constraint = mp.ext[:spineopt].constraints[:connections_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(mp; temporal_block=temporal_block(:investments_hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (connection(:connection_ab), s1, t1)
            var_c_inv_av1 = var_connections_invested_available[var_key1...]
            var_c_inv_1 = var_connections_invested[var_key1...]
            var_c_decom_1 = var_connections_decommissioned[var_key1...]
            @testset for (c, t0, t1) in connection_investment_dynamic_time_indices(
                mp;
                connection=connection(:connection_ab),
                t_after=t1,
            )
                var_key0 = (c, s0, t0)
                var_c_inv_av0 = get(var_connections_invested_available, var_key0, 0)
                con_key = (c, path, t0, t1)
                expected_con = @build_constraint(var_c_inv_av1 - var_c_inv_1 + var_c_decom_1 == var_c_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_connection_lifetime" begin
        candidate_connections = 3
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for lifetime_minutes in (30, 180, 240)
            _load_test_data(url_in, test_data)
            connection_investment_lifetime = Dict("type" => "duration", "data" => string(lifetime_minutes, "m"))
            object_parameter_values = [
                ["connection", "connection_ab", "candidate_connections", candidate_connections],
                ["connection", "connection_ab", "connection_investment_lifetime", connection_investment_lifetime],
                ["model", "instance", "model_end", model_end],
            ]
            relationships = [
                ["connection__investment_temporal_block", ["connection_ab", "hourly"]],
                ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
            ]
            SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]
            var_connections_invested = m.ext[:spineopt].variables[:connections_invested]
            constraint = m.ext[:spineopt].constraints[:connection_lifetime]

            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                length(time_slice(m; temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
            tail_hours = round(Minute(lifetime_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                key = (connection(:connection_ab), path, t)
                var_c_inv_av_key = (connection(:connection_ab), s, t)
                var_c_inv_av = var_connections_invested_available[var_c_inv_av_key...]
                vars_c_inv =
                    [var_connections_invested[connection(:connection_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_c_inv_av >= sum(vars_c_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_connection_lifetime_mp" begin
        candidate_connections = 3
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for lifetime_minutes in (30, 180, 240)
            _load_test_data(url_in, test_data)
            connection_investment_lifetime = Dict("type" => "duration", "data" => string(lifetime_minutes, "m"))
            object_parameter_values = [
                ["connection", "connection_ab", "candidate_connections", candidate_connections],
                ["connection", "connection_ab", "connection_investment_lifetime", connection_investment_lifetime],
                ["model", "instance", "model_end", model_end],
                ["model", "master", "model_end", model_end],
                ["model", "master", "model_type", "spineopt_benders_master"],
                ["model", "instance", "model_type", "spineopt_standard"],
            ]
            relationships = [
                ["connection__investment_temporal_block", ["connection_ab", "hourly"]],
                ["connection__investment_temporal_block", ["connection_ab", "investments_hourly"]],
                ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
                ["connection__investment_stochastic_structure", ["connection_ab", "investments_deterministic"]],
            ]
            SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

            m, mp = run_spineopt(url_in; log_level=0, optimize=false)
            var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]
            var_connections_invested = m.ext[:spineopt].variables[:connections_invested]
            constraint = m.ext[:spineopt].constraints[:connection_lifetime]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                length(time_slice(m; temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
            tail_hours = round(Minute(lifetime_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                key = (connection(:connection_ab), path, t)
                var_c_inv_av_key = (connection(:connection_ab), s, t)
                var_c_inv_av = var_connections_invested_available[var_c_inv_av_key...]
                vars_c_inv =
                    [var_connections_invested[connection(:connection_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_c_inv_av >= sum(vars_c_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end

            var_connections_invested_available = mp.ext[:spineopt].variables[:connections_invested_available]
            var_connections_invested = mp.ext[:spineopt].variables[:connections_invested]
            constraint = mp.ext[:spineopt].constraints[:connection_lifetime]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours = length(time_slice(mp; temporal_block=temporal_block(:investments_hourly))) - Hour(1).value
            tail_hours = round(Minute(lifetime_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:parent)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(mp; temporal_block=temporal_block(:investments_hourly)))
                reverse(history_time_slice(mp; temporal_block=temporal_block(:investments_hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                key = (connection(:connection_ab), path, t)
                var_c_inv_av_key = (connection(:connection_ab), s, t)
                var_c_inv_av = var_connections_invested_available[var_c_inv_av_key...]
                vars_c_inv =
                    [var_connections_invested[connection(:connection_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_c_inv_av >= sum(vars_c_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_connections_invested_available" begin
        _load_test_data(url_in, test_data)
        candidate_connections = 7
        object_parameter_values = [["connection", "connection_ab", "candidate_connections", candidate_connections]]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]
        constraint = m.ext[:spineopt].constraints[:connections_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (connection(:connection_ab), s, t)
            var = var_connections_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_connections)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_connections_invested_available_mp" begin
        _load_test_data(url_in, test_data)
        candidate_connections = 7
        object_parameter_values = [
            ["connection", "connection_ab", "candidate_connections", candidate_connections],
            ["model", "master", "model_type", "spineopt_benders_master"],
            ["model", "instance", "model_type", "spineopt_standard"],
        ]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "hourly"]],
            ["connection__investment_temporal_block", ["connection_ab", "investments_hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "investments_deterministic"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m, mp = run_spineopt(url_in; log_level=0, optimize=false)
        var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]
        constraint = m.ext[:spineopt].constraints[:connections_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (connection(:connection_ab), s, t)
            var = var_connections_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_connections)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
        var_connections_invested_available = mp.ext[:spineopt].variables[:connections_invested_available]
        constraint = mp.ext[:spineopt].constraints[:connections_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        time_slices = time_slice(mp; temporal_block=temporal_block(:investments_hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (connection(:connection_ab), s, t)
            var = var_connections_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_connections)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_user_constraint_node_connection" begin
        @testset for sense in ("==", ">=", "<=")
            _load_test_data(url_in, test_data)
            rhs = 40
            unit_flow_coefficient = 25
            connection_flow_coefficient = 25
            demand_coefficient = 45
            node_state_coefficient = 55
            units_on_coefficient = 20
            units_started_up_coefficient = 35
            demand = 150

            objects = [["user_constraint", "constraint_x"], ["unit", "unit_c"]]
            relationships = [
                ["unit__to_node__user_constraint", ["unit_c", "node_c", "constraint_x"]],
                ["unit__user_constraint", ["unit_c", "constraint_x"]],
                ["connection__to_node__user_constraint", ["connection_ab", "node_b", "constraint_x"]],
                ["node__user_constraint", ["node_b", "constraint_x"]],
                ["units_on__temporal_block", ["unit_c", "hourly"]],
                ["units_on__stochastic_structure", ["unit_c", "stochastic"]],
                ["unit__to_node", ["unit_c", "node_c"]],
            ]
            object_parameter_values = [
                ["user_constraint", "constraint_x", "constraint_sense", Symbol(sense)],
                ["user_constraint", "constraint_x", "right_hand_side", rhs],
                ["node", "node_b", "demand", demand],
                ["node", "node_b", "has_state", true],
            ]
            relationship_parameter_values = [
                [relationships[1]..., "unit_flow_coefficient", unit_flow_coefficient],
                [relationships[2]..., "units_on_coefficient", units_on_coefficient],
                [relationships[2]..., "units_started_up_coefficient", units_started_up_coefficient],
                [relationships[3]..., "connection_flow_coefficient", connection_flow_coefficient],
                [relationships[4]..., "demand_coefficient", demand_coefficient],
                [relationships[4]..., "node_state_coefficient", node_state_coefficient],
            ]
            SpineInterface.import_data(
                url_in;
                objects=objects,
                relationships=relationships,
                object_parameter_values=object_parameter_values,
                relationship_parameter_values=relationship_parameter_values,
            )

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
            var_units_on = m.ext[:spineopt].variables[:units_on]
            var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
            var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
            var_node_state = m.ext[:spineopt].variables[:node_state]
            constraint = m.ext[:spineopt].constraints[:user_constraint]
            @test length(constraint) == 2
            key_a = (unit(:unit_c), node(:node_c), direction(:to_node))
            key_b = (connection(:connection_ab), node(:node_b), direction(:to_node))

            s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
            t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
            t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
            expected_con_ref = SpineOpt.sense_constraint(
                m,
                + unit_flow_coefficient
                * (var_unit_flow[key_a..., s_parent, t1h1] + var_unit_flow[key_a..., s_child, t1h2]) +
                2 * connection_flow_coefficient * var_connection_flow[key_b..., s_parent, t2h] +
                units_on_coefficient
                * (var_units_on[unit(:unit_c), s_parent, t1h1] + var_units_on[unit(:unit_c), s_child, t1h2]) +
                units_started_up_coefficient * (
                    var_units_started_up[unit(:unit_c), s_parent, t1h1]
                    + var_units_started_up[unit(:unit_c), s_child, t1h2]
                ) +
                2 * node_state_coefficient * var_node_state[node(:node_b), s_parent, t2h] +
                2 * demand_coefficient * demand,
                Symbol(sense),
                rhs,
            )
            expected_con = constraint_object(expected_con_ref)
            con_key = (user_constraint(:constraint_x), [s_parent, s_child], t2h)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
            return
        end
    end
    @testset "constraint_connection_flow_intact_flow" begin
        # TODO: node_ptdf_threshold
        conn_r = 0.9
        conn_x = 0.1
        candidate_connections = 1
        _load_test_data(url_in, test_data)
        objects = [["commodity", "electricity"]]
        relationships = [
            ["connection__from_node", ["connection_ab", "node_b"]],
            ["connection__to_node", ["connection_ab", "node_a"]],
            ["connection__from_node", ["connection_bc", "node_c"]],
            ["connection__to_node", ["connection_bc", "node_b"]],
            ["connection__from_node", ["connection_ca", "node_a"]],
            ["connection__to_node", ["connection_ca", "node_c"]],
            ["node__commodity", ["node_a", "electricity"]],
            ["node__commodity", ["node_b", "electricity"]],
            ["node__commodity", ["node_c", "electricity"]],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"]],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"]],
        ]
        object_parameter_values = [
            ["connection", "connection_ab", "connection_monitored", true],
            ["connection", "connection_ab", "connection_reactance", conn_x],
            ["connection", "connection_ab", "connection_resistance", conn_r],
            ["connection", "connection_ab", "candidate_connections", candidate_connections],
            ["connection", "connection_bc", "connection_monitored", true],
            ["connection", "connection_bc", "connection_reactance", conn_x],
            ["connection", "connection_bc", "connection_resistance", conn_r],
            ["connection", "connection_ca", "connection_monitored", true],
            ["connection", "connection_ca", "connection_reactance", conn_x],
            ["connection", "connection_ca", "connection_resistance", conn_r],
            ["commodity", "electricity", "commodity_physics", "commodity_physics_ptdf"],
            ["node", "node_a", "node_opf_type", "node_opf_type_reference"],
        ]
        relationship_parameter_values = [
            ["connection__node__node", ["connection_ab", "node_b", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
        ]
        SpineInterface.import_data(
            url_in;
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        constraint = m.ext[:spineopt].constraints[:connection_flow_intact_flow]
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        var_connection_intact_flow = m.ext[:spineopt].variables[:connection_intact_flow]
        @test length(constraint) == 2
        conn_k = connection(:connection_ab)
        n_to_k = node(:node_b)
        @testset for (conn_l, n_to_l) in
                     ((connection(:connection_bc), node(:node_c)), (connection(:connection_ca), node(:node_a)))
            s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
            t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
            t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
            lodf_val = SpineOpt.lodf(connection1=conn_k, connection2=conn_l)
            expected_con = @build_constraint(
                - var_connection_flow[conn_l, n_to_l, direction(:to_node), s_parent, t1h1] +
                var_connection_flow[conn_l, n_to_l, direction(:from_node), s_parent, t1h1] +
                var_connection_intact_flow[conn_l, n_to_l, direction(:to_node), s_parent, t1h1]
                - var_connection_intact_flow[conn_l, n_to_l, direction(:from_node), s_parent, t1h1]
                - var_connection_flow[conn_l, n_to_l, direction(:to_node), s_child, t1h2] +
                var_connection_flow[conn_l, n_to_l, direction(:from_node), s_child, t1h2] +
                var_connection_intact_flow[conn_l, n_to_l, direction(:to_node), s_child, t1h2]
                - var_connection_intact_flow[conn_l, n_to_l, direction(:from_node), s_child, t1h2] ==
                2
                * lodf_val
                * (+ var_connection_flow[
                    conn_k,
                    n_to_k,
                    direction(:to_node),
                    s_parent,
                    t2h,
                ] - var_connection_flow[
                    conn_k,
                    n_to_k,
                    direction(:from_node),
                    s_parent,
                    t2h,
                ] - var_connection_intact_flow[
                    conn_k,
                    n_to_k,
                    direction(:to_node),
                    s_parent,
                    t2h,
                ] + var_connection_intact_flow[conn_k, n_to_k, direction(:from_node), s_parent, t2h])
            )
            observed_con = constraint_object(constraint[conn_l, n_to_l, [s_parent, s_child], t2h])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_candidate_connection_lb" begin
        conn_r = 0.9
        conn_x = 0.1
        candidate_connections = 1
        connection_capacity = 100
        _load_test_data(url_in, test_data)

        objects = [["commodity", "electricity"]]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "two_hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
            ["connection__from_node", ["connection_ab", "node_b"]],
            ["connection__to_node", ["connection_ab", "node_a"]],
            ["connection__from_node", ["connection_bc", "node_c"]],
            ["connection__to_node", ["connection_bc", "node_b"]],
            ["connection__from_node", ["connection_ca", "node_a"]],
            ["connection__to_node", ["connection_ca", "node_c"]],
            ["node__commodity", ["node_a", "electricity"]],
            ["node__commodity", ["node_b", "electricity"]],
            ["node__commodity", ["node_c", "electricity"]],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"]],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"]],
        ]
        object_parameter_values = [
            ["connection", "connection_ab", "connection_monitored", true],
            ["connection", "connection_ab", "connection_reactance", conn_x],
            ["connection", "connection_ab", "connection_resistance", conn_r],
            ["connection", "connection_ab", "candidate_connections", candidate_connections],
            [
                "connection",
                "connection_ab",
                "connection_investment_lifetime",
                Dict("type" => "duration", "data" => "60m"),
            ],
            ["connection", "connection_bc", "connection_monitored", true],
            ["connection", "connection_bc", "connection_reactance", conn_x],
            ["connection", "connection_bc", "connection_resistance", conn_r],
            ["connection", "connection_ca", "connection_monitored", true],
            ["connection", "connection_ca", "connection_reactance", conn_x],
            ["connection", "connection_ca", "connection_resistance", conn_r],
            ["commodity", "electricity", "commodity_physics", "commodity_physics_ptdf"],
            ["node", "node_a", "node_opf_type", "node_opf_type_reference"],
        ]
        relationship_parameter_values = [
            ["connection__from_node", ["connection_ab", "node_b"], "connection_capacity", connection_capacity],
            ["connection__to_node", ["connection_ab", "node_a"], "connection_capacity", connection_capacity],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
        ]
        SpineInterface.import_data(
            url_in;
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        constraint = m.ext[:spineopt].constraints[:candidate_connection_flow_lb]
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        var_connection_intact_flow = m.ext[:spineopt].variables[:connection_intact_flow]
        var_connections_invested_available = m.ext[:spineopt].variables[:connections_invested_available]
        @test length(constraint) == 6
        conn = connection(:connection_ab)
        n_to = node(:node_b)
        t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
        s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)

        @testset for (n, d, tb) in (
            (node(:node_a), direction(:to_node), temporal_block(:hourly)),
            (node(:node_b), direction(:from_node), temporal_block(:two_hourly)),
        )
            scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
            time_slices = time_slice(m; temporal_block=tb)
            @testset for (s, t) in zip(scenarios, time_slices)
                expected_con = @build_constraint(
                    + var_connection_flow[conn, n, d, s, t] * duration(t) >=
                    + var_connection_intact_flow[conn, n, d, s, t] * duration(t)
                    - (candidate_connections - var_connections_invested_available[conn, s_parent, t2h])
                    * connection_capacity
                    * duration(t)
                )
                s_path = (s == s_parent ? [s] : [s_parent, s_child])
                con_key = (conn, n, d, s_path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
        @testset for (n, d, tb) in (
            (node(:node_a), direction(:from_node), temporal_block(:hourly)),
            (node(:node_b), direction(:to_node), temporal_block(:two_hourly)),
        )
            scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
            time_slices = time_slice(m; temporal_block=tb)
            @testset for (s, t) in zip(scenarios, time_slices)
                expected_con = @build_constraint(
                    + var_connection_flow[conn, n, d, s, t] * duration(t) >=
                    + var_connection_intact_flow[conn, n, d, s, t] * duration(t)
                    - (candidate_connections - var_connections_invested_available[conn, s_parent, t2h])
                    * 1000000
                    * duration(t)
                )
                print(expected_con)
                s_path = (s == s_parent ? [s] : [s_parent, s_child])
                con_key = (conn, n, d, s_path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_candidate_connection_lb" begin
        conn_r = 0.9
        conn_x = 0.1
        candidate_connections = 1
        connection_capacity = 100
        _load_test_data(url_in, test_data)

        objects = [["commodity", "electricity"]]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "two_hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
            ["connection__from_node", ["connection_ab", "node_b"]],
            ["connection__to_node", ["connection_ab", "node_a"]],
            ["connection__from_node", ["connection_bc", "node_c"]],
            ["connection__to_node", ["connection_bc", "node_b"]],
            ["connection__from_node", ["connection_ca", "node_a"]],
            ["connection__to_node", ["connection_ca", "node_c"]],
            ["node__commodity", ["node_a", "electricity"]],
            ["node__commodity", ["node_b", "electricity"]],
            ["node__commodity", ["node_c", "electricity"]],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"]],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"]],
        ]
        object_parameter_values = [
            ["connection", "connection_ab", "connection_monitored", true],
            ["connection", "connection_ab", "connection_reactance", conn_x],
            ["connection", "connection_ab", "connection_resistance", conn_r],
            ["connection", "connection_ab", "candidate_connections", candidate_connections],
            [
                "connection",
                "connection_ab",
                "connection_investment_lifetime",
                Dict("type" => "duration", "data" => "60m"),
            ],
            ["connection", "connection_bc", "connection_monitored", true],
            ["connection", "connection_bc", "connection_reactance", conn_x],
            ["connection", "connection_bc", "connection_resistance", conn_r],
            ["connection", "connection_ca", "connection_monitored", true],
            ["connection", "connection_ca", "connection_reactance", conn_x],
            ["connection", "connection_ca", "connection_resistance", conn_r],
            ["commodity", "electricity", "commodity_physics", "commodity_physics_ptdf"],
            ["node", "node_a", "node_opf_type", "node_opf_type_reference"],
        ]
        relationship_parameter_values = [
            ["connection__from_node", ["connection_ab", "node_b"], "connection_capacity", connection_capacity],
            ["connection__to_node", ["connection_ab", "node_a"], "connection_capacity", connection_capacity],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
        ]
        SpineInterface.import_data(
            url_in;
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        constraint = m.ext[:spineopt].constraints[:ratio_out_in_connection_intact_flow]
        var_connection_intact_flow = m.ext[:spineopt].variables[:connection_intact_flow]
        @test length(constraint) == 8

        conn = connection(:connection_ab)
        n_to = node(:node_b)
        t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
        t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
        s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
        @testset for (conn, n_in, n_out, tb_in, tb_out) in (
            (
                connection(:connection_ab),
                node(:node_a),
                node(:node_b),
                temporal_block(:hourly),
                temporal_block(:two_hourly),
            ),
            (
                connection(:connection_bc),
                node(:node_c),
                node(:node_b),
                temporal_block(:hourly),
                temporal_block(:two_hourly),
            ),
        )
            expected_con = @build_constraint(
                + var_connection_intact_flow[conn, n_in, direction(:to_node), s_parent, t1h1]
                + var_connection_intact_flow[conn, n_in, direction(:to_node), s_child, t1h2] ==
                +2 * var_connection_intact_flow[conn, n_out, direction(:from_node), s_parent, t2h]
            )
            s_path = [s_parent, s_child]
            con_key = (conn, n_in, n_out, s_path, t2h)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
        @testset for (conn, n_in, n_out, tb_in, tb_out) in (
            (
                connection(:connection_ab),
                node(:node_b),
                node(:node_a),
                temporal_block(:hourly),
                temporal_block(:two_hourly),
            ),
            (
                connection(:connection_bc),
                node(:node_b),
                node(:node_c),
                temporal_block(:hourly),
                temporal_block(:two_hourly),
            ),
        )
            expected_con = @build_constraint(
                +2 * var_connection_intact_flow[conn, n_in, direction(:to_node), s_parent, t2h] ==
                + var_connection_intact_flow[conn, n_out, direction(:from_node), s_parent, t1h1]
                + var_connection_intact_flow[conn, n_out, direction(:from_node), s_child, t1h2]
            )
            s_path = [s_parent, s_child]
            con_key = (conn, n_in, n_out, s_path, t2h)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
        @testset for (conn, n_in, n_out, tb_in, tb_out) in (
            (
                connection(:connection_ca),
                node(:node_c),
                node(:node_a),
                temporal_block(:hourly),
                temporal_block(:hourly),
            ),
            (
                connection(:connection_ca),
                node(:node_a),
                node(:node_c),
                temporal_block(:hourly),
                temporal_block(:hourly),
            ),
        )
            scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
            time_slices = time_slice(m; temporal_block=tb_in)
            @testset for (s, t) in zip(scenarios, time_slices)
                expected_con = @build_constraint(
                    + var_connection_intact_flow[conn, n_in, direction(:to_node), s, t] ==
                    + var_connection_intact_flow[conn, n_out, direction(:from_node), s, t]
                )
                s_path = [s]
                con_key = (conn, n_in, n_out, s_path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_candidate_connection_ub" begin
        conn_r = 0.9
        conn_x = 0.1
        candidate_connections = 1
        _load_test_data(url_in, test_data)

        objects = [["commodity", "electricity"]]
        relationships = [
            ["connection__investment_temporal_block", ["connection_ab", "two_hourly"]],
            ["connection__investment_stochastic_structure", ["connection_ab", "stochastic"]],
            ["connection__from_node", ["connection_ab", "node_b"]],
            ["connection__to_node", ["connection_ab", "node_a"]],
            ["connection__from_node", ["connection_bc", "node_c"]],
            ["connection__to_node", ["connection_bc", "node_b"]],
            ["connection__from_node", ["connection_ca", "node_a"]],
            ["connection__to_node", ["connection_ca", "node_c"]],
            ["node__commodity", ["node_a", "electricity"]],
            ["node__commodity", ["node_b", "electricity"]],
            ["node__commodity", ["node_c", "electricity"]],
            ["connection__node__node", ["connection_ab", "node_b", "node_a"]],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"]],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"]],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"]],
        ]
        object_parameter_values = [
            ["connection", "connection_ab", "connection_monitored", true],
            ["connection", "connection_ab", "connection_reactance", conn_x],
            ["connection", "connection_ab", "connection_resistance", conn_r],
            ["connection", "connection_ab", "candidate_connections", candidate_connections],
            [
                "connection",
                "connection_ab",
                "connection_investment_lifetime",
                Dict("type" => "duration", "data" => "60m"),
            ],
            ["connection", "connection_bc", "connection_monitored", true],
            ["connection", "connection_bc", "connection_reactance", conn_x],
            ["connection", "connection_bc", "connection_resistance", conn_r],
            ["connection", "connection_ca", "connection_monitored", true],
            ["connection", "connection_ca", "connection_reactance", conn_x],
            ["connection", "connection_ca", "connection_resistance", conn_r],
            ["commodity", "electricity", "commodity_physics", "commodity_physics_ptdf"],
            ["node", "node_a", "node_opf_type", "node_opf_type_reference"],
        ]
        relationship_parameter_values = [
            ["connection__node__node", ["connection_ab", "node_b", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ab", "node_a", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_c", "node_b"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_bc", "node_b", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_a", "node_c"], "fix_ratio_out_in_connection_flow", 1.0],
            ["connection__node__node", ["connection_ca", "node_c", "node_a"], "fix_ratio_out_in_connection_flow", 1.0],
        ]
        SpineInterface.import_data(
            url_in;
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        constraint = m.ext[:spineopt].constraints[:candidate_connection_flow_ub]
        var_connection_intact_flow = m.ext[:spineopt].variables[:connection_intact_flow]
        var_connection_flow = m.ext[:spineopt].variables[:connection_flow]
        @test length(constraint) == 6
        t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
        t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
        s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)

        @testset for (c, n, d) in (
            (connection(:connection_ab), node(:node_a), direction(:from_node)),
            (connection(:connection_ab), node(:node_a), direction(:to_node)),
        )
            scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
            time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
            @testset for (s, t) in zip(scenarios, time_slices)
                expected_con = @build_constraint(
                    + var_connection_flow[c, n, d, s, t] <= + var_connection_intact_flow[c, n, d, s, t]
                )
                s_path = s
                con_key = (c, n, d, s_path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
        @testset for (c, n, d) in (
            (connection(:connection_ab), node(:node_b), direction(:from_node)),
            (connection(:connection_ab), node(:node_b), direction(:to_node)),
        )
            scenarios = (stochastic_scenario(:parent))
            time_slices = time_slice(m; temporal_block=temporal_block(:two_hourly))
            @testset for (s, t) in zip(scenarios, time_slices)
                expected_con = @build_constraint(
                    + var_connection_flow[c, n, d, s, t] <= + var_connection_intact_flow[c, n, d, s, t]
                )
                s_path = s
                con_key = (c, n, d, s_path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
end
