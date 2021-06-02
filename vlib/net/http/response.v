module http

import net.http.chunked
import strconv

// Response represents the result of the request
pub struct Response {
pub:
	text   string
	header Header
	// TODO: use Cookie struct
	cookies      map[string]string
	status_code  Status
	http_version Version
}

fn (mut resp Response) free() {
	unsafe { resp.header.data.free() }
}

// Format response as an HTTP response message
pub fn (resp Response) render() string {
	status_code := int(resp.status_code)
	status_msg := resp.status_code.str()
	// add cookie to the header if not already there
	mut header := resp.header.clone()
	if resp.text.len > 0 && !header.contains(.content_length) {
		header.add(.content_length, resp.text.len.str())
	}
	for cookie, value in resp.cookies {
		s := '$cookie=$value'
		if !header.values(.set_cookie).contains(s) {
			header.add(.set_cookie, s)
		}
	}
	return '$resp.http_version $status_code $status_msg\n\r${header.render(
		version: resp.http_version
	)}\n\r$resp.text'
}

// TODO: return result?
pub fn parse_response(resp string) Response {
	mut header := new_header()
	// TODO: Cookie data type
	mut cookies := map[string]string{}
	version, status := parse_response_line(resp.all_before('\n\r')) or {
		Version.unknown, Status.unknown
	}
	mut text := ''
	// Build resp header map and separate the body
	mut nl_pos := 3
	mut i := 1
	for {
		old_pos := nl_pos
		nl_pos = resp.index_after('\n', nl_pos + 1)
		if nl_pos == -1 {
			break
		}
		h := resp[old_pos + 1..nl_pos]
		// End of headers
		if h.len <= 1 {
			text = resp[nl_pos + 1..]
			break
		}
		i++
		pos := h.index(':') or { continue }
		mut key := h[..pos]
		val := h[pos + 2..].trim_space()
		header.add_custom(key, val) or { eprintln('error parsing header: $err') }
	}
	// set cookies
	for cookie in header.values(.set_cookie) {
		parts := cookie.split_nth('=', 2)
		cookies[parts[0]] = parts[1]
	}
	if header.get(.transfer_encoding) or { '' } == 'chunked' || header.get(.content_length) or {
		''
	} == '' {
		text = chunked.decode(text)
	}
	return Response{
		status_code: status
		header: header
		cookies: cookies
		text: text
		http_version: version
	}
}

fn parse_response_line(s string) ?(Version, Status) {
	words := s.split(' ')
	if words.len < 2 {
		return error('malformed response line')
	}
	version := version_from_str(words[0])
	status_code := strconv.atoi(words[1]) ?

	return version, status_from_int(status_code)
}
