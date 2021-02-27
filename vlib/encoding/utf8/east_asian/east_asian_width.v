// Copyright (c) 2021 Takahiro Yaota, a.k.a. zakuro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module east_asian

import encoding.utf8

// EastAsianWidthType represents East_Asian_Width informative prorperty
pub enum EastAsianWidthProperty {
	full
	half
	wide
	narrow
	ambiguous
	neutral
}

// display_width return the display width as number of unicode chars from a string.
pub fn display_width(s string, ambiguous_width int) int {
	mut i, mut n := 0, 0
	for i < s.len {
		c_len := utf8.char_len(s[i])
		n += match east_asian_width_property_at(s, i) {
			.ambiguous { ambiguous_width }
			.full, .wide { int(2) }
			else { int(1) }
		}
		i += c_len
	}
	return n
}

// width_property_at returns the East Asian Width properties at string[index]
pub fn east_asian_width_property_at(s string, index int) EastAsianWidthProperty {
	codepoint := utf8.get_uchar(s, index)
	mut left, mut right := 0, east_asian.east_asian_width_data.len - 1
	for left <= right {
		middle := left + ((right - left) / 2)
		entry := east_asian_width_data[middle]
		if codepoint < entry.point {
			right = middle - 1
			continue
		}

		last := entry.point + entry.len
		if codepoint > last {
			left = middle + 1
			continue
		}

		return entry.property
	}
	return .neutral
}

struct EAWEntry {
	property EastAsianWidthProperty
	point    int
	len      int
}

