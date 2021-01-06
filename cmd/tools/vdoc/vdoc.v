module main

import markdown
import net
import net.urllib
import os
import os.cmdline
import time
import strings
import sync
import runtime
import v.doc
import v.scanner
import v.table
import v.token
import v.vmod
import v.pref
import json
import io

enum HighlightTokenTyp {
	unone
	boolean
	builtin
	char
	comment
	function
	keyword
	name
	number
	operator
	punctuation
	string
	symbol
}

const (
	css_js_assets   = ['doc.css', 'normalize.css', 'doc.js', 'dark-mode.js']
	allowed_formats = ['md', 'markdown', 'json', 'text', 'stdout', 'html', 'htm']
	res_path        = os.resource_abs_path('resources')
	favicons_path   = os.join_path(res_path, 'favicons')
	vexe            = pref.vexe_path()
	vroot           = os.dir(vexe)
	html_content    = '<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="UTF-8">
		<meta http-equiv="x-ua-compatible" content="IE=edge" />
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title>{{ title }} | vdoc</title>
		<link rel="preconnect" href="https://fonts.gstatic.com">
		<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
		<link href="https://fonts.googleapis.com/css2?family=Work+Sans:wght@400;500;600&display=swap" rel="stylesheet">
		<link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">
		<link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png">
		<link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png">
		<link rel="manifest" href="site.webmanifest">
		<link rel="mask-icon" href="safari-pinned-tab.svg" color="#5bbad5">
		<meta name="msapplication-TileColor" content="#da532c">
		<meta name="theme-color" content="#ffffff">
		{{ head_assets }}
	</head>
	<body>
		<div id="page">
			<header class="doc-nav hidden">
				<div class="heading-container">
					<div class="heading">
						<input type="text" id="search" placeholder="Search... (beta)" autocomplete="off">
						<div class="module">{{ head_name }}</div>
						<div class="toggle-version-container">
							<span>{{ version }}</span>
							<div id="dark-mode-toggle" role="switch" aria-checked="false" aria-label="Toggle dark mode">{{ light_icon }}{{ dark_icon }}</div>
						</div>
						{{ menu_icon }}
					</div>
				</div>
				<nav class="search"></nav>
				<nav class="content hidden">
					<ul>
						{{ toc_links }}
					</ul>
				</nav>
			</header>
			<div class="doc-scrollview">
				<div class="doc-container">
					<div class="doc-content">
{{ contents }}
						<div class="footer">
							{{ footer_content }}
						</div>
					</div>
					{{ right_content }}
				</div>
			</div>
		</div>
		{{ footer_assets }}
		<script async src="search_index.js" type="text/javascript"></script>
	</body>
</html>'
	tabs            = ['\t\t', '\t\t\t\t\t\t', '\t\t\t\t\t\t\t']
)

enum OutputType {
	unset
	html
	markdown
	json
	plaintext
	stdout
}

struct DocConfig {
mut:
	is_local            bool
	local_filename      string
	local_pos           int
	pub_only            bool = true
	show_loc            bool // for plaintext
	serve_http          bool // for html
	is_multi            bool
	is_vlib             bool
	is_verbose          bool
	include_readme      bool
	include_examples    bool = true
	open_docs           bool
	server_port         int = 8046
	inline_assets       bool
	no_timestamp        bool
	output_path         string
	input_path          string
	symbol_name         string
	output_type         OutputType = .unset
	docs                []doc.Doc
	manifest            vmod.Manifest
	assets              map[string]string
	search_index        []string
	search_data         []SearchResult
	search_module_index []string // search results are split into a module part and the rest
	search_module_data  []SearchModuleResult
}

struct SearchModuleResult {
	description string
	link        string
}

struct SearchResult {
	prefix      string
	badge       string
	description string
	link        string
}

struct ParallelDoc {
	d doc.Doc
	i int
}

[inline]
fn slug(title string) string {
	return title.replace(' ', '-')
}

[inline]
fn open_url(url string) {
	$if windows {
		os.system('start $url')
	}
	$if macos {
		os.system('open $url')
	}
	$if linux {
		os.system('xdg-open $url')
	}
}

fn (mut cfg DocConfig) serve_html() {
	cfg.render_static()
	docs := cfg.render()
	dkeys := docs.keys()
	if dkeys.len < 1 {
		eprintln('no documentation created, the module has no `pub` functions')
		exit(1)
	}
	def_name := docs.keys()[0]
	server_url := 'http://localhost:' + cfg.server_port.str()
	server := net.listen_tcp(cfg.server_port) or { panic(err) }
	println('Serving docs on: $server_url')
	if cfg.open_docs {
		open_url(server_url)
	}
	content_type := match cfg.output_type {
		.html { 'text/html' }
		.markdown { 'text/markdown' }
		.json { 'application/json' }
		else { 'text/plain' }
	}
	server_context := VdocHttpServerContext{
		docs: docs
		content_type: content_type
		default_filename: def_name
	}
	for {
		mut conn := server.accept() or {
			server.close() or { }
			panic(err)
		}
		handle_http_connection(mut conn, server_context)
		conn.close() or { eprintln('error closing the connection: $err') }
	}
}

struct VdocHttpServerContext {
	docs             map[string]string
	content_type     string
	default_filename string
}

