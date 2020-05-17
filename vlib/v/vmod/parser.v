module vmod
import os

enum TokenKind {
    module_keyword 
    field_key
    lcbr 
    rcbr 
    labr 
    rabr 
    comma 
    colon 
    eof 
    str 
    ident
}

pub struct Manifest {
pub mut:
    name string
    version string
	description string
    dependencies []string
    license string
    repo_url string
    author string
}

struct Scanner {
mut:
    pos int
    text string
    inside_text bool
    started bool
    tokens []Token = []Token{}
}

struct Parser {
mut: 
    file_path string
    scanner Scanner
}

struct Token {
    typ TokenKind
    val string
}

pub fn from_file(vmod_path string) ?Manifest {
    if !os.exists(vmod_path) {
        return error('v.mod: v.mod file not found.')
    }

    contents := os.read_file(vmod_path) or {
        panic('v.mod: cannot parse v.mod')
    }

    return decode(contents)
}

pub fn decode(contents string) ?Manifest {
    mut parser := Parser{
        scanner: Scanner{
            pos: 0,
            text: contents
        }
    }

    return parser.parse()
}

fn (mut s Scanner) tokenize(t_type TokenKind, val string) {
    s.tokens << Token{t_type, val}
}

fn (mut s Scanner) skip_whitespace() {
	for s.pos < s.text.len && s.text[s.pos].is_space() {
		s.pos++
	}
}

fn is_name_alpha(chr byte) bool {
    return chr.is_letter() || chr == `_`
}

fn (mut s Scanner) create_string() string {
    mut str := ''

    for s.text[s.pos] != `\'` {
        str += s.text[s.pos].str()
        s.pos++
    }
    return str
}

fn (mut s Scanner) create_ident() string {
    mut text := ''

    for is_name_alpha(s.text[s.pos]) {
        text += s.text[s.pos].str()
        s.pos++
    }

    return text
}

fn (s Scanner) peek_char(c byte) bool {
    return s.pos-1 < s.text.len && s.text[s.pos-1] == c
}

fn (mut s Scanner) scan_all() {
    for s.pos < s.text.len {
        c := s.text[s.pos]

        if c.is_space() || c == `\\` {
            s.pos++
            continue
        }

        if is_name_alpha(c) {
            name := s.create_ident()

            if name == 'Module' {
                s.tokenize(.module_keyword, name)
                s.pos++
                continue
            } else if s.text[s.pos] == `:` {
                s.tokenize(.field_key, name + ':')
                s.pos += 2
                continue
            } else {
                s.tokenize(.ident, name)
                s.pos++
                continue
            }
        }

        if c == `\'` && !s.peek_char(`\\`) {
            s.pos++
            str := s.create_string()
            s.tokenize(.str, str)
            s.pos++
            continue
        }

        match c {
            `{` { s.tokenize(.lcbr, c.str()) }
            `}` { s.tokenize(.rcbr, c.str()) }
            `[` { s.tokenize(.labr, c.str()) }
            `]` { s.tokenize(.rabr, c.str()) }
            `:` { s.tokenize(.colon, c.str()) }
            `,` { s.tokenize(.comma, c.str()) }
            else { s.tokenize(.eof, 'eof') }
        }

        s.pos++
    }
}

fn get_array_content(tokens []Token, st_idx int) ?([]string, int) {
    mut vals := []string{}
    mut idx := st_idx

    if tokens[idx].typ != .labr {
        return error('vmod: not a valid array')
    }

    idx++

    for {
        tok := tokens[idx]
        match tok.typ {
            .str {
                vals << tok.val

                if tokens[idx+1].typ !in [.comma, .rabr] {
                    return error('vmod: invalid separator "${tokens[idx+1].val}"')
                }

                idx += if tokens[idx+1].typ == .comma { 2 } else { 1 }
            }
            .rabr {
                idx++
                break
            }
            else { 
                return error('vmod: invalid token "$tok.val"') 
            }
        }
    }

    return vals, idx
}

fn (mut p Parser) parse() ?Manifest {
    p.scanner.scan_all()
    tokens := p.scanner.tokens
    mut mn := Manifest{}
    err_label := 'vmod:'

    if tokens[0].typ != .module_keyword {
        panic('not a valid v.mod')
    }

    mut i := 1
    for i < tokens.len {
        tok := tokens[i]
        match tok.typ {
            .lcbr { 
                if tokens[i+1].typ !in [.field_key, .rcbr] {
                    return error('$err_label invalid content after opening brace')
                }
                i++
                continue 
            }
            .rcbr { break }
            .field_key { 
                field_name := tok.val.trim_right(':')
                if tokens[i+1].typ !in [.str, .labr] {
                    return error('$err_label value of field "$field_name" must be either string or an array of strings')
                }
                
                field_value := tokens[i+1].val
                match field_name {
                    'name' { mn.name = field_value }
                    'version' { mn.version = field_value }
                    'license' { mn.license = field_value }
                    'repo_url' { mn.repo_url = field_value }
					'description' { mn.description = field_value }
                    'author' { mn.author = field_value }
                    'dependencies' { 
                        deps, idx := get_array_content(tokens, i + 1) or {
                            return error(err)
                        }
                        mn.dependencies = deps
                        i = idx
                        continue
                    }
                    else {
                        // Ignore the field?
                        // return error('$err_label invalid field "$field_name"')
                    }
                }

                i += 2
                continue
            }
            .comma { 
                if tokens[i-1].typ !in [.str, .rabr] || tokens[i+1].typ != .field_key {
                    return error('$err_label invalid comma placement')
                }

                i++
                continue
            }
            else {
                return error('$err_label invalid token "$tok.val"')
            }
        }
    }

    return mn
}