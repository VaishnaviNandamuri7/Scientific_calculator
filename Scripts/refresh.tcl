# refresh.tcl - adds files that appeared (e.g. after git pull) to the OPEN project.
# Usage in the Tcl console:  source Scripts/refresh.tcl
set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]

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

proc add_missing {fileset files} {
    set known {}
    foreach f [get_files -quiet -of_objects [get_filesets $fileset]] { lappend known [file normalize $f] }
    set n 0
    foreach f $files {
        if {[lsearch -exact $known [file normalize $f]] < 0} {
            add_files -norecurse -fileset $fileset $f
            puts "added to $fileset: $f"
            incr n
        }
    }
    return $n
}

set n 0
incr n [add_missing sources_1 [find_files $repo_root/RTL {*.v *.sv *.vh *.svh *.vhd}]]
incr n [add_missing sim_1     [find_files $repo_root/TB  {*.v *.sv *.vh *.svh *.vhd *.hex *.mem *.coe}]]
incr n [add_missing sim_1     [find_files $repo_root/programs {*.hex *.mem *.coe}]]
incr n [add_missing constrs_1 [find_files $repo_root/Constraints {*.xdc}]]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "INFO: refresh done, $n new file(s) added."