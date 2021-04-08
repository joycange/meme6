// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license that can be found in the LICENSE file.
module c

import v.ast
import strings
import v.util

// pg,mysql etc
const (
	dbtype = 'sqlite'
)

enum SqlExprSide {
	left
	right
}

enum SqlType {
	sqlite3
	mysql
	psql
	unknown
}

fn (mut g Gen) sql_stmt(node ast.SqlStmt) {
	if node.kind == .create {
		g.sql_create_table(node)
		return
	}
	typ := g.parse_db_type(node.db_expr)
	match typ {
		.sqlite3 {
			g.sqlite3_stmt(node, typ)
		}
		else {
			verror('This database type `$typ` is not implemented yet in orm') // TODO add better error
		}
	}
}

fn (mut g Gen) sql_create_table(node ast.SqlStmt) {
	typ := g.parse_db_type(node.db_expr)
	match typ {
		.sqlite3 {
			g.sqlite3_create_table(node, typ)
		}
		else {
			verror('This database type `$typ` is not implemented yet in orm') // TODO add better error
		}
	}
}

fn (mut g Gen) sql_select_expr(node ast.SqlExpr, sub bool, line string) {
	typ := g.parse_db_type(node.db_expr)
	match typ {
		.sqlite3 {
			g.sqlite3_select_expr(node, sub, line, typ)
		}
		else {
			verror('This database type `$typ` is not implemented yet in orm') // TODO add better error
		}
	}
}

fn (mut g Gen) sql_bind_int(val string, typ SqlType) {
	match typ {
		.sqlite3 {
			g.sqlite3_bind_int(val)
		}
		else {
			// add error
		}
	}
}

fn (mut g Gen) sql_bind_string(val string, len string, typ SqlType) {
	match typ {
		.sqlite3 {
			g.sqlite3_bind_string(val, len)
		}
		else {
			// add error
		}
	}
}

fn (mut g Gen) sql_type_from_v(typ SqlType, v_typ ast.Type) string {
	match typ {
		.sqlite3 {
			return g.sqlite3_type_from_v(typ, v_typ)
		}
		else {
			// add error
		}
	}
	return ''
}

// sqlite3

