module c

import v.ast
import v.util

const cprefix = 'v__reflection__'

// reflection_string maps string to its idx
fn (g Gen) reflection_string(str string) int {
	return unsafe {
		g.reflection_strings[str] or {
			g.reflection_strings[str] = g.reflection_strings.len
			g.reflection_strings.len - 1
		}
	}
}

// gen_reflection_strings generates the reflectino string registration
[inline]
fn (mut g Gen) gen_reflection_strings() {
	for str, idx in g.reflection_strings {
		g.writeln('\t${cprefix}add_string(_SLIT("${str}"), ${idx});\n')
	}
}

// gen_empty_array generates code for empty array
[inline]
fn (g Gen) gen_empty_array(type_name string) string {
	return '__new_array_with_default(0, 0, sizeof(${type_name}), 0)'
}

// gen_functionarg_array generates the code for functionarg argument
[inline]
fn (g Gen) gen_functionarg_array(type_name string, node ast.Fn) string {
	if node.params.len == 0 {
		return g.gen_empty_array(type_name)
	}
	mut out := 'new_array_from_c_array(${node.params.len},${node.params.len},sizeof(${type_name}),'
	out += '_MOV((${type_name}[${node.params.len}]){'
	for param in node.params {
		out += '((${type_name}){.name=_SLIT("${param.name}"),.typ=${param.typ.idx()},}),'
	}
	out += '}))'
	return out
}

// gen_functionarg_array generates the code for functionarg argument
[inline]
fn (g Gen) gen_function_array(nodes []ast.Fn) string {
	type_name := '${cprefix}Function'

	if nodes.len == 0 {
		return g.gen_empty_array(type_name)
	}

	mut out := 'new_array_from_c_array(${nodes.len},${nodes.len},sizeof(${type_name}),'
	out += '_MOV((${type_name}[${nodes.len}]){'
	for method in nodes {
		out += g.gen_reflection_fn(method)
		out += ','
	}
	out += '}))'
	return out
}

[inline]
fn (g Gen) gen_reflection_fn(node ast.Fn) string {
	mut arg_str := '((${cprefix}Function){'
	v_name := node.name.all_after_last('.')
	arg_str += '.mod_name=_SLIT("${node.mod}"),'
	arg_str += '.name=_SLIT("${v_name}"),'
	arg_str += '.args=${g.gen_functionarg_array(cprefix + 'FunctionArg', node)},'
	arg_str += '.file_idx=${g.reflection_string(util.cescaped_path(node.file))},'
	arg_str += '.line_start=${node.pos.line_nr},'
	arg_str += '.line_end=${node.pos.last_line},'
	arg_str += '.is_variadic=${node.is_variadic},'
	arg_str += '.return_typ=${node.return_type.idx()},'
	arg_str += '.receiver_typ=${node.receiver_type.idx()}'
	arg_str += '})'
	return arg_str
}

// gen_reflection_sym generates C code for TypeSymbol struct
[inline]
fn (g Gen) gen_reflection_sym(tsym ast.TypeSymbol) string {
	kind_name := if tsym.kind in [.none_, .struct_, .enum_, .interface_] {
		tsym.kind.str() + '_'
	} else {
		tsym.kind.str()
	}
	info := g.gen_reflection_sym_info(tsym)
	methods := g.gen_function_array(tsym.methods)
	return '(${cprefix}TypeSymbol){.name=_SLIT("${tsym.name}"),.idx=${tsym.idx},.parent_idx=${tsym.parent_idx},.language=v__ast__Language__${tsym.language},.kind=v__ast__Kind__${kind_name},.info=${info},.methods=${methods}}'
}

// gen_attrs_array generates C code for []Attr
[inline]
fn (g Gen) gen_attrs_array(attrs []ast.Attr) string {
	if attrs.len == 0 {
		return g.gen_empty_array('string')
	}
	mut out := 'new_array_from_c_array(${attrs.len},${attrs.len},sizeof(string),'
	out += '_MOV((string[${attrs.len}]){'
	for attr in attrs {
		if attr.has_arg {
			out += '_SLIT("${attr.name}=${attr.arg}"),'
		} else {
			out += '_SLIT("${attr.name}"),'
		}
	}
	out += '}))'
	return out
}

