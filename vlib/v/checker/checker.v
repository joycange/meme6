// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module checker

import (
	v.ast
	v.depgraph
	v.table
	v.token
	v.pref
	v.util
	os
)

const (
	max_nr_errors = 300
)

pub struct Checker {
	table          &table.Table
mut:
	file           ast.File
	nr_errors      int
	errors         []string
	error_lines    []int // to avoid printing multiple errors for the same line
	expected_type  table.Type
	fn_return_type table.Type // current function's return type
	const_decl     string
	const_deps     []string
	pref           &pref.Preferences // Preferences shared from V struct
	in_for_count   int // if checker is currently in an for loop
	// checked_ident  string // to avoid infinit checker loops
	var_decl_name  string
}

pub fn new_checker(table &table.Table, pref &pref.Preferences) Checker {
	return checker.Checker{
		table: table
		pref: pref
	}
}

pub fn (c mut Checker) check(ast_file ast.File) {
	c.file = ast_file
	for stmt in ast_file.stmts {
		c.stmt(stmt)
	}
}

pub fn (c mut Checker) check2(ast_file ast.File) []string {
	c.file = ast_file
	for stmt in ast_file.stmts {
		c.stmt(stmt)
	}
	return c.errors
}

pub fn (c mut Checker) check_files(ast_files []ast.File) {
	for file in ast_files {
		c.check(file)
	}
}

pub fn (c mut Checker) struct_init(struct_init mut ast.StructInit) table.Type {
	// typ := c.table.find_type(struct_init.typ.typ.name) or {
	// c.error('unknown struct: $struct_init.typ.typ.name', struct_init.pos)
	// panic('')
	// }
	if struct_init.typ == table.void_type {
		// Short syntax `({foo: bar})`
		if c.expected_type == table.void_type {
			c.error('unexpected short struct syntax', struct_init.pos)
			return table.void_type
		}
		struct_init.typ = c.expected_type
	}
	typ_sym := c.table.get_type_symbol(struct_init.typ)
	// println('check struct $typ_sym.name')
	match typ_sym.kind {
		.placeholder {
			c.error('unknown struct: $typ_sym.name', struct_init.pos)
		}
		// string & array are also structs but .kind of string/array
		.struct_, .string, .array {
			info := typ_sym.info as table.Struct
			is_short_syntax := struct_init.fields.len == 0
			if struct_init.exprs.len > info.fields.len {
				c.error('too many fields', struct_init.pos)
			}
			mut inited_fields := []string
			for i, expr in struct_init.exprs {
				if is_short_syntax && i >= info.fields.len {
					// It doesn't make sense to check for fields that don't exist.
					// We should just stop here.
					break
				}
				// struct_field info.
				field_name := if is_short_syntax { info.fields[i].name } else { struct_init.fields[i] }
				if field_name in inited_fields {
					c.error('duplicate field name in struct literal: `$field_name`', struct_init.pos)
					continue
				}
				inited_fields << field_name
				mut field := if is_short_syntax {
					info.fields[i]
				} else {
					// There is no guarantee that `i` will not be out of bounds of `info.fields`
					// So we just use an empty field as placeholder here.
					table.Field{}
				}
				if !is_short_syntax {
					mut found_field := false
					for f in info.fields {
						if f.name == field_name {
							field = f
							found_field = true
							break
						}
					}
					if !found_field {
						c.error('struct init: no such field `$field_name` for struct `$typ_sym.name`',
							struct_init.pos)
						continue
					}
				}
				c.expected_type = field.typ
				expr_type := c.expr(expr)
				expr_type_sym := c.table.get_type_symbol(expr_type)
				field_type_sym := c.table.get_type_symbol(field.typ)
				if !c.table.check(expr_type, field.typ) {
					c.error('cannot assign `$expr_type_sym.name` as `$field_type_sym.name` for field `$field.name`',
						struct_init.pos)
				}
				struct_init.expr_types << expr_type
				struct_init.expected_types << field.typ
			}
			// Check uninitialized refs
			for field in info.fields {
				if field.name in inited_fields {
					continue
				}
				if table.type_is_ptr(field.typ) {
					c.warn('reference field `${typ_sym.name}.${field.name}` must be initialized',
						struct_init.pos)
				}
			}
		}
		else {}
	}
	return struct_init.typ
}

pub fn (c mut Checker) infix_expr(infix_expr mut ast.InfixExpr) table.Type {
	// println('checker: infix expr(op $infix_expr.op.str())')
	c.expected_type = table.void_type
	left_type := c.expr(infix_expr.left)
	infix_expr.left_type = left_type
	c.expected_type = left_type
	right_type := c.expr(infix_expr.right)
	infix_expr.right_type = right_type
	right := c.table.get_type_symbol(right_type)
	left := c.table.get_type_symbol(left_type)
	if infix_expr.op == .left_shift {
		if left.kind != .array && !left.is_int() {
			// c.error('<< can only be used with numbers and arrays', infix_expr.pos)
			c.error('incompatible types: $left.name << $right.name', infix_expr.pos)
			return table.void_type
		}
		if left.kind == .array {
			// `array << elm`
			// the expressions have different types (array_x and x)
			if c.table.check(c.table.value_type(left_type), right_type) {
				// []T << T
				return table.void_type
			}
			if right.kind == .array && c.table.check(c.table.value_type(left_type), c.table.value_type(right_type)) {
				// []T << []T
				return table.void_type
			}
			c.error('incompatible types: $left.name << $right.name', infix_expr.pos)
			return table.void_type
		}
	}
	if infix_expr.op == .key_in {
		if !(right.kind in [.array, .map, .string]) {
			c.error('`in` can only be used with an array/map/string.', infix_expr.pos)
		}
		return table.bool_type
	}
	if !c.table.check(right_type, left_type) {
		// for type-unresolved consts
		if left_type == table.void_type || right_type == table.void_type {
			return table.void_type
		}
		c.error('infix expr: cannot use `$right.name` (right) as `$left.name`', infix_expr.pos)
	}
	if infix_expr.op.is_relational() {
		return table.bool_type
	}
	return left_type
}

