module notify

import time

// Backends should provide a `new() ?FdNotifier` function
interface FdNotifier {
	add(fd int, events FdEventType, conf ...FdConfigFlags) ?
	remove(fd int) ?
	wait(timeout time.Duration) []FdEvent
	close() ?
}

interface FdEvent {
	fd int
	kind FdEventType
}

[flag]
pub enum FdEventType {
	read
	write
	peer_hangup
	exception
	error
	hangup
}

[flag]
pub enum FdConfigFlags {
	edge_trigger
	one_shot
	wake_up
	exclusive
}