fn (mut g Gen) sqlite3_stmt(node ast.SqlStmt, typ SqlType) {
	g.sql_i = 0
	g.writeln('\n\t// sql insert')
	db_name := g.new_tmp_var()
	g.sql_stmt_name = g.new_tmp_var()
	g.write('${c.dbtype}__DB $db_name = ')
	g.expr(node.db_expr)
	g.writeln(';')
	g.write('sqlite3_stmt* $g.sql_stmt_name = ${c.dbtype}__DB_init_stmt($db_name, _SLIT("')
	table_name := util.strip_mod_name(g.table.get_type_symbol(node.table_expr.typ).name)
	if node.kind == .insert {
		g.write('INSERT INTO `$table_name` (')
	} else if node.kind == .update {
		g.write('UPDATE `$table_name` SET ')
	} else if node.kind == .delete {
		g.write('DELETE FROM `$table_name` ')
	}
	if node.kind == .insert {
		for i, field in node.fields {
			if field.name == 'id' {
				continue
			}
			g.write('`$field.name`')
			if i < node.fields.len - 1 {
				g.write(', ')
			}
		}
		g.write(') values (')
		for i, field in node.fields {
			if field.name == 'id' {
				continue
			}
			g.write('?${i + 0}')
			if i < node.fields.len - 1 {
				g.write(', ')
			}
		}
		g.write(')')
	} else if node.kind == .update {
		for i, col in node.updated_columns {
			g.write(' $col = ')
			g.expr_to_sql(node.update_exprs[i], typ)
			if i < node.updated_columns.len - 1 {
				g.write(', ')
			}
		}
		g.write(' WHERE ')
	} else if node.kind == .delete {
		g.write(' WHERE ')
	}
	if node.kind == .update || node.kind == .delete {
		g.expr_to_sql(node.where_expr, typ)
	}
	g.writeln('"));')
	if node.kind == .insert {
		// build the object now (`x.name = ... x.id == ...`)
		for i, field in node.fields {
			if field.name == 'id' {
				continue
			}
			x := '${node.object_var_name}.$field.name'
			if field.typ == ast.string_type {
				g.writeln('sqlite3_bind_text($g.sql_stmt_name, ${i + 0}, ${x}.str, ${x}.len, 0);')
			} else if g.table.type_symbols[int(field.typ)].kind == .struct_ {
				// insert again
				expr := node.sub_structs[int(field.typ)]
				tmp_sql_stmt_name := g.sql_stmt_name
				g.sql_stmt(expr)
				g.sql_stmt_name = tmp_sql_stmt_name
				// get last inserted id
				g.writeln('Array_sqlite__Row rows = sqlite__DB_exec($db_name, _SLIT("SELECT last_insert_rowid()")).arg0;')
				id_name := g.new_tmp_var()
				g.writeln('int $id_name = string_int((*(string*)array_get((*(sqlite__Row*)array_get(rows, 0)).vals, 0)));')
				g.writeln('sqlite3_bind_int($g.sql_stmt_name, ${i + 0} , $id_name); // id')
			} else {
				g.writeln('sqlite3_bind_int($g.sql_stmt_name, ${i + 0} , $x); // stmt')
			}
		}
	}
	// Dump all sql parameters generated by our custom expr handler
	binds := g.sql_buf.str()
	g.sql_buf = strings.new_builder(100)
	g.writeln(binds)
	step_res := g.new_tmp_var()
	g.writeln('\tint $step_res = sqlite3_step($g.sql_stmt_name);')
	g.writeln('\tif( ($step_res != SQLITE_OK) && ($step_res != SQLITE_DONE)){ puts(sqlite3_errmsg(${db_name}.conn)); }')
	g.writeln('\tsqlite3_finalize($g.sql_stmt_name);')
}