fn (c mut Checker) assign_expr(assign_expr mut ast.AssignExpr) {
	c.expected_type = table.void_type
	left_type := c.expr(assign_expr.left)
	c.expected_type = left_type
	assign_expr.left_type = left_type
	// println('setting exp type to $c.expected_type $t.name')
	right_type := c.expr(assign_expr.val)
	assign_expr.right_type = right_type
	if ast.expr_is_blank_ident(assign_expr.left) {
		return
	}
	if !c.table.check(right_type, left_type) {
		left_type_sym := c.table.get_type_symbol(left_type)
		right_type_sym := c.table.get_type_symbol(right_type)
		c.error('cannot assign `$right_type_sym.name` to `$left_type_sym.name`', assign_expr.pos)
	}
	c.check_expr_opt_call(assign_expr.val, right_type, true)
}

pub fn (c mut Checker) call_expr(call_expr mut ast.CallExpr) table.Type {
	c.stmts(call_expr.or_block.stmts)
	if call_expr.is_method {
		left_type := c.expr(call_expr.left)
		call_expr.left_type = left_type
		left_type_sym := c.table.get_type_symbol(left_type)
		method_name := call_expr.name
		// TODO: remove this for actual methods, use only for compiler magic
		if left_type_sym.kind == .array && method_name in ['filter', 'clone', 'repeat', 'reverse',
			'map', 'slice'] {
			if method_name in ['filter', 'map'] {
				array_info := left_type_sym.info as table.Array
				mut scope := c.file.scope.innermost(call_expr.pos.pos)
				scope.update_var_type('it', array_info.elem_type)
			}
			for i, arg in call_expr.args {
				c.expr(arg.expr)
			}
			// need to return `array_xxx` instead of `array`
			call_expr.return_type = left_type
			if method_name == 'clone' {
				// in ['clone', 'str'] {
				call_expr.receiver_type = table.type_to_ptr(left_type)
				// call_expr.return_type = call_expr.receiver_type
			} else {
				call_expr.receiver_type = left_type
			}
			return left_type
		} else if left_type_sym.kind == .array && method_name in ['first', 'last'] {
			info := left_type_sym.info as table.Array
			call_expr.return_type = info.elem_type
			call_expr.receiver_type = left_type
			return info.elem_type
		}
		if method := c.table.type_find_method(left_type_sym, method_name) {
			no_args := method.args.len - 1
			min_required_args := method.args.len - if method.is_variadic && method.args.len >
				1 { 2 } else { 1 }
			if call_expr.args.len < min_required_args {
				c.error('too few arguments in call to `${left_type_sym.name}.$method_name` ($call_expr.args.len instead of $min_required_args)',
					call_expr.pos)
			} else if !method.is_variadic && call_expr.args.len > no_args {
				c.error('too many arguments in call to `${left_type_sym.name}.$method_name` ($call_expr.args.len instead of $no_args)',
					call_expr.pos)
				return method.return_type
			}
			// if method_name == 'clone' {
			// println('CLONE nr args=$method.args.len')
			// }
			// call_expr.args << method.args[0].typ
			// call_expr.exp_arg_types << method.args[0].typ
			for i, arg in call_expr.args {
				c.expected_type = if method.is_variadic && i >= method.args.len - 1 {
					method.args[method.args.len - 1].typ
				} else {
					method.args[i + 1].typ
				}
				call_expr.args[i].typ = c.expr(arg.expr)
			}
			// TODO: typ optimize.. this node can get processed more than once
			if call_expr.expected_arg_types.len == 0 {
				for i in 1 .. method.args.len {
					call_expr.expected_arg_types << method.args[i].typ
				}
			}
			call_expr.receiver_type = method.args[0].typ
			call_expr.return_type = method.return_type
			return method.return_type
		}
		// TODO: str methods
		if left_type_sym.kind == .map && method_name == 'str' {
			call_expr.receiver_type = table.new_type(c.table.type_idxs['map_string'])
			call_expr.return_type = table.string_type
			return table.string_type
		}
		if left_type_sym.kind == .array && method_name == 'str' {
			call_expr.receiver_type = left_type
			call_expr.return_type = table.string_type
			return table.string_type
		}
		c.error('unknown method: ${left_type_sym.name}.$method_name', call_expr.pos)
		return table.void_type
	} else {
		fn_name := call_expr.name
		// TODO: impl typeof properly (probably not going to be a fn call)
		if fn_name == 'typeof' {
			return table.string_type
		}
		// look for function in format `mod.fn` or `fn` (main/builtin)
		mut f := table.Fn{}
		mut found := false
		// try prefix with current module as it would have never gotten prefixed
		if !fn_name.contains('.') && !(call_expr.mod in ['builtin', 'main']) {
			name_prefixed := '${call_expr.mod}.$fn_name'
			if f1 := c.table.find_fn(name_prefixed) {
				call_expr.name = name_prefixed
				found = true
				f = f1
			}
		}
		// already prefixed (mod.fn) or C/builtin/main
		if !found {
			if f1 := c.table.find_fn(fn_name) {
				found = true
				f = f1
			}
		}
		// check for arg (var) of fn type
		if !found {
			scope := c.file.scope.innermost(call_expr.pos.pos)
			if var := scope.find_var(fn_name) {
				
			}
		}
		// check for arg (var) of fn type
		if !found {
			scope := c.file.scope.innermost(call_expr.pos.pos)
			if var := scope.find_var(fn_name) {
				if var.typ != 0 {
					vts := c.table.get_type_symbol(var.typ)
					if vts.kind == .function {
						info := vts.info as table.FnType
						f = info.func
						found = true
					}
				}
			}
		}
		if !found {
			c.error('unknown fn: $fn_name', call_expr.pos)
			return table.void_type
		}
		call_expr.return_type = f.return_type
		if f.is_c || call_expr.is_c {
			for arg in call_expr.args {
				c.expr(arg.expr)
			}
			return f.return_type
		}
		min_required_args := if f.is_variadic { f.args.len - 1 } else { f.args.len }
		if call_expr.args.len < min_required_args {
			c.error('too few arguments in call to `$fn_name` ($call_expr.args.len instead of $min_required_args)',
				call_expr.pos)
		} else if !f.is_variadic && call_expr.args.len > f.args.len {
			c.error('too many arguments in call to `$fn_name` ($call_expr.args.len instead of $f.args.len)',
				call_expr.pos)
			return f.return_type
		}
		// println can print anything
		if fn_name == 'println' || fn_name == 'print' {
			c.expected_type = table.string_type
			call_expr.args[0].typ = c.expr(call_expr.args[0].expr)
			return f.return_type
		}
		// TODO: typ optimize.. this node can get processed more than once
		if call_expr.expected_arg_types.len == 0 {
			for arg in f.args {
				call_expr.expected_arg_types << arg.typ
			}
		}
		for i, call_arg in call_expr.args {
			arg := if f.is_variadic && i >= f.args.len - 1 { f.args[f.args.len - 1] } else { f.args[i] }
			c.expected_type = arg.typ
			typ := c.expr(call_arg.expr)
			call_expr.args[i].typ = typ
			typ_sym := c.table.get_type_symbol(typ)
			arg_typ_sym := c.table.get_type_symbol(arg.typ)
			if !c.table.check(typ, arg.typ) {
				// str method, allow type with str method if fn arg is string
				if arg_typ_sym.kind == .string && typ_sym.has_method('str') {
					continue
				}
				if typ_sym.kind == .void && arg_typ_sym.kind == .string {
					continue
				}
				if typ_sym.kind == .array_fixed {
				}
				// println('fixed')
				c.error('cannot use type `$typ_sym.str()` as type `$arg_typ_sym.str()` in argument ${i+1} to `$fn_name`',
					call_expr.pos)
			}
		}
		return f.return_type
	}
}

