// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module http

fn download_file_with_progress(url, out string, cb, cb_finished voidptr) {
}

pub fn download_file(url, out string) {
	// C.URLDownloadToFileW(0, url.to_wide(), out.to_wide(), 0, 0)
	/*
	if (res == S_OK) {
	println('Download Ok')
	# } else if(res == E_OUTOFMEMORY) {
	println('Buffer length invalid, or insufficient memory')
	# } else if(res == INET_E_DOWNLOAD_FAILURE) {
	println('URL is invalid')
	# } else {
	# printf("Download error: %d\n", res);
	# }
	*/
}
