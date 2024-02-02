import time
import x.vweb

// See https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
// and https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#preflighted_requests
// >  Cross-Origin Resource Sharing (CORS) is an HTTP-header based mechanism that allows
// >  a server to indicate any origins (domain, scheme, or port) other than its own from
// >  which a browser should permit loading resources...

// Usage: do `./v run examples/xvweb/cors/` to start the app,
// then check the headers in another shell:
//
// 1) `curl -vvv -X OPTIONS http://localhost:45678/time`
// 2) `curl -vvv -X POST http://localhost:45678/time`

pub struct Context {
	vweb.Context
}

pub struct App {
	vweb.Middleware[Context]
}

// time is a simple POST request handler, that returns the current time. It should be available
// to JS scripts, running on arbitrary other origins/domains.
@[post]
pub fn (app &App) time(mut ctx Context) vweb.Result {
	return ctx.json({
		'time': time.now().format_ss_milli()
	})
}

// no_cors is a simple POST request handler, that returns a string.
// For this example we don't want to expose the private route to any other origins/domains.
@[post]
pub fn (app &App) no_cors(mut ctx Context) vweb.Result {
	return ctx.text('not available for cross-origin domains')
}

fn main() {
	println("
To test, if CORS works, copy this JS snippet, then go to for example https://stackoverflow.com/ , 
press F12, then paste the snippet in the opened JS console. You should see the vweb server's time:
	
var xhr = new XMLHttpRequest();
xhr.onload = function(data) {
	console.log('xhr loaded');
	console.log(xhr.response);
};
xhr.open('POST', 'http://localhost:45678/time');
xhr.send();
	")

	mut app := &App{}

	// use vweb's cors middleware to handle CORS requests
	app.use(vweb.cors[Context](vweb.CorsOptions{
		// allow CORS requests from every domain
		origin: '*'
		// allow CORS requests with the following request methods:
		allowed_methods: [.get, .head, .patch, .put, .post, .delete]
	}))

	vweb.run[App, Context](mut app, 45678)
}