pub fn (c mut Checker) check_expr_opt_call(x ast.Expr, xtype table.Type, is_return_used bool) {
	match x {
		ast.CallExpr {
			if table.type_is(it.return_type, .optional) {
				c.check_or_block(it, xtype, is_return_used)
			}
		}
		else {}
	}
}

pub fn (c mut Checker) check_or_block(call_expr mut ast.CallExpr, ret_type table.Type, is_ret_used bool) {
	if !call_expr.or_block.is_used {
		c.error('${call_expr.name}() returns an option, but you missed to add an `or {}` block to it',
			call_expr.pos)
		return
	}
	stmts_len := call_expr.or_block.stmts.len
	if stmts_len == 0 {
		if is_ret_used {
			// x := f() or {}
			c.error('assignment requires a non empty `or {}` block', call_expr.pos)
			return
		}
		// allow `f() or {}`
		return
	}
	last_stmt := call_expr.or_block.stmts[stmts_len - 1]
	if is_ret_used {
		if !c.is_last_or_block_stmt_valid(last_stmt) {
			expected_type_name := c.table.get_type_symbol(ret_type).name
			c.error('last statement in the `or {}` block should return ‘$expected_type_name‘',
				call_expr.pos)
			return
		}
		match last_stmt {
			ast.ExprStmt {
				type_fits := c.table.check(c.expr(it.expr), ret_type)
				is_panic_or_exit := is_expr_panic_or_exit(it.expr)
				if type_fits || is_panic_or_exit {
					return
				}
				type_name := c.table.get_type_symbol(c.expr(it.expr)).name
				expected_type_name := c.table.get_type_symbol(ret_type).name
				c.error('wrong return type `$type_name` in the `or {}` block, expected `$expected_type_name`',
					it.pos)
				return
			}
			ast.BranchStmt {
				if !(it.tok.kind in [.key_continue, .key_break]) {
					c.error('only break/continue is allowed as a branch statement in the end of an `or {}` block',
						it.tok.position())
					return
				}
			}
			else {}
		}
		return
	}
}

fn is_expr_panic_or_exit(expr ast.Expr) bool {
	match expr {
		ast.CallExpr {
			return it.name in ['panic', 'exit']
		}
		else {
			return false
		}
	}
}

// TODO: merge to check_or_block when v can handle it
pub fn (c mut Checker) is_last_or_block_stmt_valid(stmt ast.Stmt) bool {
	return match stmt {
		ast.Return {
			true
		}
		ast.BranchStmt {
			true
		}
		ast.ExprStmt {
			true
		}
		else {
			false
		}
	}
}

