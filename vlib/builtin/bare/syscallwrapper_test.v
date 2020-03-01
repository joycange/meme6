import (
	os
	filepath
)

fn test_syscallwrappers() {
	if true { return }
	$if linux {
		$if x64 {
			exe := os.executable()
			vdir := filepath.dir(exe)
			if vdir.len > 1 {
				dot_checks := vdir + "/.checks"
				assert os.is_dir(dot_checks)

				os.chdir(dot_checks)
				checks_v := "checks.v"
				assert os.is_exist(checks_v)
				rc := os.exec("v run $checks_v") or { panic(err) }
				assert !rc.output.contains("V panic: An assertion failed.")
				assert !rc.output.contains("failed")
				assert rc.exit_code == 0
			} else {
				panic("Can't find test directory")
			}
		}
	}
}
