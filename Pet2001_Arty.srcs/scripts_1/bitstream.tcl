
set project_name "[lindex $::argv 0]"
set origin_proj_dir [file normalize ./$project_name]

open_project $origin_proj_dir/$project_name.xpr

# reset runs
reset_run synth_1
reset_run impl_1

# synthesis
launch_runs synth_1 -jobs 2
wait_on_run synth_1

# implementation
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