pub fn (c mut Checker) selector_expr(selector_expr mut ast.SelectorExpr) table.Type {
	typ := c.expr(selector_expr.expr)
	if typ == table.void_type_idx {
		c.error('unknown selector expression', selector_expr.pos)
		return table.void_type
	}
	selector_expr.expr_type = typ
	// println('sel expr line_nr=$selector_expr.pos.line_nr typ=$selector_expr.expr_type')
	typ_sym := c.table.get_type_symbol(typ)
	field_name := selector_expr.field
	// variadic
	if table.type_is(typ, .variadic) {
		if field_name == 'len' {
			return table.int_type
		}
	}
	if field := c.table.struct_find_field(typ_sym, field_name) {
		return field.typ
	}
	if typ_sym.kind != .struct_ {
		c.error('`$typ_sym.name` is not a struct', selector_expr.pos)
	} else {
		c.error('unknown field `${typ_sym.name}.$field_name`', selector_expr.pos)
	}
	return table.void_type
}

// TODO: non deferred
pub fn (c mut Checker) return_stmt(return_stmt mut ast.Return) {
	c.expected_type = c.fn_return_type
	if return_stmt.exprs.len == 0 {
		return
	}
	if return_stmt.exprs.len > 0 && c.fn_return_type == table.void_type {
		c.error('too many arguments to return, current function does not return anything',
			return_stmt.pos)
		return
	}
	expected_type := c.fn_return_type
	expected_type_sym := c.table.get_type_symbol(expected_type)
	exp_is_optional := table.type_is(expected_type, .optional)
	mut expected_types := [expected_type]
	if expected_type_sym.kind == .multi_return {
		mr_info := expected_type_sym.info as table.MultiReturn
		expected_types = mr_info.types
	}
	mut got_types := []table.Type
	for expr in return_stmt.exprs {
		typ := c.expr(expr)
		got_types << typ
	}
	return_stmt.types = got_types
	// allow `none` & `error (Option)` return types for function that returns optional
	if exp_is_optional && table.type_idx(got_types[0]) in [table.none_type_idx, c.table.type_idxs['Option']] {
		return
	}
	if expected_types.len > 0 && expected_types.len != got_types.len {
		// c.error('wrong number of return arguments:\n\texpected: $expected_table.str()\n\tgot: $got_types.str()', return_stmt.pos)
		c.error('wrong number of return arguments', return_stmt.pos)
	}
	for i, exp_typ in expected_types {
		got_typ := got_types[i]
		if !c.table.check(got_typ, exp_typ) {
			got_typ_sym := c.table.get_type_symbol(got_typ)
			exp_typ_sym := c.table.get_type_symbol(exp_typ)
			c.error('cannot use `$got_typ_sym.name` as type `$exp_typ_sym.name` in return argument',
				return_stmt.pos)
		}
	}
}

pub fn (c mut Checker) assign_stmt(assign_stmt mut ast.AssignStmt) {
	c.expected_type = table.none_type	// TODO a hack to make `x := if ... work`
	if assign_stmt.left.len > assign_stmt.right.len {
		// multi return
		match assign_stmt.right[0] {
			ast.CallExpr {}
			else {
				c.error('assign_stmt: expected call', assign_stmt.pos)
			}
		}
		right_type := c.expr(assign_stmt.right[0])
		right_type_sym := c.table.get_type_symbol(right_type)
		mr_info := right_type_sym.mr_info()
		if right_type_sym.kind != .multi_return {
			c.error('wrong number of vars', assign_stmt.pos)
		}
		mut scope := c.file.scope.innermost(assign_stmt.pos.pos)
		for i, _ in assign_stmt.left {
			mut ident := assign_stmt.left[i]
			mut ident_var_info := ident.var_info()
			val_type := mr_info.types[i]
			if assign_stmt.op == .assign {
				var_type := c.expr(ident)
				assign_stmt.left_types << var_type
				if !c.table.check(val_type, var_type) {
					val_type_sym := c.table.get_type_symbol(val_type)
					var_type_sym := c.table.get_type_symbol(var_type)
					c.error('assign stmt: cannot use `$val_type_sym.name` as `$var_type_sym.name`',
						assign_stmt.pos)
				}
			}
			ident_var_info.typ = val_type
			ident.info = ident_var_info
			assign_stmt.left[i] = ident
			assign_stmt.right_types << val_type
			scope.update_var_type(ident.name, val_type)
		}
		c.check_expr_opt_call(assign_stmt.right[0], right_type, true)
	} else {
		// `a := 1` | `a,b := 1,2`
		if assign_stmt.left.len != assign_stmt.right.len {
			c.error('wrong number of vars', assign_stmt.pos)
		}
		mut scope := c.file.scope.innermost(assign_stmt.pos.pos)
		for i, _ in assign_stmt.left {
			mut ident := assign_stmt.left[i]
			if assign_stmt.op == .decl_assign {
				c.var_decl_name = ident.name
			}
			mut ident_var_info := ident.var_info()
			// c.assigned_var_name = ident.name
			val_type := c.expr(assign_stmt.right[i])
			if assign_stmt.op == .assign {
				var_type := c.expr(ident)
				assign_stmt.left_types << var_type
				if !c.table.check(val_type, var_type) {
					val_type_sym := c.table.get_type_symbol(val_type)
					var_type_sym := c.table.get_type_symbol(var_type)
					c.error('assign stmt: cannot use `$val_type_sym.name` as `$var_type_sym.name`',
						assign_stmt.pos)
				}
			}
			ident_var_info.typ = val_type
			ident.info = ident_var_info
			assign_stmt.left[i] = ident
			assign_stmt.right_types << val_type
			scope.update_var_type(ident.name, val_type)
			c.check_expr_opt_call(assign_stmt.right[i], val_type, true)
		}
	}
	c.var_decl_name = ''
	c.expected_type = table.void_type
	// c.assigned_var_name = ''
}