// gen_fields_array generates C code for []StructField
[inline]
fn (g Gen) gen_fields_array(fields []ast.StructField) string {
	if fields.len == 0 {
		return g.gen_empty_array('${cprefix}StructField')
	}
	mut out := 'new_array_from_c_array(${fields.len},${fields.len},sizeof(${cprefix}StructField),'
	out += '_MOV((${cprefix}StructField[${fields.len}]){'
	for field in fields {
		out += '((${cprefix}StructField){.name=_SLIT("${field.name}"),.typ=${field.typ.idx()},.attrs=${g.gen_attrs_array(field.attrs)},.is_pub=${field.is_pub},.is_mut=${field.is_mut}}),'
	}
	out += '}))'
	return out
}

// gen_type_array generates C code for []Type
[inline]
fn (g Gen) gen_type_array(types []ast.Type) string {
	if types.len == 0 {
		return g.gen_empty_array('int')
	}
	mut out := 'new_array_from_c_array(${types.len},${types.len},sizeof(int),'
	out += '_MOV((int[${types.len}]){${types.map(it.idx().str()).join(',')}}))'
	return out
}

// gen_string_array generates C code for []string
[inline]
fn (g Gen) gen_string_array(strs []string) string {
	if strs.len == 0 {
		return g.gen_empty_array('string')
	}
	mut out := 'new_array_from_c_array(${strs.len},${strs.len},sizeof(string),'
	items := strs.map('_SLIT("${it}")').join(',')
	out += '_MOV((string[${strs.len}]){${items}}))'
	return out
}

