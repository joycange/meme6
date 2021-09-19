// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license that can be found in the LICENSE file.
module builtin

import strings

// This was never working correctly, the issue is now
// fixed however the type checks in checker need to be
// updated. if you uncomment it you will see the issue
// type rune = int

const (
	letters = [
		`À`,
		`Á`,
		`Â`,
		`Ã`,
		`Ä`,
		`Å`,
		`Æ`,
		`Ç`,
		`È`,
		`É`,
		`Ê`,
		`Ë`,
		`Ì`,
		`Í`,
		`Î`,
		`Ï`,
		`Ð`,
		`Ñ`,
		`Ò`,
		`Ó`,
		`Ô`,
		`Õ`,
		`Ö`,
		`Ø`,
		`Ù`,
		`Ú`,
		`Û`,
		`Ü`,
		`Ý`,
		`Þ`,
		`ß`,
		`à`,
		`á`,
		`â`,
		`ã`,
		`ä`,
		`å`,
		`æ`,
		`ç`,
		`è`,
		`é`,
		`ê`,
		`ë`,
		`ì`,
		`í`,
		`î`,
		`ï`,
		`ð`,
		`ñ`,
		`ò`,
		`ó`,
		`ô`,
		`õ`,
		`ö`,
		`ø`,
		`ù`,
		`ú`,
		`û`,
		`ü`,
		`ý`,
		`þ`,
		`ÿ`,
	]
)

pub fn (c rune) str() string {
	return utf32_to_str(u32(c))
	/*
	unsafe {
		fst_byte := int(c)>>8 * 3 & 0xff
		len := utf8_char_len(byte(fst_byte))
		println('len=$len')
		mut str := string{
			len: len
			str: malloc(len + 1)
		}
		for i in 0..len {
			str.str[i] = byte(int(c)>>8 * (3 - i) & 0xff)
		}
		str.str[len] = `\0`
		println(str)
		return str
	}
	*/
}

// string converts a rune array to a string
[manualfree]
pub fn (ra []rune) string() string {
	mut sb := strings.new_builder(ra.len)
	sb.write_runes(ra)
	res := sb.str()
	unsafe { sb.free() }
	return res
}

// is_letter returns `true` if the rune is in range a-z or A-Z and `false` otherwise.
[inline]
pub fn (ra rune) is_letter() bool {
	if (ra >= `a` && ra <= `z`) || (ra >= `A` && ra <= `Z`) {
		return true
	} else if ra in letters {
		return true
	}
	return ra.is_excluding_latin(letter_table)
}

// Define this on byte as well, so that we can do `s[0].is_capital()`
pub fn (c byte) is_capital() bool {
	return c >= `A` && c <= `Z`
}

pub fn (b []byte) clone() []byte {
	mut res := []byte{len: b.len}
	// mut res := make([]byte, {repeat:b.len})
	for i in 0 .. b.len {
		res[i] = b[i]
	}
	return res
}

// TODO: remove this once runes are implemented
pub fn (b []byte) bytestr() string {
	unsafe {
		buf := malloc_noscan(b.len + 1)
		vmemcpy(buf, b.data, b.len)
		buf[b.len] = 0
		return tos(buf, b.len)
	}
}
