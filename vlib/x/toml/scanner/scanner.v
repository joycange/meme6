// Copyright (c) 2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module scanner

import os
import math.mathutil
import x.toml.input
import x.toml.token
import x.toml.util

// Scanner contains the necessary fields for the state of the scan process.
// the task the scanner does is also refered to as "lexing" or "tokenizing".
// The Scanner methods are based on much of the work in `vlib/strings/textscanner`.
pub struct Scanner {
pub:
	config Config
	text   string // the input TOML text
mut:
	col     int  // current column number (x coordinate)
	line_nr int = 1 // current line number (y coordinate)
	pos     int  // current flat/index position in the `text` field
	mode    Mode // sub-mode of the scanner
}

enum Mode {
	normal
	inside_string
}

// Config is used to configure a Scanner instance.
// Only one of the fields `text` and `file_path` is allowed to be set at time of configuration.
pub struct Config {
pub:
	input              input.Config
	tokenize_formating bool // if true, generate tokens for `\n`, ` `, `\t`, `\r` etc.
}

// new_scanner returns a new heap allocated `Scanner` instance.
pub fn new_scanner(config Config) ?&Scanner {
	config.input.validate() ?
	mut text := config.input.text
	file_path := config.input.file_path
	if os.is_file(file_path) {
		text = os.read_file(file_path) or {
			return error(@MOD + '.' + @STRUCT + '.' + @FN +
				' Could not read "$file_path": "$err.msg"')
		}
	}
	mut s := &Scanner{
		config: config
		text: text
	}
	return s
}

// scan returns the next token from the input.
[direct_array_access]
pub fn (mut s Scanner) scan() ?token.Token {
	for {
		c := s.next()
		byte_c := byte(c)
		if c == -1 {
			s.inc_line_number()
			util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'reached EOF')
			return s.new_token(.eof, '', 1)
		}

		ascii := byte_c.ascii_str()
		util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'current char "$ascii"')

		is_sign := byte_c in [`+`, `-`]
		is_signed_number := is_sign && byte(s.at()).is_digit() && !byte(s.peek(-1)).is_digit()

		// TODO (+/-)nan & (+/-)inf
		/*
		mut is_nan := s.peek(1) == `n` && s.peek(2) == `a` && s.peek(3) == `n`
		mut is_inf := s.peek(1) == `i` && s.peek(2) == `n` && s.peek(3) == `f`
		if is_nan || is_inf {
			util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified a special number "$key" ($key.len)')
			return s.new_token(.number, key, key.len)
		}
		*/

		is_digit := byte_c.is_digit()
		if is_digit || is_signed_number {
			num := s.extract_number() ?
			util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified a number "$num" ($num.len)')
			return s.new_token(.number, num, num.len)
		}

		if util.is_key_char(byte_c) {
			key := s.extract_key()
			if key in ['true', 'false'] {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified a boolean "$key" ($key.len)')
				return s.new_token(.boolean, key, key.len)
			}
			util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified a bare key "$key" ($key.len)')
			return s.new_token(.bare, key, key.len)
		}

		match rune(c) {
			` `, `\t`, `\n`, `\r` {
				if c == `\n` {
					s.inc_line_number()
					util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'incremented line nr to $s.line_nr')
				}
				// Date-Time in RFC 3339 is allowed to have a space between the date and time in supplement to the 'T'
				// so we allow space characters to slip through to the parser if the space is between two digits...
				// util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, '"'+byte(s.peek(-1)).ascii_str()+'" < "$ascii" > "'+byte(s.at()).ascii_str()+'"')
				if c == ` ` && byte(s.peek(-1)).is_digit() && byte(s.at()).is_digit() {
					util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified, what could be, a space between a RFC 3339 date and time ("$ascii") ($ascii.len)')
					return s.new_token(token.Kind.whitespace, ascii, ascii.len)
				}
				if s.config.tokenize_formating {
					mut kind := token.Kind.whitespace
					if c == `\t` {
						kind = token.Kind.tab
					} else if c == `\n` {
						kind = token.Kind.nl
					}
					util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified one of " ", "\\t" or "\\n" ("$ascii") ($ascii.len)')
					return s.new_token(kind, ascii, ascii.len)
				} else {
					util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'skipping " ", "\\t" or "\\n" ("$ascii") ($ascii.len)')
				}
				continue
			}
			`-` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified minus "$ascii" ($ascii.len)')
				return s.new_token(.minus, ascii, ascii.len)
			}
			`_` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified underscore "$ascii" ($ascii.len)')
				return s.new_token(.underscore, ascii, ascii.len)
			}
			`+` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified plus "$ascii" ($ascii.len)')
				return s.new_token(.plus, ascii, ascii.len)
			}
			`=` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified assignment "$ascii" ($ascii.len)')
				return s.new_token(.assign, ascii, ascii.len)
			}
			`"`, `'` { // ... some string "/'
				ident_string, is_multiline := s.extract_string() ?
				token_length := if is_multiline { 2 * 3 } else { 2 }
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified quoted string (multiline: $is_multiline) `$ident_string`')
				return s.new_token(.quoted, ident_string, ident_string.len + token_length) // + quote length
			}
			`#` {
				start := s.pos //+ 1
				s.ignore_line()
				hash := s.text[start..s.pos]
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified comment hash "$hash" ($hash.len)')
				return s.new_token(.hash, hash, hash.len + 1)
			}
			`{` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified left curly bracket "$ascii" ($ascii.len)')
				return s.new_token(.lcbr, ascii, ascii.len)
			}
			`}` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified right curly bracket "$ascii" ($ascii.len)')
				return s.new_token(.rcbr, ascii, ascii.len)
			}
			`[` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified left square bracket "$ascii" ($ascii.len)')
				return s.new_token(.lsbr, ascii, ascii.len)
			}
			`]` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified right square bracket "$ascii" ($ascii.len)')
				return s.new_token(.rsbr, ascii, ascii.len)
			}
			`:` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified colon "$ascii" ($ascii.len)')
				return s.new_token(.colon, ascii, ascii.len)
			}
			`,` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified comma "$ascii" ($ascii.len)')
				return s.new_token(.comma, ascii, ascii.len)
			}
			`.` {
				util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified period "$ascii" ($ascii.len)')
				return s.new_token(.period, ascii, ascii.len)
			}
			else {
				return error(@MOD + '.' + @STRUCT + '.' + @FN +
					' could not scan character `$ascii` / $c at $s.pos ($s.line_nr,$s.col) near ...${s.excerpt(s.pos, 5)}...')
			}
		}
	}
	util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'unknown character code at $s.pos ($s.line_nr,$s.col) near ...${s.excerpt(s.pos,
		5)}...')
	return s.new_token(.unknown, '', 0)
}