// gen_reflection_sym_info generates C code for TypeSymbol's info sum type
[inline]
fn (g Gen) gen_reflection_sym_info(tsym ast.TypeSymbol) string {
	match tsym.kind {
		.array {
			info := tsym.info as ast.Array
			s := 'ADDR(${cprefix}Array, (((${cprefix}Array){.nr_dims=${info.nr_dims},.elem_type=${info.elem_type.idx()}})))'
			return '(${cprefix}TypeInfo){._${cprefix}Array = memdup(${s},sizeof(${cprefix}Array)),._typ=${g.table.find_type_idx('v.reflection.Array')}}'
		}
		.array_fixed {
			info := tsym.info as ast.ArrayFixed
			s := 'ADDR(${cprefix}ArrayFixed, (((${cprefix}ArrayFixed){.size=${info.size},.elem_type=${info.elem_type.idx()}})))'
			return '(${cprefix}TypeInfo){._${cprefix}ArrayFixed = memdup(${s},sizeof(${cprefix}ArrayFixed)),._typ=${g.table.find_type_idx('v.reflection.ArrayFixed')}}'
		}
		.map {
			info := tsym.info as ast.Map
			s := 'ADDR(${cprefix}Map, (((${cprefix}Map){.key_type=${info.key_type.idx()},.value_type=${info.value_type.idx()}})))'
			return '(${cprefix}TypeInfo){._${cprefix}Map = memdup(${s},sizeof(${cprefix}Map)),._typ=${g.table.find_type_idx('v.reflection.Map')}}'
		}
		.sum_type {
			info := tsym.info as ast.SumType
			s := 'ADDR(${cprefix}SumType, (((${cprefix}SumType){.parent_idx=${info.parent_type.idx()},.variants=${g.gen_type_array(info.variants)}})))'
			return '(${cprefix}TypeInfo){._${cprefix}SumType = memdup(${s},sizeof(${cprefix}SumType)),._typ=${g.table.find_type_idx('v.reflection.SumType')}}'
		}
		.struct_ {
			info := tsym.info as ast.Struct
			attrs := g.gen_attrs_array(info.attrs)
			fields := g.gen_fields_array(info.fields)
			s := 'ADDR(${cprefix}Struct, (((${cprefix}Struct){.parent_idx = ${(tsym.info as ast.Struct).parent_type.idx()},.attrs=${attrs},.fields=${fields}})))'
			return '(${cprefix}TypeInfo){._${cprefix}Struct = memdup(${s},sizeof(${cprefix}Struct)),._typ=${g.table.find_type_idx('v.reflection.Struct')}}'
		}
		.enum_ {
			info := tsym.info as ast.Enum
			vals := g.gen_string_array(info.vals)
			s := 'ADDR(${cprefix}Enum, (((${cprefix}Enum){.vals=${vals},.is_flag=${info.is_flag}})))'
			return '(${cprefix}TypeInfo){._${cprefix}Enum = memdup(${s},sizeof(${cprefix}Enum)),._typ=${g.table.find_type_idx('v.reflection.Enum')}}'
		}
		.function {
			info := tsym.info as ast.FnType
			s := 'ADDR(${cprefix}Function, ${g.gen_reflection_fn(info.func)})'
			return '(${cprefix}TypeInfo){._${cprefix}Function = memdup(${s},sizeof(${cprefix}Function)),._typ=${g.table.find_type_idx('v.reflection.Function')}}'
		}
		.interface_ {
			name := tsym.name.all_after_last('.')
			info := tsym.info as ast.Interface
			methods := g.gen_function_array(info.methods)
			fields := g.gen_fields_array(info.fields)
			s := 'ADDR(${cprefix}Interface, (((${cprefix}Interface){.name=_SLIT("${name}"),.methods=${methods},.fields=${fields},.is_generic=${info.is_generic}})))'
			return '(${cprefix}TypeInfo){._${cprefix}Interface = memdup(${s},sizeof(${cprefix}Interface)),._typ=${g.table.find_type_idx('v.reflection.Interface')}}'
		}
		.alias {
			info := tsym.info as ast.Alias
			s := 'ADDR(${cprefix}Alias, (((${cprefix}Alias){.parent_idx=${info.parent_type.idx()},.language=v__ast__Language__${info.language.str()}})))'
			return '(${cprefix}TypeInfo){._${cprefix}Alias=memdup(${s},sizeof(${cprefix}Alias)),._typ=${g.table.find_type_idx('v.reflection.Alias')}}'
		}
		else {
			s := 'ADDR(${cprefix}None, (((${cprefix}None){.parent_idx=${tsym.parent_idx},})))'
			return '(${cprefix}TypeInfo){._${cprefix}None=memdup(${s},sizeof(${cprefix}None)),._typ=${g.table.find_type_idx('v.reflection.None')}}'
		}
	}
}

// gen_reflection_function generates C code for reflection function metadata
[inline]
fn (mut g Gen) gen_reflection_function(node ast.FnDecl) {
	if !g.has_reflection {
		return
	}
	// func_struct := g.gen_reflection_fndecl(node)
	// g.reflection_funcs.write_string('\t${cprefix}add_func(${func_struct});\n')
}

// gen_reflection_data generates code to initilized V reflection metadata
fn (mut g Gen) gen_reflection_data() {
	// modules declaration
	for mod_name in g.table.modules {
		g.writeln('\t${cprefix}add_module(_SLIT("${mod_name}"));\n')
	}

	// types declaration
	for full_name, idx in g.table.type_idxs {
		tsym := g.table.sym_by_idx(idx)
		name := full_name.all_after_last('.')
		sym := g.gen_reflection_sym(tsym)
		g.writeln('\t${cprefix}add_type((${cprefix}Type){.name=_SLIT("${name}"),.idx=${idx},.sym=${sym}});\n')
	}

	// func declaration (methods come from struct methods)
	for _, fn_ in g.table.fns {
		if fn_.no_body || fn_.is_method || fn_.language != .v {
			continue
		}
		func := g.gen_reflection_fn(fn_)
		g.writeln('\t${cprefix}add_func(${func});\n')
	}

	// type symbols declaration
	for _, tsym in g.table.type_symbols {
		sym := g.gen_reflection_sym(tsym)
		g.writeln('\t${cprefix}add_type_symbol(${sym});\n')
	}

	g.gen_reflection_strings()
}
