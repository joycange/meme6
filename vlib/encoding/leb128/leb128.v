module leb128

// Encode int as byte array using leb128
pub fn encode_int(value int) []u8 {
	mut result := []u8{cap: int(sizeof(int))}
	mut val := value
	mut i := 0
	for {
		mut b := u8(val & 0x7f)
		val >>= 7
		if (val == 0 && b & 0x40 == 0) || (val == -1 && b & 0x40 != 0) {
			result << b
			break
		}
		result << b | 0x80
		i++
	}
	return result
}

// Encode i64 as byte array using leb128
pub fn encode_i64(value i64) []u8 {
	mut result := []u8{cap: 8}
	mut val := value
	for {
		mut b := u8(val & 0x7f)
		val >>= 7
		if (val == 0 && b & 0x40 == 0) || (val == -1 && b & 0x40 != 0) {
			result << b
			break
		}
		result << b | 0x80
	}
	return result
}

// Encode u64 as byte array using leb128
pub fn encode_u64(value u64) []u8 {
	mut result := []u8{cap: 8}
	mut val := value
	for {
		mut b := u8(val & 0x7f)
		val >>= 7
		if val == 0 {
			result << b
			break
		}
		result << b | 0x80
	}
	return result
}

// Encode u32 as byte array using leb128
pub fn encode_u32(value u32) []u8 {
	mut result := []u8{cap: 4}
	mut val := value
	for {
		mut b := u8(val & 0x7f)
		val >>= 7
		if val == 0 {
			result << b
			break
		}
		result << b | 0x80
	}
	return result
}

// Decode int from byte array using leb128
pub fn decode_int(value []u8) int {
	mut result := int(0)
	mut shift := 0
	for b in value {
		result |= b & 0x7f << shift
		shift += 7
		if b & 0x80 == 0 {
			if shift < sizeof(int) * 8 && b & 0x40 != 0 {
				result |= ~0 << shift
			}
			break
		}
	}
	return result
}

// Decode int from byte array using leb128
pub fn decode_i64(value []u8) i64 {
	mut result := i64(0)
	mut shift := 0
	for b in value {
		result |= i64(b & 0x7f) << shift
		shift += 7
		if b & 0x80 == 0 {
			if shift < 64 && b & 0x40 != 0 {
				result |= ~i64(0) << shift
			}
			break
		}
	}
	return result
}

// Decode int from byte array using leb128
pub fn decode_u64(value []u8) u64 {
	mut result := u64(0)
	mut shift := 0
	for b in value {
		result |= u64(b & 0x7f) << shift
		if b & 0x80 == 0 {
			break
		}
		shift += 7
	}
	return result
}

// Decode int from byte array using leb128
pub fn decode_u32(value []u8) u32 {
	mut result := u32(0)
	mut shift := 0
	for b in value {
		result |= u32(b & 0x7f) << shift
		if b & 0x80 == 0 {
			break
		}
		shift += 7
	}
	return result
}