fn (mut g Gen) sqlite3_select_expr(node ast.SqlExpr, sub bool, line string, sql_typ SqlType) {
	g.sql_i = 0
	/*
	`nr_users := sql db { ... }` =>
	```
		sql_init_stmt()
		sqlite3_bind_int()
		sqlite3_bind_string()
		...
		int nr_users = get_int(stmt)
	```
	*/
	mut cur_line := line
	if !sub {
		cur_line = g.go_before_stmt(0)
	}
	mut sql_query := 'SELECT '
	table_name := util.strip_mod_name(g.table.get_type_symbol(node.table_expr.typ).name)
	if node.is_count {
		// `select count(*) from User`
		sql_query += 'COUNT(*) FROM `$table_name` '
	} else {
		// `select id, name, country from User`
		for i, field in node.fields {
			sql_query += '`$field.name`'
			if i < node.fields.len - 1 {
				sql_query += ', '
			}
		}
		sql_query += ' FROM `$table_name`'
	}
	if node.has_where {
		sql_query += ' WHERE '
	}
	// g.write('${dbtype}__DB_q_int(*(${dbtype}__DB*)${node.db_var_name}.data, _SLIT("$sql_query')
	g.sql_stmt_name = g.new_tmp_var()
	db_name := g.new_tmp_var()
	g.writeln('\n\t// sql select')
	// g.write('${dbtype}__DB $db_name = *(${dbtype}__DB*)${node.db_var_name}.data;')
	g.write('${c.dbtype}__DB $db_name = ') // $node.db_var_name;')
	g.expr(node.db_expr)
	g.writeln(';')
	// g.write('sqlite3_stmt* $g.sql_stmt_name = ${dbtype}__DB_init_stmt(*(${dbtype}__DB*)${node.db_var_name}.data, _SLIT("$sql_query')
	g.write('sqlite3_stmt* $g.sql_stmt_name = ${c.dbtype}__DB_init_stmt($db_name, _SLIT("')
	g.write(sql_query)
	if node.has_where && node.where_expr is ast.InfixExpr {
		g.expr_to_sql(node.where_expr, sql_typ)
	}
	if node.has_order {
		g.write(' ORDER BY ')
		g.sql_side = .left
		g.expr_to_sql(node.order_expr, sql_typ)
		if node.has_desc {
			g.write(' DESC ')
		}
	} else {
		g.write(' ORDER BY id ')
	}
	if node.has_limit {
		g.write(' LIMIT ')
		g.sql_side = .right
		g.expr_to_sql(node.limit_expr, sql_typ)
	}
	if node.has_offset {
		g.write(' OFFSET ')
		g.sql_side = .right
		g.expr_to_sql(node.offset_expr, sql_typ)
	}
	g.writeln('"));')
	// Dump all sql parameters generated by our custom expr handler
	binds := g.sql_buf.str()
	g.sql_buf = strings.new_builder(100)
	g.writeln(binds)
	binding_res := g.new_tmp_var()
	g.writeln('int $binding_res = sqlite3_extended_errcode(${db_name}.conn);')
	g.writeln('if ($binding_res != SQLITE_OK) { puts(sqlite3_errmsg(${db_name}.conn)); }')
	//
	if node.is_count {
		g.writeln('$cur_line ${c.dbtype}__get_int_from_stmt($g.sql_stmt_name);')
	} else {
		// `user := sql db { select from User where id = 1 }`
		tmp := g.new_tmp_var()
		styp := g.typ(node.typ)
		mut elem_type_str := ''
		if node.is_array {
			// array_User array_tmp;
			// for { User tmp; ... array_tmp << tmp; }
			array_sym := g.table.get_type_symbol(node.typ)
			array_info := array_sym.info as ast.Array
			elem_type_str = g.typ(array_info.elem_type)
			g.writeln('$styp ${tmp}_array = __new_array(0, 10, sizeof($elem_type_str));')
			g.writeln('while (1) {')
			g.writeln('\t$elem_type_str $tmp = ($elem_type_str) {')
			//
			sym := g.table.get_type_symbol(array_info.elem_type)
			info := sym.info as ast.Struct
			for i, field in info.fields {
				g.zero_struct_field(field)
				if i != info.fields.len - 1 {
					g.write(', ')
				}
			}
			g.writeln('};')
		} else {
			// `User tmp;`
			g.writeln('$styp $tmp = ($styp){')
			// Zero fields, (only the [skip] ones?)
			// If we don't, string values are going to be nil etc for fields that are not returned
			// by the db engine.
			sym := g.table.get_type_symbol(node.typ)
			info := sym.info as ast.Struct
			for i, field in info.fields {
				g.zero_struct_field(field)
				if i != info.fields.len - 1 {
					g.write(', ')
				}
			}
			g.writeln('};')
		}
		//
		g.writeln('int _step_res$tmp = sqlite3_step($g.sql_stmt_name);')
		if node.is_array {
			// g.writeln('\tprintf("step res=%d\\n", _step_res$tmp);')
			g.writeln('\tif (_step_res$tmp == SQLITE_DONE) break;')
			g.writeln('\tif (_step_res$tmp == SQLITE_ROW) ;') // another row
			g.writeln('\telse if (_step_res$tmp != SQLITE_OK) break;')
		} else {
			// g.writeln('printf("RES: %d\\n", _step_res$tmp) ;')
			g.writeln('\tif (_step_res$tmp == SQLITE_OK || _step_res$tmp == SQLITE_ROW) {')
		}
		for i, field in node.fields {
			mut func := 'sqlite3_column_int'
			if field.typ == ast.string_type {
				func = 'sqlite3_column_text'
				string_data := g.new_tmp_var()
				g.writeln('byteptr $string_data = ${func}($g.sql_stmt_name, $i);')
				g.writeln('if ($string_data != NULL) {')
				g.writeln('\t${tmp}.$field.name = tos_clone($string_data);')
				g.writeln('}')
			} else if g.table.type_symbols[int(field.typ)].kind == .struct_ {
				id_name := g.new_tmp_var()
				g.writeln('//parse struct start')
				g.writeln('int $id_name = ${func}($g.sql_stmt_name, $i);')
				mut expr := node.sub_structs[int(field.typ)]
				mut where_expr := expr.where_expr as ast.InfixExpr
				mut ident := where_expr.right as ast.Ident
				ident.name = id_name
				where_expr.right = ident
				expr.where_expr = where_expr

				tmp_sql_i := g.sql_i
				tmp_sql_stmt_name := g.sql_stmt_name
				tmp_sql_buf := g.sql_buf

				g.sql_select_expr(expr, true, '\t${tmp}.$field.name =')
				g.writeln('//parse struct end')

				g.sql_stmt_name = tmp_sql_stmt_name
				g.sql_buf = tmp_sql_buf
				g.sql_i = tmp_sql_i
			} else {
				g.writeln('${tmp}.$field.name = ${func}($g.sql_stmt_name, $i);')
			}
		}
		if node.is_array {
			g.writeln('\t array_push(&${tmp}_array, _MOV(($elem_type_str[]){ $tmp }));')
		}
		g.writeln('}')
		g.writeln('sqlite3_finalize($g.sql_stmt_name);')
		if node.is_array {
			g.writeln('$cur_line ${tmp}_array; ') // `array_User users = tmp_array;`
		} else {
			g.writeln('$cur_line $tmp; ') // `User user = tmp;`
		}
	}
}