pub fn (c mut Checker) array_init(array_init mut ast.ArrayInit) table.Type {
	// println('checker: array init $array_init.pos.line_nr $c.file.path')
	mut elem_type := table.void_type
	// []string - was set in parser
	if array_init.typ != table.void_type {
		return array_init.typ
	}
	// a = []
	if array_init.exprs.len == 0 {
		type_sym := c.table.get_type_symbol(c.expected_type)
		if type_sym.kind != .array {
			c.error('array_init: no type specified (maybe: `[]Type` instead of `[]`)', array_init.pos)
			return table.void_type
		}
		// TODO: seperate errors once bug is fixed with `x := if expr { ... } else { ... }`
		// if c.expected_type == table.void_type {
		// c.error('array_init: use `[]Type` instead of `[]`', array_init.pos)
		// return table.void_type
		// }
		array_info := type_sym.array_info()
		array_init.elem_type = array_info.elem_type
		return c.expected_type
	}
	// [1,2,3]
	if array_init.exprs.len > 0 && array_init.elem_type == table.void_type {
		for i, expr in array_init.exprs {
			typ := c.expr(expr)
			// The first element's type
			if i == 0 {
				elem_type = typ
				c.expected_type = typ
				continue
			}
			if !c.table.check(elem_type, typ) {
				elem_type_sym := c.table.get_type_symbol(elem_type)
				c.error('expected array element with type `$elem_type_sym.name`', array_init.pos)
			}
		}
		idx := c.table.find_or_register_array(elem_type, 1)
		array_init.typ = table.new_type(idx)
		array_init.elem_type = elem_type
	} else if array_init.exprs.len == 1 && array_init.elem_type != table.void_type {
		// [50]byte
		mut fixed_size := 1
		match array_init.exprs[0] {
			ast.IntegerLiteral {
				fixed_size = it.val.int()
			}
			ast.Ident {
				/*
				QTODO
				scope := c.file.scope.innermost(array_init.pos.pos)
				if obj := c.file.global_scope.find(it.name) {
				} else {
					c.error(it.name, array_init.pos)
				}
				scope.find(it.name) or {
					c.error('undefined: `$it.name`', array_init.pos)
				}
*/
			}
			else {
				c.error('expecting `int` for fixed size', array_init.pos)
			}
		}
		idx := c.table.find_or_register_array_fixed(array_init.elem_type, fixed_size, 1)
		array_type := table.new_type(idx)
		array_init.typ = array_type
	}
	return array_init.typ
}

fn (c mut Checker) stmt(node ast.Stmt) {
	// c.expected_type = table.void_type
	match mut node {
		ast.AssertStmt {
			assert_type := c.expr(it.expr)
			if assert_type != table.bool_type_idx {
				atype_name := c.table.get_type_symbol(assert_type).name
				c.error('assert can be used only with `bool` expressions, but found `${atype_name}` instead',
					it.pos)
			}
		}
		ast.AssignStmt {
			c.assign_stmt(mut it)
		}
		ast.Block {
			c.stmts(it.stmts)
		}
		ast.BranchStmt {
			if c.in_for_count == 0 {
				c.error('$it.tok.lit statement not within a loop', it.tok.position())
			}
		}
		// ast.Attr {}
		ast.CompIf {
			// c.expr(it.cond)
			c.stmts(it.stmts)
			if it.has_else {
				c.stmts(it.else_stmts)
			}
		}
		ast.DeferStmt {
			c.stmts(it.stmts)
		}
		ast.ConstDecl {
			mut field_names := []string
			mut field_order := []int
			for i, field in it.fields {
				field_names << field.name
				field_order << i
			}
			mut needs_order := false
			mut done_fields := []int
			for i, field in it.fields {
				c.const_decl = field.name
				c.const_deps << field.name
				typ := c.expr(field.expr)
				it.fields[i].typ = typ
				for cd in c.const_deps {
					for j, f in it.fields {
						if j != i && cd in field_names && cd == f.name && !(j in done_fields) {
							needs_order = true
							x := field_order[j]
							field_order[j] = field_order[i]
							field_order[i] = x
							break
						}
					}
				}
				done_fields << i
				c.const_deps = []
			}
			if needs_order {
				mut ordered_fields := []ast.ConstField
				for order in field_order {
					ordered_fields << it.fields[order]
				}
				it.fields = ordered_fields
			}
		}
		ast.ExprStmt {
			etype := c.expr(it.expr)
			c.expected_type = table.void_type
			c.check_expr_opt_call(it.expr, etype, false)
		}
		ast.FnDecl {
			// if it.is_method {
			// sym := c.table.get_type_symbol(it.receiver.typ)
			// if sym.has_method(it.name) {
			// c.warn('duplicate method `$it.name`', it.pos)
			// }
			// }
			c.expected_type = table.void_type
			c.fn_return_type = it.return_type
			c.stmts(it.stmts)
		}
		ast.ForStmt {
			c.in_for_count++
			typ := c.expr(it.cond)
			if !it.is_inf && table.type_idx(typ) != table.bool_type_idx {
				c.error('non-bool used as for condition', it.pos)
			}
			// TODO: update loop var type
			// how does this work currenly?
			c.stmts(it.stmts)
			c.in_for_count--
		}
		ast.ForCStmt {
			c.in_for_count++
			c.stmt(it.init)
			c.expr(it.cond)
			// c.stmt(it.inc)
			c.expr(it.inc)
			c.stmts(it.stmts)
			c.in_for_count--
		}
		ast.ForInStmt {
			c.in_for_count++
			typ := c.expr(it.cond)
			if it.is_range {
				c.expr(it.high)
			} else {
				mut scope := c.file.scope.innermost(it.pos.pos)
				sym := c.table.get_type_symbol(typ)
				if it.key_var.len > 0 {
					key_type := match sym.kind {
						.map {
							sym.map_info().key_type
						}
						else {
							table.int_type
						}
					}
					it.key_type = key_type
					scope.update_var_type(it.key_var, key_type)
				}
				value_type := c.table.value_type(typ)
				if value_type == table.void_type {
					typ_sym := c.table.get_type_symbol(typ)
					c.error('for in: cannot index `$typ_sym.name`', it.pos)
				}
				it.cond_type = typ
				it.kind = sym.kind
				it.val_type = value_type
				scope.update_var_type(it.val_var, value_type)
			}
			c.stmts(it.stmts)
			c.in_for_count--
		}
		ast.GoStmt {
			c.expr(it.call_expr)
		}
		// ast.HashStmt {}
		ast.Import {}
		// ast.GlobalDecl {}
		ast.Return {
			c.return_stmt(mut it)
		}
		// ast.StructDecl {}
		ast.UnsafeStmt {
			c.stmts(it.stmts)
		}
		else {
			// println('checker.stmt(): unhandled node')
			// println('checker.stmt(): unhandled node (${typeof(node)})')
		}
	}
}

