module main

import sdl

fn main() {
	window := C.SDL_CreateWindow('Hello SDL2', 300, 300, 500, 300, 0)
	renderer := C.SDL_CreateRenderer(window, -1, C.SDL_RENDERER_ACCELERATED | C.SDL_RENDERER_PRESENTVSYNC)
	
/*	sdl.create_window_and_renderer(800, 600, 0, &sdlc.window, &sdlc.renderer)
	C.SDL_SetWindowTitle(sdlc.window, 'Hello SDL!`)*/

	mut should_close := false
	for {
		ev := sdl.Event{}
		for 0 < sdl.poll_event(&ev) {
			match int(ev._type) {
				C.SDL_QUIT { should_close = true }
				else {}
			}
		}
		if should_close {
			break
		}

		C.SDL_SetRenderDrawColor(renderer, 255, 55, 55, 255)
		C.SDL_RenderClear(renderer)
		C.SDL_RenderPresent(renderer)
	}
}