fn handle_http_connection(mut con net.TcpConn, ctx &VdocHttpServerContext) {
	mut reader := io.new_buffered_reader(reader: io.make_reader(con))
	first_line := reader.read_line() or {
		send_http_response(mut con, 501, ctx.content_type, 'bad request')
		return
	}
	request_parts := first_line.split(' ')
	if request_parts.len != 3 {
		send_http_response(mut con, 501, ctx.content_type, 'bad request')
		return
	}
	urlpath := request_parts[1]
	filename := if urlpath == '/' {
		ctx.default_filename.trim_left('/')
	} else {
		urlpath.trim_left('/')
	}
	if ctx.docs[filename].len == 0 {
		send_http_response(mut con, 404, ctx.content_type, 'file not found')
		return
	}
	send_http_response(mut con, 200, ctx.content_type, ctx.docs[filename])
}

fn send_http_response(mut con net.TcpConn, http_code int, content_type string, html string) {
	content_length := html.len.str()
	shttp_code := http_code.str()
	mut http_response := strings.new_builder(20000)
	http_response.write('HTTP/1.1 ')
	http_response.write(shttp_code)
	http_response.write(' OK\r\n')
	http_response.write('Server: VDoc\r\n')
	http_response.write('Content-Type: ')
	http_response.write(content_type)
	http_response.write('\r\n')
	http_response.write('Content-Length: ')
	http_response.write(content_length)
	http_response.write('\r\n')
	http_response.write('Connection: close\r\n')
	http_response.write('\r\n')
	http_response.write(html)
	sresponse := http_response.str()
	con.write_str(sresponse) or { eprintln('error sending http response: $err') }
}

fn get_src_link(repo_url string, file_name string, line_nr int) string {
	mut url := urllib.parse(repo_url) or { return '' }
	if url.path.len <= 1 || file_name.len == 0 {
		return ''
	}
	url.path = url.path.trim_right('/') + match url.host {
		'github.com' { '/blob/master/$file_name' }
		'gitlab.com' { '/-/blob/master/$file_name' }
		'git.sir.ht' { '/tree/master/$file_name' }
		else { '' }
	}
	if url.path == '/' {
		return ''
	}
	url.fragment = 'L$line_nr'
	return url.str()
}

fn js_compress(str string) string {
	mut js := strings.new_builder(200)
	lines := str.split_into_lines()
	rules := [') {', ' = ', ', ', '{ ', ' }', ' (', '; ', ' + ', ' < ', ' - ', ' || ', ' var',
		': ', ' >= ', ' && ', ' else if', ' === ', ' !== ', ' else ']
	clean := ['){', '=', ',', '{', '}', '(', ';', '+', '<', '-', '||', 'var', ':', '>=', '&&',
		'else if', '===', '!==', 'else']
	for line in lines {
		mut trimmed := line.trim_space()
		if trimmed.starts_with('//') || (trimmed.starts_with('/*') && trimmed.ends_with('*/')) {
			continue
		}
		for i in 0 .. rules.len - 1 {
			trimmed = trimmed.replace(rules[i], clean[i])
		}
		js.write(trimmed)
	}
	js_str := js.str()
	js.free()
	return js_str
}

fn escape(str string) string {
	return str.replace_each(['"', '\\"', '\r\n', '\\n', '\n', '\\n', '\t', '\\t'])
}

fn (cfg DocConfig) gen_json(idx int) string {
	dcs := cfg.docs[idx]
	mut jw := strings.new_builder(200)
	comments := if cfg.include_examples { dcs.head.merge_comments() } else { dcs.head.merge_comments_without_examples() }
	jw.write('{"module_name":"$dcs.head.name","description":"${escape(comments)}","contents":')
	jw.write(json.encode(dcs.contents.keys().map(dcs.contents[it])))
	jw.write(',"generator":"vdoc","time_generated":"$dcs.time_generated.str()"}')
	return jw.str()
}

fn html_highlight(code string, tb &table.Table) string {
	builtin := ['bool', 'string', 'i8', 'i16', 'int', 'i64', 'i128', 'byte', 'u16', 'u32', 'u64',
		'u128', 'rune', 'f32', 'f64', 'any_int', 'any_float', 'byteptr', 'voidptr', 'any']
	highlight_code := fn (tok token.Token, typ HighlightTokenTyp) string {
		lit := if typ in [.unone, .operator, .punctuation] {
			tok.kind.str()
		} else if typ == .string {
			"'$tok.lit'"
		} else if typ == .char {
			'`$tok.lit`'
		} else {
			tok.lit
		}
		return if typ in [.unone, .name] {
			lit
		} else {
			'<span class="token $typ">$lit</span>'
		}
	}
	mut s := scanner.new_scanner(code, .parse_comments, &pref.Preferences{})
	mut tok := s.scan()
	mut next_tok := s.scan()
	mut buf := strings.new_builder(200)
	mut i := 0
	for i < code.len {
		if i == tok.pos {
			mut tok_typ := HighlightTokenTyp.unone
			match tok.kind {
				.name {
					if tok.lit in builtin || tb.known_type(tok.lit) {
						tok_typ = .builtin
					} else if next_tok.kind == .lcbr {
						tok_typ = .symbol
					} else if next_tok.kind == .lpar {
						tok_typ = .function
					} else {
						tok_typ = .name
					}
				}
				.comment {
					tok_typ = .comment
				}
				.chartoken {
					tok_typ = .char
				}
				.string {
					tok_typ = .string
				}
				.number {
					tok_typ = .number
				}
				.key_true, .key_false {
					tok_typ = .boolean
				}
				.lpar, .lcbr, .rpar, .rcbr, .lsbr, .rsbr, .semicolon, .colon, .comma, .dot {
					tok_typ = .punctuation
				}
				else {
					if token.is_key(tok.lit) || token.is_decl(tok.kind) {
						tok_typ = .keyword
					} else if tok.kind == .decl_assign || tok.kind.is_assign() || tok.is_unary() ||
						tok.kind.is_relational() || tok.kind.is_infix() {
						tok_typ = .operator
					}
				}
			}
			buf.write(highlight_code(tok, tok_typ))
			if next_tok.kind != .eof {
				i = tok.pos + tok.len
				tok = next_tok
				next_tok = s.scan()
			} else {
				break
			}
		} else {
			buf.write_b(code[i])
			i++
		}
	}
	return buf.str()
}

