// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module c

import v.ast
import v.util
import strings

// TODO replace with comptime code generation.
// TODO remove cJSON dependency.
// OLD: User decode_User(string js) {
// now it's
// User decode_User(cJSON* root) {
// User res;
// res.name = decode_string(js_get(root, "name"));
// res.profile = decode_Profile(js_get(root, "profile"));
// return res;
// }
// Codegen json_decode/encode funcs
fn (mut g Gen) gen_json_for_type(typ ast.Type) {
	utyp := g.unwrap_generic(typ)
	mut dec := strings.new_builder(100)
	mut enc := strings.new_builder(100)
	sym := g.table.get_type_symbol(utyp)
	styp := g.typ(utyp)
	g.register_optional(utyp)
	if is_js_prim(sym.name) || sym.kind == .enum_ {
		return
	}
	if sym.kind == .array {
		// return
	}
	if sym.name in g.json_types {
		return
	}
	g.json_types << sym.name
	// println('gen_json_for_type($sym.name)')
	// decode_TYPE funcs receive an actual cJSON* object to decode
	// cJSON_Parse(str) call is added by the compiler
	// Code gen decoder
	dec_fn_name := js_dec_name(styp)
	dec_fn_dec := 'Option_$styp ${dec_fn_name}(cJSON* root)'
	dec.writeln('
$dec_fn_dec {
	$styp res;
	if (!root) {
		const char *error_ptr = cJSON_GetErrorPtr();
		if (error_ptr != NULL)	{
			// fprintf(stderr, "Error in decode() for $styp error_ptr=: %s\\n", error_ptr);
			// printf("\\nbad js=%%s\\n", js.str);
			return (Option_$styp){.state = 2,.err = _v_error(tos2((byteptr)error_ptr)),.data = {0}};
		}
	}
')
	g.json_forward_decls.writeln('$dec_fn_dec;')
	// Code gen encoder
	// encode_TYPE funcs receive an object to encode
	enc_fn_name := js_enc_name(styp)
	enc_fn_dec := 'cJSON* ${enc_fn_name}($styp val)'
	g.json_forward_decls.writeln('$enc_fn_dec;\n')
	enc.writeln('
$enc_fn_dec {
\tcJSON *o;')
	if sym.kind == .array {
		// Handle arrays
		value_type := g.table.value_type(utyp)
		// If we have `[]Profile`, have to register a Profile en(de)coder first
		g.gen_json_for_type(value_type)
		dec.writeln(g.decode_array(value_type))
		enc.writeln(g.encode_array(value_type))
		// enc += g.encode_array(t)
	} else if sym.kind == .map {
		// Handle maps
		m := sym.info as ast.Map
		g.gen_json_for_type(m.key_type)
		g.gen_json_for_type(m.value_type)
		dec.writeln(g.decode_map(m.key_type, m.value_type))
		enc.writeln(g.encode_map(m.key_type, m.value_type))
	} else if sym.kind == .alias {
		a := sym.info as ast.Alias
		parent_typ := a.parent_type
		psym := g.table.get_type_symbol(parent_typ)
		if is_js_prim(g.typ(parent_typ)) {
			g.gen_json_for_type(parent_typ)
			return
		}
		enc.writeln('\to = cJSON_CreateObject();')
		if psym.info !is ast.Struct {
			verror('json: $sym.name is not struct')
		}
		g.gen_struct_enc_dec(psym.info, styp, mut enc, mut dec)
	} else if sym.kind == .sum_type {
		enc.writeln('\to = cJSON_CreateObject();')
		// Structs. Range through fields
		if sym.info !is ast.SumType {
			verror('json: $sym.name is not a sumtype')
		}
		g.gen_sumtype_enc_dec(sym, mut enc, mut dec)
	} else {
		enc.writeln('\to = cJSON_CreateObject();')
		// Structs. Range through fields
		if sym.info !is ast.Struct {
			verror('json: $sym.name is not struct')
		}
		g.gen_struct_enc_dec(sym.info, styp, mut enc, mut dec)
	}
	// cJSON_delete
	// p.cgen.fns << '$dec return opt_ok(res); \n}'
	dec.writeln('\tOption_$styp ret;')
	dec.writeln('\topt_ok(&res, (Option*)&ret, sizeof(res));')
	dec.writeln('\treturn ret;\n}')
	enc.writeln('\treturn o;\n}')
	g.definitions.writeln(dec.str())
	g.gowrappers.writeln(enc.str())
}

[inline]
fn (mut g Gen) gen_sumtype_enc_dec(sym ast.TypeSymbol, mut enc strings.Builder, mut dec strings.Builder) {
	info := sym.info as ast.SumType
	typ := sym.idx

	for variant in info.variants {
		variant_typ := g.typ(variant)
		variant_sym := g.table.get_type_symbol(variant)

		g.gen_json_for_type(variant)
		g.write_sumtype_casting_fn(variant, typ)
		g.definitions.writeln('static inline $sym.cname ${variant_typ}_to_sumtype_${sym.cname}(${variant_typ}* x);')

		// ENCODING
		enc.writeln('\tif (val._typ == $variant) {')
		if variant_sym.kind == .enum_ {
			enc.writeln('\t\tcJSON_AddItemToObject(o, "$variant_sym.name", json__encode_u64(*val._$variant_typ));')
		} else if variant_sym.name == "time.Time" {
			enc.writeln('\t\tcJSON_AddItemToObject(o, "$variant_sym.name", json__encode_i64(val._${variant_typ}->_v_unix));')
		} else {
			enc.writeln('\t\tcJSON_AddItemToObject(o, "$variant_sym.name", json__encode_${variant_typ}(*val._$variant_typ));')
		}
		enc.writeln('\t}')

		// DECODING
		dec.writeln('\tif (strcmp("$variant_sym.name", root->child->string) == 0) {')
			tmp := g.new_tmp_var()
			if is_js_prim(variant_typ) {
				gen_js_get(variant_typ, tmp, variant_sym.name, mut dec, false)
				dec.writeln('\t\t${variant_typ} value = (${js_dec_name(variant_sym.name)})(jsonroot_$tmp);')
			} else if variant_sym.kind == .enum_ {
				gen_js_get(variant_typ, tmp, variant_sym.name, mut dec, false)
				dec.writeln('\t\t${variant_typ} value = json__decode_u64(jsonroot_$tmp);')	
			} else if variant_sym.name == 'time.Time' {
				gen_js_get(variant_typ, tmp, variant_sym.name, mut dec, false)
				dec.writeln('\t\t${variant_typ} value = time__unix(json__decode_i64(jsonroot_$tmp));')
			} else {
				gen_js_get_opt(js_dec_name(variant_sym.cname), variant_typ, sym.cname, tmp, variant_sym.name, mut dec, false)
				// dec.writeln('\t\tOption_${variant_typ} $tmp = json__decode_${variant_typ}(js_get(root, "$variant_sym.name"));')
				dec.writeln('\t\t${variant_typ} value = *(${variant_typ}*)(${tmp}.data);')
			}
			dec.writeln('\t\tres = ${variant_typ}_to_sumtype_${sym.cname}(&value);')
		dec.writeln('\t}')
	}
}

[inline]
fn (mut g Gen) gen_struct_enc_dec(type_info ast.TypeInfo, styp string, mut enc strings.Builder, mut dec strings.Builder) {
	info := type_info as ast.Struct
	for field in info.fields {
		mut name := field.name
		mut is_raw := false
		mut is_skip := false
		mut is_required := false
		mut is_omit_empty := false

		for attr in field.attrs {
			match attr.name {
				'json' {
					name = attr.arg
				}
				'skip' {
					is_skip = true
				}
				'raw' {
					is_raw = true
				}
				'required' {
					is_required = true
				}
				'omitempty' {
					is_omit_empty = true
				}
				else {}
			}
		}
		if is_skip {
			continue
		}
		field_type := g.typ(field.typ)
		field_sym := g.table.get_type_symbol(field.typ)
		// First generate decoding
		if is_raw {
			dec.writeln('\tres.${c_name(field.name)} = tos5(cJSON_PrintUnformatted(' +
				'js_get(root, "$name")));')
		} else {
			// Now generate decoders for all field types in this struct
			// need to do it here so that these functions are generated first
			g.gen_json_for_type(field.typ)
			dec_name := js_dec_name(field_type)
			if is_js_prim(field_type) {
				tmp := g.new_tmp_var()
				gen_js_get(styp, tmp, name, mut dec, is_required)
				dec.writeln('\tres.${c_name(field.name)} = $dec_name (jsonroot_$tmp);')
			} else if field_sym.kind == .enum_ {
				tmp := g.new_tmp_var()
				gen_js_get(styp, tmp, name, mut dec, is_required)
				dec.writeln('\tres.${c_name(field.name)} = json__decode_u64(jsonroot_$tmp);')
			} else if field_sym.name == 'time.Time' {
				// time struct requires special treatment
				// it has to be decoded from a unix timestamp number
				tmp := g.new_tmp_var()
				gen_js_get(styp, tmp, name, mut dec, is_required)
				dec.writeln('\tres.${c_name(field.name)} = time__unix(json__decode_u64(jsonroot_$tmp));')
			} else if field_sym.kind == .alias {
				alias := field_sym.info as ast.Alias
				parent_type := g.typ(alias.parent_type)
				parent_dec_name := js_dec_name(parent_type)
				if is_js_prim(parent_type) {
					tmp := g.new_tmp_var()
					gen_js_get(styp, tmp, name, mut dec, is_required)
					dec.writeln('\tres.${c_name(field.name)} = $parent_dec_name (jsonroot_$tmp);')
				} else {
					g.gen_json_for_type(field.typ)
					tmp := g.new_tmp_var()
					gen_js_get_opt(dec_name, field_type, styp, tmp, name, mut dec, is_required)
					dec.writeln('\tres.${c_name(field.name)} = *($field_type*) ${tmp}.data;')
				}
			} else {
				tmp := g.new_tmp_var()
				gen_js_get_opt(dec_name, field_type, styp, tmp, name, mut dec, is_required)
				dec.writeln('\tres.${c_name(field.name)} = *($field_type*) ${tmp}.data;')
			}
		}
		// Encoding
		mut enc_name := js_enc_name(field_type)
		if is_omit_empty {
			enc.writeln('\t if (val.${c_name(field.name)} != ${g.type_default(field.typ)}) \n')
		}
		if !is_js_prim(field_type) {
			if field_sym.kind == .alias {
				ainfo := field_sym.info as ast.Alias
				enc_name = js_enc_name(g.typ(ainfo.parent_type))
			}
		}
		if field_sym.kind == .enum_ {
			enc.writeln('\tcJSON_AddItemToObject(o, "$name", json__encode_u64(val.${c_name(field.name)}));\n')
		} else {
			if field_sym.name == 'time.Time' {
				// time struct requires special treatment
				// it has to be encoded as a unix timestamp number
				enc.writeln('\tcJSON_AddItemToObject(o, "$name", json__encode_u64(val.${c_name(field.name)}._v_unix));')
			} else {
				enc.writeln('\tcJSON_AddItemToObject(o, "$name", ${enc_name}(val.${c_name(field.name)}));\n')
			}
		}
	}
}

fn gen_js_get(styp string, tmp string, name string, mut dec strings.Builder, is_required bool) {
	dec.writeln('\tcJSON *jsonroot_$tmp = js_get(root,"$name");')
	if is_required {
		dec.writeln('\tif(jsonroot_$tmp == 0) {')
		dec.writeln('\t\treturn (Option_$styp){ .state = 2, .err = _v_error(_SLIT("expected field \'$name\' is missing")), .data = {0} };')
		dec.writeln('\t}')
	}
}

fn gen_js_get_opt(dec_name string, field_type string, styp string, tmp string, name string, mut dec strings.Builder, is_required bool) {
	gen_js_get(styp, tmp, name, mut dec, is_required)
	dec.writeln('\tOption_$field_type $tmp = $dec_name (jsonroot_$tmp);')
	dec.writeln('\tif(${tmp}.state != 0) {')
	dec.writeln('\t\treturn (Option_$styp){ .state = ${tmp}.state, .err = ${tmp}.err, .data = {0} };')
	dec.writeln('\t}')
}

fn js_enc_name(typ string) string {
	suffix := if typ.ends_with('*') { typ.replace('*', '') } else { typ }
	name := 'json__encode_$suffix'
	return util.no_dots(name)
}

fn js_dec_name(typ string) string {
	name := 'json__decode_$typ'
	return util.no_dots(name)
}

fn is_js_prim(typ string) bool {
	return typ in ['int', 'string', 'bool', 'f32', 'f64', 'i8', 'i16', 'i64', 'u16', 'u32', 'u64',
		'byte',
	]
}

fn (mut g Gen) decode_array(value_type ast.Type) string {
	styp := g.typ(value_type)
	fn_name := js_dec_name(styp)
	mut s := ''
	if is_js_prim(styp) {
		s = '$styp val = ${fn_name}((cJSON *)jsval); '
	} else {
		s = '
		Option_$styp val2 = $fn_name ((cJSON *)jsval);
		if(val2.state != 0) {
			array_free(&res);
			return *(Option_Array_$styp*)&val2;
		}
		$styp val = *($styp*)val2.data;
'
	}
	noscan := g.check_noscan(value_type)
	return '
	if(root && !cJSON_IsArray(root) && !cJSON_IsNull(root)) {
		return (Option_Array_$styp){.state = 2, .err = _v_error(string__plus(_SLIT("Json element is not an array: "), tos2((byteptr)cJSON_PrintUnformatted(root)))), .data = {0}};
	}
	res = __new_array${noscan}(0, 0, sizeof($styp));
	const cJSON *jsval = NULL;
	cJSON_ArrayForEach(jsval, root)
	{
	$s
		array_push${noscan}((array*)&res, &val);
	}
'
}

fn (mut g Gen) encode_array(value_type ast.Type) string {
	styp := g.typ(value_type)
	fn_name := js_enc_name(styp)
	return '
	o = cJSON_CreateArray();
	for (int i = 0; i < val.len; i++){
		cJSON_AddItemToArray(o, $fn_name (  (($styp*)val.data)[i]  ));
	}
'
}

fn (mut g Gen) decode_map(key_type ast.Type, value_type ast.Type) string {
	styp := g.typ(key_type)
	styp_v := g.typ(value_type)
	key_type_symbol := g.table.get_type_symbol(key_type)
	hash_fn, key_eq_fn, clone_fn, free_fn := g.map_fn_ptrs(key_type_symbol)
	fn_name_v := js_dec_name(styp_v)
	mut s := ''
	if is_js_prim(styp_v) {
		s = '$styp_v val = $fn_name_v (js_get(root, jsval->string));'
	} else {
		s = '
		Option_$styp_v val2 = $fn_name_v (js_get(root, jsval->string));
		if(val2.state != 0) {
			map_free(&res);
			return *(Option_Map_${styp}_$styp_v*)&val2;
		}
		$styp_v val = *($styp_v*)val2.data;
'
	}
	return '
	if(!cJSON_IsObject(root) && !cJSON_IsNull(root)) {
		return (Option_Map_${styp}_$styp_v){ .state = 2, .err = _v_error(string__plus(_SLIT("Json element is not an object: "), tos2((byteptr)cJSON_PrintUnformatted(root)))), .data = {0}};
	}
	res = new_map(sizeof($styp), sizeof($styp_v), $hash_fn, $key_eq_fn, $clone_fn, $free_fn);
	cJSON *jsval = NULL;
	cJSON_ArrayForEach(jsval, root)
	{
		$s
		string key = tos2((byteptr)jsval->string);
		map_set(&res, &key, &val);
	}
'
}

fn (mut g Gen) encode_map(key_type ast.Type, value_type ast.Type) string {
	styp := g.typ(key_type)
	styp_v := g.typ(value_type)
	fn_name_v := js_enc_name(styp_v)
	zero := g.type_default(value_type)
	keys_tmp := g.new_tmp_var()
	mut key := 'string key = '
	if key_type.is_string() {
		key += '(($styp*)${keys_tmp}.data)[i];'
	} else {
		// key += '${styp}_str((($styp*)${keys_tmp}.data)[i]);'
		verror('json: encode only maps with string keys')
	}
	return '
	o = cJSON_CreateObject();
	Array_$styp $keys_tmp = map_keys(&val);
	for (int i = 0; i < ${keys_tmp}.len; ++i) {
		$key
		cJSON_AddItemToObject(o, (char*) key.str, $fn_name_v ( *($styp_v*) map_get(&val, &key, &($styp_v[]) { $zero } ) ) );
	}
	array_free(&$keys_tmp);
'
}