fn (c mut Checker) stmts(stmts []ast.Stmt) {
	c.expected_type = table.void_type
	for stmt in stmts {
		c.stmt(stmt)
	}
	c.expected_type = table.void_type
}

pub fn (c mut Checker) expr(node ast.Expr) table.Type {
	match mut node {
		ast.ArrayInit {
			return c.array_init(mut it)
		}
		ast.AsCast {
			it.expr_type = c.expr(it.expr)
			expr_type_sym := c.table.get_type_symbol(it.expr_type)
			type_sym := c.table.get_type_symbol(it.typ)
			if expr_type_sym.kind == .sum_type {
				info := expr_type_sym.info as table.SumType
				if !(it.typ in info.variants) {
					c.error('cannot cast `$expr_type_sym.name` to `$type_sym.name`', it.pos)
					// c.error('only $info.variants can be casted to `$typ`', it.pos)
				}
			} else {
				c.error('cannot cast non sum type `$type_sym.name` using `as`', it.pos)
			}
			return it.typ
		}
		ast.AssignExpr {
			c.assign_expr(mut it)
		}
		ast.Assoc {
			scope := c.file.scope.innermost(it.pos.pos)
			var := scope.find_var(it.var_name) or {
				panic(err)
			}
			for i, _ in it.fields {
				c.expr(it.exprs[i])
			}
			it.typ = var.typ
			return var.typ
		}
		ast.BoolLiteral {
			return table.bool_type
		}
		ast.CastExpr {
			it.expr_type = c.expr(it.expr)
			if it.has_arg {
				c.expr(it.arg)
			}
			it.typname = c.table.get_type_symbol(it.typ).name
			return it.typ
		}
		ast.CallExpr {
			return c.call_expr(mut it)
		}
		ast.CharLiteral {
			return table.byte_type
		}
		ast.EnumVal {
			return c.enum_val(mut it)
		}
		ast.FloatLiteral {
			return table.f64_type
		}
		ast.Ident {
			// c.checked_ident = it.name
			res := c.ident(mut it)
			// c.checked_ident = ''
			return res
		}
		ast.IfExpr {
			return c.if_expr(mut it)
		}
		ast.IfGuardExpr {
			it.expr_type = c.expr(it.expr)
			return table.bool_type
		}
		ast.IndexExpr {
			return c.index_expr(mut it)
		}
		ast.InfixExpr {
			return c.infix_expr(mut it)
		}
		ast.IntegerLiteral {
			return table.int_type
		}
		ast.MapInit {
			return c.map_init(mut it)
		}
		ast.MatchExpr {
			return c.match_expr(mut it)
		}
		ast.PostfixExpr {
			return c.postfix_expr(it)
		}
		ast.PrefixExpr {
			right_type := c.expr(it.right)
			// TODO: testing ref/deref strategy
			if it.op == .amp && !table.type_is_ptr(right_type) {
				return table.type_to_ptr(right_type)
			}
			if it.op == .mul && table.type_is_ptr(right_type) {
				return table.type_deref(right_type)
			}
			if it.op == .not && right_type != table.bool_type_idx {
				c.error('! operator can only be used with bool types', it.pos)
			}
			return right_type
		}
		ast.None {
			return table.none_type
		}
		ast.ParExpr {
			return c.expr(it.expr)
		}
		ast.SelectorExpr {
			return c.selector_expr(mut it)
		}
		ast.SizeOf {
			return table.int_type
		}
		ast.StringLiteral {
			if it.is_c {
				return table.byteptr_type
			}
			return table.string_type
		}
		ast.StringInterLiteral {
			for expr in it.exprs {
				it.expr_types << c.expr(expr)
			}
			return table.string_type
		}
		ast.StructInit {
			return c.struct_init(mut it)
		}
		ast.Type {
			return it.typ
		}
		ast.TypeOf {
			it.expr_type = c.expr(it.expr)
			return table.string_type
		}
		else {
			tnode := typeof(node)
			if tnode != 'unknown v.ast.Expr' {
				println('checker.expr(): unhandled node with typeof(`${tnode}`)')
			}
		}
	}
	return table.void_type
}