fn doc_node_html(dd doc.DocNode, link string, head bool, include_examples bool, tb &table.Table) string {
	mut dnw := strings.new_builder(200)
	link_svg := '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M0 0h24v24H0z" fill="none"/><path d="M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z"/></svg>'
	head_tag := if head { 'h1' } else { 'h2' }
	comments := dd.merge_comments_without_examples()
	md_content := markdown.to_html(html_tag_escape(comments))
	hlighted_code := html_highlight(dd.content, tb)
	node_class := if dd.kind == .const_group { ' const' } else { '' }
	sym_name := get_sym_name(dd)
	mut node_id := get_node_id(dd)
	mut hash_link := if !head { ' <a href="#$node_id">#</a>' } else { '' }
	if head && is_module_readme(dd) {
		node_id = 'readme_$node_id'
		hash_link = ' <a href="#$node_id">#</a>'
	}
	dnw.writeln('${tabs[1]}<section id="$node_id" class="doc-node$node_class">')
	if dd.name.len > 0 {
		if dd.kind == .const_group {
			dnw.write('${tabs[2]}<div class="title"><$head_tag>$sym_name$hash_link</$head_tag>')
		} else {
			dnw.write('${tabs[2]}<div class="title"><$head_tag>$dd.kind $sym_name$hash_link</$head_tag>')
		}
		if link.len != 0 {
			dnw.write('<a class="link" rel="noreferrer" target="_blank" href="$link">$link_svg</a>')
		}
		dnw.write('</div>')
	}
	if !head && dd.content.len > 0 {
		dnw.writeln('<pre class="signature"><code>$hlighted_code</code></pre>')
	}
	// do not mess with md_content further, its formatting is important, just output it 1:1 !
	dnw.writeln('$md_content\n')
	// Write examples if any found
	examples := dd.examples()
	if include_examples && examples.len > 0 {
		example_title := if examples.len > 1 { 'Examples' } else { 'Example' }
		dnw.writeln('<section class="doc-node examples"><h4>$example_title</h4>')
		for example in examples {
			//hl_example := html_highlight(example, tb)
			dnw.writeln('<pre class="signature"><code class="example">$example</code></pre>')
		}
		dnw.writeln('</section>')
	}
	dnw.writeln('</section>')
	dnw_str := dnw.str()
	defer {
		dnw.free()
	}
	return dnw_str
}

fn html_tag_escape(str string) string {
	return str.replace_each(['<', '&lt;', '>', '&gt;'])
}

fn get_sym_name(dn doc.DocNode) string {
	sym_name := if dn.parent_name.len > 0 && dn.parent_name != 'void' {
		'($dn.parent_name) $dn.name'
	} else {
		dn.name
	}
	return sym_name
}

fn get_node_id(dn doc.DocNode) string {
	tag := if dn.parent_name.len > 0 && dn.parent_name != 'void' {
		'${dn.parent_name}.$dn.name'
	} else {
		dn.name
	}
	return slug(tag)
}

fn (cfg DocConfig) readme_idx() int {
	for i, dc in cfg.docs {
		if dc.head.name != 'README' {
			continue
		}
		return i
	}
	return -1
}

fn write_toc(dn doc.DocNode, mut toc strings.Builder) {
	mut toc_slug := if dn.name.len == 0 || dn.content.len == 0 { '' } else { slug(dn.name) }
	if toc_slug == '' && dn.children.len > 0 {
		if dn.children[0].name == '' {
			toc_slug = slug(dn.name)
		} else {
			toc_slug = slug(dn.name + '.' + dn.children[0].name)
		}
	}
	if is_module_readme(dn) {
		toc.write('<li class="open"><a href="#readme_$toc_slug">README</a>')
	} else if dn.name != 'Constants' {
		toc.write('<li class="open"><a href="#$toc_slug">$dn.kind $dn.name</a>')
		toc.writeln('        <ul>')
		for child in dn.children {
			cname := dn.name + '.' + child.name
			toc.writeln('<li><a href="#${slug(cname)}">$child.kind $child.name</a></li>')
		}
		toc.writeln('</ul>')
	} else {
		toc.write('<li class="open"><a href="#$toc_slug">$dn.name</a>')
	}
	toc.writeln('</li>')
}

fn (cfg DocConfig) write_content(cn &doc.DocNode, dcs &doc.Doc, mut hw strings.Builder) {
	base_dir := os.dir(os.real_path(cfg.input_path))
	file_path_name := if cfg.is_multi {
		cn.file_path.replace('$base_dir/', '')
	} else {
		os.file_name(cn.file_path)
	}
	src_link := get_src_link(cfg.manifest.repo_url, file_path_name, cn.pos.line)
	if cn.content.len != 0 || (cn.name == 'Constants') {
		hw.write(doc_node_html(cn, src_link, false, cfg.include_examples, dcs.table))
	}
	for child in cn.children {
		child_file_path_name := child.file_path.replace('$base_dir/', '')
		child_src_link := get_src_link(cfg.manifest.repo_url, child_file_path_name, child.pos.line)
		hw.write(doc_node_html(child, child_src_link, false, cfg.include_examples, dcs.table))
	}
}