fn (mut g Gen) sqlite3_create_table(node ast.SqlStmt, typ SqlType) {
	typ_sym := g.table.get_type_symbol(node.table_expr.typ)
	if typ_sym.info !is ast.Struct {
		verror('Type `$typ_sym.name` has to be a struct')
	}
	g.writeln('// sqlite3 table creator ($typ_sym.name)')
	struct_data := typ_sym.info as ast.Struct
	table_name := typ_sym.name.split('.').last()
	mut create_string := 'CREATE TABLE IF NOT EXISTS `$table_name` ('

	mut fields := []string{}

	for field in struct_data.fields {
		mut is_primary := false
		mut skip := false
		for attr in field.attrs {
			match attr.name {
				'skip' {
					skip = true
				}
				'primary' {
					is_primary = true
				}
				else {}
			}
		}
		if skip { // cpp workaround
			continue
		}
		mut stmt := ''
		mut converted_typ := g.sql_type_from_v(typ, field.typ)
		mut name := field.name
		if converted_typ == '' {
			if g.table.get_type_symbol(field.typ).kind == .struct_ {
				converted_typ = g.sql_type_from_v(typ, ast.int_type)
				g.sql_create_table(ast.SqlStmt{
					db_expr: node.db_expr
					kind: node.kind
					pos: node.pos
					table_expr: ast.TypeNode{
						typ: field.typ
						pos: node.table_expr.pos
					}
				})
			} else {
				eprintln(g.table.get_type_symbol(field.typ).kind)
				verror('unknown type ($field.typ)')
				continue
			}
		}
		stmt = '`$name` $converted_typ'

		if field.has_default_expr {
			stmt += ' DEFAULT '
			stmt += field.default_expr.str()
		}
		if is_primary {
			stmt += ' PRIMARY KEY'
		}
		fields << stmt
	}
	create_string += fields.join(', ')
	create_string += ');'
	g.write('sqlite__DB_exec(')
	g.expr(node.db_expr)
	g.writeln(', _SLIT("$create_string"));')
}

fn (mut g Gen) sqlite3_bind_int(val string) {
	g.sql_buf.writeln('sqlite3_bind_int($g.sql_stmt_name, $g.sql_i, $val);')
}

fn (mut g Gen) sqlite3_bind_string(val string, len string) {
	g.sql_buf.writeln('sqlite3_bind_text($g.sql_stmt_name, $g.sql_i, $val, $len, 0);')
}

fn (mut g Gen) sqlite3_type_from_v(typ SqlType, v_typ ast.Type) string {
	if v_typ.is_number() || v_typ == ast.bool_type {
		return 'INTEGER'
	}
	if v_typ.is_string() {
		return 'TEXT'
	}
	return ''
}

// mysql

