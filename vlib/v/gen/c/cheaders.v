module c

import strings
import v.pref

// Note: @@@ here serve as placeholders.
// They will be replaced with correct strings
// for each constant, during C code generation.

// V_COMMIT_HASH is generated by cmd/tools/gen_vc.v .
const c_commit_hash_default = '
#ifndef V_COMMIT_HASH
	#define V_COMMIT_HASH "@@@"
#endif
'

// V_CURRENT_COMMIT_HASH is updated, when V is rebuilt inside a git repo.
const c_current_commit_hash_default = '
#ifndef V_CURRENT_COMMIT_HASH
	#define V_CURRENT_COMMIT_HASH "@@@"
#endif
'

const c_concurrency_helpers = '
typedef struct __shared_map __shared_map;
struct __shared_map {
	sync__RwMutex mtx;
	map val;
};
static inline voidptr __dup_shared_map(voidptr src, int sz) {
	__shared_map* dest = memdup(src, sz);
	sync__RwMutex_init(&dest->mtx);
	return dest;
}
typedef struct __shared_array __shared_array;
struct __shared_array {
	sync__RwMutex mtx;
	array val;
};
static inline voidptr __dup_shared_array(voidptr src, int sz) {
	__shared_array* dest = memdup(src, sz);
	sync__RwMutex_init(&dest->mtx);
	return dest;
}
static inline void __sort_ptr(uintptr_t a[], bool b[], int l) {
	for (int i=1; i<l; i++) {
		uintptr_t ins = a[i];
		bool insb = b[i];
		int j = i;
		while(j>0 && a[j-1] > ins) {
			a[j] = a[j-1];
			b[j] = b[j-1];
			j--;
		}
		a[j] = ins;
		b[j] = insb;
	}
}
'

// Inspired from Chris Wellons's work
// https://nullprogram.com/blog/2017/01/08/