fn (cfg DocConfig) gen_html(idx int) string {
	mut symbols_toc := strings.new_builder(200)
	mut modules_toc := strings.new_builder(200)
	mut contents := strings.new_builder(200)
	dcs := cfg.docs[idx]
	dcs_contents := dcs.contents.arr()
	// generate toc first
	contents.writeln(doc_node_html(dcs.head, '', true, cfg.include_examples, dcs.table))
	if is_module_readme(dcs.head) {
		write_toc(dcs.head, mut symbols_toc)
	}
	for cn in dcs_contents {
		cfg.write_content(&cn, &dcs, mut contents)
		write_toc(cn, mut symbols_toc)
	} // write head
	// write css
	version := if cfg.manifest.version.len != 0 { cfg.manifest.version } else { '' }
	header_name := if cfg.is_multi && cfg.docs.len > 1 {
		os.file_name(os.real_path(cfg.input_path))
	} else {
		dcs.head.name
	}
	// write nav1
	if cfg.is_multi || cfg.docs.len > 1 {
		mut submod_prefix := ''
		for i, doc in cfg.docs {
			if i - 1 >= 0 && doc.head.name.starts_with(submod_prefix + '.') {
				continue
			}
			names := doc.head.name.split('.')
			submod_prefix = if names.len > 1 { names[0] } else { doc.head.name }
			mut href_name := './${doc.head.name}.html'
			if (cfg.is_vlib && doc.head.name == 'builtin' && !cfg.include_readme) ||
				doc.head.name == 'README' {
				href_name = './index.html'
			} else if submod_prefix !in cfg.docs.map(it.head.name) {
				href_name = '#'
			}
			submodules := cfg.docs.filter(it.head.name.starts_with(submod_prefix + '.'))
			dropdown := if submodules.len > 0 { cfg.assets['arrow_icon'] } else { '' }
			active_class := if doc.head.name == dcs.head.name { ' active' } else { '' }
			modules_toc.write('<li class="open$active_class"><div class="menu-row">$dropdown<a href="$href_name">$submod_prefix</a></div>')
			for j, cdoc in submodules {
				if j == 0 {
					modules_toc.write('<ul>')
				}
				submod_name := cdoc.head.name.all_after(submod_prefix + '.')
				sub_selected_classes := if cdoc.head.name == dcs.head.name {
					' class="active"'
				} else {
					''
				}
				modules_toc.write('<li$sub_selected_classes><a href="./${cdoc.head.name}.html">$submod_name</a></li>')
				if j == submodules.len - 1 {
					modules_toc.write('</ul>')
				}
			}
			modules_toc.write('</li>')
		}
	}
	modules_toc_str := modules_toc.str()
	symbols_toc_str := symbols_toc.str()
	modules_toc.free()
	symbols_toc.free()
	return html_content.replace('{{ title }}', dcs.head.name).replace('{{ head_name }}',
		header_name).replace('{{ version }}', version).replace('{{ light_icon }}', cfg.assets['light_icon']).replace('{{ dark_icon }}',
		cfg.assets['dark_icon']).replace('{{ menu_icon }}', cfg.assets['menu_icon']).replace('{{ head_assets }}',
		if cfg.inline_assets {
		'\n${tabs[0]}<style>' + cfg.assets['doc_css'] + '</style>\n${tabs[0]}<style>' + cfg.assets['normalize_css'] +
			'</style>\n${tabs[0]}<script>' + cfg.assets['dark_mode_js'] + '</script>'
	} else {
		'\n${tabs[0]}<link rel="stylesheet" href="' + cfg.assets['doc_css'] + '" />\n${tabs[0]}<link rel="stylesheet" href="' +
			cfg.assets['normalize_css'] + '" />\n${tabs[0]}<script src="' + cfg.assets['dark_mode_js'] + '"></script>'
	}).replace('{{ toc_links }}', if cfg.is_multi || cfg.docs.len > 1 {
		modules_toc_str
	} else {
		symbols_toc_str
	}).replace('{{ contents }}', contents.str()).replace('{{ right_content }}', if cfg.is_multi &&
		cfg.docs.len > 1 && dcs.head.name != 'README' {
		'<div class="doc-toc"><ul>' + symbols_toc_str + '</ul></div>'
	} else {
		''
	}).replace('{{ footer_content }}', cfg.gen_footer_text(idx)).replace('{{ footer_assets }}',
		if cfg.inline_assets {
		'<script>' + cfg.assets['doc_js'] + '</script>'
	} else {
		'<script src="' + cfg.assets['doc_js'] + '"></script>'
	})
}

fn (cfg DocConfig) gen_plaintext(idx int) string {
	dcs := cfg.docs[idx]
	mut pw := strings.new_builder(200)
	pw.writeln('$dcs.head.content\n')
	comments := if cfg.include_examples { dcs.head.merge_comments() } else { dcs.head.merge_comments_without_examples() }
	if comments.trim_space().len > 0 && !cfg.pub_only {
		pw.writeln(comments.split_into_lines().map('    ' + it).join('\n'))
	}
	cfg.write_plaintext_content(dcs.contents.arr(), mut pw)
	return pw.str()
}

