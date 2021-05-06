module io

// new_multiwriter returns a Writer that writes to all writers. The write
// function of the returned Writer writes to all writers of the MultiWriter,
// returns the length of bytes written, and iif any writer fails to write the
// full length an error is returned and writing to other writers stops, and if
// any writer returns an error the error is returned immediately and writing to
// other writers stops.
pub fn new_multiwriter(writers []Writer) MultiWriter {
	return MultiWriter{
		writers: writers
	}
}

// MultiWriter writes to all its writers.
pub struct MultiWriter {
pub:
	writers []Writer
}

// write writes to all writers of the MultiWriter. Returns the length of bytes
// written. If any writer fails to write the full length an error is returned
// and writing to other writers stops. If any writer returns an error the error
// is returned immediately and writing to other writers stops.
pub fn (m MultiWriter) write(buf []byte) ?int {
	for w in m.writers {
		n := w.write(buf) ?
		if n != buf.len {
			return error('io: incomplete write to writer of MultiWriter')
		}
	}
	return buf.len
}
