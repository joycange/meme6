module filepath

const (
	MAX_PATH = 4096
)

// ext returns the extension in the file `path`.
pub fn ext(path string) string {
	pos := path.last_index('.') or {
		return ''
	}
	return path[pos..]
}

// is_abs returns true if `path` is absolute.
pub fn is_abs(path string) bool {
	$if windows {
		return path[0] == `/` || // incase we're in MingGW bash
		(path[0].is_letter() && path[1] == `:`)
	}
	return path[0] == `/`
}

// Returns the full absolute path for fpath, with all relative ../../, symlinks and so on resolved.
// See http://pubs.opengroup.org/onlinepubs/9699919799/functions/realpath.html
// Also https://insanecoding.blogspot.com/2007/11/pathmax-simply-isnt.html
// and https://insanecoding.blogspot.com/2007/11/implementing-realpath-in-c.html
// NB: this particular rabbit hole is *deep* ...
pub fn abs(fpath string) string {
	mut fullpath := calloc(MAX_PATH)
	mut ret := charptr(0)
	$if windows {
		ret = C._fullpath(fullpath, fpath.str, MAX_PATH)
		if ret == 0 {
			return fpath
		}
	} $else {
		ret = C.realpath(fpath.str, fullpath)
		if ret == 0 {
			return fpath
		}
	}
	return string(fullpath)
}

// join returns path as string from string parameter(s).
pub fn join(base string, dirs ...string) string {
	mut result := []string
	result << base.trim_right('\\/')
	for d in dirs {
		result << d
	}
	return result.join(separator)
}

// dir returns all but the last element of path, typically the path's directory.
pub fn dir(path string) string {
	pos := path.last_index(separator) or {
		return '.'
	}
	return path[..pos]
}

// base returns a directory name from path
pub fn base(path string) string {
	pos := path.last_index(separator) or {
		return path
	}
	// NB: *without* terminating /
	return path[..pos]
}

// filename returns a file name from path
pub fn filename(path string) string {
	return path.all_after(separator)
}
