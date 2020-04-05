module main

import os
import testing

const (
	fixed_test_files = [
		// 'vlib/arrays/arrays_test.v',
		'vlib/bitfield/bitfield_test.v',
		'vlib/builtin/array_test.v',
		'vlib/builtin/byte_test.v',
		// 'vlib/builtin/float_test.v',
		// 'vlib/builtin/int_test.v',
		'vlib/builtin/isnil_test.v',
		// 'vlib/builtin/map_test.v',
		'vlib/builtin/string_int_test.v',
		'vlib/builtin/string_strip_margin_test.v',
		'vlib/builtin/string_test.v',
		'vlib/builtin/utf8_test.v',
		'vlib/builtin/bare/syscallwrapper_test.v',
		// 'vlib/cli/command_test.v',
		// 'vlib/cli/flag_test.v',
		// 'vlib/clipboard/clipboard_test.v', // Linux only
		// 'vlib/crypto/aes/aes_test.v',
		// 'vlib/crypto/md5/md5_test.v',
		// 'vlib/crypto/rand/rand_test.v',
		// 'vlib/crypto/rc4/rc4_test.v',
		// 'vlib/crypto/sha1/sha1_test.v',
		// 'vlib/crypto/sha256/sha256_test.v',
		// 'vlib/crypto/sha512/sha512_test.v',
		// 'vlib/encoding/base64/base64_memory_test.v',
		// 'vlib/encoding/base64/base64_test.v',
		// 'vlib/encoding/csv/csv_test.v',
		// 'vlib/encoding/utf8/utf8_util_test.v',
		// 'vlib/eventbus/eventbus_test.v',
		// 'vlib/flag/flag_test.v',
		'vlib/glm/glm_test.v',
		'vlib/gx/gx_test.v',
		'vlib/hash/crc32/crc32_test.v',
		'vlib/hash/fnv1a/fnv1a_test.v',
		'vlib/hash/wyhash/wyhash_test.v',
		// 'vlib/json/json_test.v',
		'vlib/math/math_test.v',
		// 'vlib/math/big/big_test.v',
		// 'vlib/math/bits/bits_test.v',
		// 'vlib/math/complex/complex_test.v',
		// 'vlib/math/factorial/factorial_test.v',
		// 'vlib/math/fractions/fraction_test.v',
		// 'vlib/math/stats/stats_test.v',
		// 'vlib/net/socket_test.v',
		// 'vlib/net/socket_udp_test.v',
		// 'vlib/net/ftp/ftp_test.v',
		// 'vlib/net/http/http_httpbin_test.v',
		// 'vlib/net/http/http_test.v',
		// 'vlib/net/urllib/urllib_test.v',
		'vlib/orm/orm_test.v',
		// 'vlib/os/environment_test.v', // Linux only
		'vlib/os/inode_test.v',
		'vlib/os/os_test.v',
		'vlib/os/cmdline/cmdline_test.v',
		'vlib/os2/os2_test.v',
		// 'vlib/rand/pcg32_test.v',
		'vlib/rand/rand_test.v',
		// 'vlib/rand/splitmix64_test.v',
		// 'vlib/regex/regex_test.v',
		'vlib/runtime/runtime_test.v',
		// 'vlib/sqlite/sqlite_test.v', // Linux only
		'vlib/strconv/atof_test.v',
		'vlib/strconv/atoi_test.v',
		// 'vlib/strconv/ftoa/f32_f64_to_string_test.v',
		'vlib/strings/builder_test.v',
		'vlib/strings/similarity_test.v',
		'vlib/strings/strings_test.v',
		'vlib/sync/pool_test.v',
		'vlib/term/term_test.v',
		'vlib/time/format_test.v',
		'vlib/time/parse_test.v',
		'vlib/time/time_test.v',
		'vlib/time/misc/misc_test.v',
		'vlib/v/doc/doc_test.v',
		// 'vlib/v/fmt/fmt_keep_test.v',
		'vlib/v/fmt/fmt_test.v',
		'vlib/v/gen/cgen_test.v',
		// 'vlib/v/parser/parser_test.v',
		'vlib/v/scanner/scanner_test.v',
		// 'vlib/v/tests/array_to_string_test.v',
		// 'vlib/v/tests/asm_test.v', // Linux only
		'vlib/v/tests/attribute_test.v',
		// 'vlib/v/tests/backtrace_test.v', // TCC only
		'vlib/v/tests/comptime_bittness_and_endianess_test.v',
		'vlib/v/tests/const_test.v',
		'vlib/v/tests/cstrings_test.v',
		'vlib/v/tests/defer_test.v',
		// 'vlib/v/tests/enum_bitfield_test.v',
		'vlib/v/tests/enum_hex_test.v',
		'vlib/v/tests/enum_test.v',
		// 'vlib/v/tests/fixed_array_test.v',
		'vlib/v/tests/fn_expecting_ref_but_returning_struct_test.v',
		'vlib/v/tests/fn_expecting_ref_but_returning_struct_time_module_test.v',
		'vlib/v/tests/fn_multiple_returns_test.v',
		// 'vlib/v/tests/fn_test.v',
		// 'vlib/v/tests/fn_variadic_test.v',
		'vlib/v/tests/generic_test.v',
		'vlib/v/tests/if_expression_test.v',
		'vlib/v/tests/interfaces_map_test.v',
		'vlib/v/tests/interface_test.v',
		'vlib/v/tests/in_expression_test.v',
		// 'vlib/v/tests/live_test.v', // Linux only
		'vlib/v/tests/local_test.v',
		// 'vlib/v/tests/match_test.v',
		// 'vlib/v/tests/module_test.v',
		// 'vlib/v/tests/msvc_test.v',
		'vlib/v/tests/multiret_with_ptrtype_test.v',
		// 'vlib/v/tests/mut_test.v',
		'vlib/v/tests/nameof_test.v',
		// 'vlib/v/tests/num_lit_call_method_test.v',
		'vlib/v/tests/option_default_values_test.v',
		// 'vlib/v/tests/option_test.v',
		// 'vlib/v/tests/pointers_test.v',
		'vlib/v/tests/print_test.v',
		'vlib/v/tests/prod_test.v',
		'vlib/v/tests/repeated_multiret_values_test.v',
		'vlib/v/tests/return_voidptr_test.v',
		'vlib/v/tests/reusable_mut_multiret_values_test.v',
		'vlib/v/tests/shift_test.v',
		// 'vlib/v/tests/string_interpolation_array_of_structs_test.v',
		// 'vlib/v/tests/string_interpolation_struct_test.v',
		'vlib/v/tests/string_interpolation_test.v',
		// 'vlib/v/tests/string_interpolation_variadic_test.v',
		'vlib/v/tests/string_struct_interpolation_test.v',
		'vlib/v/tests/struct_chained_fields_correct_test.v',
		// 'vlib/v/tests/struct_test.v',
		'vlib/v/tests/str_gen_test.v',
		'vlib/v/tests/typeof_simple_types_test.v',
		// 'vlib/v/tests/typeof_test.v',
		'vlib/v/tests/type_alias_test.v',
		// 'vlib/v/tests/type_test.v',
		'vlib/v/tests/voidptr_to_u64_cast_a_test.v',
		'vlib/v/tests/voidptr_to_u64_cast_b_test.v',
		'vlib/v/tests/working_with_an_empty_struct_test.v',
		'vlib/v/tests/inout/compiler_test.v',
		'vlib/v/tests/modules/amodule/another_internal_module_test.v',
		'vlib/v/tests/modules/amodule/internal_module_test.v',
		'vlib/v/tests/modules/simplemodule/importing_test.v',
		// 'vlib/v/tests/project_with_c_code/main_test.v',
		// 'vlib/v/tests/project_with_modules_having_submodules/bin/a_program_under_bin_can_find_mod1_test.v',
		// 'vlib/v/tests/project_with_modules_having_submodules/tests/submodule_test.v',
		// 'vlib/v/tests/repl/repl_test.v',
		// 'vlib/v/tests/valgrind/valgrind_test.v', // ubuntu-musl only
		// 'vlib/vweb/assets/assets_test.v',
   ]
)

fn main() {
	args := os.args
	args_string := args[1..].join(' ')
	cmd_prefix := args_string.all_before('test-fixed')
	title := 'testing all fixed tests'
	testing.eheader(title)
	mut tsession := testing.new_test_session(cmd_prefix)
	tsession.files << fixed_test_files
	tsession.test()
	eprintln(tsession.benchmark.total_message(title))
	if tsession.benchmark.nfail > 0 {
		panic('\nWARNING: failed ${tsession.benchmark.nfail} times.\n')
	}
}
