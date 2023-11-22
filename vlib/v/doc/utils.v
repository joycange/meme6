module doc

import strings
import v.ast
import v.token

// merge_comments merges all the comment contents into a single text.
pub fn merge_comments(comments []ast.Comment) string {
	mut res := []string{}
	for comment in comments {
		res << comment.text.trim_left('\x01')
	}
	return res.join('\n')
}

// ast_comment_to_doc_comment converts an `ast.Comment` node type to a `DocComment`
pub fn ast_comment_to_doc_comment(ast_node ast.Comment) DocComment {
	text := ast_node.text // TODO .trim_left('\x01') // BUG why are this byte here in the first place?
	return DocComment{
		text: text
		is_multi: ast_node.is_multi
		pos: token.Pos{
			line_nr: ast_node.pos.line_nr
			col: 0 // ast_node.pos.pos - ast_node.text.len
			len: text.len
		}
	}
}

// ast_comments_to_doc_comments converts an array of `ast.Comment` nodes to
// an array of `DocComment` nodes
pub fn ast_comments_to_doc_comments(ast_nodes []ast.Comment) []DocComment {
	mut doc_comments := []DocComment{len: ast_nodes.len}
	for ast_comment in ast_nodes {
		doc_comments << ast_comment_to_doc_comment(ast_comment)
	}
	return doc_comments
}

// merge_doc_comments merges all the comments starting from
// the last up to the first item of the array.
pub fn merge_doc_comments(comments []DocComment) string {
	if comments.len == 0 {
		return ''
	}
	mut comment := ''
	mut next_on_newline := true
	for i, cmt in comments {
		if cmt.is_multi {
			// /**/ comments are deliberately NOT supported as vdoc comments, ignore them.
			continue
		}
		if next_comment := comments[i + 1] {
			if next_comment.pos.line_nr > cmt.pos.line_nr + 1 {
				// Don't add comments that are not part of a contiguous block into comment.
				comment = ''
				continue
			}
		}
		mut is_codeblock := false
		line_loop: for line in cmt.text.split_into_lines() {
			l := line.trim_left('\x01').trim_space()
			if is_codeblock {
				comment += l + '\n'
				continue
			}
			if l.starts_with('```') {
				if !is_codeblock {
					comment += '\n'
				}
				comment += l + '\n'
				is_codeblock = !is_codeblock
				next_on_newline = true
				continue
			}
			if l == '' {
				comment += if comment.ends_with('\n') { '\n' } else { '\n\n' }
				next_on_newline = true
				continue
			}
			line_before_spaces := l.before(' ')
			if (l.starts_with('|') && l.ends_with('|')) || l.starts_with('- ')
				|| (l.starts_with('#') && line_before_spaces.count('#') == line_before_spaces.len) {
				comment += l + '\n'
				next_on_newline = true
				continue
			}
			// Use own paragraph for "highlight" comments.
			ll := l.to_lower()
			for word in ['note:', 'fixme:', 'todo:'] {
				if ll.starts_with(word) {
					comment += '\n\n${word.title()}${l[word.len..]}'
					continue line_loop
				}
			}
			line_no_spaces := l.replace(' ', '')
			for ch in ['-', '=', '*', '_', '~'] {
				if line_no_spaces.starts_with(ch.repeat(3))
					&& line_no_spaces.count(ch) == line_no_spaces.len {
					comment += '\n' + l + '\n'
					next_on_newline = true
					continue line_loop
				}
			}
			if !next_on_newline {
				comment += ' '
			}
			comment += l
			next_on_newline = false
		}
	}
	return comment
}

// stmt_signature returns the signature of a given `ast.Stmt` node.
pub fn (mut d Doc) stmt_signature(stmt ast.Stmt) string {
	match stmt {
		ast.Module {
			return 'module ${stmt.name}'
		}
		ast.FnDecl {
			return d.table.stringify_fn_decl(&stmt, d.fmt.cur_mod, d.fmt.mod2alias)
		}
		else {
			d.fmt.out = strings.new_builder(1000)
			d.fmt.stmt(stmt)
			return d.fmt.out.str().trim_space()
		}
	}
}

// stmt_name returns the name of a given `ast.Stmt` node.
pub fn (d Doc) stmt_name(stmt ast.Stmt) string {
	match stmt {
		ast.StructDecl, ast.EnumDecl, ast.InterfaceDecl {
			return stmt.name
		}
		ast.FnDecl {
			if stmt.is_static_type_method {
				return stmt.name.replace('__static__', '.')
			} else {
				return stmt.name
			}
		}
		ast.TypeDecl {
			match stmt {
				ast.FnTypeDecl, ast.AliasTypeDecl, ast.SumTypeDecl { return stmt.name }
			}
		}
		ast.ConstDecl {
			return ''
		} // leave it blank
		else {
			return ''
		}
	}
}

// stmt_pub returns a boolean if a given `ast.Stmt` node
// is exposed to the public.
pub fn (d Doc) stmt_pub(stmt ast.Stmt) bool {
	match stmt {
		ast.FnDecl, ast.StructDecl, ast.EnumDecl, ast.InterfaceDecl, ast.ConstDecl {
			return stmt.is_pub
		}
		ast.TypeDecl {
			match stmt {
				ast.FnTypeDecl, ast.AliasTypeDecl, ast.SumTypeDecl { return stmt.is_pub }
			}
		}
		else {
			return false
		}
	}
}

// type_to_str is a wrapper function around `fmt.ast.type_to_str`.
pub fn (mut d Doc) type_to_str(typ ast.Type) string {
	// why is it the default behaviour of ast.type_to_str
	// to convert math.bits.Type to bits.Type?
	d.table.cmod_prefix = d.orig_mod_name + '.'
	return d.fmt.table.type_to_str(typ).all_after('&')
}

// expr_typ_to_string has the same function as `Doc.typ_to_str`
// but for `ast.Expr` nodes. The checker will check first the
// node and it executes the `type_to_str` method.
pub fn (mut d Doc) expr_typ_to_string(mut expr ast.Expr) string {
	expr_typ := d.checker.expr(mut expr)
	return d.type_to_str(expr_typ)
}