fn (cfg DocConfig) write_plaintext_content(contents []doc.DocNode, mut pw strings.Builder) {
	for cn in contents {
		if cn.content.len > 0 {
			pw.writeln(cn.content)
			if cn.comments.len > 0 && !cfg.pub_only {
				comments := if cfg.include_examples { cn.merge_comments() } else { cn.merge_comments_without_examples() }
				pw.writeln(comments.trim_space().split_into_lines().map('    ' + it).join('\n'))
			}
			if cfg.show_loc {
				pw.writeln('Location: $cn.file_path:$cn.pos.line\n')
			}
		}
		cfg.write_plaintext_content(cn.children, mut pw)
	}
}

fn (cfg DocConfig) gen_markdown(idx int, with_toc bool) string {
	dcs := cfg.docs[idx]
	mut hw := strings.new_builder(200)
	mut cw := strings.new_builder(200)
	hw.writeln('# $dcs.head.content\n')
	if dcs.head.comments.len > 0 {
		comments := if cfg.include_examples { dcs.head.merge_comments() } else { dcs.head.merge_comments_without_examples() }
		hw.writeln('$comments\n')
	}
	if with_toc {
		hw.writeln('## Contents')
	}
	cfg.write_markdown_content(dcs.contents.arr(), mut cw, mut hw, 0, with_toc)
	footer_text := cfg.gen_footer_text(idx)
	cw.writeln('#### $footer_text')
	return hw.str() + '\n' + cw.str()
}

fn (cfg DocConfig) write_markdown_content(contents []doc.DocNode, mut cw strings.Builder, mut hw strings.Builder, indent int, with_toc bool) {
	for cn in contents {
		if with_toc && cn.name.len > 0 {
			hw.writeln(' '.repeat(2 * indent) + '- [#$cn.name](${slug(cn.name)})')
			cw.writeln('## $cn.name')
		}
		if cn.content.len > 0 {
			comments := cn.merge_comments_without_examples()
			cw.writeln('```v\n$cn.content\n```\n$comments\n')
			// Write examples if any found
			examples := cn.examples()
			if cfg.include_examples && examples.len > 0 {
				example_title := if examples.len > 1 { 'Examples' } else { 'Example' }
				cw.writeln('$example_title\n```v\n')
				for example in examples {
					cw.writeln('$example\n')
				}
				cw.writeln('```\n')
			}
			cw.writeln('[\[Return to contents\]](#Contents)\n')
		}
		cfg.write_markdown_content(cn.children, mut cw, mut hw, indent + 1, with_toc)
	}
}

fn (cfg DocConfig) gen_footer_text(idx int) string {
	current_doc := cfg.docs[idx]
	footer_text := 'Powered by vdoc.'
	if cfg.no_timestamp {
		return footer_text
	}
	generated_time := current_doc.time_generated
	time_str := '$generated_time.day $generated_time.smonth() $generated_time.year $generated_time.hhmmss()'
	return '$footer_text Generated on: $time_str'
}

fn (cfg DocConfig) render_doc(doc doc.Doc, i int) (string, string) {
	name := cfg.get_file_name(doc.head.name)
	output := match cfg.output_type {
		.html { cfg.gen_html(i) }
		.markdown { cfg.gen_markdown(i, true) }
		.json { cfg.gen_json(i) }
		else { cfg.gen_plaintext(i) }
	}
	return name, output
}

// get_file_name returns the final file name from a module name
fn (cfg DocConfig) get_file_name(mod string) string {
	mut name := mod
	// since builtin is generated first, ignore it
	if (cfg.is_vlib && mod == 'builtin' && !cfg.include_readme) || mod == 'README' {
		name = 'index'
	} else if !cfg.is_multi && !os.is_dir(cfg.output_path) {
		name = os.file_name(cfg.output_path)
	}
	name = name + match cfg.output_type {
		.html { '.html' }
		.markdown { '.md' }
		.json { '.json' }
		else { '.txt' }
	}
	return name
}

fn (cfg DocConfig) work_processor(mut work sync.Channel, mut wg sync.WaitGroup) {
	for {
		mut pdoc := ParallelDoc{}
		if !work.pop(&pdoc) {
			break
		}
		file_name, content := cfg.render_doc(pdoc.d, pdoc.i)
		output_path := os.join_path(cfg.output_path, file_name)
		println('Generating $output_path')
		os.write_file(output_path, content)
	}
	wg.done()
}

fn (cfg DocConfig) render_parallel() {
	vjobs := runtime.nr_jobs()
	mut work := sync.new_channel<ParallelDoc>(cfg.docs.len)
	mut wg := sync.new_waitgroup()
	for i in 0 .. cfg.docs.len {
		p_doc := ParallelDoc{cfg.docs[i], i}
		work.push(&p_doc)
	}
	work.close()
	wg.add(vjobs)
	for _ in 0 .. vjobs {
		go cfg.work_processor(mut work, mut wg)
	}
	wg.wait()
}

fn (cfg DocConfig) render() map[string]string {
	mut docs := map[string]string{}
	for i, doc in cfg.docs {
		name, output := cfg.render_doc(doc, i)
		docs[name] = output.trim_space()
	}
	cfg.vprintln('Rendered: ' + docs.keys().str())
	return docs
}

