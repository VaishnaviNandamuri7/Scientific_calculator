# sim.tcl - opens the project if needed, then runs the testbench again.
#
# Usage in the Vivado Tcl console:
#     source C:/DEV/Scientific_calculator/Scripts/sim.tcl
# To run a different testbench, set its name first:
#     set tb_name IFU_tb ; source C:/DEV/Scientific_calculator/Scripts/sim.tcl

set script_dir [file normalize [file dirname [info script]]]
set xpr [file join $script_dir CALC_PRO CALC_PRO.xpr]

if {![info exists tb_name]} {
    set tb_name "Top_RISC_tb"
}

# A plain Tcl session starts with an "in-memory" project (no files in it).
# If that is the case, open our real project first.
if {[catch {get_property IN_MEMORY [current_project]} in_memory]} {
    set in_memory 1
}
if {$in_memory} {
    if {[file exists $xpr]} {
        open_project $xpr
    } else {
        puts "ERROR: project not found: $xpr"
        puts "Create it first with:  source $script_dir/build.tcl"
        return
    }
}

# close the old simulation if there is one (the error is ignored if there is none)
catch {close_sim -quiet}

set_property top $tb_name [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation

# keep running until the testbench calls $finish (ignored if it already finished)
catch {run all}