module main

import os
import v.doc
import strings

enum OutputType {
	html
	markdown
	json
	plaintext
	stdout
}

fn slug(title string) string {
	return title.replace(' ', '-')
}

fn escape(str string) string {
	return str.replace_each(['"', '\\"', '\r\n', '\\n', '\n', '\\n'])
}

fn gen_json(d doc.Doc) string {
	mut jw := strings.new_builder(200)
	jw.writeln('{\n\t"module_name": "$d.head_node.name",\n\t"description": "${escape(d.head_node.comment)}",\n\t"contents": [')
	for i, cn in d.content_nodes {
		name := cn.name[d.head_node.name.len+1..]
		jw.writeln('\t\t{')
		jw.writeln('\t\t\t"name": "$name",')
		jw.writeln('\t\t\t"signature": "${escape(cn.content)}",')
		jw.writeln('\t\t\t"description": "${escape(cn.comment)}"')
		jw.write('\t\t}')
		if i < d.content_nodes.len-1 { jw.writeln(',') }
	}
	jw.writeln('\n\t],')
	jw.write('\t"generator": "vdoc",\n\t"time_generated": "${d.time_generated.str()}"\n}')
	return jw.str()
}

fn gen_html(d doc.Doc) string {
	eprintln('vdoc: HTML output is disabled for now.')
	exit(1)
	return ''
}

fn gen_plaintext(d doc.Doc, show_loc bool) string {
	mut pw := strings.new_builder(200)

	head_lines := '='.repeat(d.head_node.content.len)
	pw.writeln('${d.head_node.content}\n$head_lines\n')

	for cn in d.content_nodes {
		pw.writeln(cn.content)
		if cn.comment.len > 0 {
			pw.writeln('\n' + cn.comment)
		}
		if show_loc {
			pw.writeln('Location: ${cn.file_path}:${cn.pos.line}:${cn.pos.col}\n\n')
		}
	}

	pw.writeln('Generated on $d.time_generated')
	return pw.str()
}

fn gen_markdown(d doc.Doc, with_toc bool) string {
	mut hw := strings.new_builder(200)
	mut cw := strings.new_builder(200)

	hw.writeln('# ${d.head_node.content}\n${d.head_node.comment}\n')
	if with_toc {
		hw.writeln('## Contents')
	}
	
	for cn in d.content_nodes {
		name := cn.name[d.head_node.name.len+1..]

		if with_toc {
			hw.writeln('- [#$name](${slug(name)})')
		}
		cw.writeln('## $name')
		cw.writeln('```v\n${cn.content}\n```${cn.comment}\n')
		cw.writeln('[\[Return to contents\]](#Contents)\n')
	}

	cw.writeln('#### Generated by vdoc. Last generated: ${d.time_generated.str()}')
	return hw.str() + '\n' + cw.str()
}

fn generate_docs_from_file(ipath string, opath string, pub_only bool, show_loc bool) {
	mut output_type := OutputType.plaintext
	// identify output type
	if opath.len == 0 {
		output_type = .stdout
	} else {
		ext := os.file_ext(opath)[1..]
		if ext in ['md', 'markdown'] || opath in [':md:', ':markdown:'] {
			output_type = .markdown
		} else if ext in ['html', 'htm'] || opath == ':html:' {
			output_type = .html
		} else if ext == 'json' || opath == ':json:' {
			output_type = .json
		} else {
			output_type = .plaintext
		}
	}
	
	d := doc.generate(ipath, pub_only) or {
		panic(err)
	}

	output := match output_type {
		.html { gen_html(d) }
		.markdown { gen_markdown(d, true) }
		.json { gen_json(d) }
		else { gen_plaintext(d, show_loc) }
	}

	if output_type == .stdout || (opath.starts_with(':') && opath.ends_with(':')) {
		println(output)
	} else {
		os.write_file(opath, output)
	}
}

fn lookup_module(mod string) ?string {
	mod_path := mod.replace('.', '/')
	vexe_path := os.base_dir(os.base_dir(os.base_dir(os.executable())))

	compile_dir := os.real_path(os.base_dir('.'))
	modules_dir := os.join_path(compile_dir, 'modules', mod_path)
	vlib_path := os.join_path(vexe_path, 'vlib', mod_path)
	vmodules_path := os.join_path(os.home_dir(), '.vmodules', mod_path)
	paths := [modules_dir, vlib_path, vmodules_path]

	for path in paths {
		if os.is_dir_empty(path) { continue }
		return path
	}

	return error('vdoc: Module "${mod}" not found.')
}

fn parse_args(args []string) ([]string, []string) {
	mut opts := []string{}
	mut unkn := []string{}
	
	for arg in args {
		if arg.starts_with('-') {
			opts << arg
		} else {
			unkn << arg
		}
	}

	return opts, unkn
}

fn main() {
	osargs := os.args[2..]
	opts, args := parse_args(osargs)
	
	if osargs.len == 0 || args[0] == 'help' {
		os.system('v help doc')
		exit(0)
	}

	mut src_path := args[0]
	mut opath := if args.len >= 2 { args[1] } else { '' }
	pub_only := '-all' !in opts
	show_loc := '-loc' in opts
	is_path := src_path.ends_with('.v') || src_path.split('/').len > 1 || src_path == '.'

	if !is_path {
		mod_path := lookup_module(src_path) or {
			eprintln(err)
			exit(1)
		}

		src_path = mod_path
	}

	generate_docs_from_file(src_path, opath, pub_only, show_loc)
}