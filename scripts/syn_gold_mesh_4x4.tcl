# Setup Library Paths
set osu45_lib_dir "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files"
set search_path [list . $osu45_lib_dir [getenv SYNOPSYS_DC]/libraries/syn $search_path]

set target_library [list gscl45nm.db]
set synthetic_library [list dw_foundation.sldb standard.sldb]
set link_library [list * gscl45nm.db dw_foundation.sldb standard.sldb]

# Design Settings
set DESIGN_NAME "gold_mesh_4x4"

# Read All RTL Files on a single line
read_verilog [list rtl/router/router_input_ctrl.v rtl/router/router_output_ctrl.v rtl/router/router_node.v rtl/mesh/gold_mesh_4x4.v]

current_design $DESIGN_NAME
link

# Timing Constraints (250 MHz -> 4.0 ns period)
create_clock -name "clk" -period 4.0 -waveform {0.0 2.0} [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition  0.1 [get_clocks clk]

set_input_delay  0.4 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 0.4 -clock clk [all_outputs]
set_load 0.05 [all_outputs]

# Pre-Compile Check
check_design > report/gold_mesh_4x4.check_design

# Synthesize / Compile
compile -map_effort medium

# Post-Compile Check
check_design >> report/gold_mesh_4x4.check_design

# Export Gate-Level Netlist
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output netlist/gold_mesh_4x4.syn.v

# Reports
report_timing > report/gold_mesh_4x4.timing
report_area   > report/gold_mesh_4x4.area
report_power  > report/gold_mesh_4x4.power

quit