// free frees all allocated resources.
[unsafe]
pub fn (mut s Scanner) free() {
	unsafe {
		s.text.free()
	}
}

// remaining returns how many characters remain in the text input.
[inline]
pub fn (s &Scanner) remaining() int {
	return s.text.len - s.pos
}

// next returns the next character code from the input text.
// next returns `-1` if it can't reach the next character.
[direct_array_access; inline]
pub fn (mut s Scanner) next() int {
	if s.pos < s.text.len {
		opos := s.pos
		s.pos++
		s.col++
		c := s.text[opos]
		return c
	}
	return -1
}

// skip skips one character ahead.
[inline]
pub fn (mut s Scanner) skip() {
	if s.pos + 1 < s.text.len {
		s.pos++
		s.col++
	}
}

// skip_n skips ahead `n` characters.
// If the skip goes out of bounds from the length of `Scanner.text`,
// the scanner position will be sat to the last character possible.
[inline]
pub fn (mut s Scanner) skip_n(n int) {
	s.pos += n
	if s.pos > s.text.len {
		s.pos = s.text.len
	}
	s.col = s.pos
}

// at returns the *current* character code from the input text.
// at returns `-1` if it can't get the current character.
// unlike `next()`, `at()` does not change the state of the scanner.
[direct_array_access; inline]
pub fn (s &Scanner) at() byte {
	if s.pos < s.text.len {
		return s.text[s.pos]
	}
	return -1
}

