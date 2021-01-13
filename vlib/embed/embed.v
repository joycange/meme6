module embed

import os

pub const (
	is_used = 1 // TODO
)

// https://github.com/vlang/rfcs/blob/master/embedding_resources.md
// EmbeddedData encapsulates functionality for the `$embed_file()` compile time call.
pub struct EmbeddedData {
	path string
mut:
	compressed   byteptr
	uncompressed byteptr
pub:
	len int
}

pub fn (ed EmbeddedData) str() string {
	return 'embed.EmbeddedData{
    len: $ed.len
}'
}

pub fn (mut ed EmbeddedData) data() byteptr {
	if !isnil(ed.uncompressed) {
		return ed.uncompressed
	} else {
		if isnil(ed.uncompressed) && !isnil(ed.compressed) {
			// TODO implement uncompression
			// See also C Gen.gen_embedded_data() where the compression should occur.
			ed.uncompressed = ed.compressed
		} else {
			bytes := os.read_bytes(ed.path) or { 'deadbeef'.bytes() }
			ed.uncompressed = bytes.data
		}
	}
	return ed.uncompressed
}
