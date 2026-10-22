# ==============================================================================
# EE577B Phase 1 - Synopsys DC Synthesis Script for router_node
# Target Technology: FreePDK45 / gscl45nm (45nm Standard Cell Library)
# Target Frequency: 250 MHz (Clock Period = 4.0 ns)
# ==============================================================================

# Setup Library Paths
set osu45_lib_dir "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files"
set search_path [list . $osu45_lib_dir [getenv SYNOPSYS_DC]/libraries/syn $search_path]

set target_library [list gscl45nm.db]
set synthetic_library [list dw_foundation.sldb standard.sldb]
set link_library [list * gscl45nm.db dw_foundation.sldb standard.sldb]

# Design Settings
set DESIGN_NAME "router_node"

# Read Hierarchical RTL files (Controllers first, then top router_node)
read_verilog [list rtl/router/router_input_ctrl.v rtl/router/router_output_ctrl.v rtl/router/router_node.v]
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
check_design > report/router_node.check_design

# Synthesize / Compile
compile -map_effort high

# Post-Compile Check
check_design >> report/router_node.check_design

# Export Gate-Level Netlist
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output netlist/router_node.syn.v

# Reports
report_timing > report/router_node.timing
report_area   > report/router_node.area
report_power  > report/router_node.power

quit
