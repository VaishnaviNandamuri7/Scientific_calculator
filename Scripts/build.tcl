# =============================================================================
# build.tcl - (re)creates the Vivado project from the sources in this repo.
#
# Vivado Tcl console:  cd <repo>   then   source Scripts/build.tcl
# cmd (batch):         vivado -mode batch -source Scripts/build.tcl
# Optional args:       -tclargs --name CALC_TEST --sim_top IFU_tb --rtl_top Top_RISC
#
# Everything is found by folder, so new files need NO edits here.
# Files are referenced in place (never copied into the project).
# =============================================================================

# ---------- settings you may want to change ----------
set proj_name "CALC_PRO"
set part      "xc7a100tcsg324-1"   ;# Nexys 4 DDR. Change if you use another board.
set rtl_top   "Top_RISC"           ;# synthesis top, used once the module exists
set sim_top   "IMU_tb"             ;# default simulation top, switch any time with: tb <name>
# -----------------------------------------------------

# Optional overrides from the Tcl shell or -tclargs
if { [info exists ::user_project_name] } { set proj_name $::user_project_name }
for {set i 0} {$i < $::argc} {incr i} {
    switch -- [lindex $::argv $i] {
        "--name"    { incr i; set proj_name [lindex $::argv $i] }
        "--sim_top" { incr i; set sim_top   [lindex $::argv $i] }
        "--rtl_top" { incr i; set rtl_top   [lindex $::argv $i] }
    }
}

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]

# Recursively collect files matching any pattern under dir
proc find_files {dir patterns} {
    set out {}
    foreach p $patterns {
        set out [concat $out [glob -nocomplain -directory $dir -types f $p]]
    }
    foreach sub [glob -nocomplain -directory $dir -types d *] {
        set out [concat $out [find_files $sub $patterns]]
    }
    return $out
}

# Close any open project so -force can overwrite cleanly
catch {close_project -quiet}

create_project $proj_name [file join $script_dir $proj_name] -part $part -force

# ---------- design sources ----------
set rtl_files [find_files [file join $repo_root RTL] {*.v *.sv *.vh *.svh *.vhd}]
if {[llength $rtl_files]} { add_files -norecurse -fileset sources_1 $rtl_files }
set_property include_dirs [list [file join $repo_root RTL]] [get_filesets sources_1]

# ---------- simulation sources ----------
set tb_files   [find_files [file join $repo_root TB] {*.v *.sv *.vh *.svh *.vhd}]
set data_files [concat \
    [find_files [file join $repo_root TB]       {*.hex *.mem *.coe}] \
    [find_files [file join $repo_root programs] {*.hex *.mem *.coe}]]
if {[llength $tb_files]}   { add_files -norecurse -fileset sim_1 $tb_files }
if {[llength $data_files]} { add_files -norecurse -fileset sim_1 $data_files }

# ---------- constraints ----------
set xdc_files [find_files [file join $repo_root Constraints] {*.xdc}]
if {[llength $xdc_files]} { add_files -norecurse -fileset constrs_1 $xdc_files }

# ---------- tops ----------
if {[lsearch -glob $rtl_files "*/$rtl_top.*"] >= 0} {
    set_property top $rtl_top [get_filesets sources_1]
} else {
    puts "WARNING: RTL top '$rtl_top' not found, letting Vivado pick one."
}
if {[lsearch -glob $tb_files "*/$sim_top.*"] >= 0} {
    set_property top $sim_top [get_filesets sim_1]
} else {
    puts "WARNING: sim top '$sim_top' not found in TB/, letting Vivado pick one."
}
set_property top_lib xil_defaultlib [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# ---------- helper: switch testbench and run it ----------
#   tb IFU_tb      -> sets IFU_tb as sim top and launches the simulation
proc tb {name} {
    set_property top $name [get_filesets sim_1]
    update_compile_order -fileset sim_1
    launch_simulation
}

puts "INFO: Project '$proj_name' created with [llength $rtl_files] RTL, [llength $tb_files] TB, [llength $data_files] data files."
puts "INFO: Run a testbench with:  tb <module_name>"