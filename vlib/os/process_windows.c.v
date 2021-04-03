module os

fn C.GetModuleHandleA(charptr) HMODULE
fn C.GetProcAddress(handle voidptr, procname byteptr) voidptr
fn C.TerminateProcess(process HANDLE, exit_code u32) bool

type FN_NTSuspendResume = fn (voidptr)

fn ntdll_fn(name charptr) FN_NTSuspendResume {
	ntdll := C.GetModuleHandleA(c'NTDLL')
	if ntdll == 0 {
		return FN_NTSuspendResume(0)
	}
	the_fn := FN_NTSuspendResume(C.GetProcAddress(ntdll, name))
	return the_fn
}

pub struct WProcess {
pub mut:
	proc_info    ProcessInformation
	command_line [65536]byte
	child_stdin  &u32
	//
	child_stdout_read  &u32
	child_stdout_write &u32
	//
	child_stderr_read  &u32
	child_stderr_write &u32
}

fn (mut p Process) win_spawn_process() int {
	mut wdata := &WProcess{
		child_stdin: 0
		child_stdout_read: 0
		child_stdout_write: 0
		child_stderr_read: 0
		child_stderr_write: 0
	}
	p.wdata = voidptr(wdata)
	mut start_info := StartupInfo{
		lp_reserved: 0
		lp_desktop: 0
		lp_title: 0
		cb: sizeof(C.PROCESS_INFORMATION)
	}
	if p.use_stdio_ctl {
		mut sa := SecurityAttributes{}
		sa.n_length = sizeof(C.SECURITY_ATTRIBUTES)
		sa.b_inherit_handle = true
		create_pipe_ok1 := C.CreatePipe(voidptr(&wdata.child_stdout_read), voidptr(&wdata.child_stdout_write),
			voidptr(&sa), 0)
		if !create_pipe_ok1 {
			error_num := int(C.GetLastError())
			error_msg := get_error_msg(error_num)
			eprintln('exec failed (CreatePipe): $error_msg')
			exit(1)
		}
		set_handle_info_ok1 := C.SetHandleInformation(wdata.child_stdout_read, C.HANDLE_FLAG_INHERIT,
			0)
		if !set_handle_info_ok1 {
			error_num := int(C.GetLastError())
			error_msg := get_error_msg(error_num)
			eprintln('exec failed (SetHandleInformation): $error_msg')
			exit(1)
		}
		create_pipe_ok2 := C.CreatePipe(voidptr(&wdata.child_stderr_read), voidptr(&wdata.child_stderr_write),
			voidptr(&sa), 0)
		if !create_pipe_ok2 {
			error_num := int(C.GetLastError())
			error_msg := get_error_msg(error_num)
			eprintln('exec failed (CreatePipe): $error_msg')
			exit(1)
		}
		set_handle_info_ok2 := C.SetHandleInformation(wdata.child_stderr_read, C.HANDLE_FLAG_INHERIT,
			0)
		if !set_handle_info_ok2 {
			error_num := int(C.GetLastError())
			error_msg := get_error_msg(error_num)
			eprintln('exec failed (SetHandleInformation): $error_msg')
			exit(1)
		}
		start_info.h_std_input = wdata.child_stdin
		start_info.h_std_output = wdata.child_stdout_write
		start_info.h_std_error = wdata.child_stderr_write
		start_info.dw_flags = u32(C.STARTF_USESTDHANDLES)
	}

	cmd := '$p.filename ' + p.args.join(' ')
	C.ExpandEnvironmentStringsW(cmd.to_wide(), voidptr(&wdata.command_line[0]), 32768)
	create_process_ok := C.CreateProcessW(0, &wdata.command_line[0], 0, 0, C.TRUE, 0,
		0, 0, voidptr(&start_info), voidptr(&wdata.proc_info))
	if !create_process_ok {
		error_num := int(C.GetLastError())
		error_msg := get_error_msg(error_num)
		eprintln('exec failed (CreateProcess) with code $error_num: $error_msg cmd: $cmd')
		exit(1)
	}

	p.pid = int(wdata.proc_info.dw_process_id)
	return p.pid
}

fn (mut p Process) win_stop_process() {
	the_fn := ntdll_fn(c'NtSuspendProcess')
	if voidptr(the_fn) == 0 {
		return
	}
	wdata := &WProcess(p.wdata)
	the_fn(wdata.proc_info.h_process)
}

fn (mut p Process) win_resume_process() {
	the_fn := ntdll_fn(c'NtResumeProcess')
	if voidptr(the_fn) == 0 {
		return
	}
	wdata := &WProcess(p.wdata)
	the_fn(wdata.proc_info.h_process)
}

fn (mut p Process) win_kill_process() {
	wdata := &WProcess(p.wdata)
	C.TerminateProcess(wdata.proc_info.h_process, 1)
}

fn (mut p Process) win_kill_pgroup() {
	wdata := &WProcess(p.wdata)
	C.TerminateProcess(wdata.proc_info.h_process, 1)
}

fn (mut p Process) win_wait() {
	exit_code := u32(1)
	eprintln(@METHOD)
	mut wdata := &WProcess(p.wdata)
	if p.wdata != 0 {
		C.WaitForSingleObject(wdata.proc_info.h_process, C.INFINITE)
		C.GetExitCodeProcess(wdata.proc_info.h_process, voidptr(&exit_code))
		//
		C.CloseHandle(wdata.proc_info.h_process)
		C.CloseHandle(wdata.proc_info.h_thread)
		//
		if wdata.child_stdin != 0 {
			C.CloseHandle(wdata.child_stdin)
		}
		if wdata.child_stdout_write != 0 {
			C.CloseHandle(wdata.child_stdout_write)
		}
		if wdata.child_stderr_write != 0 {
			C.CloseHandle(wdata.child_stderr_write)
		}
	}
	p.status = .exited
	p.code = int(exit_code)
}

fn (mut p Process) win_is_alive() bool {
	exit_code := u32(0)
	wdata := &WProcess(p.wdata)
	C.GetExitCodeProcess(wdata.proc_info.h_process, voidptr(&exit_code))
	if exit_code == C.STILL_ACTIVE {
		return true
	}
	return false
}

//
// these are here to make v_win.c/v.c generation work in all cases:
fn (mut p Process) unix_spawn_process() int {
	return 0
}

fn (mut p Process) unix_stop_process() {
}

fn (mut p Process) unix_resume_process() {
}

fn (mut p Process) unix_kill_process() {
}

fn (mut p Process) unix_kill_pgroup() {
}

fn (mut p Process) unix_wait() {
}

fn (mut p Process) unix_is_alive() bool {
	return false
}
