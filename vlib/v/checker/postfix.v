module checker

import v.ast

fn (mut c Checker) postfix_expr(mut node ast.PostfixExpr) ast.Type {
	typ := c.unwrap_generic(c.expr(node.expr))
	typ_sym := c.table.sym(typ)
	is_non_void_pointer := (typ.is_ptr() || typ.is_pointer()) && typ_sym.kind != .voidptr

	if node.op in [.inc, .dec] && !node.expr.is_lvalue() {
		kind, op_str := if node.op == .inc { 'increment', '++' } else { 'decrement', '--' }

		c.add_error_detail('try assign expression to a variable and use ${kind} for it:
	mut variable := ${node.expr}
	variable${op_str}')
		c.error('cannot ${kind} ${node.expr} because it is non lvalue expression', node.expr.pos())
	}

	if !c.inside_unsafe && is_non_void_pointer && !node.expr.is_auto_deref_var() {
		c.warn('pointer arithmetic is only allowed in `unsafe` blocks', node.pos)
	}
	if !(typ_sym.is_number() || ((c.inside_unsafe || c.pref.translated) && is_non_void_pointer)) {
		if c.inside_comptime_for_field {
			if c.is_comptime_var(node.expr) {
				return c.comptime_fields_default_type
			} else if node.expr is ast.ComptimeSelector {
				return c.comptime_fields_default_type
			}
		}

		typ_str := c.table.type_to_str(typ)
		c.error('invalid operation: ${node.op.str()} (non-numeric type `${typ_str}`)',
			node.pos)
	} else {
		node.auto_locked, _ = c.fail_if_immutable(node.expr)
	}
	return typ
}
