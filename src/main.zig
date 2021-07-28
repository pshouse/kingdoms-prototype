
const std = @import("std");
const c = @import("c.zig");

const stronghold_png_data = @embedFile("../assets/graphics/buildings/Seats-of-power.png");

const Stronghold = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};
pub fn main() anyerror!void {
    //std.log.info("All your domain are belong to us.", .{});
    // if (!(c.SDL_SetHintWithPriority(c.SDL_HINT_NO_SIGNAL_HANDLERS, "1" , c.SDL_HintPriority.SDL_HINT_OVERRIDE) != c.SDL_bool.SDL_FALSE)) {
    //     std.debug.panic("failed to disable sdl signal handlers\n", .{});
    // }
    var width: c_int = undefined;
    var height: c_int = undefined;
    const image_data = c.stbi_load_from_memory(stronghold_png_data, @intCast(c_int, stronghold_png_data.len), &width, &height, null, 4);

    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS | c.SDL_INIT_AUDIO) < 0)
        {std.debug.panic("SDL_Init failed: {s}\n", .{c.SDL_GetError()});}
    defer c.SDL_Quit();

    const screen = c.SDL_CreateWindow(
        "K1ngd0m5",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        800,
        600,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.debug.panic("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        std.debug.panic("SDL_CreateRenderer failed: {s}", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyRenderer(renderer);
    const pitch = width * 4; // width * bits_per_channel * channel_count / 8
    const stronghold_surface = c.SDL_CreateRGBSurfaceFrom(image_data, width, height, 32, pitch, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
    const stronghold_texture = c.SDL_CreateTextureFromSurface(renderer, stronghold_surface) orelse std.debug.panic("unable to convert surface to texture", .{});
    
    const stronghold = Stronghold {
        .x = 400,
        .y = 400,
        .w = 148,
        .h = 128,
    };

    while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => return,
                else => {},
            }
        }

        sdlAssertZero(c.SDL_RenderClear(renderer));
        const src_rect = c.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = 148,
            .h = 128,
        };
        const dest_rect = c.SDL_Rect{
            .x = stronghold.x,
            .y = stronghold.y,
            .w = stronghold.w,
            .h = stronghold.h,
        };
        sdlAssertZero(c.SDL_RenderCopy(renderer, stronghold_texture, &src_rect, &dest_rect));
        c.SDL_RenderPresent(renderer);
    }
}

fn sdlAssertZero(ret: c_int) void {
    if (ret == 0) return;
    std.debug.panic("sdl function returned an error: {s}\n", .{c.SDL_GetError()});
}