fn (mut cfg DocConfig) collect_search_index() {
	if cfg.output_type != .html {
		return
	}
	for doc in cfg.docs {
		mod := doc.head.name
		cfg.search_module_index << mod
		comments := if cfg.include_examples { doc.head.merge_comments() } else { doc.head.merge_comments_without_examples() }
		cfg.search_module_data << SearchModuleResult{
			description: trim_doc_node_description(comments)
			link: cfg.get_file_name(mod)
		}
		for _, dn in doc.contents {
			cfg.create_search_results(mod, dn)
		}
	}
}

fn (mut cfg DocConfig) create_search_results(mod string, dn doc.DocNode) {
	if dn.kind == .const_group {
		return
	}
	comments := if cfg.include_examples { dn.merge_comments() } else { dn.merge_comments_without_examples() }
	dn_description := trim_doc_node_description(comments)
	cfg.search_index << dn.name
	cfg.search_data << SearchResult{
		prefix: if dn.parent_name != '' {
			'$dn.kind ($dn.parent_name)'
		} else {
			'$dn.kind '
		}
		description: dn_description
		badge: mod
		link: cfg.get_file_name(mod) + '#' + get_node_id(dn)
	}
	for child in dn.children {
		cfg.create_search_results(mod, child)
	}
}

fn trim_doc_node_description(description string) string {
	mut dn_description := description.replace_each(['\r\n', '\n', '"', '\\"'])
	// 80 is enough to fill one line
	if dn_description.len > 80 {
		dn_description = dn_description[..80]
	}
	if '\n' in dn_description {
		dn_description = dn_description.split('\n')[0]
	}
	// if \ is last character, it ends with \" which leads to a JS error
	if dn_description.ends_with('\\') {
		dn_description = dn_description.trim_right('\\')
	}
	return dn_description
}

fn (cfg DocConfig) render_search_index() {
	mut js_search_index := strings.new_builder(200)
	mut js_search_data := strings.new_builder(200)
	js_search_index.write('var searchModuleIndex = [')
	js_search_data.write('var searchModuleData = [')
	for i, title in cfg.search_module_index {
		data := cfg.search_module_data[i]
		js_search_index.write('"$title",')
		js_search_data.write('["$data.description","$data.link"],')
	}
	js_search_index.writeln('];')
	js_search_index.write('var searchIndex = [')
	js_search_data.writeln('];')
	js_search_data.write('var searchData = [')
	for i, title in cfg.search_index {
		data := cfg.search_data[i]
		js_search_index.write('"$title",')
		// array instead of object to reduce file size
		js_search_data.write('["$data.badge","$data.description","$data.link","$data.prefix"],')
	}
	js_search_index.writeln('];')
	js_search_data.writeln('];')
	out_file_path := os.join_path(cfg.output_path, 'search_index.js')
	os.write_file(out_file_path, js_search_index.str() + js_search_data.str())
}

fn (mut cfg DocConfig) render_static() {
	if cfg.output_type != .html {
		return
	}
	cfg.assets = {
		'doc_css':       cfg.get_resource(css_js_assets[0], true)
		'normalize_css': cfg.get_resource(css_js_assets[1], true)
		'doc_js':        cfg.get_resource(css_js_assets[2], !cfg.serve_http)
		'dark_mode_js':  cfg.get_resource(css_js_assets[3], !cfg.serve_http)
		'light_icon':    cfg.get_resource('light.svg', true)
		'dark_icon':     cfg.get_resource('dark.svg', true)
		'menu_icon':     cfg.get_resource('menu.svg', true)
		'arrow_icon':    cfg.get_resource('arrow.svg', true)
	}
}

fn (cfg DocConfig) get_readme(path string) string {
	mut fname := ''
	for name in ['readme', 'README'] {
		if os.exists(os.join_path(path, '${name}.md')) {
			fname = name
			break
		}
	}
	if fname == '' {
		return ''
	}
	readme_path := os.join_path(path, '${fname}.md')
	cfg.vprintln('Reading README file from $readme_path')
	readme_contents := os.read_file(readme_path) or { '' }
	return readme_contents
}

fn (cfg DocConfig) emit_generate_err(err string, errcode int) {
	mut err_msg := err
	if errcode == 1 {
		mod_list := get_modules_list(cfg.input_path, []string{})
		println('Available modules:\n==================')
		for mod in mod_list {
			println(mod.all_after('vlib/').all_after('modules/').replace('/', '.'))
		}
		err_msg += ' Use the `-m` flag when generating docs from a directory that has multiple modules.'
	}
	eprintln(err_msg)
}

