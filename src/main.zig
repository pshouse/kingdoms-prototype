
const std = @import("std");
const c = @import("c.zig");

const stronghold_png_data = @embedFile("../assets/graphics/buildings/Seats-of-power.png");

const font_data = @embedFile("../assets/fonts/Kingthings_Petrock.ttf");

const Stronghold = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

const GlyphMapEntry = struct {
    w: i32,
    h: i32,
    bitmap: std.ArrayList(u8),
};

pub fn main() anyerror!void {
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // var allocator = &arena.allocator;
    var allocator = std.heap.page_allocator;
    

    var glyph_map = std.AutoHashMap(u8, GlyphMapEntry).init(allocator);
    defer glyph_map.deinit();

    //std.log.info("All your domain are belong to us.", .{});
    // if (!(c.SDL_SetHintWithPriority(c.SDL_HINT_NO_SIGNAL_HANDLERS, "1" , c.SDL_HintPriority.SDL_HINT_OVERRIDE) != c.SDL_bool.SDL_FALSE)) {
    //     std.debug.panic("failed to disable sdl signal handlers\n", .{});
    // }

    // Initialize TTF
    // var info: c.stbtt_fontinfo = undefined;
    
    var info: c.stbtt_fontinfo = undefined;
    const init_result = c.stbtt_InitFont(&info, font_data,0);
    if (init_result != 1) {
        std.debug.panic("font initialization failed", .{});
    }

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
        
        // render some text
        // NOTE: passing glyph_map instead of &glyph_map doesn't compile because parameters are immutable
        try drawText(info, 10, 10,
            "Greetings adventurer!\nYou've been granted a stronghold.", 
            allocator, renderer, &glyph_map);
        
        c.SDL_RenderPresent(renderer);
    }
}

fn drawText(info: c.stbtt_fontinfo, x0: i32, y0: i32, 
    text:  []const u8, allocator: *std.mem.Allocator, 
    renderer: *c.SDL_Renderer, glyph_map: *std.AutoHashMap(u8, GlyphMapEntry)) anyerror!void {

    var b_w: i32 = undefined;
    var b_h: i32 = undefined;
    const l_h: i32 = 32;

    var bitmap: [*]u8 = undefined;

    var scale: f32 = c.stbtt_ScaleForPixelHeight(&info, l_h);

    var ascent: i32 = undefined;
    var descent: i32 = undefined;
    var lineGap: i32 = undefined;

    c.stbtt_GetFontVMetrics(&info, &ascent, &descent, &lineGap);
    ascent = @floatToInt(i32, std.math.round(@intToFloat(f32, ascent) * scale));
    descent = @floatToInt(i32, std.math.round(@intToFloat(f32, descent) * scale));
    var x: i32 = x0;
    var y_base: i32 = y0;

    for (text) |char| {
        var ax: i32 = 0;
        var lsb: i32 = 0;
        c.stbtt_GetCodepointHMetrics(&info, char, &ax, &lsb);

        var c_x1: i32 = 0;
        var c_y1: i32 = 0;
        var c_x2: i32 = 0;
        var c_y2: i32 = 0;
        c.stbtt_GetCodepointBitmapBox(&info, char, scale, scale, &c_x1, &c_y1, &c_x2, &c_y2);

        var y: i32 = y_base + ascent + c_y1;
        if (char == '\n') {
            y_base += l_h;
            x = x0; 
        } else { 
            if (c_x2 > 0 or c_y2 >0)  { //check for empty bitmap
                if (!glyph_map.contains(char)) {
                    bitmap = c.stbtt_GetCodepointBitmap(&info, 0.0, scale, char, &b_w, &b_h, 0, 0);
                
                    var argb_bitmap = std.ArrayList(u8).init(allocator);
                    var num_bytes = b_w*b_h;
                    var b_i: usize = 0;
                    
                    while (b_i<num_bytes) {
                        try argb_bitmap.append(bitmap[b_i]);
                        try argb_bitmap.append(bitmap[b_i]);
                        try argb_bitmap.append(bitmap[b_i]);
                        try argb_bitmap.append(bitmap[b_i]);
                        b_i+=1;
                    }
                    
                    var new_entry: GlyphMapEntry = .{
                        .w = b_w,
                        .h = b_h,
                        .bitmap = argb_bitmap,
                    };
                    
                    try glyph_map.put(char, new_entry);

                } 
                
                if(glyph_map.get(char)) |result| {
                    const text_texture = c.SDL_CreateTexture(
                        renderer, c.SDL_PIXELFORMAT_ARGB8888, 
                        c.SDL_TEXTUREACCESS_STREAMING, result.w, result.h
                    );
                    sdlAssertZero(c.SDL_UpdateTexture(text_texture, 0, result.bitmap.items.ptr, result.w*4));
                   
                    const text_src_rect = c.SDL_Rect{
                        .x = 0,
                        .y = 0,
                        .w = b_w,
                        .h = b_h,
                    };
                    const text_dest_rect = c.SDL_Rect{
                        .x = x,
                        .y = y,
                        .w = b_w,
                        .h = b_h,
                    };
                    sdlAssertZero(c.SDL_RenderCopy(renderer, text_texture, &text_src_rect, &text_dest_rect));
                }
            }
            x += @floatToInt(c_int, std.math.round(@intToFloat(f32, ax) * scale));
        }
        // TODO: figure out how to get this working.
        // var kern: c_int = c.stbtt_GetCodepointKernAdvance(&info, text[i], text[i+1]);
        // x += @floatToInt(c_int, std.math.round(@intToFloat(f32, kern) * scale));
    }

}
fn sdlAssertZero(ret: c_int) void {
    if (ret == 0) return;
    std.debug.panic("sdl function returned an error: {s}\n", .{c.SDL_GetError()});
}