pub fn (c mut Checker) ident(ident mut ast.Ident) table.Type {
	if ident.name == c.var_decl_name {		// c.checked_ident {
		c.error('unresolved: `$ident.name`', ident.pos)
		return table.void_type
	}
	// TODO: move this
	if c.const_deps.len > 0 {
		mut name := ident.name
		if !name.contains('.') && !(ident.mod in ['builtin', 'main']) {
			name = '${ident.mod}.$ident.name'
		}
		if name == c.const_decl {
			c.error('cycle in constant `$c.const_decl`', ident.pos)
			return table.void_type
		}
		c.const_deps << name
	}
	if ident.kind == .blank_ident {
		return table.void_type
	}
	// second use
	if ident.kind == .variable {
		info := ident.info as ast.IdentVar
		return info.typ
	} else if ident.kind == .constant {
		info := ident.info as ast.IdentVar
		return info.typ
	} else if ident.kind == .function {
		info := ident.info as ast.IdentFn
		return info.typ
	} else if ident.kind == .unresolved {
		// first use
		start_scope := c.file.scope.innermost(ident.pos.pos)
		if obj := start_scope.find(ident.name) {
			match obj {
				ast.Var {
					mut typ := it.typ
					if typ == 0 {
						typ = c.expr(it.expr)
					}
					is_optional := table.type_is(typ, .optional)
					ident.kind = .variable
					ident.info = ast.IdentVar{
						typ: typ
						is_optional: is_optional
					}
					it.typ = typ
					// unwrap optional (`println(x)`)
					if is_optional {
						return table.type_set(typ, .unset)
					}
					return typ
				}
				else {}
			}
		}
		// prepend mod to look for fn call or const
		mut name := ident.name
		if !name.contains('.') && !(ident.mod in ['builtin', 'main']) {
			name = '${ident.mod}.$ident.name'
		}
		if obj := c.file.global_scope.find(name) {
			match obj {
				ast.GlobalDecl {
					ident.kind = .global
					ident.info = ast.IdentVar{
						typ: it.typ
					}
					return it.typ
				}
				ast.ConstField {
					mut typ := it.typ
					if typ == 0 {
						typ = c.expr(it.expr)
					}
					ident.name = name
					ident.kind = .constant
					ident.info = ast.IdentVar{
						typ: typ
					}
					it.typ = typ
					return typ
				}
				else {}
			}
		}
		// Function object (not a call), e.g. `onclick(my_click)`
		if func := c.table.find_fn(name) {
			fn_type := table.new_type(c.table.find_or_register_fn_type(func, true))
			ident.name = name
			ident.kind = .function
			ident.info = ast.IdentFn{
				typ: fn_type
			}
			return fn_type
		}
	}
	if ident.is_c {
		return table.int_type
	}
	if ident.name != '_' {
		c.error('undefined: `$ident.name`', ident.pos)
	}
	return table.void_type
}

pub fn (c mut Checker) match_expr(node mut ast.MatchExpr) table.Type {
	node.is_expr = c.expected_type != table.void_type
	node.expected_type = c.expected_type
	cond_type := c.expr(node.cond)
	if cond_type == 0 {
		c.error('match 0 cond type', node.pos)
	}
	c.expected_type = cond_type
	mut ret_type := table.void_type
	for branch in node.branches {
		for expr in branch.exprs {
			c.expected_type = cond_type
			typ := c.expr(expr)
			typ_sym := c.table.get_type_symbol(typ)
			// TODO:
			if typ_sym.kind == .sum_type {
			}
		}
		c.stmts(branch.stmts)
		// If the last statement is an expression, return its type
		if branch.stmts.len > 0 {
			match branch.stmts[branch.stmts.len - 1] {
				ast.ExprStmt {
					ret_type = c.expr(it.expr)
				}
				else {
					// TODO: ask alex about this
					// typ := c.expr(it.expr)
					// type_sym := c.table.get_type_symbol(typ)
					// p.warn('match expr ret $type_sym.name')
					// node.typ = typ
					// return typ
				}
			}
		}
	}
	// if ret_type != table.void_type {
	// node.is_expr = c.expected_type != table.void_type
	// node.expected_type = c.expected_type
	// }
	node.return_type = ret_type
	node.cond_type = cond_type
	// println('!m $expr_type')
	return ret_type
}

pub fn (c mut Checker) if_expr(node mut ast.IfExpr) table.Type {
	if c.expected_type != table.void_type {
		// | c.assigned_var_name != '' {
		// sym := c.table.get_type_symbol(c.expected_type)
		// println('$c.file.path  $node.pos.line_nr IF is expr: checker exp type = ' + sym.name)
		node.is_expr = true
	}
	node.typ = table.void_type
	for i, branch in node.branches {
		match branch.cond {
			ast.ParExpr {
				c.error('unnecessary `()` in an if condition. use `if expr {` instead of `if (expr) {`.',
					node.pos)
			}
			else {}
		}
		typ := c.expr(branch.cond)
		if i < node.branches.len - 1 || !node.has_else {
			typ_sym := c.table.get_type_symbol(typ)
			// if typ_sym.kind != .bool {
			if table.type_idx(typ) != table.bool_type_idx {
				c.error('non-bool (`$typ_sym.name`) used as if condition', node.pos)
			}
		}
		c.stmts(branch.stmts)
	}
	if node.has_else && node.is_expr {
		last_branch := node.branches[node.branches.len - 1]
		if last_branch.stmts.len > 0 {
			match last_branch.stmts[last_branch.stmts.len - 1] {
				ast.ExprStmt {
					// type_sym := p.table.get_type_symbol(it.typ)
					// p.warn('if expr ret $type_sym.name')
					t := c.expr(it.expr)
					node.typ = t
					return t
				}
				else {}
			}
		}
	}
	return table.bool_type
}

pub fn (c mut Checker) postfix_expr(node ast.PostfixExpr) table.Type {
	/*
	match node.expr {
		ast.IdentVar {
			println('postfix identvar')
		}
		else {}
	}
*/
	typ := c.expr(node.expr)
	typ_sym := c.table.get_type_symbol(typ)
	// if !table.is_number(typ) {
	if !typ_sym.is_number() {
		println(typ_sym.kind.str())
		c.error('invalid operation: $node.op.str() (non-numeric type `$typ_sym.name`)', node.pos)
	}
	return typ
}

