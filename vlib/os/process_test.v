import os
import time

const (
	vexe = os.getenv('VEXE')
	vroot = os.dir(vexe)
	test_os_process = os.join_path(os.temp_dir(), 'v', 'test_os_process.exe')
	test_os_process_source = os.join_path(vroot, 'cmd/tools/test_os_process.v')
	test_os_process_exe = os.join_path(vroot, 'cmd/tools/test_os_process.exe')
)

fn testsuite_begin() ? {
	os.rm(test_os_process) or {}
	if os.exists(test_os_process_exe) {
		os.cp(test_os_process_exe, test_os_process) ?
	}
	$if !windows {
		os.system('$vexe -o $test_os_process $test_os_process_source')
	}
	assert os.exists(test_os_process)
}

fn test_getpid() {
	pid := os.getpid()
	eprintln('current pid: $pid')
	assert pid != 0
}

fn test_run() {
	mut p := os.new_process(test_os_process)
	p.set_args(['-timeout_ms', '150', '-period_ms', '50'])
	p.run()
	assert p.status == .running
	assert p.pid > 0
	assert p.pid != os.getpid()
	mut i := 0
	for {
		if !p.is_alive() {
			break
		}
		$if trace_process_output ? {
			os.system('ps -opid= -oppid= -ouser= -onice= -of= -ovsz= -orss= -otime= -oargs= -p $p.pid')
		}
		time.sleep(50 * time.millisecond)
		i++
	}
	p.wait()
	assert p.code == 0
	assert p.status == .exited
	//
	eprintln('polling iterations: $i')
	assert i < 20
}

fn test_wait() {
	mut p := os.new_process(test_os_process)
	assert p.status != .exited
	p.wait()
	assert p.status == .exited
	assert p.code == 0
	assert p.pid != os.getpid()
}

fn test_slurping_output() {
	mut p := os.new_process(test_os_process)
	p.set_args(['-timeout_ms', '500', '-period_ms', '50'])
	p.set_redirect_stdio()
	assert p.status != .exited
	p.wait()
	assert p.status == .exited
	assert p.code == 0
	output := p.stdout_slurp().trim_space()
	errors := p.stderr_slurp().trim_space()
	$if trace_process_output ? {
		eprintln('---------------------------')
		eprintln('p output: "$output"')
		eprintln('p errors: "$errors"')
		eprintln('---------------------------')
	}
	dump(output)
	assert output.contains('stdout, 1')
	assert output.contains('stdout, 2')
	assert output.contains('stdout, 3')
	assert output.contains('stdout, 4')
	assert errors.contains('stderr, 1')
	assert errors.contains('stderr, 2')
	assert errors.contains('stderr, 3')
	assert errors.contains('stderr, 4')
}
