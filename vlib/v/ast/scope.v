// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ast

import v.table
import v.token

pub struct Scope {
mut:
	parent    &Scope
	children  []&Scope
	start_pos int
	end_pos   int
	unused_vars map[string]UnusedVar
	objects   map[string]ScopeObject
}

pub struct UnusedVar {
	name string
	pos token.Position
}

pub fn new_scope(parent &Scope, start_pos int) &Scope {
	return &ast.Scope{
		parent: parent
		start_pos: start_pos
	}
}

pub fn (s &Scope) find_with_scope(name string) ?(ScopeObject, &Scope) {
	mut sc := s
	for  {
		if name in sc.objects {
			return sc.objects[name], sc
		}
		if isnil(sc.parent) {
			break
		}
		sc = sc.parent
	}
	return none
}

pub fn (s &Scope) find(name string) ?ScopeObject {
	for sc := s; ; sc = sc.parent {
		if name in sc.objects {
			return sc.objects[name]
		}
		if isnil(sc.parent) {
			break
		}
	}
	return none
}

pub fn (s &Scope) is_known(name string) bool {
	if _ := s.find(name) {
		return true
	}
	return false
}

pub fn (s &Scope) find_var(name string) ?Var {
	if obj := s.find(name) {
		v := ScopeObject(obj)
		match v {
			Var {
				return *it
			}
			else {}
		}
	}
	return none
}

pub fn (s &Scope) find_const(name string) ?ConstField {
	if obj := s.find(name) {
		cf := ScopeObject(obj)
		match cf {
			ConstField {
				return *it
			}
			else {}
		}
	}
	return none
}

pub fn (s &Scope) known_var(name string) bool {
	if _ := s.find_var(name) {
		return true
	}
	return false
}

pub fn (s mut Scope) update_var_type(name string, typ table.Type) {
	match mut s.objects[name] {
		Var {
			if it.typ == typ {
				return
			}
			it.typ = typ
		}
		else {}
	}
}

pub fn (s mut Scope) register(name string, obj ScopeObject) {
	if x := s.find(name) {
		// println('existing obect: $name')
		return
	}
	s.objects[name] = obj
}

pub fn (s mut Scope) register_unused_variable(name string, pos token.Position) {
	s.unused_vars[name] = UnusedVar{name, pos}
}

pub fn (s mut Scope) remove_unused_variable(name string) {
	mut sc := s
	for !isnil(cur) {
		sc.unused_vars.delete(name)
		sc = sc.parent
	}
}

pub fn (s mut Scope) unused_variables() []UnusedVar {
	ret := []UnusedVar
	for _, v in s.unused_vars {
		ret << v
	}
	return ret
}

pub fn (s mut Scope) clear_unused_variables() {
	s.unused_vars = map[string]UnusedVar
}

pub fn (s &Scope) outermost() &Scope {
	mut sc := s
	for !isnil(sc.parent) {
		sc = sc.parent
	}
	return sc
}

// returns the innermost scope containing pos
// pub fn (s &Scope) innermost(pos int) ?&Scope {
pub fn (s &Scope) innermost(pos int) &Scope {
	if s.contains(pos) {
		// binary search
		mut first := 0
		mut last := s.children.len - 1
		mut middle := last / 2
		for first <= last {
			// println('FIRST: $first, LAST: $last, LEN: $s.children.len-1')
			s1 := s.children[middle]
			if s1.end_pos < pos {
				first = middle + 1
			} else if s1.contains(pos) {
				return s1.innermost(pos)
			} else {
				last = middle - 1
			}
			middle = (first + last) / 2
			if first > last {
				break
			}
		}
		return s
	}
	// return none
	return s
}

[inline]
fn (s &Scope) contains(pos int) bool {
	return pos >= s.start_pos && pos <= s.end_pos
}

pub fn (sc &Scope) show(depth, max_depth int) string {
	mut out := ''
	mut indent := ''
	for _ in 0 .. depth * 4 {
		indent += ' '
	}
	out += '$indent# $sc.start_pos - $sc.end_pos\n'
	for _, obj in sc.objects {
		match obj {
			ConstField {
				out += '$indent  * const: $it.name - $it.typ\n'
			}
			Var {
				out += '$indent  * var: $it.name - $it.typ\n'
			}
			else {}
		}
	}
	if max_depth == 0 || depth < max_depth - 1 {
		for i, _ in sc.children {
			out += sc.children[i].show(depth + 1, max_depth)
		}
	}
	return out
}

pub fn (sc &Scope) str() string {
	return sc.show(0, 0)
}
