module vweb

import net.urllib
import net.http

// Parsing function attributes for methods and path.
fn parse_attrs(name string, attrs []string) ?([]http.Method, string) {
	if attrs.len == 0 {
		return [http.Method.get], '/$name'
	}

	mut x := attrs.clone()
	mut methods := []http.Method{}
	mut path := ''

	for i := 0; i < x.len; {
		attr := x[i]
		attru := attr.to_upper()
		m := http.method_from_str(attru)
		if attru == 'GET' || m != .get {
			methods << m
			x.delete(i)
			continue
		}
		if attr.starts_with('/') {
			if path != '' {
				return IError(&MultiplePathAttributesError{})
			}
			path = attr
			x.delete(i)
			continue
		}
		i++
	}
	if x.len > 0 {
		return IError(&UnexpectedExtraAttributeError{
			msg: 'Encountered unexpected extra attributes: $x'
		})
	}
	if methods.len == 0 {
		methods = [http.Method.get]
	}
	if path == '' {
		path = '/$name'
	}
	// Make path lowercase for case-insensitive comparisons
	return methods, path.to_lower()
}

fn parse_query_from_url(url urllib.URL) map[string]string {
	query := map[string]string{}
	for k, v in url.query().data {
		query[k] = v.data[0]
	}
	return query
}

fn parse_form_from_request(request http.Request) (map[string]string, map[string][]http.FileData) {
	form := map[string]string{}
	files := map[string]string{}
	if request.method in vweb.methods_with_form {
		ct := request.header.get(.content_type) or { '' }.split(';').map(it.trim_left(' \t'))
		if 'multipart/form-data' in ct {
			boundary := ct.filter(it.starts_with('boundary='))
			if boundary.len != 1 {
				conn.write(vweb.http_400.bytes()) or {}
				return
			}
			form, files = http.parse_multipart_form(request.data, boundary[0][9..])
		} else {
			form = http.parse_form(request.data)
		}
	}
	return form, files
}