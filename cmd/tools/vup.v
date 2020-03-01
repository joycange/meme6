module main

import (
	os
	filepath
	v.pref
)

fn main() {
	println('Updating V...')
	vroot := filepath.dir(pref.vexe_path())
	os.chdir(vroot)
	// git pull
	s := os.exec('git pull --rebase origin master') or {
		panic(err)
	}
	println(s.output)

	$if windows {
		v_backup_file := 'v_old.exe'
		if os.is_exist(v_backup_file) {
			os.remove(v_backup_file)
		}
		os.rename('v.exe', v_backup_file)

		s2 := os.exec('make.bat') or {
			panic(err)
		}
		println(s2.output)
	} $else {
		s2 := os.exec('make') or {
			panic(err)
		}
		println(s2.output)
	}
}
