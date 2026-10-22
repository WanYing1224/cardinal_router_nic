set log file report/cardinal_nic.lec -replace

read library -both -verilog include/gscl45nm.v

read design rtl/nic/cardinal_nic.v -golden -verilog
read design netlist/cardinal_nic.syn.v -revised -verilog

set system mode lec
add compared points -all
compare

report compare data
exit -f