// peek returns the character code from the input text at position + `n`.
// peek returns `-1` if it can't peek `n` characters ahead.
[direct_array_access; inline]
pub fn (s &Scanner) peek(n int) int {
	if s.pos + n < s.text.len {
		// Allow peeking back - needed for spaces between date and time in RFC 3339 format :/
		if n - 1 < 0 && s.pos + n - 1 >= 0 {
			// util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'LOOKING BAAAA-AACK - OOOVER MY SHOOOOULDEEEER "${s.text[s.pos + n-1]}"')
			return s.text[s.pos + n - 1]
		}
		return s.text[s.pos + n]
	}
	return -1
}

// reset resets the internal state of the scanner.
pub fn (mut s Scanner) reset() {
	s.pos = 0
	s.col = 0
	s.line_nr = 1
}

// new_token returns a new `token.Token`.
[inline]
fn (mut s Scanner) new_token(kind token.Kind, lit string, len int) token.Token {
	// line_offset := 1
	// println('new_token($lit)')
	return token.Token{
		kind: kind
		lit: lit
		col: mathutil.max(1, s.col - len + 1)
		line_nr: s.line_nr + 1 //+ line_offset
		pos: s.pos - len + 1
		len: len
	}
}

// ignore_line forwards the scanner to the end of the current line.
[direct_array_access; inline]
fn (mut s Scanner) ignore_line() {
	util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, ' ignoring until EOL')
	for c := s.at(); c != -1 && c != `\n`; c = s.at() {
		s.next()
		util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'skipping "${byte(c).ascii_str()}"')
		continue
	}
}

// inc_line_number increases the internal line number.
[inline]
fn (mut s Scanner) inc_line_number() {
	s.col = 0
	s.line_nr++
}

// extract_key parses and returns a TOML key as a string.
[direct_array_access; inline]
fn (mut s Scanner) extract_key() string {
	s.pos--
	s.col--
	start := s.pos
	for s.pos < s.text.len {
		c := s.at()
		if !(util.is_key_char(c) || c.is_digit() || c in [`_`, `-`]) {
			break
		}
		s.pos++
		s.col++
	}
	key := s.text[start..s.pos]
	return key
}

// extract_string collects and returns a string containing
// any bytes recognized as a TOML string.
// TOML strings are everything found between two double or single quotation marks (`"`/`'`).
[direct_array_access; inline]
fn (mut s Scanner) extract_string() ?(string, bool) {
	// extract_string is called when the scanner has already reached
	// a byte that is the start of a string so we rewind it to start at the correct
	s.pos--
	s.col--
	quote := s.at()
	start := s.pos
	mut lit := ''

	is_multiline := s.text[s.pos + 1] == quote && s.text[s.pos + 2] == quote
	// Check for escaped multiline quote
	if is_multiline {
		mls := s.extract_multiline_string() ?
		return mls, is_multiline
	}

	for {
		s.pos++
		s.col++

		if s.pos >= s.text.len {
			return error(@MOD + '.' + @STRUCT + '.' + @FN +
				' unfinished string literal `$quote.ascii_str()` started at $start ($s.line_nr,$s.col) "${byte(s.at()).ascii_str()}" near ...${s.excerpt(s.pos, 5)}...')
		}

		c := s.at()
		util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'c: `$c.ascii_str()` / $c (quote type: $quote/$quote.ascii_str())')

		// Check for escaped chars
		if c == byte(92) {
			esc, skip := s.handle_escapes(quote, is_multiline)
			lit += esc
			if skip > 0 {
				s.pos += skip
				s.col += skip
				continue
			}
		}

		if c == quote {
			s.pos++
			s.col++
			return lit, is_multiline
		}

		lit += c.ascii_str()
	}
	return lit, is_multiline
}

