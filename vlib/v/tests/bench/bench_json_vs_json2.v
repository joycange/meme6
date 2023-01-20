import os
import json
import x.json2
import time
import benchmark

// recommendations:
// MAX_ITERATIONS=90_000 ./v run vlib/v/tests/bench/bench_json_vs_json2.v
// MAX_ITERATIONS=90_000 ./v -no-bounds-checking -prod -cc clang-15 crun vlib/v/tests/bench/bench_json_vs_json2.v

fn main() {
	benchmark_measure_json_vs_json2()!
	println('')
	benchmark_measure_encode_by_type()!
	println('')
	benchmark_measure_encode_by_alias_type()!
	println('')
	benchmark_measure_decode_by_type()!
}

type StringAlias = string
type BoolAlias = bool
type IntAlias = int
type TimeAlias = time.Time
type StructAlias = StructType[int]
type EnumAlias = Enum

type SumTypes = StructType[string] | bool | int | string | time.Time

enum Enum {
	a
	b
	c
	d
	e = 99
	f
}

struct StructType[T] {
mut:
	val T
}

struct StructTypeOption[T] {
mut:
	val ?T
}

struct StructTypePointer[T] {
mut:
	val &T
}

struct Person {
	name       string
	age        int
	created_at time.Time
}

fn benchmark_measure_json_vs_json2() ! {
	max_iterations := os.getenv_opt('MAX_ITERATIONS') or { '1000' }.int()

	s := '{"name":"Bilbo Baggins","age":99,"created_at":1670840340}'
	mut b := benchmark.start()
	for _ in 0 .. max_iterations {
		p := json2.decode[Person](s)!
		if p.age != 99 {
			return error('json2.decode ${p}')
		}
	}
	b.measure('json2.decode')
	for _ in 0 .. max_iterations {
		p := json.decode(Person, s)!
		if p.age != 99 {
			return error('json.decode ${p}')
		}
	}
	b.measure('json.decode')

	measure_json_encode_old_vs_new(json.decode(Person, s)!, max_iterations)!
}

fn benchmark_measure_encode_by_type() ! {
	println(@FN)
	max_iterations := os.getenv_opt('MAX_ITERATIONS') or { '1000' }.int()
	measure_json_encode_old_vs_new(StructType[string]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[time.Time]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[int]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[f64]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[bool]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[[]int]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[StructType[int]]{ val: StructType[int]{} },
		max_iterations)!
	measure_json_encode_old_vs_new(StructType[Enum]{}, max_iterations)!
}

fn benchmark_measure_encode_by_alias_type() ! {
	println(@FN)
	max_iterations := os.getenv_opt('MAX_ITERATIONS') or { '1000' }.int()
	measure_json_encode_old_vs_new(StructType[StringAlias]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[TimeAlias]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[IntAlias]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[BoolAlias]{}, max_iterations)!
	measure_json_encode_old_vs_new(StructType[StructAlias]{}, max_iterations)!
}

fn benchmark_measure_decode_by_type() ! {
	println(@FN)
	max_iterations := os.getenv_opt('MAX_ITERATIONS') or { '1000' }.int()

	mut b := benchmark.start()

	vs := '{"val": ""}'
	for _ in 0 .. max_iterations {
		d := json2.decode[StructType[string]](vs)!
		if d.val != '' {
			return error('json2.decode ${d}')
		}
	}
	b.measure('json2.decode [string]')

	vb := '{"val": true}'
	for _ in 0 .. max_iterations {
		d := json2.decode[StructType[bool]](vb) or { panic('') }
		if !d.val {
			return error('json2.decode ${d}')
		}
	}
	b.measure('json2.decode [bool]')

	v0 := '{"val": 0}'
	for _ in 0 .. max_iterations {
		d := json2.decode[StructType[int]](v0)!
		if d.val != 0 {
			return error('json2.decode ${d}')
		}
	}
	b.measure('json2.decode [int]')

	vt := '{"val": "2015-01-06 15:47:32"}'
	for _ in 0 .. max_iterations {
		d := json2.decode[StructType[time.Time]](vt)!
		if d.val.year != 2015 {
			return error('json2.decode ${d}')
		}
	}
	b.measure('json2.decode [time.Time]')
}

fn measure_json_encode_old_vs_new[T](val T, max_iterations int) ! {
	typename := typeof[T]().name
	mut b := benchmark.start()
	for _ in 0 .. max_iterations {
		e := json2.encode(val)
		if e[0] != `{` {
			return error('json2.encode ${e}')
		}
	}
	b.measure('json2.encode ${typename}')
	for _ in 0 .. max_iterations {
		e := json.encode(val)
		if e[0] != `{` {
			return error('json.encode ${e}')
		}
	}
	b.measure(' json.encode ${typename}')
}
