module clipboard

#include <libkern/OSAtomic.h>
#include <Cocoa/Cocoa.h>

#flag -framework Cocoa

struct Clipboard {
    pb voidptr
    last_cb_serial i64
}

fn new_clipboard() &Clipboard{
	mut pb := voidptr(0)
	#pb = [NSPasteboard generalPasteboard];
	cb := &Clipboard{
		pb: pb
	}
	return cb
}

fn (c &Clipboard) clear(){
	#[c->pb clearContents];
}

fn (c &Clipboard) free(){
	//nothing to free
}

fn (c &Clipboard) has_ownership() bool {
	#return [c->pb changeCount] == c->last_cb_serial;
	return false
}

fn (c &Clipboard) set_text(text string) bool {
	#NSString *ns_clip;
	mut ret := false

	#ns_clip = [[ NSString alloc ] initWithBytesNoCopy:text.str length:text.len encoding:NSUTF8StringEncoding freeWhenDone: false];
	#[c->pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	#ret = [c->pb setString:ns_clip forType:NSStringPboardType];
	#[ns_clip release];

	mut serial := 0
	#serial = [c->pb changeCount];
	C.OSAtomicCompareAndSwapLong(c.last_cb_serial, serial, &c.last_cb_serial)
	return ret
}

fn (c &Clipboard) get_text() string {
	#NSString *ns_clip;
	mut utf8_clip := byteptr(0)

	#ns_clip = [c->pb stringForType:NSStringPboardType]; //NSPasteboardTypeString
	#if (ns_clip == nil) {
	#	return tos3(""); //in case clipboard is empty
	#}

	#utf8_clip = [ns_clip UTF8String];
	return string(utf8_clip)
}