fn (mut cfg DocConfig) generate_docs_from_file() {
	if cfg.output_path.len == 0 {
		if cfg.output_type == .unset {
			cfg.output_type = .stdout
		} else {
			cfg.vprintln('No output path has detected. Using input path instead.')
			cfg.output_path = cfg.input_path
		}
	} else if cfg.output_type == .unset {
		cfg.vprintln('Output path detected. Identifying output type..')
		ext := os.file_ext(cfg.output_path)
		cfg.set_output_type_from_str(ext.all_after('.'))
	}
	if cfg.include_readme && cfg.output_type !in [.html, .stdout] {
		eprintln('vdoc: Including README.md for doc generation is supported on HTML output, or when running directly in the terminal.')
		exit(1)
	}
	dir_path := if cfg.is_vlib {
		vroot
	} else if os.is_dir(cfg.input_path) {
		cfg.input_path
	} else {
		os.dir(cfg.input_path)
	}
	manifest_path := os.join_path(dir_path, 'v.mod')
	if os.exists(manifest_path) {
		cfg.vprintln('Reading v.mod info from $manifest_path')
		if manifest := vmod.from_file(manifest_path) {
			cfg.manifest = manifest
		}
	}
	if cfg.include_readme {
		readme_contents := cfg.get_readme(dir_path)
		comment := doc.DocComment{
			text: readme_contents
		}
		if cfg.output_type == .stdout {
			println(markdown.to_plain(readme_contents))
		} else if cfg.output_type == .html && cfg.is_multi {
			cfg.docs << doc.Doc{
				head: doc.DocNode{
					name: 'README'
					comments: [comment]
				}
				time_generated: time.now()
			}
		}
	}
	dirs := if cfg.is_multi {
		get_modules_list(cfg.input_path, []string{})
	} else {
		[cfg.input_path]
	}
	is_local_and_single := cfg.is_local && !cfg.is_multi
	for dirpath in dirs {
		mut dcs := doc.Doc{}
		cfg.vprintln('Generating docs for $dirpath')
		if is_local_and_single {
			dcs = doc.generate_with_pos(dirpath, cfg.local_filename, cfg.local_pos) or {
				cfg.emit_generate_err(err, errcode)
				exit(1)
			}
		} else {
			dcs = doc.generate(dirpath, cfg.pub_only, true) or {
				cfg.emit_generate_err(err, errcode)
				exit(1)
			}
		}
		if dcs.contents.len == 0 {
			continue
		}
		if !is_local_and_single {
			if cfg.is_multi || (!cfg.is_multi && cfg.include_readme) {
				readme_contents := cfg.get_readme(dirpath)
				comment := doc.DocComment{
					text: readme_contents
				}
				dcs.head.comments = [comment]
			}
			if cfg.pub_only {
				for name, dc in dcs.contents {
					dcs.contents[name].content = dc.content.all_after('pub ')
					for i, cc in dc.children {
						dcs.contents[name].children[i].content = cc.content.all_after('pub ')
					}
				}
			}
			if !cfg.is_multi && cfg.symbol_name.len > 0 {
				if cfg.symbol_name in dcs.contents {
					for _, c in dcs.contents[cfg.symbol_name].children {
						dcs.contents[c.name] = c
					}
				}
			}
		}
		cfg.docs << dcs
	}
	if cfg.is_vlib {
		mut docs := cfg.docs.filter(it.head.name == 'builtin')
		docs << cfg.docs.filter(it.head.name != 'builtin')
		cfg.docs = docs
	}
	if cfg.serve_http {
		cfg.serve_html()
		return
	}
	cfg.vprintln('Rendering docs...')
	if cfg.output_path.len == 0 || cfg.output_path == 'stdout' {
		cfg.render_static()
		outputs := cfg.render()
		if outputs.len == 0 {
			println('No documentation for $dirs')
		} else {
			first := outputs.keys()[0]
			println(outputs[first])
		}
	} else {
		if !os.is_dir(cfg.output_path) {
			cfg.output_path = os.real_path('.')
		}
		if !os.exists(cfg.output_path) {
			os.mkdir(cfg.output_path) or { panic(err) }
		}
		if cfg.is_multi {
			cfg.output_path = os.join_path(cfg.output_path, '_docs')
			if !os.exists(cfg.output_path) {
				os.mkdir(cfg.output_path) or { panic(err) }
			} else {
				for fname in css_js_assets {
					os.rm(os.join_path(cfg.output_path, fname))
				}
			}
		}
		cfg.render_static()
		cfg.render_parallel()
		println('Creating search index...')
		cfg.collect_search_index()
		cfg.render_search_index()
		// move favicons to target directory
		println('Copying favicons...')
		favicons := os.ls(favicons_path) or { panic(err) }
		for favicon in favicons {
			favicon_path := os.join_path(favicons_path, favicon)
			destination_path := os.join_path(cfg.output_path, favicon)
			os.cp(favicon_path, destination_path)
		}
	}
}

fn (mut cfg DocConfig) set_output_type_from_str(format string) {
	match format {
		'htm', 'html' { cfg.output_type = .html }
		'md', 'markdown' { cfg.output_type = .markdown }
		'json' { cfg.output_type = .json }
		'stdout' { cfg.output_type = .stdout }
		else { cfg.output_type = .plaintext }
	}
	cfg.vprintln('Setting output type to "$cfg.output_type"')
}

fn (cfg DocConfig) vprintln(str string) {
	if cfg.is_verbose {
		println('vdoc: $str')
	}
}

fn get_ignore_paths(path string) ?[]string {
	ignore_file_path := os.join_path(path, '.vdocignore')
	ignore_content := os.read_file(ignore_file_path) or {
		return error_with_code('ignore file not found.', 1)
	}
	mut res := []string{}
	if ignore_content.trim_space().len > 0 {
		rules := ignore_content.split_into_lines().map(it.trim_space())
		mut final := []string{}
		for rule in rules {
			if rule.contains('*.') || rule.contains('**') {
				println('vdoc: Wildcards in ignore rules are not allowed for now.')
				continue
			}
			final << rule
		}
		res = final.map(os.join_path(path, it.trim_right('/')))
	} else {
		mut dirs := os.ls(path) or { return []string{} }
		res = dirs.map(os.join_path(path, it)).filter(os.is_dir(it))
	}
	return res.map(it.replace('/', os.path_separator))
}