fn (mut g Gen) mysql_stmt(node ast.SqlStmt) {
}

fn (mut g Gen) mysql_select_expr(node ast.SqlExpr, sub bool, line string) {
}

fn (mut g Gen) mysql_bind_int(val string) {
}

fn (mut g Gen) mysql_bind_string(val string, len string) {
}

// utils

fn (mut g Gen) expr_to_sql(expr ast.Expr, typ SqlType) {
	// Custom handling for infix exprs (since we need e.g. `and` instead of `&&` in SQL queries),
	// strings. Everything else (like numbers, a.b) is handled by g.expr()
	//
	// TODO `where id = some_column + 1` needs literal generation of `some_column` as a string,
	// not a V variable. Need to distinguish column names from V variables.
	match expr {
		ast.InfixExpr {
			g.sql_side = .left
			g.expr_to_sql(expr.left, typ)
			match expr.op {
				.ne { g.write(' != ') }
				.eq { g.write(' = ') }
				.gt { g.write(' > ') }
				.lt { g.write(' < ') }
				.ge { g.write(' >= ') }
				.le { g.write(' <= ') }
				.and { g.write(' and ') }
				.logical_or { g.write(' or ') }
				.plus { g.write(' + ') }
				.minus { g.write(' - ') }
				.mul { g.write(' * ') }
				.div { g.write(' / ') }
				else {}
			}
			g.sql_side = .right
			g.expr_to_sql(expr.right, typ)
		}
		ast.StringLiteral {
			// g.write("'$it.val'")
			g.inc_sql_i()
			g.sql_bind_string('"$expr.val"', expr.val.len.str(), typ)
		}
		ast.IntegerLiteral {
			g.inc_sql_i()
			g.sql_bind_int(expr.val, typ)
		}
		ast.BoolLiteral {
			// true/false literals were added to Sqlite 3.23 (2018-04-02)
			// but lots of apps/distros use older sqlite (e.g. Ubuntu 18.04 LTS )
			g.inc_sql_i()
			eval := if expr.val { '1' } else { '0' }
			g.sql_bind_int(eval, typ)
		}
		ast.Ident {
			// `name == user_name` => `name == ?1`
			// for left sides just add a string, for right sides, generate the bindings
			if g.sql_side == .left {
				// println("sql gen left $expr.name")
				g.write(expr.name)
			} else {
				g.inc_sql_i()
				info := expr.info as ast.IdentVar
				ityp := info.typ
				if ityp == ast.string_type {
					g.sql_bind_string('${expr.name}.str', '${expr.name}.len', typ)
				} else if ityp == ast.int_type {
					g.sql_bind_int(expr.name, typ)
				} else {
					verror('bad sql type=$ityp ident_name=$expr.name')
				}
			}
		}
		ast.SelectorExpr {
			g.inc_sql_i()
			if expr.typ == ast.int_type {
				if expr.expr !is ast.Ident {
					verror('orm selector not ident')
				}
				ident := expr.expr as ast.Ident
				g.sql_bind_int(ident.name + '.' + expr.field_name, typ)
			} else {
				verror('bad sql type=$expr.typ selector expr=$expr.field_name')
			}
		}
		else {
			g.expr(expr)
		}
	}
	/*
	ast.Ident {
			g.write('$it.name')
		}
		else {}
	*/
}

fn (mut g Gen) inc_sql_i() {
	g.sql_i++
	g.write('?$g.sql_i')
}

fn (mut g Gen) parse_db_type(expr ast.Expr) SqlType {
	match expr {
		ast.Ident {
			if expr.info is ast.IdentVar {
				return g.parse_db_from_type_string(g.table.get_type_name(expr.info.typ))
			}
		}
		ast.SelectorExpr {
			return g.parse_db_from_type_string(g.table.get_type_name(expr.typ))
		}
		else {
			return .unknown
		}
	}
	return .unknown
}

fn (mut g Gen) parse_db_from_type_string(name string) SqlType {
	match name {
		'sqlite.DB' {
			return .sqlite3
		}
		else {
			return .unknown
		}
	}
}