// extract_multiline_string collects and returns a string containing
// any bytes recognized as a TOML string.
// TOML strings are everything found between two double or single quotation marks (`"`/`'`).
[direct_array_access; inline]
fn (mut s Scanner) extract_multiline_string() ?string {
	// extract_multiline_string is called from extract_string so we know the 3 first
	// characters is the quotes
	quote := s.at()
	start := s.pos
	mut lit := ''

	util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'multiline `$quote.ascii_str()${s.text[s.pos + 1].ascii_str()}${s.text[
		s.pos + 2].ascii_str()}` string started at pos $start ($s.line_nr,$s.col) (quote type: $quote.ascii_str() / $quote)')

	s.pos += 2
	s.col += 2

	for {
		s.pos++
		s.col++

		if s.pos >= s.text.len {
			return error(@MOD + '.' + @STRUCT + '.' + @FN +
				' unfinished multiline string literal ($quote.ascii_str()$quote.ascii_str()$quote.ascii_str()) started at $start ($s.line_nr,$s.col) "${byte(s.at()).ascii_str()}" near ...${s.excerpt(s.pos, 5)}...')
		}

		c := s.at()
		if c == `\n` {
			s.inc_line_number()
			lit += c.ascii_str()
			util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'c: `\\n` / $c')
			continue
		}
		// Check for escaped chars
		if c == byte(92) {
			esc, skip := s.handle_escapes(quote, true)
			lit += esc
			if skip > 0 {
				s.pos += skip
				s.col += skip
				continue
			}
		}

		util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'c: `$c.ascii_str()` / $c')

		if c == quote {
			if s.peek(1) == quote && s.peek(2) == quote {
				if s.peek(3) == -1 {
					s.pos += 3
					s.col += 3
					util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'returning at $c.ascii_str() `$lit`')
					return lit
				} else if s.peek(3) != quote {
					// lit += c.ascii_str()
					// lit += quote.ascii_str()
					s.pos += 3
					s.col += 3
					util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'returning at $c.ascii_str() `$lit`')
					return lit
				}
			}
		}
		lit += c.ascii_str()
	}
	return lit
}

// handle_escapes
fn (mut s Scanner) handle_escapes(quote byte, is_multiline bool) (string, int) {
	c := s.at()
	mut lit := c.ascii_str()
	if s.peek(1) == byte(92) {
		lit += lit
		util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'gulp escaped `$lit`')
		return lit, 1
	} else if s.peek(1) == quote {
		if (!is_multiline && s.peek(2) == `\n`)
			|| (is_multiline && s.peek(2) == quote && s.peek(3) == quote && s.peek(4) == `\n`) {
			util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'ignore special case escaped `$lit` at end of string')
			return '', 0
		}
		lit += quote.ascii_str()
		util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'gulp escaped `$lit`')
		return lit, 1
	} else if s.peek(1) == `u` && byte(s.peek(2)).is_hex_digit()
		&& byte(s.peek(3)).is_hex_digit() && byte(s.peek(4)).is_hex_digit()
		&& byte(s.peek(5)).is_hex_digit() {
		lit += s.text[s.pos + 1..s.pos + 6] //.ascii_str()
		util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'gulp escaped `$lit`')
		return lit, 4
	}
	return '', 0
}

// extract_number collects and returns a string containing
// any bytes recognized as a TOML number.
// TOML numbers can include digits 0-9 and `_`.
[direct_array_access; inline]
fn (mut s Scanner) extract_number() ?string {
	// extract_number is called when the scanner has already reached
	// a byte that is a number or +/- - so we rewind it to start at the correct
	// position to get the complete number. Even if it's only one digit
	s.pos--
	s.col--
	start := s.pos

	mut c := s.at()
	is_digit := byte(c).is_digit()
	if !(is_digit || c in [`+`, `-`]) {
		return error(@MOD + '.' + @STRUCT + '.' + @FN +
			' ${byte(c).ascii_str()} is not a number at ${s.excerpt(s.pos, 10)}')
	}
	s.pos++
	s.col++
	for s.pos < s.text.len {
		c = s.at()
		if !(byte(c).is_hex_digit() || c in [`_`, `.`, `x`, `o`, `b`]) {
			break
		}
		s.pos++
		s.col++
	}
	key := s.text[start..s.pos]
	util.printdbg(@MOD + '.' + @STRUCT + '.' + @FN, 'identified number "$key" in range [$start .. $s.pos]')
	return key
}

// excerpt returns a string excerpt of the input text centered
// at `pos`. The `margin` argument defines how many chacters
// on each side of `pos` is returned
pub fn (mut s Scanner) excerpt(pos int, margin int) string {
	start := if pos > 0 && pos >= margin { pos - margin } else { 0 }
	end := if pos + margin < s.text.len { pos + margin } else { s.text.len }
	return s.text[start..end].replace('\n', r'\n')
}