fn is_included(path string, ignore_paths []string) bool {
	if path.len == 0 {
		return true
	}
	for ignore_path in ignore_paths {
		if ignore_path !in path {
			continue
		}
		return false
	}
	return true
}

fn get_modules_list(path string, ignore_paths2 []string) []string {
	files := os.ls(path) or { return []string{} }
	mut ignore_paths := get_ignore_paths(path) or { []string{} }
	ignore_paths << ignore_paths2
	mut dirs := []string{}
	for file in files {
		fpath := os.join_path(path, file)
		if os.is_dir(fpath) && is_included(fpath, ignore_paths) && !os.is_link(path) {
			dirs << get_modules_list(fpath, ignore_paths.filter(it.starts_with(fpath)))
		} else if fpath.ends_with('.v') && !fpath.ends_with('_test.v') {
			if path in dirs {
				continue
			}
			dirs << path
		}
	}
	dirs.sort()
	return dirs
}

fn (cfg DocConfig) get_resource(name string, minify bool) string {
	path := os.join_path(res_path, name)
	mut res := os.read_file(path) or { panic('vdoc: could not read $path') }
	if minify {
		if name.ends_with('.js') {
			res = js_compress(res)
		} else {
			res = res.split_into_lines().map(it.trim_space()).join('')
		}
	}
	// TODO: Make SVG inline for now
	if cfg.inline_assets || path.ends_with('.svg') {
		return res
	} else {
		output_path := os.join_path(cfg.output_path, name)
		if !os.exists(output_path) {
			println('Generating $output_path')
			os.write_file(output_path, res)
		}
		return name
	}
}

fn main() {
	if os.args.len < 2 || '-h' in os.args || '--help' in os.args || os.args[1..] == ['doc', 'help'] {
		os.system('$vexe help doc')
		exit(0)
	}
	args := os.args[2..].clone()
	mut cfg := DocConfig{
		manifest: vmod.Manifest{
			repo_url: ''
		}
	}
	for i := 0; i < args.len; i++ {
		arg := args[i]
		current_args := args[i..]
		match arg {
			'-all' {
				cfg.pub_only = false
			}
			'-filename' {
				cfg.is_local = true
				cfg.local_filename = cmdline.option(current_args, '-filename', '')
				i++
			}
			'-f' {
				format := cmdline.option(current_args, '-f', '')
				if format !in allowed_formats {
					allowed_str := allowed_formats.join(', ')
					eprintln('vdoc: "$format" is not a valid format. Only $allowed_str are allowed.')
					exit(1)
				}
				cfg.set_output_type_from_str(format)
				i++
			}
			'-inline-assets' {
				cfg.inline_assets = true
			}
			'-l' {
				cfg.show_loc = true
			}
			'-m' {
				cfg.is_multi = true
			}
			'-o' {
				opath := cmdline.option(current_args, '-o', '')
				cfg.output_path = if opath == 'stdout' { opath } else { os.real_path(opath) }
				i++
			}
			'-open' {
				cfg.open_docs = true
			}
			'-pos' {
				if !cfg.is_local {
					eprintln('vdoc: `-pos` is only allowed with `-filename` flag.')
					exit(1)
				}
				cfg.local_pos = cmdline.option(current_args, '-pos', '').int()
				i++
			}
			'-p' {
				s_port := cmdline.option(current_args, '-p', '')
				s_port_int := s_port.int()
				if s_port.len == 0 {
					eprintln('vdoc: No port number specified on "-p".')
					exit(1)
				}
				if s_port != s_port_int.str() {
					eprintln('vdoc: Invalid port number.')
					exit(1)
				}
				cfg.server_port = s_port_int
				i++
			}
			'-s' {
				cfg.inline_assets = true
				cfg.serve_http = true
				if cfg.output_type == .unset {
					cfg.output_type = .html
				}
			}
			'-no-timestamp' {
				cfg.no_timestamp = true
			}
			'-no-examples' {
				cfg.include_examples = false
			}
			'-readme' {
				cfg.include_readme = true
			}
			'-v' {
				cfg.is_verbose = true
			}
			else {
				if cfg.input_path.len < 1 {
					cfg.input_path = arg
				} else {
					cfg.symbol_name = arg
				}
				if i == args.len - 1 {
					break
				}
			}
		}
	}
	if cfg.input_path.len == 0 {
		eprintln('vdoc: No input path found.')
		exit(1)
	}
	if cfg.output_path == 'stdout' && cfg.output_type == .html {
		cfg.inline_assets = true
	}
	$if windows {
		cfg.input_path = cfg.input_path.replace('/', os.path_separator)
	} $else {
		cfg.input_path = cfg.input_path.replace('\\', os.path_separator)
	}
	is_path := cfg.input_path.ends_with('.v') || cfg.input_path.split(os.path_separator).len >
		1 || cfg.input_path == '.'
	if cfg.input_path.trim_right('/') == 'vlib' {
		cfg.is_vlib = true
		cfg.is_multi = true
		cfg.input_path = os.join_path(vroot, 'vlib')
	} else if !is_path {
		cfg.vprintln('Input "$cfg.input_path" is not a valid path. Looking for modules named "$cfg.input_path"...')
		mod_path := doc.lookup_module(cfg.input_path) or {
			eprintln('vdoc: $err')
			exit(1)
		}
		cfg.input_path = mod_path
	}
	cfg.generate_docs_from_file()
}

fn is_module_readme(dn doc.DocNode) bool {
	if dn.comments.len > 0 && dn.content == 'module $dn.name' {
		return true
	}
	return false
}