// EastAsianWidth-13.0.0.txt
const (
	east_asian_width_data = [
		EAWEntry{.neutral, 0x0000, 32},
		EAWEntry{.narrow, 0x0020, 95},
		EAWEntry{.neutral, 0x007f, 34},
		EAWEntry{.ambiguous, 0x00a1, 1},
		EAWEntry{.narrow, 0x00a2, 2},
		EAWEntry{.ambiguous, 0x00a4, 1},
		EAWEntry{.narrow, 0x00a5, 2},
		EAWEntry{.ambiguous, 0x00a7, 2},
		EAWEntry{.neutral, 0x00a9, 1},
		EAWEntry{.ambiguous, 0x00aa, 1},
		EAWEntry{.neutral, 0x00ab, 1},
		EAWEntry{.narrow, 0x00ac, 1},
		EAWEntry{.ambiguous, 0x00ad, 2},
		EAWEntry{.narrow, 0x00af, 1},
		EAWEntry{.ambiguous, 0x00b0, 5},
		EAWEntry{.neutral, 0x00b5, 1},
		EAWEntry{.ambiguous, 0x00b6, 5},
		EAWEntry{.neutral, 0x00bb, 1},
		EAWEntry{.ambiguous, 0x00bc, 4},
		EAWEntry{.neutral, 0x00c0, 6},
		EAWEntry{.ambiguous, 0x00c6, 1},
		EAWEntry{.neutral, 0x00c7, 9},
		EAWEntry{.ambiguous, 0x00d0, 1},
		EAWEntry{.neutral, 0x00d1, 6},
		EAWEntry{.ambiguous, 0x00d7, 2},
		EAWEntry{.neutral, 0x00d9, 5},
		EAWEntry{.ambiguous, 0x00de, 4},
		EAWEntry{.neutral, 0x00e2, 4},
		EAWEntry{.ambiguous, 0x00e6, 1},
		EAWEntry{.neutral, 0x00e7, 1},
		EAWEntry{.ambiguous, 0x00e8, 3},
		EAWEntry{.neutral, 0x00eb, 1},
		EAWEntry{.ambiguous, 0x00ec, 2},
		EAWEntry{.neutral, 0x00ee, 2},
		EAWEntry{.ambiguous, 0x00f0, 1},
		EAWEntry{.neutral, 0x00f1, 1},
		EAWEntry{.ambiguous, 0x00f2, 2},
		EAWEntry{.neutral, 0x00f4, 3},
		EAWEntry{.ambiguous, 0x00f7, 4},
		EAWEntry{.neutral, 0x00fb, 1},
		EAWEntry{.ambiguous, 0x00fc, 1},
		EAWEntry{.neutral, 0x00fd, 1},
		EAWEntry{.ambiguous, 0x00fe, 1},
		EAWEntry{.neutral, 0x00ff, 2},
		EAWEntry{.ambiguous, 0x0101, 1},
		EAWEntry{.neutral, 0x0102, 15},
		EAWEntry{.ambiguous, 0x0111, 1},
		EAWEntry{.neutral, 0x0112, 1},
		EAWEntry{.ambiguous, 0x0113, 1},
		EAWEntry{.neutral, 0x0114, 7},
		EAWEntry{.ambiguous, 0x011b, 1},
		EAWEntry{.neutral, 0x011c, 10},
		EAWEntry{.ambiguous, 0x0126, 2},
		EAWEntry{.neutral, 0x0128, 3},
		EAWEntry{.ambiguous, 0x012b, 1},
		EAWEntry{.neutral, 0x012c, 5},
		EAWEntry{.ambiguous, 0x0131, 3},
		EAWEntry{.neutral, 0x0134, 4},
		EAWEntry{.ambiguous, 0x0138, 1},
		EAWEntry{.neutral, 0x0139, 6},
		EAWEntry{.ambiguous, 0x013f, 4},
		EAWEntry{.neutral, 0x0143, 1},
		EAWEntry{.ambiguous, 0x0144, 1},
		EAWEntry{.neutral, 0x0145, 3},
		EAWEntry{.ambiguous, 0x0148, 4},
		EAWEntry{.neutral, 0x014c, 1},
		EAWEntry{.ambiguous, 0x014d, 1},
		EAWEntry{.neutral, 0x014e, 4},
		EAWEntry{.ambiguous, 0x0152, 2},
		EAWEntry{.neutral, 0x0154, 18},
		EAWEntry{.ambiguous, 0x0166, 2},
		EAWEntry{.neutral, 0x0168, 3},
		EAWEntry{.ambiguous, 0x016b, 1},
		EAWEntry{.neutral, 0x016c, 98},
		EAWEntry{.ambiguous, 0x01ce, 1},
		EAWEntry{.neutral, 0x01cf, 1},
		EAWEntry{.ambiguous, 0x01d0, 1},
		EAWEntry{.neutral, 0x01d1, 1},
		EAWEntry{.ambiguous, 0x01d2, 1},
		EAWEntry{.neutral, 0x01d3, 1},
		EAWEntry{.ambiguous, 0x01d4, 1},
		EAWEntry{.neutral, 0x01d5, 1},
		EAWEntry{.ambiguous, 0x01d6, 1},
		EAWEntry{.neutral, 0x01d7, 1},
		EAWEntry{.ambiguous, 0x01d8, 1},
		EAWEntry{.neutral, 0x01d9, 1},
		EAWEntry{.ambiguous, 0x01da, 1},
		EAWEntry{.neutral, 0x01db, 1},
		EAWEntry{.ambiguous, 0x01dc, 1},
		EAWEntry{.neutral, 0x01dd, 116},
		EAWEntry{.ambiguous, 0x0251, 1},
		EAWEntry{.neutral, 0x0252, 15},
		EAWEntry{.ambiguous, 0x0261, 1},
		EAWEntry{.neutral, 0x0262, 98},
		EAWEntry{.ambiguous, 0x02c4, 1},
		EAWEntry{.neutral, 0x02c5, 2},
		EAWEntry{.ambiguous, 0x02c7, 1},
		EAWEntry{.neutral, 0x02c8, 1},
		EAWEntry{.ambiguous, 0x02c9, 3},
		EAWEntry{.neutral, 0x02cc, 1},
		EAWEntry{.ambiguous, 0x02cd, 1},
		EAWEntry{.neutral, 0x02ce, 2},
		EAWEntry{.ambiguous, 0x02d0, 1},
		EAWEntry{.neutral, 0x02d1, 7},
		EAWEntry{.ambiguous, 0x02d8, 4},
		EAWEntry{.neutral, 0x02dc, 1},
		EAWEntry{.ambiguous, 0x02dd, 1},
		EAWEntry{.neutral, 0x02de, 1},
		EAWEntry{.ambiguous, 0x02df, 1},
		EAWEntry{.neutral, 0x02e0, 32},
		EAWEntry{.ambiguous, 0x0300, 112},
		EAWEntry{.neutral, 0x0370, 8},
		EAWEntry{.neutral, 0x037a, 6},
		EAWEntry{.neutral, 0x0384, 7},
		EAWEntry{.neutral, 0x038c, 1},
		EAWEntry{.neutral, 0x038e, 3},
		EAWEntry{.ambiguous, 0x0391, 17},
		EAWEntry{.ambiguous, 0x03a3, 7},
		EAWEntry{.neutral, 0x03aa, 7},
		EAWEntry{.ambiguous, 0x03b1, 17},
		EAWEntry{.neutral, 0x03c2, 1},
		EAWEntry{.ambiguous, 0x03c3, 7},
		EAWEntry{.neutral, 0x03ca, 55},
		EAWEntry{.ambiguous, 0x0401, 1},
		EAWEntry{.neutral, 0x0402, 14},
		EAWEntry{.ambiguous, 0x0410, 64},
		EAWEntry{.neutral, 0x0450, 1},
		EAWEntry{.ambiguous, 0x0451, 1},
		EAWEntry{.neutral, 0x0452, 222},
		EAWEntry{.neutral, 0x0531, 38},
		EAWEntry{.neutral, 0x0559, 50},
		EAWEntry{.neutral, 0x058d, 3},
		EAWEntry{.neutral, 0x0591, 55},
		EAWEntry{.neutral, 0x05d0, 27},
		EAWEntry{.neutral, 0x05ef, 6},
		EAWEntry{.neutral, 0x0600, 29},
		EAWEntry{.neutral, 0x061e, 240},
		EAWEntry{.neutral, 0x070f, 60},
		EAWEntry{.neutral, 0x074d, 101},
		EAWEntry{.neutral, 0x07c0, 59},
		EAWEntry{.neutral, 0x07fd, 49},
		EAWEntry{.neutral, 0x0830, 15},
		EAWEntry{.neutral, 0x0840, 28},
		EAWEntry{.neutral, 0x085e, 1},
		EAWEntry{.neutral, 0x0860, 11},
		EAWEntry{.neutral, 0x08a0, 21},
		EAWEntry{.neutral, 0x08b6, 18},
		EAWEntry{.neutral, 0x08d3, 177},
		EAWEntry{.neutral, 0x0985, 8},
		EAWEntry{.neutral, 0x098f, 2},
		EAWEntry{.neutral, 0x0993, 22},
		EAWEntry{.neutral, 0x09aa, 7},
		EAWEntry{.neutral, 0x09b2, 1},
		EAWEntry{.neutral, 0x09b6, 4},
		EAWEntry{.neutral, 0x09bc, 9},
		EAWEntry{.neutral, 0x09c7, 2},
		EAWEntry{.neutral, 0x09cb, 4},
		EAWEntry{.neutral, 0x09d7, 1},
		EAWEntry{.neutral, 0x09dc, 2},
		EAWEntry{.neutral, 0x09df, 5},
		EAWEntry{.neutral, 0x09e6, 25},
		EAWEntry{.neutral, 0x0a01, 3},
		EAWEntry{.neutral, 0x0a05, 6},
		EAWEntry{.neutral, 0x0a0f, 2},
		EAWEntry{.neutral, 0x0a13, 22},
		EAWEntry{.neutral, 0x0a2a, 7},
		EAWEntry{.neutral, 0x0a32, 2},
		EAWEntry{.neutral, 0x0a35, 2},
		EAWEntry{.neutral, 0x0a38, 2},
		EAWEntry{.neutral, 0x0a3c, 1},
		EAWEntry{.neutral, 0x0a3e, 5},
		EAWEntry{.neutral, 0x0a47, 2},
		EAWEntry{.neutral, 0x0a4b, 3},
		EAWEntry{.neutral, 0x0a51, 1},
		EAWEntry{.neutral, 0x0a59, 4},
		EAWEntry{.neutral, 0x0a5e, 1},
		EAWEntry{.neutral, 0x0a66, 17},
		EAWEntry{.neutral, 0x0a81, 3},
		EAWEntry{.neutral, 0x0a85, 9},
		EAWEntry{.neutral, 0x0a8f, 3},
		EAWEntry{.neutral, 0x0a93, 22},
		EAWEntry{.neutral, 0x0aaa, 7},
		EAWEntry{.neutral, 0x0ab2, 2},
		EAWEntry{.neutral, 0x0ab5, 5},
		EAWEntry{.neutral, 0x0abc, 10},
		EAWEntry{.neutral, 0x0ac7, 3},
		EAWEntry{.neutral, 0x0acb, 3},
		EAWEntry{.neutral, 0x0ad0, 1},
		EAWEntry{.neutral, 0x0ae0, 4},
		EAWEntry{.neutral, 0x0ae6, 12},
		EAWEntry{.neutral, 0x0af9, 7},
		EAWEntry{.neutral, 0x0b01, 3},
		EAWEntry{.neutral, 0x0b05, 8},
		EAWEntry{.neutral, 0x0b0f, 2},
		EAWEntry{.neutral, 0x0b13, 22},
		EAWEntry{.neutral, 0x0b2a, 7},
		EAWEntry{.neutral, 0x0b32, 2},
		EAWEntry{.neutral, 0x0b35, 5},
		EAWEntry{.neutral, 0x0b3c, 9},
		EAWEntry{.neutral, 0x0b47, 2},
		EAWEntry{.neutral, 0x0b4b, 3},
		EAWEntry{.neutral, 0x0b55, 3},
		EAWEntry{.neutral, 0x0b5c, 2},
		EAWEntry{.neutral, 0x0b5f, 5},
		EAWEntry{.neutral, 0x0b66, 18},
		EAWEntry{.neutral, 0x0b82, 2},
		EAWEntry{.neutral, 0x0b85, 6},
		EAWEntry{.neutral, 0x0b8e, 3},
		EAWEntry{.neutral, 0x0b92, 4},
		EAWEntry{.neutral, 0x0b99, 2},
		EAWEntry{.neutral, 0x0b9c, 1},
		EAWEntry{.neutral, 0x0b9e, 2},
		EAWEntry{.neutral, 0x0ba3, 2},
		EAWEntry{.neutral, 0x0ba8, 3},
		EAWEntry{.neutral, 0x0bae, 12},
		EAWEntry{.neutral, 0x0bbe, 5},
		EAWEntry{.neutral, 0x0bc6, 3},
		EAWEntry{.neutral, 0x0bca, 4},
		EAWEntry{.neutral, 0x0bd0, 1},
		EAWEntry{.neutral, 0x0bd7, 1},
		EAWEntry{.neutral, 0x0be6, 21},
		EAWEntry{.neutral, 0x0c00, 13},
		EAWEntry{.neutral, 0x0c0e, 3},
		EAWEntry{.neutral, 0x0c12, 23},
		EAWEntry{.neutral, 0x0c2a, 16},
		EAWEntry{.neutral, 0x0c3d, 8},
		EAWEntry{.neutral, 0x0c46, 3},
		EAWEntry{.neutral, 0x0c4a, 4},
		EAWEntry{.neutral, 0x0c55, 2},
		EAWEntry{.neutral, 0x0c58, 3},
		EAWEntry{.neutral, 0x0c60, 4},
		EAWEntry{.neutral, 0x0c66, 10},
		EAWEntry{.neutral, 0x0c77, 22},
		EAWEntry{.neutral, 0x0c8e, 3},
		EAWEntry{.neutral, 0x0c92, 23},
		EAWEntry{.neutral, 0x0caa, 10},
		EAWEntry{.neutral, 0x0cb5, 5},
		EAWEntry{.neutral, 0x0cbc, 9},
		EAWEntry{.neutral, 0x0cc6, 3},
		EAWEntry{.neutral, 0x0cca, 4},
		EAWEntry{.neutral, 0x0cd5, 2},
		EAWEntry{.neutral, 0x0cde, 1},
		EAWEntry{.neutral, 0x0ce0, 4},
		EAWEntry{.neutral, 0x0ce6, 10},
		EAWEntry{.neutral, 0x0cf1, 2},
		EAWEntry{.neutral, 0x0d00, 13},
		EAWEntry{.neutral, 0x0d0e, 3},
		EAWEntry{.neutral, 0x0d12, 51},
		EAWEntry{.neutral, 0x0d46, 3},
		EAWEntry{.neutral, 0x0d4a, 6},
		EAWEntry{.neutral, 0x0d54, 16},
		EAWEntry{.neutral, 0x0d66, 26},
		EAWEntry{.neutral, 0x0d81, 3},
		EAWEntry{.neutral, 0x0d85, 18},
		EAWEntry{.neutral, 0x0d9a, 24},
		EAWEntry{.neutral, 0x0db3, 9},
		EAWEntry{.neutral, 0x0dbd, 1},
		EAWEntry{.neutral, 0x0dc0, 7},
		EAWEntry{.neutral, 0x0dca, 1},
		EAWEntry{.neutral, 0x0dcf, 6},
		EAWEntry{.neutral, 0x0dd6, 1},
		EAWEntry{.neutral, 0x0dd8, 8},
		EAWEntry{.neutral, 0x0de6, 10},
		EAWEntry{.neutral, 0x0df2, 3},
		EAWEntry{.neutral, 0x0e01, 58},
		EAWEntry{.neutral, 0x0e3f, 29},
		EAWEntry{.neutral, 0x0e81, 2},
		EAWEntry{.neutral, 0x0e84, 1},
		EAWEntry{.neutral, 0x0e86, 5},
		EAWEntry{.neutral, 0x0e8c, 24},
		EAWEntry{.neutral, 0x0ea5, 1},
		EAWEntry{.neutral, 0x0ea7, 23},
		EAWEntry{.neutral, 0x0ec0, 5},
		EAWEntry{.neutral, 0x0ec6, 1},
		EAWEntry{.neutral, 0x0ec8, 6},
		EAWEntry{.neutral, 0x0ed0, 10},
		EAWEntry{.neutral, 0x0edc, 4},
		EAWEntry{.neutral, 0x0f00, 72},
		EAWEntry{.neutral, 0x0f49, 36},
		EAWEntry{.neutral, 0x0f71, 39},
		EAWEntry{.neutral, 0x0f99, 36},
		EAWEntry{.neutral, 0x0fbe, 15},
		EAWEntry{.neutral, 0x0fce, 13},
		EAWEntry{.neutral, 0x1000, 198},
		EAWEntry{.neutral, 0x10c7, 1},
		EAWEntry{.neutral, 0x10cd, 1},
		EAWEntry{.neutral, 0x10d0, 48},
		EAWEntry{.wide, 0x1100, 96},
		EAWEntry{.neutral, 0x1160, 233},
		EAWEntry{.neutral, 0x124a, 4},
		EAWEntry{.neutral, 0x1250, 7},
		EAWEntry{.neutral, 0x1258, 1},
		EAWEntry{.neutral, 0x125a, 4},
		EAWEntry{.neutral, 0x1260, 41},
		EAWEntry{.neutral, 0x128a, 4},
		EAWEntry{.neutral, 0x1290, 33},
		EAWEntry{.neutral, 0x12b2, 4},
		EAWEntry{.neutral, 0x12b8, 7},
		EAWEntry{.neutral, 0x12c0, 1},
		EAWEntry{.neutral, 0x12c2, 4},
		EAWEntry{.neutral, 0x12c8, 15},
		EAWEntry{.neutral, 0x12d8, 57},
		EAWEntry{.neutral, 0x1312, 4},
		EAWEntry{.neutral, 0x1318, 67},
		EAWEntry{.neutral, 0x135d, 32},
		EAWEntry{.neutral, 0x1380, 26},
		EAWEntry{.neutral, 0x13a0, 86},
		EAWEntry{.neutral, 0x13f8, 6},
		EAWEntry{.neutral, 0x1400, 669},
		EAWEntry{.neutral, 0x16a0, 89},
		EAWEntry{.neutral, 0x1700, 13},
		EAWEntry{.neutral, 0x170e, 7},
		EAWEntry{.neutral, 0x1720, 23},
		EAWEntry{.neutral, 0x1740, 20},
		EAWEntry{.neutral, 0x1760, 13},
		EAWEntry{.neutral, 0x176e, 3},
		EAWEntry{.neutral, 0x1772, 2},
		EAWEntry{.neutral, 0x1780, 94},
		EAWEntry{.neutral, 0x17e0, 10},
		EAWEntry{.neutral, 0x17f0, 10},
		EAWEntry{.neutral, 0x1800, 15},
		EAWEntry{.neutral, 0x1810, 10},
		EAWEntry{.neutral, 0x1820, 89},
		EAWEntry{.neutral, 0x1880, 43},
		EAWEntry{.neutral, 0x18b0, 70},
		EAWEntry{.neutral, 0x1900, 31},
		EAWEntry{.neutral, 0x1920, 12},
		EAWEntry{.neutral, 0x1930, 12},
		EAWEntry{.neutral, 0x1940, 1},
		EAWEntry{.neutral, 0x1944, 42},
		EAWEntry{.neutral, 0x1970, 5},
		EAWEntry{.neutral, 0x1980, 44},
		EAWEntry{.neutral, 0x19b0, 26},
		EAWEntry{.neutral, 0x19d0, 11},
		EAWEntry{.neutral, 0x19de, 62},
		EAWEntry{.neutral, 0x1a1e, 65},
		EAWEntry{.neutral, 0x1a60, 29},
		EAWEntry{.neutral, 0x1a7f, 11},
		EAWEntry{.neutral, 0x1a90, 10},
		EAWEntry{.neutral, 0x1aa0, 14},
		EAWEntry{.neutral, 0x1ab0, 17},
		EAWEntry{.neutral, 0x1b00, 76},
		EAWEntry{.neutral, 0x1b50, 45},
		EAWEntry{.neutral, 0x1b80, 116},
		EAWEntry{.neutral, 0x1bfc, 60},
		EAWEntry{.neutral, 0x1c3b, 15},
		EAWEntry{.neutral, 0x1c4d, 60},
		EAWEntry{.neutral, 0x1c90, 43},
		EAWEntry{.neutral, 0x1cbd, 11},
		EAWEntry{.neutral, 0x1cd0, 43},
		EAWEntry{.neutral, 0x1d00, 250},
		EAWEntry{.neutral, 0x1dfb, 283},
		EAWEntry{.neutral, 0x1f18, 6},
		EAWEntry{.neutral, 0x1f20, 38},
		EAWEntry{.neutral, 0x1f48, 6},
		EAWEntry{.neutral, 0x1f50, 8},
		EAWEntry{.neutral, 0x1f59, 1},
		EAWEntry{.neutral, 0x1f5b, 1},
		EAWEntry{.neutral, 0x1f5d, 1},
		EAWEntry{.neutral, 0x1f5f, 31},
		EAWEntry{.neutral, 0x1f80, 53},
		EAWEntry{.neutral, 0x1fb6, 15},
		EAWEntry{.neutral, 0x1fc6, 14},
		EAWEntry{.neutral, 0x1fd6, 6},
		EAWEntry{.neutral, 0x1fdd, 19},
		EAWEntry{.neutral, 0x1ff2, 3},
		EAWEntry{.neutral, 0x1ff6, 9},
		EAWEntry{.neutral, 0x2000, 16},
		EAWEntry{.ambiguous, 0x2010, 1},
		EAWEntry{.neutral, 0x2011, 2},
		EAWEntry{.ambiguous, 0x2013, 4},
		EAWEntry{.neutral, 0x2017, 1},
		EAWEntry{.ambiguous, 0x2018, 2},
		EAWEntry{.neutral, 0x201a, 2},
		EAWEntry{.ambiguous, 0x201c, 2},
		EAWEntry{.neutral, 0x201e, 2},
		EAWEntry{.ambiguous, 0x2020, 3},
		EAWEntry{.neutral, 0x2023, 1},
		EAWEntry{.ambiguous, 0x2024, 4},
		EAWEntry{.neutral, 0x2028, 8},
		EAWEntry{.ambiguous, 0x2030, 1},
		EAWEntry{.neutral, 0x2031, 1},
		EAWEntry{.ambiguous, 0x2032, 2},
		EAWEntry{.neutral, 0x2034, 1},
		EAWEntry{.ambiguous, 0x2035, 1},
		EAWEntry{.neutral, 0x2036, 5},
		EAWEntry{.ambiguous, 0x203b, 1},
		EAWEntry{.neutral, 0x203c, 2},
		EAWEntry{.ambiguous, 0x203e, 1},
		EAWEntry{.neutral, 0x203f, 38},
		EAWEntry{.neutral, 0x2066, 12},
		EAWEntry{.ambiguous, 0x2074, 1},
		EAWEntry{.neutral, 0x2075, 10},
		EAWEntry{.ambiguous, 0x207f, 1},
		EAWEntry{.neutral, 0x2080, 1},
		EAWEntry{.ambiguous, 0x2081, 4},
		EAWEntry{.neutral, 0x2085, 10},
		EAWEntry{.neutral, 0x2090, 13},
		EAWEntry{.neutral, 0x20a0, 9},
		EAWEntry{.half, 0x20a9, 1},
		EAWEntry{.neutral, 0x20aa, 2},
		EAWEntry{.ambiguous, 0x20ac, 1},
		EAWEntry{.neutral, 0x20ad, 19},
		EAWEntry{.neutral, 0x20d0, 33},
		EAWEntry{.neutral, 0x2100, 3},
		EAWEntry{.ambiguous, 0x2103, 1},
		EAWEntry{.neutral, 0x2104, 1},
		EAWEntry{.ambiguous, 0x2105, 1},
		EAWEntry{.neutral, 0x2106, 3},
		EAWEntry{.ambiguous, 0x2109, 1},
		EAWEntry{.neutral, 0x210a, 9},
		EAWEntry{.ambiguous, 0x2113, 1},
		EAWEntry{.neutral, 0x2114, 2},
		EAWEntry{.ambiguous, 0x2116, 1},
		EAWEntry{.neutral, 0x2117, 10},
		EAWEntry{.ambiguous, 0x2121, 2},
		EAWEntry{.neutral, 0x2123, 3},
		EAWEntry{.ambiguous, 0x2126, 1},
		EAWEntry{.neutral, 0x2127, 4},
		EAWEntry{.ambiguous, 0x212b, 1},
		EAWEntry{.neutral, 0x212c, 39},
		EAWEntry{.ambiguous, 0x2153, 2},
		EAWEntry{.neutral, 0x2155, 6},
		EAWEntry{.ambiguous, 0x215b, 4},
		EAWEntry{.neutral, 0x215f, 1},
		EAWEntry{.ambiguous, 0x2160, 12},
		EAWEntry{.neutral, 0x216c, 4},
		EAWEntry{.ambiguous, 0x2170, 10},
		EAWEntry{.neutral, 0x217a, 15},
		EAWEntry{.ambiguous, 0x2189, 1},
		EAWEntry{.neutral, 0x218a, 2},
		EAWEntry{.ambiguous, 0x2190, 10},
		EAWEntry{.neutral, 0x219a, 30},
		EAWEntry{.ambiguous, 0x21b8, 2},
		EAWEntry{.neutral, 0x21ba, 24},
		EAWEntry{.ambiguous, 0x21d2, 1},
		EAWEntry{.neutral, 0x21d3, 1},
		EAWEntry{.ambiguous, 0x21d4, 1},
		EAWEntry{.neutral, 0x21d5, 18},
		EAWEntry{.ambiguous, 0x21e7, 1},
		EAWEntry{.neutral, 0x21e8, 24},
		EAWEntry{.ambiguous, 0x2200, 1},
		EAWEntry{.neutral, 0x2201, 1},
		EAWEntry{.ambiguous, 0x2202, 2},
		EAWEntry{.neutral, 0x2204, 3},
		EAWEntry{.ambiguous, 0x2207, 2},
		EAWEntry{.neutral, 0x2209, 2},
		EAWEntry{.ambiguous, 0x220b, 1},
		EAWEntry{.neutral, 0x220c, 3},
		EAWEntry{.ambiguous, 0x220f, 1},
		EAWEntry{.neutral, 0x2210, 1},
		EAWEntry{.ambiguous, 0x2211, 1},
		EAWEntry{.neutral, 0x2212, 3},
		EAWEntry{.ambiguous, 0x2215, 1},
		EAWEntry{.neutral, 0x2216, 4},
		EAWEntry{.ambiguous, 0x221a, 1},
		EAWEntry{.neutral, 0x221b, 2},
		EAWEntry{.ambiguous, 0x221d, 4},
		EAWEntry{.neutral, 0x2221, 2},
		EAWEntry{.ambiguous, 0x2223, 1},
		EAWEntry{.neutral, 0x2224, 1},
		EAWEntry{.ambiguous, 0x2225, 1},
		EAWEntry{.neutral, 0x2226, 1},
		EAWEntry{.ambiguous, 0x2227, 6},
		EAWEntry{.neutral, 0x222d, 1},
		EAWEntry{.ambiguous, 0x222e, 1},
		EAWEntry{.neutral, 0x222f, 5},
		EAWEntry{.ambiguous, 0x2234, 4},
		EAWEntry{.neutral, 0x2238, 4},
		EAWEntry{.ambiguous, 0x223c, 2},
		EAWEntry{.neutral, 0x223e, 10},
		EAWEntry{.ambiguous, 0x2248, 1},
		EAWEntry{.neutral, 0x2249, 3},
		EAWEntry{.ambiguous, 0x224c, 1},
		EAWEntry{.neutral, 0x224d, 5},
		EAWEntry{.ambiguous, 0x2252, 1},
		EAWEntry{.neutral, 0x2253, 13},
		EAWEntry{.ambiguous, 0x2260, 2},
		EAWEntry{.neutral, 0x2262, 2},
		EAWEntry{.ambiguous, 0x2264, 4},
		EAWEntry{.neutral, 0x2268, 2},
		EAWEntry{.ambiguous, 0x226a, 2},
		EAWEntry{.neutral, 0x226c, 2},
		EAWEntry{.ambiguous, 0x226e, 2},
		EAWEntry{.neutral, 0x2270, 18},
		EAWEntry{.ambiguous, 0x2282, 2},
		EAWEntry{.neutral, 0x2284, 2},
		EAWEntry{.ambiguous, 0x2286, 2},
		EAWEntry{.neutral, 0x2288, 13},
		EAWEntry{.ambiguous, 0x2295, 1},
		EAWEntry{.neutral, 0x2296, 3},
		EAWEntry{.ambiguous, 0x2299, 1},
		EAWEntry{.neutral, 0x229a, 11},
		EAWEntry{.ambiguous, 0x22a5, 1},
		EAWEntry{.neutral, 0x22a6, 25},
		EAWEntry{.ambiguous, 0x22bf, 1},
		EAWEntry{.neutral, 0x22c0, 82},
		EAWEntry{.ambiguous, 0x2312, 1},
		EAWEntry{.neutral, 0x2313, 7},
		EAWEntry{.wide, 0x231a, 2},
		EAWEntry{.neutral, 0x231c, 13},
		EAWEntry{.wide, 0x2329, 2},
		EAWEntry{.neutral, 0x232b, 190},
		EAWEntry{.wide, 0x23e9, 4},
		EAWEntry{.neutral, 0x23ed, 3},
		EAWEntry{.wide, 0x23f0, 1},
		EAWEntry{.neutral, 0x23f1, 2},
		EAWEntry{.wide, 0x23f3, 1},
		EAWEntry{.neutral, 0x23f4, 51},
		EAWEntry{.neutral, 0x2440, 11},
		EAWEntry{.ambiguous, 0x2460, 138},
		EAWEntry{.neutral, 0x24ea, 1},
		EAWEntry{.ambiguous, 0x24eb, 97},
		EAWEntry{.neutral, 0x254c, 4},
		EAWEntry{.ambiguous, 0x2550, 36},
		EAWEntry{.neutral, 0x2574, 12},
		EAWEntry{.ambiguous, 0x2580, 16},
		EAWEntry{.neutral, 0x2590, 2},
		EAWEntry{.ambiguous, 0x2592, 4},
		EAWEntry{.neutral, 0x2596, 10},
		EAWEntry{.ambiguous, 0x25a0, 2},
		EAWEntry{.neutral, 0x25a2, 1},
		EAWEntry{.ambiguous, 0x25a3, 7},
		EAWEntry{.neutral, 0x25aa, 8},
		EAWEntry{.ambiguous, 0x25b2, 2},
		EAWEntry{.neutral, 0x25b4, 2},
		EAWEntry{.ambiguous, 0x25b6, 2},
		EAWEntry{.neutral, 0x25b8, 4},
		EAWEntry{.ambiguous, 0x25bc, 2},
		EAWEntry{.neutral, 0x25be, 2},
		EAWEntry{.ambiguous, 0x25c0, 2},
		EAWEntry{.neutral, 0x25c2, 4},
		EAWEntry{.ambiguous, 0x25c6, 3},
		EAWEntry{.neutral, 0x25c9, 2},
		EAWEntry{.ambiguous, 0x25cb, 1},
		EAWEntry{.neutral, 0x25cc, 2},
		EAWEntry{.ambiguous, 0x25ce, 4},
		EAWEntry{.neutral, 0x25d2, 16},
		EAWEntry{.ambiguous, 0x25e2, 4},
		EAWEntry{.neutral, 0x25e6, 9},
		EAWEntry{.ambiguous, 0x25ef, 1},
		EAWEntry{.neutral, 0x25f0, 13},
		EAWEntry{.wide, 0x25fd, 2},
		EAWEntry{.neutral, 0x25ff, 6},
		EAWEntry{.ambiguous, 0x2605, 2},
		EAWEntry{.neutral, 0x2607, 2},
		EAWEntry{.ambiguous, 0x2609, 1},
		EAWEntry{.neutral, 0x260a, 4},
		EAWEntry{.ambiguous, 0x260e, 2},
		EAWEntry{.neutral, 0x2610, 4},
		EAWEntry{.wide, 0x2614, 2},
		EAWEntry{.neutral, 0x2616, 6},
		EAWEntry{.ambiguous, 0x261c, 1},
		EAWEntry{.neutral, 0x261d, 1},
		EAWEntry{.ambiguous, 0x261e, 1},
		EAWEntry{.neutral, 0x261f, 33},
		EAWEntry{.ambiguous, 0x2640, 1},
		EAWEntry{.neutral, 0x2641, 1},
		EAWEntry{.ambiguous, 0x2642, 1},
		EAWEntry{.neutral, 0x2643, 5},
		EAWEntry{.wide, 0x2648, 12},
		EAWEntry{.neutral, 0x2654, 12},
		EAWEntry{.ambiguous, 0x2660, 2},
		EAWEntry{.neutral, 0x2662, 1},
		EAWEntry{.ambiguous, 0x2663, 3},
		EAWEntry{.neutral, 0x2666, 1},
		EAWEntry{.ambiguous, 0x2667, 4},
		EAWEntry{.neutral, 0x266b, 1},
		EAWEntry{.ambiguous, 0x266c, 2},
		EAWEntry{.neutral, 0x266e, 1},
		EAWEntry{.ambiguous, 0x266f, 1},
		EAWEntry{.neutral, 0x2670, 15},
		EAWEntry{.wide, 0x267f, 1},
		EAWEntry{.neutral, 0x2680, 19},
		EAWEntry{.wide, 0x2693, 1},
		EAWEntry{.neutral, 0x2694, 10},
		EAWEntry{.ambiguous, 0x269e, 2},
		EAWEntry{.neutral, 0x26a0, 1},
		EAWEntry{.wide, 0x26a1, 1},
		EAWEntry{.neutral, 0x26a2, 8},
		EAWEntry{.wide, 0x26aa, 2},
		EAWEntry{.neutral, 0x26ac, 17},
		EAWEntry{.wide, 0x26bd, 2},
		EAWEntry{.ambiguous, 0x26bf, 1},
		EAWEntry{.neutral, 0x26c0, 4},
		EAWEntry{.wide, 0x26c4, 2},
		EAWEntry{.ambiguous, 0x26c6, 8},
		EAWEntry{.wide, 0x26ce, 1},
		EAWEntry{.ambiguous, 0x26cf, 5},
		EAWEntry{.wide, 0x26d4, 1},
		EAWEntry{.ambiguous, 0x26d5, 13},
		EAWEntry{.neutral, 0x26e2, 1},
		EAWEntry{.ambiguous, 0x26e3, 1},
		EAWEntry{.neutral, 0x26e4, 4},
		EAWEntry{.ambiguous, 0x26e8, 2},
		EAWEntry{.wide, 0x26ea, 1},
		EAWEntry{.ambiguous, 0x26eb, 7},
		EAWEntry{.wide, 0x26f2, 2},
		EAWEntry{.ambiguous, 0x26f4, 1},
		EAWEntry{.wide, 0x26f5, 1},
		EAWEntry{.ambiguous, 0x26f6, 4},
		EAWEntry{.wide, 0x26fa, 1},
		EAWEntry{.ambiguous, 0x26fb, 2},
		EAWEntry{.wide, 0x26fd, 1},
		EAWEntry{.ambiguous, 0x26fe, 2},
		EAWEntry{.neutral, 0x2700, 5},
		EAWEntry{.wide, 0x2705, 1},
		EAWEntry{.neutral, 0x2706, 4},
		EAWEntry{.wide, 0x270a, 2},
		EAWEntry{.neutral, 0x270c, 28},
		EAWEntry{.wide, 0x2728, 1},
		EAWEntry{.neutral, 0x2729, 20},
		EAWEntry{.ambiguous, 0x273d, 1},
		EAWEntry{.neutral, 0x273e, 14},
		EAWEntry{.wide, 0x274c, 1},
		EAWEntry{.neutral, 0x274d, 1},
		EAWEntry{.wide, 0x274e, 1},
		EAWEntry{.neutral, 0x274f, 4},
		EAWEntry{.wide, 0x2753, 3},
		EAWEntry{.neutral, 0x2756, 1},
		EAWEntry{.wide, 0x2757, 1},
		EAWEntry{.neutral, 0x2758, 30},
		EAWEntry{.ambiguous, 0x2776, 10},
		EAWEntry{.neutral, 0x2780, 21},
		EAWEntry{.wide, 0x2795, 3},
		EAWEntry{.neutral, 0x2798, 24},
		EAWEntry{.wide, 0x27b0, 1},
		EAWEntry{.neutral, 0x27b1, 14},
		EAWEntry{.wide, 0x27bf, 1},
		EAWEntry{.neutral, 0x27c0, 38},
		EAWEntry{.narrow, 0x27e6, 8},
		EAWEntry{.neutral, 0x27ee, 407},
		EAWEntry{.narrow, 0x2985, 2},
		EAWEntry{.neutral, 0x2987, 404},
		EAWEntry{.wide, 0x2b1b, 2},
		EAWEntry{.neutral, 0x2b1d, 51},
		EAWEntry{.wide, 0x2b50, 1},
		EAWEntry{.neutral, 0x2b51, 4},
		EAWEntry{.wide, 0x2b55, 1},
		EAWEntry{.ambiguous, 0x2b56, 4},
		EAWEntry{.neutral, 0x2b5a, 26},
		EAWEntry{.neutral, 0x2b76, 32},
		EAWEntry{.neutral, 0x2b97, 152},
		EAWEntry{.neutral, 0x2c30, 47},
		EAWEntry{.neutral, 0x2c60, 148},
		EAWEntry{.neutral, 0x2cf9, 45},
		EAWEntry{.neutral, 0x2d27, 1},
		EAWEntry{.neutral, 0x2d2d, 1},
		EAWEntry{.neutral, 0x2d30, 56},
		EAWEntry{.neutral, 0x2d6f, 2},
		EAWEntry{.neutral, 0x2d7f, 24},
		EAWEntry{.neutral, 0x2da0, 7},
		EAWEntry{.neutral, 0x2da8, 7},
		EAWEntry{.neutral, 0x2db0, 7},
		EAWEntry{.neutral, 0x2db8, 7},
		EAWEntry{.neutral, 0x2dc0, 7},
		EAWEntry{.neutral, 0x2dc8, 7},
		EAWEntry{.neutral, 0x2dd0, 7},
		EAWEntry{.neutral, 0x2dd8, 7},
		EAWEntry{.neutral, 0x2de0, 115},
		EAWEntry{.wide, 0x2e80, 26},
		EAWEntry{.wide, 0x2e9b, 89},
		EAWEntry{.wide, 0x2f00, 214},
		EAWEntry{.wide, 0x2ff0, 12},
		EAWEntry{.full, 0x3000, 1},
		EAWEntry{.wide, 0x3001, 62},
		EAWEntry{.neutral, 0x303f, 1},
		EAWEntry{.wide, 0x3041, 86},
		EAWEntry{.wide, 0x3099, 103},
		EAWEntry{.wide, 0x3105, 43},
		EAWEntry{.wide, 0x3131, 94},
		EAWEntry{.wide, 0x3190, 84},
		EAWEntry{.wide, 0x31f0, 47},
		EAWEntry{.wide, 0x3220, 40},
		EAWEntry{.ambiguous, 0x3248, 8},
		EAWEntry{.wide, 0x3250, 7024},
		EAWEntry{.neutral, 0x4dc0, 64},
		EAWEntry{.wide, 0x4e00, 22157},
		EAWEntry{.wide, 0xa490, 55},
		EAWEntry{.neutral, 0xa4d0, 348},
		EAWEntry{.neutral, 0xa640, 184},
		EAWEntry{.neutral, 0xa700, 192},
		EAWEntry{.neutral, 0xa7c2, 9},
		EAWEntry{.neutral, 0xa7f5, 56},
		EAWEntry{.neutral, 0xa830, 10},
		EAWEntry{.neutral, 0xa840, 56},
		EAWEntry{.neutral, 0xa880, 70},
		EAWEntry{.neutral, 0xa8ce, 12},
		EAWEntry{.neutral, 0xa8e0, 116},
		EAWEntry{.neutral, 0xa95f, 1},
		EAWEntry{.wide, 0xa960, 29},
		EAWEntry{.neutral, 0xa980, 78},
		EAWEntry{.neutral, 0xa9cf, 11},
		EAWEntry{.neutral, 0xa9de, 33},
		EAWEntry{.neutral, 0xaa00, 55},
		EAWEntry{.neutral, 0xaa40, 14},
		EAWEntry{.neutral, 0xaa50, 10},
		EAWEntry{.neutral, 0xaa5c, 103},
		EAWEntry{.neutral, 0xaadb, 28},
		EAWEntry{.neutral, 0xab01, 6},
		EAWEntry{.neutral, 0xab09, 6},
		EAWEntry{.neutral, 0xab11, 6},
		EAWEntry{.neutral, 0xab20, 7},
		EAWEntry{.neutral, 0xab28, 7},
		EAWEntry{.neutral, 0xab30, 60},
		EAWEntry{.neutral, 0xab70, 126},
		EAWEntry{.neutral, 0xabf0, 10},
		EAWEntry{.wide, 0xac00, 11172},
		EAWEntry{.neutral, 0xd7b0, 23},
		EAWEntry{.neutral, 0xd7cb, 49},
		EAWEntry{.neutral, 0xd800, 2048},
		EAWEntry{.ambiguous, 0xe000, 6400},
		EAWEntry{.wide, 0xf900, 512},
		EAWEntry{.neutral, 0xfb00, 7},
		EAWEntry{.neutral, 0xfb13, 5},
		EAWEntry{.neutral, 0xfb1d, 26},
		EAWEntry{.neutral, 0xfb38, 5},
		EAWEntry{.neutral, 0xfb3e, 1},
		EAWEntry{.neutral, 0xfb40, 2},
		EAWEntry{.neutral, 0xfb43, 2},
		EAWEntry{.neutral, 0xfb46, 124},
		EAWEntry{.neutral, 0xfbd3, 365},
		EAWEntry{.neutral, 0xfd50, 64},
		EAWEntry{.neutral, 0xfd92, 54},
		EAWEntry{.neutral, 0xfdf0, 14},
		EAWEntry{.ambiguous, 0xfe00, 16},
		EAWEntry{.wide, 0xfe10, 10},
		EAWEntry{.neutral, 0xfe20, 16},
		EAWEntry{.wide, 0xfe30, 35},
		EAWEntry{.wide, 0xfe54, 19},
		EAWEntry{.wide, 0xfe68, 4},
		EAWEntry{.neutral, 0xfe70, 5},
		EAWEntry{.neutral, 0xfe76, 135},
		EAWEntry{.neutral, 0xfeff, 1},
		EAWEntry{.full, 0xff01, 96},
		EAWEntry{.half, 0xff61, 94},
		EAWEntry{.half, 0xffc2, 6},
		EAWEntry{.half, 0xffca, 6},
		EAWEntry{.half, 0xffd2, 6},
		EAWEntry{.half, 0xffda, 3},
		EAWEntry{.full, 0xffe0, 7},
		EAWEntry{.half, 0xffe8, 7},
		EAWEntry{.neutral, 0xfff9, 4},
		EAWEntry{.ambiguous, 0xfffd, 1},
		EAWEntry{.neutral, 0x10000, 12},
		EAWEntry{.neutral, 0x1000d, 26},
		EAWEntry{.neutral, 0x10028, 19},
		EAWEntry{.neutral, 0x1003c, 2},
		EAWEntry{.neutral, 0x1003f, 15},
		EAWEntry{.neutral, 0x10050, 14},
		EAWEntry{.neutral, 0x10080, 123},
		EAWEntry{.neutral, 0x10100, 3},
		EAWEntry{.neutral, 0x10107, 45},
		EAWEntry{.neutral, 0x10137, 88},
		EAWEntry{.neutral, 0x10190, 13},
		EAWEntry{.neutral, 0x101a0, 1},
		EAWEntry{.neutral, 0x101d0, 46},
		EAWEntry{.neutral, 0x10280, 29},
		EAWEntry{.neutral, 0x102a0, 49},
		EAWEntry{.neutral, 0x102e0, 28},
		EAWEntry{.neutral, 0x10300, 36},
		EAWEntry{.neutral, 0x1032d, 30},
		EAWEntry{.neutral, 0x10350, 43},
		EAWEntry{.neutral, 0x10380, 30},
		EAWEntry{.neutral, 0x1039f, 37},
		EAWEntry{.neutral, 0x103c8, 14},
		EAWEntry{.neutral, 0x10400, 158},
		EAWEntry{.neutral, 0x104a0, 10},
		EAWEntry{.neutral, 0x104b0, 36},
		EAWEntry{.neutral, 0x104d8, 36},
		EAWEntry{.neutral, 0x10500, 40},
		EAWEntry{.neutral, 0x10530, 52},
		EAWEntry{.neutral, 0x1056f, 1},
		EAWEntry{.neutral, 0x10600, 311},
		EAWEntry{.neutral, 0x10740, 22},
		EAWEntry{.neutral, 0x10760, 8},
		EAWEntry{.neutral, 0x10800, 6},
		EAWEntry{.neutral, 0x10808, 1},
		EAWEntry{.neutral, 0x1080a, 44},
		EAWEntry{.neutral, 0x10837, 2},
		EAWEntry{.neutral, 0x1083c, 1},
		EAWEntry{.neutral, 0x1083f, 23},
		EAWEntry{.neutral, 0x10857, 72},
		EAWEntry{.neutral, 0x108a7, 9},
		EAWEntry{.neutral, 0x108e0, 19},
		EAWEntry{.neutral, 0x108f4, 2},
		EAWEntry{.neutral, 0x108fb, 33},
		EAWEntry{.neutral, 0x1091f, 27},
		EAWEntry{.neutral, 0x1093f, 1},
		EAWEntry{.neutral, 0x10980, 56},
		EAWEntry{.neutral, 0x109bc, 20},
		EAWEntry{.neutral, 0x109d2, 50},
		EAWEntry{.neutral, 0x10a05, 2},
		EAWEntry{.neutral, 0x10a0c, 8},
		EAWEntry{.neutral, 0x10a15, 3},
		EAWEntry{.neutral, 0x10a19, 29},
		EAWEntry{.neutral, 0x10a38, 3},
		EAWEntry{.neutral, 0x10a3f, 10},
		EAWEntry{.neutral, 0x10a50, 9},
		EAWEntry{.neutral, 0x10a60, 64},
		EAWEntry{.neutral, 0x10ac0, 39},
		EAWEntry{.neutral, 0x10aeb, 12},
		EAWEntry{.neutral, 0x10b00, 54},
		EAWEntry{.neutral, 0x10b39, 29},
		EAWEntry{.neutral, 0x10b58, 27},
		EAWEntry{.neutral, 0x10b78, 26},
		EAWEntry{.neutral, 0x10b99, 4},
		EAWEntry{.neutral, 0x10ba9, 7},
		EAWEntry{.neutral, 0x10c00, 73},
		EAWEntry{.neutral, 0x10c80, 51},
		EAWEntry{.neutral, 0x10cc0, 51},
		EAWEntry{.neutral, 0x10cfa, 46},
		EAWEntry{.neutral, 0x10d30, 10},
		EAWEntry{.neutral, 0x10e60, 31},
		EAWEntry{.neutral, 0x10e80, 42},
		EAWEntry{.neutral, 0x10eab, 3},
		EAWEntry{.neutral, 0x10eb0, 2},
		EAWEntry{.neutral, 0x10f00, 40},
		EAWEntry{.neutral, 0x10f30, 42},
		EAWEntry{.neutral, 0x10fb0, 28},
		EAWEntry{.neutral, 0x10fe0, 23},
		EAWEntry{.neutral, 0x11000, 78},
		EAWEntry{.neutral, 0x11052, 30},
		EAWEntry{.neutral, 0x1107f, 67},
		EAWEntry{.neutral, 0x110cd, 1},
		EAWEntry{.neutral, 0x110d0, 25},
		EAWEntry{.neutral, 0x110f0, 10},
		EAWEntry{.neutral, 0x11100, 53},
		EAWEntry{.neutral, 0x11136, 18},
		EAWEntry{.neutral, 0x11150, 39},
		EAWEntry{.neutral, 0x11180, 96},
		EAWEntry{.neutral, 0x111e1, 20},
		EAWEntry{.neutral, 0x11200, 18},
		EAWEntry{.neutral, 0x11213, 44},
		EAWEntry{.neutral, 0x11280, 7},
		EAWEntry{.neutral, 0x11288, 1},
		EAWEntry{.neutral, 0x1128a, 4},
		EAWEntry{.neutral, 0x1128f, 15},
		EAWEntry{.neutral, 0x1129f, 11},
		EAWEntry{.neutral, 0x112b0, 59},
		EAWEntry{.neutral, 0x112f0, 10},
		EAWEntry{.neutral, 0x11300, 4},
		EAWEntry{.neutral, 0x11305, 8},
		EAWEntry{.neutral, 0x1130f, 2},
		EAWEntry{.neutral, 0x11313, 22},
		EAWEntry{.neutral, 0x1132a, 7},
		EAWEntry{.neutral, 0x11332, 2},
		EAWEntry{.neutral, 0x11335, 5},
		EAWEntry{.neutral, 0x1133b, 10},
		EAWEntry{.neutral, 0x11347, 2},
		EAWEntry{.neutral, 0x1134b, 3},
		EAWEntry{.neutral, 0x11350, 1},
		EAWEntry{.neutral, 0x11357, 1},
		EAWEntry{.neutral, 0x1135d, 7},
		EAWEntry{.neutral, 0x11366, 7},
		EAWEntry{.neutral, 0x11370, 5},
		EAWEntry{.neutral, 0x11400, 92},
		EAWEntry{.neutral, 0x1145d, 5},
		EAWEntry{.neutral, 0x11480, 72},
		EAWEntry{.neutral, 0x114d0, 10},
		EAWEntry{.neutral, 0x11580, 54},
		EAWEntry{.neutral, 0x115b8, 38},
		EAWEntry{.neutral, 0x11600, 69},
		EAWEntry{.neutral, 0x11650, 10},
		EAWEntry{.neutral, 0x11660, 13},
		EAWEntry{.neutral, 0x11680, 57},
		EAWEntry{.neutral, 0x116c0, 10},
		EAWEntry{.neutral, 0x11700, 27},
		EAWEntry{.neutral, 0x1171d, 15},
		EAWEntry{.neutral, 0x11730, 16},
		EAWEntry{.neutral, 0x11800, 60},
		EAWEntry{.neutral, 0x118a0, 83},
		EAWEntry{.neutral, 0x118ff, 8},
		EAWEntry{.neutral, 0x11909, 1},
		EAWEntry{.neutral, 0x1190c, 8},
		EAWEntry{.neutral, 0x11915, 2},
		EAWEntry{.neutral, 0x11918, 30},
		EAWEntry{.neutral, 0x11937, 2},
		EAWEntry{.neutral, 0x1193b, 12},
		EAWEntry{.neutral, 0x11950, 10},
		EAWEntry{.neutral, 0x119a0, 8},
		EAWEntry{.neutral, 0x119aa, 46},
		EAWEntry{.neutral, 0x119da, 11},
		EAWEntry{.neutral, 0x11a00, 72},
		EAWEntry{.neutral, 0x11a50, 83},
		EAWEntry{.neutral, 0x11ac0, 57},
		EAWEntry{.neutral, 0x11c00, 9},
		EAWEntry{.neutral, 0x11c0a, 45},
		EAWEntry{.neutral, 0x11c38, 14},
		EAWEntry{.neutral, 0x11c50, 29},
		EAWEntry{.neutral, 0x11c70, 32},
		EAWEntry{.neutral, 0x11c92, 22},
		EAWEntry{.neutral, 0x11ca9, 14},
		EAWEntry{.neutral, 0x11d00, 7},
		EAWEntry{.neutral, 0x11d08, 2},
		EAWEntry{.neutral, 0x11d0b, 44},
		EAWEntry{.neutral, 0x11d3a, 1},
		EAWEntry{.neutral, 0x11d3c, 2},
		EAWEntry{.neutral, 0x11d3f, 9},
		EAWEntry{.neutral, 0x11d50, 10},
		EAWEntry{.neutral, 0x11d60, 6},
		EAWEntry{.neutral, 0x11d67, 2},
		EAWEntry{.neutral, 0x11d6a, 37},
		EAWEntry{.neutral, 0x11d90, 2},
		EAWEntry{.neutral, 0x11d93, 6},
		EAWEntry{.neutral, 0x11da0, 10},
		EAWEntry{.neutral, 0x11ee0, 25},
		EAWEntry{.neutral, 0x11fb0, 1},
		EAWEntry{.neutral, 0x11fc0, 50},
		EAWEntry{.neutral, 0x11fff, 923},
		EAWEntry{.neutral, 0x12400, 111},
		EAWEntry{.neutral, 0x12470, 5},
		EAWEntry{.neutral, 0x12480, 196},
		EAWEntry{.neutral, 0x13000, 1071},
		EAWEntry{.neutral, 0x13430, 9},
		EAWEntry{.neutral, 0x14400, 583},
		EAWEntry{.neutral, 0x16800, 569},
		EAWEntry{.neutral, 0x16a40, 31},
		EAWEntry{.neutral, 0x16a60, 10},
		EAWEntry{.neutral, 0x16a6e, 2},
		EAWEntry{.neutral, 0x16ad0, 30},
		EAWEntry{.neutral, 0x16af0, 6},
		EAWEntry{.neutral, 0x16b00, 70},
		EAWEntry{.neutral, 0x16b50, 10},
		EAWEntry{.neutral, 0x16b5b, 7},
		EAWEntry{.neutral, 0x16b63, 21},
		EAWEntry{.neutral, 0x16b7d, 19},
		EAWEntry{.neutral, 0x16e40, 91},
		EAWEntry{.neutral, 0x16f00, 75},
		EAWEntry{.neutral, 0x16f4f, 57},
		EAWEntry{.neutral, 0x16f8f, 17},
		EAWEntry{.wide, 0x16fe0, 5},
		EAWEntry{.wide, 0x16ff0, 2},
		EAWEntry{.wide, 0x17000, 6136},
		EAWEntry{.wide, 0x18800, 1238},
		EAWEntry{.wide, 0x18d00, 9},
		EAWEntry{.wide, 0x1b000, 287},
		EAWEntry{.wide, 0x1b150, 3},
		EAWEntry{.wide, 0x1b164, 4},
		EAWEntry{.wide, 0x1b170, 396},
		EAWEntry{.neutral, 0x1bc00, 107},
		EAWEntry{.neutral, 0x1bc70, 13},
		EAWEntry{.neutral, 0x1bc80, 9},
		EAWEntry{.neutral, 0x1bc90, 10},
		EAWEntry{.neutral, 0x1bc9c, 8},
		EAWEntry{.neutral, 0x1d000, 246},
		EAWEntry{.neutral, 0x1d100, 39},
		EAWEntry{.neutral, 0x1d129, 192},
		EAWEntry{.neutral, 0x1d200, 70},
		EAWEntry{.neutral, 0x1d2e0, 20},
		EAWEntry{.neutral, 0x1d300, 87},
		EAWEntry{.neutral, 0x1d360, 25},
		EAWEntry{.neutral, 0x1d400, 85},
		EAWEntry{.neutral, 0x1d456, 71},
		EAWEntry{.neutral, 0x1d49e, 2},
		EAWEntry{.neutral, 0x1d4a2, 1},
		EAWEntry{.neutral, 0x1d4a5, 2},
		EAWEntry{.neutral, 0x1d4a9, 4},
		EAWEntry{.neutral, 0x1d4ae, 12},
		EAWEntry{.neutral, 0x1d4bb, 1},
		EAWEntry{.neutral, 0x1d4bd, 7},
		EAWEntry{.neutral, 0x1d4c5, 65},
		EAWEntry{.neutral, 0x1d507, 4},
		EAWEntry{.neutral, 0x1d50d, 8},
		EAWEntry{.neutral, 0x1d516, 7},
		EAWEntry{.neutral, 0x1d51e, 28},
		EAWEntry{.neutral, 0x1d53b, 4},
		EAWEntry{.neutral, 0x1d540, 5},
		EAWEntry{.neutral, 0x1d546, 1},
		EAWEntry{.neutral, 0x1d54a, 7},
		EAWEntry{.neutral, 0x1d552, 340},
		EAWEntry{.neutral, 0x1d6a8, 292},
		EAWEntry{.neutral, 0x1d7ce, 702},
		EAWEntry{.neutral, 0x1da9b, 5},
		EAWEntry{.neutral, 0x1daa1, 15},
		EAWEntry{.neutral, 0x1e000, 7},
		EAWEntry{.neutral, 0x1e008, 17},
		EAWEntry{.neutral, 0x1e01b, 7},
		EAWEntry{.neutral, 0x1e023, 2},
		EAWEntry{.neutral, 0x1e026, 5},
		EAWEntry{.neutral, 0x1e100, 45},
		EAWEntry{.neutral, 0x1e130, 14},
		EAWEntry{.neutral, 0x1e140, 10},
		EAWEntry{.neutral, 0x1e14e, 2},
		EAWEntry{.neutral, 0x1e2c0, 58},
		EAWEntry{.neutral, 0x1e2ff, 1},
		EAWEntry{.neutral, 0x1e800, 197},
		EAWEntry{.neutral, 0x1e8c7, 16},
		EAWEntry{.neutral, 0x1e900, 76},
		EAWEntry{.neutral, 0x1e950, 10},
		EAWEntry{.neutral, 0x1e95e, 2},
		EAWEntry{.neutral, 0x1ec71, 68},
		EAWEntry{.neutral, 0x1ed01, 61},
		EAWEntry{.neutral, 0x1ee00, 4},
		EAWEntry{.neutral, 0x1ee05, 27},
		EAWEntry{.neutral, 0x1ee21, 2},
		EAWEntry{.neutral, 0x1ee24, 1},
		EAWEntry{.neutral, 0x1ee27, 1},
		EAWEntry{.neutral, 0x1ee29, 10},
		EAWEntry{.neutral, 0x1ee34, 4},
		EAWEntry{.neutral, 0x1ee39, 1},
		EAWEntry{.neutral, 0x1ee3b, 1},
		EAWEntry{.neutral, 0x1ee42, 1},
		EAWEntry{.neutral, 0x1ee47, 1},
		EAWEntry{.neutral, 0x1ee49, 1},
		EAWEntry{.neutral, 0x1ee4b, 1},
		EAWEntry{.neutral, 0x1ee4d, 3},
		EAWEntry{.neutral, 0x1ee51, 2},
		EAWEntry{.neutral, 0x1ee54, 1},
		EAWEntry{.neutral, 0x1ee57, 1},
		EAWEntry{.neutral, 0x1ee59, 1},
		EAWEntry{.neutral, 0x1ee5b, 1},
		EAWEntry{.neutral, 0x1ee5d, 1},
		EAWEntry{.neutral, 0x1ee5f, 1},
		EAWEntry{.neutral, 0x1ee61, 2},
		EAWEntry{.neutral, 0x1ee64, 1},
		EAWEntry{.neutral, 0x1ee67, 4},
		EAWEntry{.neutral, 0x1ee6c, 7},
		EAWEntry{.neutral, 0x1ee74, 4},
		EAWEntry{.neutral, 0x1ee79, 4},
		EAWEntry{.neutral, 0x1ee7e, 1},
		EAWEntry{.neutral, 0x1ee80, 10},
		EAWEntry{.neutral, 0x1ee8b, 17},
		EAWEntry{.neutral, 0x1eea1, 3},
		EAWEntry{.neutral, 0x1eea5, 5},
		EAWEntry{.neutral, 0x1eeab, 17},
		EAWEntry{.neutral, 0x1eef0, 2},
		EAWEntry{.neutral, 0x1f000, 4},
		EAWEntry{.wide, 0x1f004, 1},
		EAWEntry{.neutral, 0x1f005, 39},
		EAWEntry{.neutral, 0x1f030, 100},
		EAWEntry{.neutral, 0x1f0a0, 15},
		EAWEntry{.neutral, 0x1f0b1, 15},
		EAWEntry{.neutral, 0x1f0c1, 14},
		EAWEntry{.wide, 0x1f0cf, 1},
		EAWEntry{.neutral, 0x1f0d1, 37},
		EAWEntry{.ambiguous, 0x1f100, 11},
		EAWEntry{.neutral, 0x1f10b, 5},
		EAWEntry{.ambiguous, 0x1f110, 30},
		EAWEntry{.neutral, 0x1f12e, 2},
		EAWEntry{.ambiguous, 0x1f130, 58},
		EAWEntry{.neutral, 0x1f16a, 6},
		EAWEntry{.ambiguous, 0x1f170, 30},
		EAWEntry{.wide, 0x1f18e, 1},
		EAWEntry{.ambiguous, 0x1f18f, 2},
		EAWEntry{.wide, 0x1f191, 10},
		EAWEntry{.ambiguous, 0x1f19b, 18},
		EAWEntry{.neutral, 0x1f1ad, 1},
		EAWEntry{.neutral, 0x1f1e6, 26},
		EAWEntry{.wide, 0x1f200, 3},
		EAWEntry{.wide, 0x1f210, 44},
		EAWEntry{.wide, 0x1f240, 9},
		EAWEntry{.wide, 0x1f250, 2},
		EAWEntry{.wide, 0x1f260, 6},
		EAWEntry{.wide, 0x1f300, 33},
		EAWEntry{.neutral, 0x1f321, 12},
		EAWEntry{.wide, 0x1f32d, 9},
		EAWEntry{.neutral, 0x1f336, 1},
		EAWEntry{.wide, 0x1f337, 70},
		EAWEntry{.neutral, 0x1f37d, 1},
		EAWEntry{.wide, 0x1f37e, 22},
		EAWEntry{.neutral, 0x1f394, 12},
		EAWEntry{.wide, 0x1f3a0, 43},
		EAWEntry{.neutral, 0x1f3cb, 4},
		EAWEntry{.wide, 0x1f3cf, 5},
		EAWEntry{.neutral, 0x1f3d4, 12},
		EAWEntry{.wide, 0x1f3e0, 17},
		EAWEntry{.neutral, 0x1f3f1, 3},
		EAWEntry{.wide, 0x1f3f4, 1},
		EAWEntry{.neutral, 0x1f3f5, 3},
		EAWEntry{.wide, 0x1f3f8, 71},
		EAWEntry{.neutral, 0x1f43f, 1},
		EAWEntry{.wide, 0x1f440, 1},
		EAWEntry{.neutral, 0x1f441, 1},
		EAWEntry{.wide, 0x1f442, 187},
		EAWEntry{.neutral, 0x1f4fd, 2},
		EAWEntry{.wide, 0x1f4ff, 63},
		EAWEntry{.neutral, 0x1f53e, 13},
		EAWEntry{.wide, 0x1f54b, 4},
		EAWEntry{.neutral, 0x1f54f, 1},
		EAWEntry{.wide, 0x1f550, 24},
		EAWEntry{.neutral, 0x1f568, 18},
		EAWEntry{.wide, 0x1f57a, 1},
		EAWEntry{.neutral, 0x1f57b, 26},
		EAWEntry{.wide, 0x1f595, 2},
		EAWEntry{.neutral, 0x1f597, 13},
		EAWEntry{.wide, 0x1f5a4, 1},
		EAWEntry{.neutral, 0x1f5a5, 86},
		EAWEntry{.wide, 0x1f5fb, 85},
		EAWEntry{.neutral, 0x1f650, 48},
		EAWEntry{.wide, 0x1f680, 70},
		EAWEntry{.neutral, 0x1f6c6, 6},
		EAWEntry{.wide, 0x1f6cc, 1},
		EAWEntry{.neutral, 0x1f6cd, 3},
		EAWEntry{.wide, 0x1f6d0, 3},
		EAWEntry{.neutral, 0x1f6d3, 2},
		EAWEntry{.wide, 0x1f6d5, 3},
		EAWEntry{.neutral, 0x1f6e0, 11},
		EAWEntry{.wide, 0x1f6eb, 2},
		EAWEntry{.neutral, 0x1f6f0, 4},
		EAWEntry{.wide, 0x1f6f4, 9},
		EAWEntry{.neutral, 0x1f700, 116},
		EAWEntry{.neutral, 0x1f780, 89},
		EAWEntry{.wide, 0x1f7e0, 12},
		EAWEntry{.neutral, 0x1f800, 12},
		EAWEntry{.neutral, 0x1f810, 56},
		EAWEntry{.neutral, 0x1f850, 10},
		EAWEntry{.neutral, 0x1f860, 40},
		EAWEntry{.neutral, 0x1f890, 30},
		EAWEntry{.neutral, 0x1f8b0, 2},
		EAWEntry{.neutral, 0x1f900, 12},
		EAWEntry{.wide, 0x1f90c, 47},
		EAWEntry{.neutral, 0x1f93b, 1},
		EAWEntry{.wide, 0x1f93c, 10},
		EAWEntry{.neutral, 0x1f946, 1},
		EAWEntry{.wide, 0x1f947, 50},
		EAWEntry{.wide, 0x1f97a, 82},
		EAWEntry{.wide, 0x1f9cd, 51},
		EAWEntry{.neutral, 0x1fa00, 84},
		EAWEntry{.neutral, 0x1fa60, 14},
		EAWEntry{.wide, 0x1fa70, 5},
		EAWEntry{.wide, 0x1fa78, 3},
		EAWEntry{.wide, 0x1fa80, 7},
		EAWEntry{.wide, 0x1fa90, 25},
		EAWEntry{.wide, 0x1fab0, 7},
		EAWEntry{.wide, 0x1fac0, 3},
		EAWEntry{.wide, 0x1fad0, 7},
		EAWEntry{.neutral, 0x1fb00, 147},
		EAWEntry{.neutral, 0x1fb94, 55},
		EAWEntry{.neutral, 0x1fbf0, 10},
		EAWEntry{.wide, 0x20000, 65534},
		EAWEntry{.wide, 0x30000, 65534},
		EAWEntry{.neutral, 0xe0001, 1},
		EAWEntry{.neutral, 0xe0020, 96},
		EAWEntry{.ambiguous, 0xe0100, 240},
		EAWEntry{.ambiguous, 0xf0000, 65534},
		EAWEntry{.ambiguous, 0x100000, 65534},
	]
)