fn c_closure_helpers(pref_ &pref.Preferences) string {
	mut builder := strings.new_builder(2048)
	if pref_.os != .windows {
		builder.writeln('#include <sys/mman.h>')
	}

	builder.write_string('
#ifdef _MSC_VER
	#define __RETURN_ADDRESS() ((char*)_ReturnAddress())
#elif defined(__TINYC__) && defined(_WIN32)
	#define __RETURN_ADDRESS() ((char*)__builtin_return_address(0))
#else
	#define __RETURN_ADDRESS() ((char*)__builtin_extract_return_addr(__builtin_return_address(0)))
#endif

static int _V_page_size = 0x4000; // 16K
#define ASSUMED_PAGE_SIZE 0x4000
#define _CLOSURE_SIZE (((2*sizeof(void*) > sizeof(__closure_thunk) ? 2*sizeof(void*) : sizeof(__closure_thunk)) + sizeof(void*) - 1) & ~(sizeof(void*) - 1))
// equal to `max(2*sizeof(void*), sizeof(__closure_thunk))`, rounded up to the next multiple of `sizeof(void*)`

// refer to https://godbolt.org/z/r7P3EYv6c for a complete assembly
#ifdef __V_amd64
static const char __closure_thunk[] = {
	0xF3, 0x44, 0x0F, 0x7E, 0x3D, 0xF7, 0xBF, 0xFF, 0xFF,  // movq  xmm15, QWORD PTR [rip - userdata]
	0xFF, 0x25, 0xF9, 0xBF, 0xFF, 0xFF                     // jmp  QWORD PTR [rip - fn]
};
static char __CLOSURE_GET_DATA_BYTES[] = {
	0x66, 0x4C, 0x0F, 0x7E, 0xF8,  // movq rax, xmm15
	0xC3                           // ret
};
#elif defined(__V_x86)
static char __closure_thunk[] = {
	0xe8, 0x00, 0x00, 0x00, 0x00,        // call here
	                                     // here:
	0x59,                                // pop  ecx
	0x66, 0x0F, 0x6E, 0xF9,              // movd xmm7, ecx
	0xff, 0xA1, 0xff, 0xbf, 0xff, 0xff,  // jmp  DWORD PTR [ecx - 0x4001] # <fn>
};

static char __CLOSURE_GET_DATA_BYTES[] = {
	0x66, 0x0F, 0x7E, 0xF8,              // movd eax, xmm7
	0x8B, 0x80, 0xFB, 0xBF, 0xFF, 0xFF,  // mov eax, DWORD PTR [eax - 0x4005]
	0xc3                                 // ret
};

#elif defined(__V_arm64)
static char __closure_thunk[] = {
	0x11, 0x00, 0xFE, 0x58,  // ldr x17, userdata
	0x30, 0x00, 0xFE, 0x58,  // ldr x16, fn
	0x00, 0x02, 0x1F, 0xD6   // br  x16
};
static char __CLOSURE_GET_DATA_BYTES[] = {
	0xE0, 0x03, 0x11, 0xAA,  // mov x0, x17
	0xC0, 0x03, 0x5F, 0xD6   // ret
};
#elif defined(__V_arm32)
static char __closure_thunk[] = {
	0x04, 0xC0, 0x4F, 0xE2,  // adr ip, here
                             // here:
	0x01, 0xC9, 0x4C, 0xE2,  // sub  ip, ip, #4000
	0x90, 0xCA, 0x07, 0xEE,  // vmov s15, ip
	0x00, 0xC0, 0x9C, 0xE5,  // ldr  ip, [ip, 0]
	0x1C, 0xFF, 0x2F, 0xE1   // bx   ip
};
static char __CLOSURE_GET_DATA_BYTES[] = {
	0x90, 0x0A, 0x17, 0xEE,
	0x04, 0x00, 0x10, 0xE5,
	0x1E, 0xFF, 0x2F, 0xE1
};
#elif defined (__V_rv64)
static char __closure_thunk[] = {
	0x97, 0xCF, 0xFF, 0xFF,  // auipc t6, 0xffffc
	0x03, 0xBF, 0x8F, 0x00,  // ld    t5, 8(t6)
	0x67, 0x00, 0x0F, 0x00   // jr    t5
};
static char __CLOSURE_GET_DATA_BYTES[] = {
	0x03, 0xb5, 0x0f, 0x00,  // ld    a0, 0(t6)
	0x67, 0x80, 0x00, 0x00   // ret
};
#elif defined (__V_rv32)
static char __closure_thunk[] = {
	0x97, 0xCF, 0xFF, 0xFF,  // auipc t6, 0xffffc
	0x03, 0xAF, 0x4F, 0x00,  // lw    t5, 4(t6)
	0x67, 0x00, 0x0F, 0x00   // jr    t5
};
static char __CLOSURE_GET_DATA_BYTES[] = {
	0x03, 0xA5, 0x0F, 0x00,  // lw    a0, 0(t6)
	0x67, 0x80, 0x00, 0x00   // ret
};
#endif

static void*(*__CLOSURE_GET_DATA)(void) = 0;

static inline void __closure_set_data(char* closure, void* data) {
	void** p = (void**)(closure - ASSUMED_PAGE_SIZE);
	p[0] = data;
}

static inline void __closure_set_function(char* closure, void* f) {
	void** p = (void**)(closure - ASSUMED_PAGE_SIZE);
	p[1] = f;
}

#ifdef _WIN32
#include <synchapi.h>
static SRWLOCK _closure_mtx;
#define _closure_mtx_init() InitializeSRWLock(&_closure_mtx)
#define _closure_mtx_lock() AcquireSRWLockExclusive(&_closure_mtx)
#define _closure_mtx_unlock() ReleaseSRWLockExclusive(&_closure_mtx)
#else
static pthread_mutex_t _closure_mtx;
#define _closure_mtx_init() pthread_mutex_init(&_closure_mtx, 0)
#define _closure_mtx_lock() pthread_mutex_lock(&_closure_mtx)
#define _closure_mtx_unlock() pthread_mutex_unlock(&_closure_mtx)
#endif
static char* _closure_ptr = 0;
static int _closure_cap = 0;

static void __closure_alloc(void) {
#ifdef _WIN32
	char* p = VirtualAlloc(NULL, _V_page_size * 2, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
	if (p == NULL) return;
#else
	char* p = mmap(0, _V_page_size * 2, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
	if (p == MAP_FAILED) return;
#endif
	char* x = p + _V_page_size;
	int remaining = _V_page_size / _CLOSURE_SIZE;
	_closure_ptr = x;
	_closure_cap = remaining;
	while (remaining > 0) {
		memcpy(x, __closure_thunk, sizeof(__closure_thunk));
		remaining--;
		x += _CLOSURE_SIZE;
	}
#ifdef _WIN32
	DWORD _tmp;
	VirtualProtect(_closure_ptr, _V_page_size, PAGE_EXECUTE_READ, &_tmp);
#else
	mprotect(_closure_ptr, _V_page_size, PROT_READ | PROT_EXEC);
#endif
}

#ifdef _WIN32
void __closure_init() {
	SYSTEM_INFO si;
	GetNativeSystemInfo(&si);
	uint32_t page_size = si.dwPageSize * (((ASSUMED_PAGE_SIZE - 1) / si.dwPageSize) + 1);
	_V_page_size = page_size;
	__closure_alloc();
	DWORD _tmp;
	VirtualProtect(_closure_ptr, page_size, PAGE_READWRITE, &_tmp);
	memcpy(_closure_ptr, __CLOSURE_GET_DATA_BYTES, sizeof(__CLOSURE_GET_DATA_BYTES));
	VirtualProtect(_closure_ptr, page_size, PAGE_EXECUTE_READ, &_tmp);
	__CLOSURE_GET_DATA = (void*)_closure_ptr;
	_closure_ptr += _CLOSURE_SIZE;
	_closure_cap--;
}
#else
void __closure_init() {
	uint32_t page_size = sysconf(_SC_PAGESIZE);
	page_size = page_size * (((ASSUMED_PAGE_SIZE - 1) / page_size) + 1);
	_V_page_size = page_size;
	__closure_alloc();
	mprotect(_closure_ptr, page_size, PROT_READ | PROT_WRITE);
	memcpy(_closure_ptr, __CLOSURE_GET_DATA_BYTES, sizeof(__CLOSURE_GET_DATA_BYTES));
	mprotect(_closure_ptr, page_size, PROT_READ | PROT_EXEC);
	__CLOSURE_GET_DATA = (void*)_closure_ptr;
	_closure_ptr += _CLOSURE_SIZE;
	_closure_cap--;
}
#endif

static void* __closure_create(void* fn, void* data) {
	_closure_mtx_lock();
	if (_closure_cap == 0) {
		__closure_alloc();
	}
	_closure_cap--;
	void* closure = _closure_ptr;
	_closure_ptr += _CLOSURE_SIZE;
	__closure_set_data(closure, data);
	__closure_set_function(closure, fn);
	_closure_mtx_unlock();
	return closure;
}
')
	return builder.str()
}

const c_common_macros = '
#define EMPTY_VARG_INITIALIZATION 0
#define EMPTY_STRUCT_DECLARATION
#define EMPTY_STRUCT_INITIALIZATION
// Due to a tcc bug, the length of an array needs to be specified, but GCC crashes if it is...
#define EMPTY_ARRAY_OF_ELEMS(x,n) (x[])
#define TCCSKIP(x) x

#define __NOINLINE __attribute__((noinline))
#define __IRQHANDLER __attribute__((interrupt))

#define __V_architecture 0
#if defined(__x86_64__) || defined(_M_AMD64)
	#define __V_amd64  1
	#undef __V_architecture
	#define __V_architecture 1
#endif

#if defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64)
	#define __V_arm64  1
	#undef __V_architecture
	#define __V_architecture 2
#endif

#if defined(__arm__) || defined(_M_ARM)
	#define __V_arm32  1
	#undef __V_architecture
	#define __V_architecture 3
#endif

#if defined(__riscv) && __riscv_xlen == 64
	#define __V_rv64  1
	#undef __V_architecture
	#define __V_architecture 4
#endif

#if defined(__riscv) && __riscv_xlen == 32
	#define __V_rv32  1
	#undef __V_architecture
	#define __V_architecture 5
#endif

#if defined(__i386__) || defined(_M_IX86)
	#define __V_x86    1
	#undef __V_architecture
	#define __V_architecture 6
#endif

// Using just __GNUC__ for detecting gcc, is not reliable because other compilers define it too:
#ifdef __GNUC__
	#define __V_GCC__
#endif
#ifdef __TINYC__
	#undef __V_GCC__
#endif
#ifdef __cplusplus
	#undef __V_GCC__
#endif
#ifdef __clang__
	#undef __V_GCC__
#endif

#ifdef _MSC_VER
	#undef __V_GCC__
	#undef EMPTY_STRUCT_DECLARATION
	#undef EMPTY_STRUCT_INITIALIZATION
	#define EMPTY_STRUCT_DECLARATION unsigned char _dummy_pad
	#define EMPTY_STRUCT_INITIALIZATION 0
#endif

#ifndef _WIN32
	#if defined __has_include
		#if __has_include (<execinfo.h>)
			#include <execinfo.h>
		#else
			// On linux: int backtrace(void **__array, int __size);
			// On BSD: size_t backtrace(void **, size_t);
		#endif		
	#endif
#endif
		      
#ifdef __TINYC__
	#define _Atomic volatile
	#undef EMPTY_STRUCT_DECLARATION
	#undef EMPTY_STRUCT_INITIALIZATION
	#define EMPTY_STRUCT_DECLARATION unsigned char _dummy_pad
	#define EMPTY_STRUCT_INITIALIZATION 0
	#undef EMPTY_ARRAY_OF_ELEMS
	#define EMPTY_ARRAY_OF_ELEMS(x,n) (x[n])
	#undef __NOINLINE
	#undef __IRQHANDLER
	// tcc does not support inlining at all
	#define __NOINLINE
	#define __IRQHANDLER
	#undef TCCSKIP
	#define TCCSKIP(x)
	// #include <byteswap.h>
	#ifndef _WIN32
		int tcc_backtrace(const char *fmt, ...);
	#endif
#endif

// Use __offsetof_ptr instead of __offset_of, when you *do* have a valid pointer, to avoid UB:
#ifndef __offsetof_ptr
	#define __offsetof_ptr(ptr,PTYPE,FIELDNAME) ((size_t)((byte *)&((PTYPE *)ptr)->FIELDNAME - (byte *)ptr))
#endif

// for __offset_of
#ifndef __offsetof
	#define __offsetof(PTYPE,FIELDNAME) ((size_t)((char *)&((PTYPE *)0)->FIELDNAME - (char *)0))
#endif

#define OPTION_CAST(x) (x)

#ifndef V64_PRINTFORMAT
	#ifdef PRIx64
		#define V64_PRINTFORMAT "0x%"PRIx64
	#elif defined(__WIN32__)
		#define V64_PRINTFORMAT "0x%I64x"
	#elif defined(__linux__) && defined(__LP64__)
		#define V64_PRINTFORMAT "0x%lx"
	#else
		#define V64_PRINTFORMAT "0x%llx"
	#endif
#endif

#if defined(_WIN32) || defined(__CYGWIN__)
	#define VV_EXPORTED_SYMBOL extern __declspec(dllexport)
	#define VV_LOCAL_SYMBOL static
#else
	// 4 < gcc < 5 is used by some older Ubuntu LTS and Centos versions,
	// and does not support __has_attribute(visibility) ...
	#ifndef __has_attribute
		#define __has_attribute(x) 0  // Compatibility with non-clang compilers.
	#endif
	#if (defined(__GNUC__) && (__GNUC__ >= 4)) || (defined(__clang__) && __has_attribute(visibility))
		#ifdef ARM
			#define VV_EXPORTED_SYMBOL  extern __attribute__((externally_visible,visibility("default")))
		#else
			#define VV_EXPORTED_SYMBOL  extern __attribute__((visibility("default")))
		#endif
		#if defined(__clang__) && (defined(_VUSECACHE) || defined(_VBUILDMODULE))
			#define VV_LOCAL_SYMBOL static
		#else
			#define VV_LOCAL_SYMBOL  __attribute__ ((visibility ("hidden")))
		#endif
	#else
		#define VV_EXPORTED_SYMBOL extern
		#define VV_LOCAL_SYMBOL static
	#endif
#endif

#ifdef __cplusplus
	#include <utility>
	#define _MOV std::move
#else
	#define _MOV
#endif

// tcc does not support has_include properly yet, turn it off completely
#if defined(__TINYC__) && defined(__has_include)
#undef __has_include
#endif


#if !defined(VWEAK)
	#define VWEAK __attribute__((weak))
	#ifdef _MSC_VER
		#undef VWEAK
		#define VWEAK
	#endif
	#if defined(__MINGW32__) || defined(__MINGW64__)
		#undef VWEAK
		#define VWEAK
	#endif
#endif

#if !defined(VNORETURN)
	#if defined(__TINYC__)
		#include <stdnoreturn.h>
		#define VNORETURN noreturn
	#endif
	# if !defined(__TINYC__) && defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
	#  define VNORETURN _Noreturn
	# elif defined(__GNUC__) && __GNUC__ >= 2
	#  define VNORETURN __attribute__((noreturn))
	# endif
	#ifndef VNORETURN
		#define VNORETURN
	#endif
#endif

#if !defined(VUNREACHABLE)
	#if defined(__GNUC__) && !defined(__clang__)
		#define V_GCC_VERSION  (__GNUC__ * 10000L + __GNUC_MINOR__ * 100L + __GNUC_PATCHLEVEL__)
		#if (V_GCC_VERSION >= 40500L)
			#define VUNREACHABLE()  do { __builtin_unreachable(); } while (0)
		#endif
	#endif
	#if defined(__clang__) && defined(__has_builtin)
		#if __has_builtin(__builtin_unreachable)
			#define VUNREACHABLE()  do { __builtin_unreachable(); } while (0)
		#endif
	#endif
	#ifndef VUNREACHABLE
		#define VUNREACHABLE() do { } while (0)
	#endif
	#if defined(__FreeBSD__) && defined(__TINYC__)
		#define VUNREACHABLE() do { } while (0)
	#endif
#endif

//likely and unlikely macros
#if defined(__GNUC__) || defined(__INTEL_COMPILER) || defined(__clang__)
	#define _likely_(x)  __builtin_expect(x,1)
	#define _unlikely_(x)  __builtin_expect(x,0)
#else
	#define _likely_(x) (x)
	#define _unlikely_(x) (x)
#endif

'

const c_unsigned_comparison_functions = '
// unsigned/signed comparisons
static inline bool _us32_gt(uint32_t a, int32_t b) { return a > INT32_MAX || (int32_t)a > b; }
static inline bool _us32_ge(uint32_t a, int32_t b) { return a >= INT32_MAX || (int32_t)a >= b; }
static inline bool _us32_eq(uint32_t a, int32_t b) { return a <= INT32_MAX && (int32_t)a == b; }
static inline bool _us32_ne(uint32_t a, int32_t b) { return a > INT32_MAX || (int32_t)a != b; }
static inline bool _us32_le(uint32_t a, int32_t b) { return a <= INT32_MAX && (int32_t)a <= b; }
static inline bool _us32_lt(uint32_t a, int32_t b) { return a < INT32_MAX && (int32_t)a < b; }
static inline bool _us64_gt(uint64_t a, int64_t b) { return a > INT64_MAX || (int64_t)a > b; }
static inline bool _us64_ge(uint64_t a, int64_t b) { return a >= INT64_MAX || (int64_t)a >= b; }
static inline bool _us64_eq(uint64_t a, int64_t b) { return a <= INT64_MAX && (int64_t)a == b; }
static inline bool _us64_ne(uint64_t a, int64_t b) { return a > INT64_MAX || (int64_t)a != b; }
static inline bool _us64_le(uint64_t a, int64_t b) { return a <= INT64_MAX && (int64_t)a <= b; }
static inline bool _us64_lt(uint64_t a, int64_t b) { return a < INT64_MAX && (int64_t)a < b; }
'

const c_helper_macros = '//============================== HELPER C MACROS =============================*/
// _SLIT0 is used as NULL string for literal arguments
// `"" s` is used to enforce a string literal argument
#define _SLIT0 (string){.str=(byteptr)(""), .len=0, .is_lit=1}
#define _SLIT(s) ((string){.str=(byteptr)("" s), .len=(sizeof(s)-1), .is_lit=1})
#define _SLEN(s, n) ((string){.str=(byteptr)("" s), .len=n, .is_lit=1})

// take the address of an rvalue
#define ADDR(type, expr) (&((type[]){expr}[0]))

// copy something to the heap
#define HEAP(type, expr) ((type*)memdup((void*)&((type[]){expr}[0]), sizeof(type)))
#define HEAP_noscan(type, expr) ((type*)memdup_noscan((void*)&((type[]){expr}[0]), sizeof(type)))

#define _PUSH_MANY(arr, val, tmp, tmp_typ) {tmp_typ tmp = (val); array_push_many(arr, tmp.data, tmp.len);}
#define _PUSH_MANY_noscan(arr, val, tmp, tmp_typ) {tmp_typ tmp = (val); array_push_many_noscan(arr, tmp.data, tmp.len);}
'

const c_headers = c_helper_macros + c_unsigned_comparison_functions + c_common_macros +
	r'
// c_headers
typedef int (*qsort_callback_func)(const void*, const void*);
#include <stdio.h>  // TODO remove all these includes, define all function signatures and types manually
#include <stdlib.h>
#include <string.h>

#include <stdarg.h> // for va_list

//================================== GLOBALS =================================*/
int load_so(byteptr);
void _vinit(int ___argc, voidptr ___argv);
void _vcleanup(void);
#define sigaction_size sizeof(sigaction);
#define _ARR_LEN(a) ( (sizeof(a)) / (sizeof(a[0])) )

void v_free(voidptr ptr);
voidptr memdup(voidptr src, int sz);

#if INTPTR_MAX == INT32_MAX
	#define TARGET_IS_32BIT 1
#elif INTPTR_MAX == INT64_MAX
	#define TARGET_IS_64BIT 1
#else
	#error "The environment is not 32 or 64-bit."
#endif

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__ || defined(__BYTE_ORDER) && __BYTE_ORDER == __BIG_ENDIAN || defined(__BIG_ENDIAN__) || defined(__ARMEB__) || defined(__THUMBEB__) || defined(__AARCH64EB__) || defined(_MIBSEB) || defined(__MIBSEB) || defined(__MIBSEB__)
	#define TARGET_ORDER_IS_BIG 1
#elif defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__ || defined(__BYTE_ORDER) && __BYTE_ORDER == __LITTLE_ENDIAN || defined(__LITTLE_ENDIAN__) || defined(__ARMEL__) || defined(__THUMBEL__) || defined(__AARCH64EL__) || defined(_MIPSEL) || defined(__MIPSEL) || defined(__MIPSEL__) || defined(_M_AMD64) || defined(_M_X64) || defined(_M_IX86)
	#define TARGET_ORDER_IS_LITTLE 1
#else
	#error "Unknown architecture endianness"
#endif

#ifndef _WIN32
	#include <ctype.h>
	#include <locale.h> // tolower
	#include <sys/time.h>
	#include <unistd.h> // sleep
	extern char **environ;
#endif

#if defined(__CYGWIN__) && !defined(_WIN32)
	#error Cygwin is not supported, please use MinGW or Visual Studio.
#endif

#if defined(__linux__) || defined(__FreeBSD__) || defined(__DragonFly__) || defined(__vinix__) || defined(__serenity__) || defined(__sun)
	#include <sys/types.h>
	#include <sys/wait.h> // os__wait uses wait on nix
#endif

#ifdef __OpenBSD__
	#include <sys/types.h>
	#include <sys/resource.h>
	#include <sys/wait.h> // os__wait uses wait on nix
#endif

#ifdef __NetBSD__
	#include <sys/wait.h> // os__wait uses wait on nix
#endif

#ifdef _WIN32
	#define WINVER 0x0600
	#ifdef _WIN32_WINNT
		#undef _WIN32_WINNT
	#endif
	#define _WIN32_WINNT 0x0600
	#ifndef WIN32_FULL
	#define WIN32_LEAN_AND_MEAN
	#endif
	#ifndef _UNICODE
	#define _UNICODE
	#endif
	#ifndef UNICODE
	#define UNICODE
	#endif
	#include <windows.h>

	#include <io.h> // _waccess
	#include <direct.h> // _wgetcwd
	#ifdef V_USE_SIGNAL_H
	#include <signal.h> // signal and SIGSEGV for segmentation fault handler
	#endif

	#ifdef _MSC_VER
		// On MSVC these are the same (as long as /volatile:ms is passed)
		#define _Atomic volatile

		// MSVC cannot parse some things properly
		#undef OPTION_CAST
		#define OPTION_CAST(x)
		#undef __NOINLINE
		#undef __IRQHANDLER
		#define __NOINLINE __declspec(noinline)
		#define __IRQHANDLER __declspec(naked)

		#include <dbghelp.h>
		#pragma comment(lib, "Dbghelp")
	#endif
#else
	#include <pthread.h>
	#ifndef PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP
		// musl does not have that
		#define pthread_rwlockattr_setkind_np(a, b)
	#endif
#endif

// g_live_info is used by live.info()
static void* g_live_info = NULL;

#if defined(__MINGW32__) || defined(__MINGW64__) || (defined(_WIN32) && defined(__TINYC__))
	#undef PRId64
	#undef PRIi64
	#undef PRIo64
	#undef PRIu64
	#undef PRIx64
	#undef PRIX64
	#define PRId64 "lld"
	#define PRIi64 "lli"
	#define PRIo64 "llo"
	#define PRIu64 "llu"
	#define PRIx64 "llx"
	#define PRIX64 "llX"
#endif

#ifdef _VFREESTANDING
#undef _VFREESTANDING
#endif
'

const c_builtin_types = '
//================================== builtin types ================================*/
typedef int64_t i64;
typedef int16_t i16;
typedef int8_t i8;
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint8_t u8;
typedef uint16_t u16;
typedef u8 byte;
typedef int i32;
typedef uint32_t rune;
typedef size_t usize;
typedef ptrdiff_t isize;
#ifndef VNOFLOAT
typedef float f32;
typedef double f64;
#else
typedef int32_t f32;
typedef int64_t f64;
#endif
typedef int64_t int_literal;
#ifndef VNOFLOAT
typedef double float_literal;
#else
typedef int64_t float_literal;
#endif
typedef unsigned char* byteptr;
typedef void* voidptr;
typedef char* charptr;
typedef u8 array_fixed_byte_300 [300];

typedef struct sync__Channel* chan;

#ifndef __cplusplus
	#ifndef bool
		#ifdef CUSTOM_DEFINE_4bytebool
			typedef int bool;
		#else
			typedef u8 bool;
		#endif
		#define true 1
		#define false 0
	#endif
#endif

typedef u64 (*MapHashFn)(voidptr);
typedef bool (*MapEqFn)(voidptr, voidptr);
typedef void (*MapCloneFn)(voidptr, voidptr);
typedef void (*MapFreeFn)(voidptr);
'

const c_bare_headers = c_helper_macros + c_unsigned_comparison_functions + c_common_macros +
	'
#define _VFREESTANDING

typedef long unsigned int size_t;

// Memory allocation related headers
void *malloc(size_t size);
void *calloc(size_t nitems, size_t size);
void *realloc(void *ptr, size_t size);
void *memcpy(void *dest, void *src, size_t n);
void *memset(void *s, int c, size_t n);
void *memmove(void *dest, void *src, size_t n);

// varargs implementation, TODO: works on tcc and gcc, but is very unportable and hacky
typedef __builtin_va_list va_list;
#define va_start(a, b) __builtin_va_start(a, b)
#define va_end(a)      __builtin_va_end(a)
#define va_arg(a, b)   __builtin_va_arg(a, b)
#define va_copy(a, b)  __builtin_va_copy(a, b)

//================================== GLOBALS =================================*/
int load_so(byteptr);
void _vinit(int ___argc, voidptr ___argv);
void _vcleanup();
#define sigaction_size sizeof(sigaction);
#define _ARR_LEN(a) ( (sizeof(a)) / (sizeof(a[0])) )

void v_free(voidptr ptr);
voidptr memdup(voidptr src, int sz);

'

const c_wyhash_headers = '
// ============== wyhash ==============
#ifndef wyhash_final_version_3
#define wyhash_final_version_3

#ifndef WYHASH_CONDOM
// protections that produce different results:
// 1: normal valid behavior
// 2: extra protection against entropy loss (probability=2^-63), aka. "blind multiplication"
#define WYHASH_CONDOM 1
#endif

#ifndef WYHASH_32BIT_MUM
// 0: normal version, slow on 32 bit systems
// 1: faster on 32 bit systems but produces different results, incompatible with wy2u0k function
#define WYHASH_32BIT_MUM 0
#endif

// includes
#include <stdint.h>
#if defined(_MSC_VER) && defined(_M_X64)
	#include <intrin.h>
	#pragma intrinsic(_umul128)
#endif

// 128bit multiply function
static inline uint64_t _wyrot(uint64_t x) { return (x>>32)|(x<<32); }
static inline void _wymum(uint64_t *A, uint64_t *B){
#if(WYHASH_32BIT_MUM)
	uint64_t hh=(*A>>32)*(*B>>32), hl=(*A>>32)*(uint32_t)*B, lh=(uint32_t)*A*(*B>>32), ll=(uint64_t)(uint32_t)*A*(uint32_t)*B;
	#if(WYHASH_CONDOM>1)
	*A^=_wyrot(hl)^hh; *B^=_wyrot(lh)^ll;
	#else
	*A=_wyrot(hl)^hh; *B=_wyrot(lh)^ll;
	#endif
#elif defined(__SIZEOF_INT128__) && !defined(VWASM)
	__uint128_t r=*A; r*=*B;
	#if(WYHASH_CONDOM>1)
	*A^=(uint64_t)r; *B^=(uint64_t)(r>>64);
	#else
	*A=(uint64_t)r; *B=(uint64_t)(r>>64);
	#endif
#elif defined(_MSC_VER) && defined(_M_X64)
	#if(WYHASH_CONDOM>1)
	uint64_t  a,  b;
	a=_umul128(*A,*B,&b);
	*A^=a;  *B^=b;
	#else
	*A=_umul128(*A,*B,B);
	#endif
#else
	uint64_t ha=*A>>32, hb=*B>>32, la=(uint32_t)*A, lb=(uint32_t)*B, hi, lo;
	uint64_t rh=ha*hb, rm0=ha*lb, rm1=hb*la, rl=la*lb, t=rl+(rm0<<32), c=t<rl;
	lo=t+(rm1<<32); c+=lo<t; hi=rh+(rm0>>32)+(rm1>>32)+c;
	#if(WYHASH_CONDOM>1)
	*A^=lo;  *B^=hi;
	#else
	*A=lo;  *B=hi;
	#endif
#endif
}

// multiply and xor mix function, aka MUM
static inline uint64_t _wymix(uint64_t A, uint64_t B){ _wymum(&A,&B); return A^B; }

// endian macros
#ifndef WYHASH_LITTLE_ENDIAN
	#ifdef TARGET_ORDER_IS_LITTLE
		#define WYHASH_LITTLE_ENDIAN 1
	#else
		#define WYHASH_LITTLE_ENDIAN 0
	#endif
#endif

// read functions
#if (WYHASH_LITTLE_ENDIAN)
	static inline uint64_t _wyr8(const uint8_t *p) { uint64_t v; memcpy(&v, p, 8); return v;}
	static inline uint64_t _wyr4(const uint8_t *p) { uint32_t v; memcpy(&v, p, 4); return v;}
#elif defined(__GNUC__) || defined(__INTEL_COMPILER) || defined(__clang__)
	static inline uint64_t _wyr8(const uint8_t *p) { uint64_t v; memcpy(&v, p, 8); return __builtin_bswap64(v);}
	static inline uint64_t _wyr4(const uint8_t *p) { uint32_t v; memcpy(&v, p, 4); return __builtin_bswap32(v);}
#elif defined(_MSC_VER)
	static inline uint64_t _wyr8(const uint8_t *p) { uint64_t v; memcpy(&v, p, 8); return _byteswap_uint64(v);}
	static inline uint64_t _wyr4(const uint8_t *p) { uint32_t v; memcpy(&v, p, 4); return _byteswap_ulong(v);}
#else
	static inline uint64_t _wyr8(const uint8_t *p) {
		uint64_t v; memcpy(&v, p, 8);
		return (((v >> 56) & 0xff)| ((v >> 40) & 0xff00)| ((v >> 24) & 0xff0000)| ((v >>  8) & 0xff000000)| ((v <<  8) & 0xff00000000)| ((v << 24) & 0xff0000000000)| ((v << 40) & 0xff000000000000)| ((v << 56) & 0xff00000000000000));
	}
	static inline uint64_t _wyr4(const uint8_t *p) {
		uint32_t v; memcpy(&v, p, 4);
		return (((v >> 24) & 0xff)| ((v >>  8) & 0xff00)| ((v <<  8) & 0xff0000)| ((v << 24) & 0xff000000));
	}
#endif
static inline uint64_t _wyr3(const uint8_t *p, size_t k) { return (((uint64_t)p[0])<<16)|(((uint64_t)p[k>>1])<<8)|p[k-1];}
// wyhash main function
static inline uint64_t wyhash(const void *key, size_t len, uint64_t seed, const uint64_t *secret){
	const uint8_t *p=(const uint8_t *)key; seed^=*secret;	uint64_t a, b;
	if (_likely_(len<=16)) {
		if (_likely_(len>=4)) { a=(_wyr4(p)<<32)|_wyr4(p+((len>>3)<<2)); b=(_wyr4(p+len-4)<<32)|_wyr4(p+len-4-((len>>3)<<2)); }
		else if (_likely_(len>0)) { a=_wyr3(p,len); b=0; }
		else a=b=0;
	} else {
		size_t i=len;
		if (_unlikely_(i>48)) {
			uint64_t see1=seed, see2=seed;
			do {
				seed=_wymix(_wyr8(p)^secret[1],_wyr8(p+8)^seed);
				see1=_wymix(_wyr8(p+16)^secret[2],_wyr8(p+24)^see1);
				see2=_wymix(_wyr8(p+32)^secret[3],_wyr8(p+40)^see2);
				p+=48; i-=48;
			} while(_likely_(i>48));
			seed^=see1^see2;
		}
		while(_unlikely_(i>16)) { seed=_wymix(_wyr8(p)^secret[1],_wyr8(p+8)^seed);  i-=16; p+=16; }
		a=_wyr8(p+i-16);  b=_wyr8(p+i-8);
	}
	return _wymix(secret[1]^len,_wymix(a^secret[1],b^seed));
}
// the default secret parameters
static const uint64_t _wyp[4] = {0xa0761d6478bd642full, 0xe7037ed1a0b428dbull, 0x8ebc6af09c88c6e3ull, 0x589965cc75374cc3ull};

// a useful 64bit-64bit mix function to produce deterministic pseudo random numbers that can pass BigCrush and PractRand
static inline uint64_t wyhash64(uint64_t A, uint64_t B){ A^=0xa0761d6478bd642full; B^=0xe7037ed1a0b428dbull; _wymum(&A,&B); return _wymix(A^0xa0761d6478bd642full,B^0xe7037ed1a0b428dbull);}

// the wyrand PRNG that pass BigCrush and PractRand
static inline uint64_t wyrand(uint64_t *seed){ *seed+=0xa0761d6478bd642full; return _wymix(*seed,*seed^0xe7037ed1a0b428dbull);}

#ifndef __vinix__
// convert any 64 bit pseudo random numbers to uniform distribution [0,1). It can be combined with wyrand, wyhash64 or wyhash.
static inline double wy2u01(uint64_t r){ const double _wynorm=1.0/(1ull<<52); return (r>>12)*_wynorm;}

// convert any 64 bit pseudo random numbers to APPROXIMATE Gaussian distribution. It can be combined with wyrand, wyhash64 or wyhash.
static inline double wy2gau(uint64_t r){ const double _wynorm=1.0/(1ull<<20); return ((r&0x1fffff)+((r>>21)&0x1fffff)+((r>>42)&0x1fffff))*_wynorm-3.0;}
#endif

#if(!WYHASH_32BIT_MUM)
// fast range integer random number generation on [0,k) credit to Daniel Lemire. May not work when WYHASH_32BIT_MUM=1. It can be combined with wyrand, wyhash64 or wyhash.
static inline uint64_t wy2u0k(uint64_t r, uint64_t k){ _wymum(&r,&k); return k; }
#endif
#endif

#define _IN_MAP(val, m) map_exists(m, val)

'
