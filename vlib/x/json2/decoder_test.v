import x.json2 as json

fn test_raw_decode_string() {
	str := json.raw_decode('"Hello!"')!
	assert str.str() == 'Hello!'
}

fn test_raw_decode_string_escape() {
	jstr := json.raw_decode('"\u001b"')!
	str := jstr.str()
	assert str.len == 1
	assert str[0] == 27
}

fn test_raw_decode_number() {
	num := json.raw_decode('123')!
	assert num.int() == 123
}

fn test_raw_decode_array() {
	raw_arr := json.raw_decode('["Foo", 1]')!
	arr := raw_arr.arr()
	assert arr[0] or { 0 }.str() == 'Foo'
	assert arr[1] or { 0 }.int() == 1
}

fn test_raw_decode_bool() {
	bol := json.raw_decode('false')!
	assert bol.bool() == false
}

fn test_raw_decode_map() {
	raw_mp := json.raw_decode('{"name":"Bob","age":20}')!
	mp := raw_mp.as_map()
	assert mp['name'] or { 0 }.str() == 'Bob'
	assert mp['age'] or { 0 }.int() == 20
}

fn test_raw_decode_null() {
	nul := json.raw_decode('null')!
	assert nul is json.Null
}

fn test_raw_decode_invalid() {
	json.raw_decode('1z') or {
		assert err.msg() == '[x.json2] invalid token `z` (0:17)'
		return
	}
	assert false
}

fn test_raw_decode_string_with_dollarsign() {
	str := json.raw_decode(r'"Hello $world"')!
	assert str.str() == r'Hello $world'
}

fn test_raw_decode_map_with_whitespaces() {
	raw_mp := json.raw_decode(' \n\t{"name":"Bob","age":20}\n\t')!
	mp := raw_mp.as_map()
	assert mp['name'] or { 0 }.str() == 'Bob'
	assert mp['age'] or { 0 }.int() == 20
}

fn test_nested_array_object() {
	mut parser := json.new_parser(r'[[[[[],[],[]]]],{"Test":{}},[[]]]', false)
	decoded := parser.decode()!
	assert parser.n_level == 0
}

fn test_raw_decode_map_invalid() {
	json.raw_decode('{"name","Bob","age":20}') or {
		assert err.msg() == '[x.json2] invalid token `comma`, expecting `colon` (0:5)'
		return
	}
	assert false
}

fn test_raw_decode_array_invalid() {
	json.raw_decode('["Foo", 1,}') or {
		assert err.msg() == '[x.json2] invalid token `rcbr` (0:5)'
		return
	}
	assert false
}
