import time

struct AA {
mut:
	b string
}

const (
	run_time   = time.millisecond * 200 // must be big enough to ensure threads have started
	sleep_time = time.millisecond * 250 // some tolerance added
)

fn test_return_lock() {
	start := time.now()
	shared s := AA{'3'}
	go printer(shared s, start)
	go fn (shared s AA, start time.Time) {
		for {
			reader(shared s)
			if time.now() - start > run_time {
				exit(0)
			}
		}
	}(shared s, start)
	time.sleep(sleep_time)
	assert false
}

fn printer(shared s AA, start time.Time) {
	for {
		lock s {
			assert s.b in ['0', '1', '2', '3', '4', '5']
		}
		if time.now() - start > run_time {
			exit(0)
		}
	}
}

fn reader(shared s AA) {
	mut i := 0
	for {
		i++
		x := i.str()
		lock s {
			s.b = x
			if s.b == '5' {
				// this test checks if cgen unlocks the mutex here
				return
			}
		}
	}
}
