// Copyright (c) 2019-2022 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module pcg32

import rand.seed
import rand.constants

pub const seed_len = 4

// PCG32RNG ported from http://www.pcg-random.org/download.html,
// https://github.com/imneme/pcg-c-basic/blob/master/pcg_basic.c, and
// https://github.com/imneme/pcg-c-basic/blob/master/pcg_basic.h
pub struct PCG32RNG {
mut:
	state      u64 = u64(0x853c49e6748fea9b) ^ seed.time_seed_64()
	inc        u64 = u64(0xda3e39cb94b95bdb) ^ seed.time_seed_64()
	bytes_left int
	buffer     u32
}

// seed seeds the PCG32RNG with 4 `u32` values.
// The first 2 represent the 64-bit initial state as `[lower 32 bits, higher 32 bits]`
// The last 2 represent the 64-bit stream/step of the PRNG.
pub fn (mut rng PCG32RNG) seed(seed_data []u32) {
	if seed_data.len != 4 {
		eprintln('PCG32RNG needs 4 u32s to be seeded. First two the initial state and the last two the stream/step. Both in little endian format: [lower, higher].')
		exit(1)
	}
	init_state := u64(seed_data[0]) | (u64(seed_data[1]) << 32)
	init_seq := u64(seed_data[2]) | (u64(seed_data[3]) << 32)
	rng.state = u64(0)
	rng.inc = (init_seq << u64(1)) | u64(1)
	rng.u32()
	rng.state += init_state
	rng.u32()
}

// byte returns a uniformly distributed pseudorandom 8-bit unsigned positive `byte`.
[inline]
fn (mut rng PCG32RNG) byte() byte {
	// Can we extract a value from the buffer?
	if rng.bytes_left >= 1 {
		rng.bytes_left -= 1
		value := byte(rng.buffer)
		rng.buffer >>= 8
		return value
	}
	// Add a new value to the buffer
	rng.buffer = rng.internal_u32()
	rng.bytes_left = 3
	value := byte(rng.buffer)
	rng.buffer >>= 8
	return value
}

// bytes returns a buffer of `bytes_needed` random bytes.
[inline]
pub fn (mut rng PCG32RNG) bytes(bytes_needed int) ?[]byte {
	if bytes_needed < 0 {
		return error('can not read < 0 random bytes')
	}
	mut res := []byte{len: bytes_needed}

	rng.read(mut res)

	return res
}

// read fills up the buffer with random bytes.
pub fn (mut rng PCG32RNG) read(mut buf []byte) {
	mut bytes_needed := buf.len
	mut index := 0

	for _ in 0 .. rng.bytes_left {
		buf[index] = rng.byte()
		bytes_needed--
		index++
	}

	for bytes_needed >= 4 {
		mut full_value := rng.u32()
		for _ in 0 .. 4 {
			buf[index] = byte(full_value)
			full_value >>= 8
			index++
		}
		bytes_needed -= 4
	}

	for bytes_needed > 0 {
		buf[index] += rng.byte()
		index++
		bytes_needed--
	}
}

[inline]
fn (mut rng PCG32RNG) step_by(amount int) u32 {
	next_number := rng.internal_u32()

	bits_left := rng.bytes_left * 8
	bits_needed := amount - bits_left

	old_value := rng.buffer & ((u32(1) << bits_left) - 1)
	new_value := next_number & ((u32(1) << bits_needed) - 1)
	value := old_value | (new_value << bits_left)

	rng.buffer = next_number >> bits_needed
	rng.bytes_left = 4 - (bits_needed / 8)

	return value
}

// u16 returns a pseudorandom 16-bit unsigned integer (`u16`).
[inline]
pub fn (mut rng PCG32RNG) u16() u16 {
	// Can we take a whole u16 out of the buffer?
	if rng.bytes_left >= 2 {
		rng.bytes_left -= 2
		value := u16(rng.buffer)
		rng.buffer >>= 16
		return value
	}
	if rng.bytes_left > 0 {
		return u16(rng.step_by(16))
	}
	ans := rng.internal_u32()
	rng.buffer = ans >> 16
	rng.bytes_left = 2
	return u16(ans)
}

// u32 returns a pseudorandom unsigned `u32`.
[inline]
pub fn (mut rng PCG32RNG) u32() u32 {
	if rng.bytes_left >= 1 {
		return rng.step_by(32)
	}
	return rng.internal_u32()
}

fn (mut rng PCG32RNG) internal_u32() u32 {
	oldstate := rng.state
	rng.state = oldstate * (6364136223846793005) + rng.inc
	xorshifted := u32(((oldstate >> u64(18)) ^ oldstate) >> u64(27))
	rot := u32(oldstate >> u64(59))
	return (xorshifted >> rot) | (xorshifted << ((-rot) & u32(31)))
}

// u64 returns a pseudorandom 64-bit unsigned `u64`.
[inline]
pub fn (mut rng PCG32RNG) u64() u64 {
	return u64(rng.u32()) | (u64(rng.u32()) << 32)
}

// free should be called when the generator is no longer needed
[unsafe]
pub fn (mut rng PCG32RNG) free() {
	unsafe { free(rng) }
}
