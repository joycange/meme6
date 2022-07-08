module main

import os
import term
import os.cmdline

// Finder is entity that contains all the logic
struct Finder {
mut:
	symbol  Symbol
	visib   Visibility
	mutab   Mutability
	name    string
	modul   string
	mth_of  string
	dirs    []string
	matches []Match
}

fn (mut fdr Finder) configure_from_arguments() {
	args := os.args[2..]
	match args.len {
		1 {
			fdr.name = args[0]
		}
		2 {
			fdr.symbol.set_from_str(args[0])
			fdr.name = args[1]
		}
		else {
			fdr.symbol.set_from_str(args[0])
			fdr.name = args[1]
			fdr.visib.set_from_str(cmdline.option(args, '-vis', '${Visibility.all}'))
			fdr.mutab.set_from_str(cmdline.option(args, '-mut', '${Mutability.any}'))
			fdr.modul = cmdline.option(args, '-mod', '')
			fdr.mth_of = cmdline.option(args, '-m-of', '')
			if fdr.symbol != .@fn && fdr.mth_of != '' {
				make_and_print_error('-m-of $fdr.mth_of just can be setted with symbol_type fn',
					[], '$fdr.symbol')
			}
			fdr.dirs = cmdline.options(args, '-dir')
		}
	}
}

fn (mut fdr Finder) search_for_matches() {
	// fdr.matches << Match{'./un/lugar/en/tu/pc.v', 35}
	// fdr.matches << Match{'./un/lugar/en/mi/laptop.v', 13}
}

fn (fdr Finder) show_results() {
	print(fdr)
	if fdr.matches.len < 1 {
		println(maybe_color(term.bright_yellow, 'No Matches found'))
	} else {
		println(maybe_color(term.bright_green, '$fdr.matches.len matches Found\n'))
		for result in fdr.matches {
			result.show()
		}
	}
}

fn (fdr Finder) str() string {
	v := maybe_color(term.bright_red, '$fdr.visib')
	m := maybe_color(term.bright_red, '$fdr.mutab')
	st := if fdr.mth_of != '' { '( $fdr.mth_of)' } else { '' }
	s := maybe_color(term.bright_magenta, '$fdr.symbol')
	n := maybe_color(term.bright_blue, '$fdr.name')

	mm := if fdr.modul != '' { maybe_color(term.bright_blue, '$fdr.modul') } else { '' }
	dd := if fdr.dirs.len != 0 { 
		fdr.dirs.map(maybe_color(term.bright_blue, it))
	} else { 
		fdr.dirs
	}

	dm := if fdr.dirs.len == 0 && fdr.modul == '' {
		'all the project scope'
	} else if fdr.dirs.len == 0 && fdr.modul != '' {
		'module $mm'
	} else if fdr.dirs.len != 0 && fdr.modul == '' {
		'directories: $dd'
	} else {
		'module $mm searching within directories: $dd'
	}

	return '\nFind: $s $st $n | visibility: $v mutability: $m\nwithin $dm '
}

// Match is one result of the search_for_matches() process
struct Match {
	path string [required]
	line int    [required]
}

fn (mtc Match) show() {
	path := maybe_color(term.bright_magenta, mtc.path)
	line := maybe_color(term.bright_yellow, '$mtc.line')
	println('$path line: $line\n')
}
