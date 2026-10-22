set log file report/router_node.lec -replace

read library -both -verilog include/gscl45nm.v

read design rtl/router/router_input_ctrl.v rtl/router/router_output_ctrl.v rtl/router/router_node.v -golden -verilog
read design netlist/router_node.syn.v -revised -verilog

set system mode lec
add compared points -all
compare

report compare data
exit -f