pub fn (c mut Checker) index_expr(node mut ast.IndexExpr) table.Type {
	typ := c.expr(node.left)
	node.left_type = typ
	mut is_range := false	// TODO is_range := node.index is ast.RangeExpr
	match node.index {
		ast.RangeExpr {
			is_range = true
			if it.has_low {
				c.expr(it.low)
			}
			if it.has_high {
				c.expr(it.high)
			}
		}
		else {}
	}
	typ_sym := c.table.get_type_symbol(typ)
	if !is_range {
		index_type := c.expr(node.index)
		index_type_sym := c.table.get_type_symbol(index_type)
		// println('index expr left=$typ_sym.name $node.pos.line_nr')
		// if typ_sym.kind == .array && (!(table.type_idx(index_type) in table.number_type_idxs) &&
		// index_type_sym.kind != .enum_) {
		if typ_sym.kind in [.array, .array_fixed] && !(table.is_number(index_type) || index_type_sym.kind ==
			.enum_) {
			c.error('non-integer index `$index_type_sym.name` (array type `$typ_sym.name`)',
				node.pos)
		} else if typ_sym.kind == .map && table.type_idx(index_type) != table.string_type_idx {
			c.error('non-string map index (map type `$typ_sym.name`)', node.pos)
		}
		value_type := c.table.value_type(typ)
		if value_type != table.void_type {
			return value_type
		}
	} else if is_range {
		// array[1..2] => array
		// fixed_array[1..2] => array
		if typ_sym.kind == .array_fixed {
			elem_type := c.table.value_type(typ)
			idx := c.table.find_or_register_array(elem_type, 1)
			return table.new_type(idx)
		}
	}
	return typ
}

// `.green` or `Color.green`
// If a short form is used, `expected_type` needs to be an enum
// with this value.
pub fn (c mut Checker) enum_val(node mut ast.EnumVal) table.Type {
	typ_idx := if node.enum_name == '' {
		table.type_idx(c.expected_type)
	} else {		//
		c.table.find_type_idx(node.enum_name)
	}
	// println('checker: enum_val: $node.enum_name typeidx=$typ_idx')
	if typ_idx == 0 {
		c.error('not an enum (name=$node.enum_name) (type_idx=0)', node.pos)
	}
	typ := table.new_type(typ_idx)
	typ_sym := c.table.get_type_symbol(typ)
	// println('tname=$typ.name')
	if typ_sym.kind != .enum_ {
		c.error('not an enum', node.pos)
	}
	// info := typ_sym.info as table.Enum
	info := typ_sym.enum_info()
	// rintln('checker: x = $info.x enum val $c.expected_type $typ_sym.name')
	// println(info.vals)
	if !(node.val in info.vals) {
		c.error('enum `$typ_sym.name` does not have a value `$node.val`', node.pos)
	}
	node.typ = typ
	return typ
}

pub fn (c mut Checker) map_init(node mut ast.MapInit) table.Type {
	// `x ;= map[string]string` - set in parser
	if node.typ != 0 {
		info := c.table.get_type_symbol(node.typ).map_info()
		node.key_type = info.key_type
		node.value_type = info.value_type
		return node.typ
	}
	// `{'age': 20}`
	key0_type := c.expr(node.keys[0])
	val0_type := c.expr(node.vals[0])
	for i, key in node.keys {
		if i == 0 {
			continue
		}
		val := node.vals[i]
		key_type := c.expr(key)
		val_type := c.expr(val)
		if !c.table.check(key_type, key0_type) {
			key0_type_sym := c.table.get_type_symbol(key0_type)
			key_type_sym := c.table.get_type_symbol(key_type)
			c.error('map init: cannot use `$key_type_sym.name` as `$key0_type_sym` for map key',
				node.pos)
		}
		if !c.table.check(val_type, val0_type) {
			val0_type_sym := c.table.get_type_symbol(val0_type)
			val_type_sym := c.table.get_type_symbol(val_type)
			c.error('map init: cannot use `$val_type_sym.name` as `$val0_type_sym` for map value',
				node.pos)
		}
	}
	map_type := table.new_type(c.table.find_or_register_map(key0_type, val0_type))
	node.typ = map_type
	node.key_type = key0_type
	node.value_type = val0_type
	return map_type
}

pub fn (c mut Checker) warn(s string, pos token.Position) {
	allow_warnings := !c.pref.is_prod	// allow warnings only in dev builds
	c.warn_or_error(s, pos, allow_warnings)	// allow warnings only in dev builds
}

pub fn (c mut Checker) error(s string, pos token.Position) {
	c.warn_or_error(s, pos, false)
}

fn (c mut Checker) warn_or_error(s string, pos token.Position, warn bool) {
	if !warn {
		c.nr_errors++
	}
	// if c.pref.is_verbose {
	if c.pref.is_verbose {
		print_backtrace()
	}
	typ := if warn { 'warning' } else { 'error' }
	kind := if c.pref.is_verbose { 'checker $typ #$c.nr_errors:' } else { '$typ:' }
	ferror := util.formated_error(kind, s, c.file.path, pos)
	c.errors << ferror
	if !(pos.line_nr in c.error_lines) {
		if warn {
			println(ferror)
		} else {
			eprintln(ferror)
		}
	}
	if !warn {
		c.error_lines << pos.line_nr
	}
	if c.pref.is_verbose {
		println('\n\n')
	}
	if c.nr_errors >= max_nr_errors {
		exit(1)
	}
}
