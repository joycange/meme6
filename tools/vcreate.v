// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	os
)

struct Create {
mut:
	name string
	description string
	version string
}

fn cerror(e string){
	eprintln('\nerror: $e')
}

fn (c Create)write_vmod() {
	vmod := os.create('${c.name}/v.mod') or { cerror(err) exit(1) }
	mut vmod_content := []string
	vmod_content << '#V Project#\n'
	vmod_content << 'Module {'
	vmod_content << '	name: \'${c.name}\','
	vmod_content << '	description: \'${c.description}\','
	vmod_content << '       version: v${c.version},'
	vmod_content << '	dependencies: []'
	vmod_content << '}'
	vmod.write(vmod_content.join('\n'))
}

fn (c Create)write_main() {
	main := os.create('${c.name}/${c.name}.v') or {	cerror(err) exit(2)	}
	mut main_content := []string
	main_content << 'module main\n'
	main_content << 'import ( mod )\n'
	main_content << 'fn main() {'
	main_content << '	println(\'Hello World !\')'
	main_content << '}'
	main.write(main_content.join('\n'))
}

fn (_ Create)write_mod(){
	os.mkdir('${c.name}/mod')
	mod := os.create('${c.name}/mod/mod.v') or {return}
	mut mod_in := []string
	mod_in << 'module mod\n'
	mod_in << 'pub fn add(i, j int) int {'
	mod_in << '    return i + j'
	mod_in << '}\n'
	mod.write(mod_in.join('\n'))
}

fn main() {
	mut c := Create{}
	print('Choose your project name: ')
	c.name = os.get_line()
	print('Choose your project description: ')
	c.description = os.get_line()
	c.version='0.0.1'
	println('Initialising ...')
	if (os.is_dir(c.name)) { cerror('folder already exists') exit(3) }
	os.mkdir(c.name)
	c.write_vmod()
	c.write_main()
	c.write_mod()			// add a user defined module
	println('Complete !')
}
