const std = @import("std");
const c = @import("c.zig");
const unit = @import("unit.zig");

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

const OrgType = enum {party, regiment, guild, circle, pact, court, order, syndicate};
const orgLabels: [8][]const u8 = .{
    "Adventuring Party",
    "Martial Regiment",
    "Mercantile Guild",
    "Mystic Circle",
    "Nature Pact",
    "Noble Court",
    "Relious Order",
    "Underworld Syndicate",
};

const Org = struct {
    type: OrgType,
    size: i32,
    label: []const u8,
    dev_points: i32,
    units: [4]unit.Unit,
    pub fn turns() i32 {
        return size + 4;
    }
};
const Orgs = std.MultiArrayList(Org);

const RealmType = enum {despotic_regime, draconic_empire, dwarven_thanedom, fey_court, giant_jarldom, 
                    gnomish_kingdom, goblinoid_coalition, hag_coven, infernal_eschelon, medusean_tyranny,
                    orc_clan, planar_invaders, reptialian_band, undead_dominion, undersea_colony, world_below_city_state};
const realmLabels: [16][]const u8 = .{
    "Despotic Regime", 
    "Draconic Empire", 
    "Dwarven Thanedom", 
    "Fey Court", 
    "Giant Jarldom",
    "Gnomish Kingdom", 
    "Goblinoid Coalition", 
    "Hag Coven", 
    "Infernal Eschelon", 
    "Medusean Tyranny",
    "Orc Clan", 
    "Planar Invaders", 
    "Reptialian Band", 
    "Undead Dominion", 
    "Undersea Colony", 
    "World Below City-State",
};

const Realm = struct {
    type: RealmType,
    size: i32,
    label: []const u8,
    pub fn turns() i32 {
        return size + 4;
    }
};

const Realms = std.MultiArrayList(Realm);

const Player = struct {
    org: Org,
};

const Enemy = struct {
    realm: Realm,
};

const GameState = enum(u32) {
    greetings,
    stronghold_acquired,
    choose_org,
    org_founded,
    realm_founded,
    dev_points_spent,
    tier_i_units_mustered,
};

const Game = struct {
    state: GameState,
    time: u64,
};

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;
    
    var units = init_units();

    var orgs = Orgs{};
    defer orgs.deinit(allocator);
    
    for (std.enums.values(OrgType)) |orgType, i| {
        const org = Org {
            .type = orgType,
            .size = 1,
            .label = orgLabels[i],
            .dev_points = 8,
            .units = undefined,
        };
        try orgs.append(allocator, org);
    }
    
    var player = Player{
        .org = undefined,
    };

    var realms = Realms{};
    defer realms.deinit(allocator);

    for (std.enums.values(RealmType)) |realmType, i| {
        const realm = Realm {
            .type = realmType,
            .size = 1,
            .label = realmLabels[i],
        };
        try realms.append(allocator, realm);
    }
    
    // var realm_selected: u32 = std.crypto.random.intRangeAtMost(u32, 0, 15);
    const realm_selected: u32 = 13;
    var enemy = Enemy {
        .realm = realms.get(realm_selected),
    };

    var game = Game {
        .state = GameState.greetings,
        .time = 0,
    };

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
    
    const Screen = struct {
        w: i32,
        h: i32,
    };

    const screen: Screen =  .{
        .w = 800,
        .h = 600,
    };
    
    const window = c.SDL_CreateWindow(
        "K1ngd0m5",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        screen.w,
        screen.h,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.debug.panic("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyWindow(window);

    const renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(window, -1, 0) orelse {
        std.debug.panic("SDL_CreateRenderer failed: {s}", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyRenderer(renderer);
    const pitch = width * 4; // width * bits_per_channel * channel_count / 8
    const stronghold_surface = c.SDL_CreateRGBSurfaceFrom(image_data, width, height, 32, pitch, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
    const stronghold_texture = c.SDL_CreateTextureFromSurface(renderer, stronghold_surface) orelse std.debug.panic("unable to convert surface to texture", .{});
    
    const stronghold = Stronghold {
        .x = (screen.w/2) - (148/2),
        .y = 425,
        .w = 148,
        .h = 128,
    };

    while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => return,
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.scancode) {
                        c.SDL_SCANCODE_ESCAPE => return,
                        30...37 => {
                            var i: u32 = event.key.keysym.scancode - 30;
                            if (game.state == GameState.choose_org) {
                                var selected_org = orgs.get(i);
                                std.debug.print("Selected: {s}\n", .{selected_org.label});
                                player.org = selected_org;
                                game.state = GameState.org_founded;
                                // game.state = GameState.dev_points_spent;
                            }
                            else if (game.state == GameState.realm_founded and i < units.len) {
                            // else if (game.state == GameState.realm_founded and i < 6) {
                                var selected_unit = units[i];
                                std.debug.print("Selected: {s}\n", .{selected_unit.name});
                                player.org.units[0] = selected_unit;
                                std.debug.print("units: {s}", .{player.org.units[0]});
                            }
                            
                        },
                        //c.SDL_SCANCODE_2 => std.debug.print("Selected: {s}\n", .{orgs.get(1).label}),
                        else => std.debug.warn("key pressed: {}\n", .{event.key.keysym.scancode}),
                    }
                },
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

        if (game.state == GameState.stronghold_acquired ) {
            try drawText(info, 10, 10,
                "You have acquired a STRONGHOLD.",
                allocator, renderer, &glyph_map
            );
            
            if (30*10 < game.time ) game.state = GameState.choose_org;
        }

        if (@enumToInt(game.state) >= @enumToInt(GameState.stronghold_acquired)) {

            sdlAssertZero(c.SDL_RenderCopy(renderer, stronghold_texture, &src_rect, &dest_rect));
            
            if (@enumToInt(game.state) >= @enumToInt(GameState.org_founded)) {
                var buf: [105]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "Your {s}", .{player.org.label});
                try drawText(info, stronghold.x, stronghold.y+stronghold.h+10, 
                    msg, allocator, renderer, &glyph_map);
                game.state = GameState.realm_founded;
            }
        }
        
        if (@enumToInt(game.state) >= @enumToInt(GameState.tier_i_units_mustered)) {
            const realm_dest = c.SDL_Rect{
                .x = stronghold.x,
                .y = stronghold.y  - 400,
                .w = stronghold.w,
                .h = stronghold.h,
            };  
            sdlAssertZero(c.SDL_RenderCopy(renderer, stronghold_texture, &src_rect, &realm_dest));
            
            var buf: [105]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "Enemy {s}", .{enemy.realm.label});
            try drawText(info, stronghold.x, realm_dest.y+realm_dest.h+10, 
                msg, allocator, renderer, &glyph_map);
            //    game.state = GameState.realm_founded;
            
        }
        // render some text
        // NOTE: passing glyph_map instead of &glyph_map doesn't compile because parameters are immutable
        // place holder text courtsy: https://lotremipsum.com/result-basic.php
        if (game.state == GameState.greetings) {
            try drawText(info, 10, 10,
            "Greetings adventurer!\n\nHelm Hammerhand awake iron cost hunting clear must.\nDwalin forebearers precautions shovel liege goes.Arod \nmorbid roads. Reached signature Goblin-mutant?", 
            allocator, renderer, &glyph_map);
            if (30*2 < game.time) game.state = GameState.stronghold_acquired;
        }
        
        // const y: usize = 10 + 3 * 32;
        if (game.state == GameState.choose_org) {
            try drawText(info, 10, 10,
                "Found a DOMAIN of your choosing:",
                allocator, renderer, &glyph_map
            );
            for(orgLabels) |label, j| {
                var buffer: [100]u8 = undefined;
                const choices = try std.fmt.bufPrint(&buffer,"{d} ~ {s}", .{@intCast(i32, j)+1, label});
                // std.debug.print("{s}", .{slice});
                try drawText(
                    info, 32, (10+1*32)+@intCast(i32, j)*32,
                    choices,
                    allocator, renderer, &glyph_map
                );
            }
        }
        if (game.state == GameState.realm_founded) {
            try drawText(info, 10, 10,
                "Muster a UNIT of your choosing:",
                allocator, renderer, &glyph_map
            );
            for(units) |u, k| {
                var buf: [100]u8 = undefined;
                const choices = try std.fmt.bufPrint(&buf, "{d} ~ {s}", .{@intCast(i32, k)+1, u.name});
                try drawText(
                    info, 32, (10+1*32)+@intCast(i32, k)*32,
                    choices,
                    allocator, renderer, &glyph_map
                );
            }
        }
        c.SDL_RenderPresent(renderer);
        game.time += 1;
        // std.debug.print("{d}\n", .{game.time});
    }
}

fn init_units() [6]unit.Unit {
    var human_infantry = unit.Unit {
        .name = "Human Infantry",
        .size = 6,
        .tier = 1,
        .type = unit.UnitType.infantry,
        .atk = 3,
        .def = 12,
        .pow = 2,
        .tou = 12,
        .mor = 1,
        .com = 2,
        .dmg = 1,
        .slots = undefined,
        .active_slots = 0,
        .attacks = 1,
        .movement = 1,
        .ancestry = unit.Ancestry.human,
        .condition = undefined,
    };

    _ = human_infantry.assign_trait(.{ .type = .adaptable });
    // std.debug.print("unit_traits: {s}", .{unit_traits});
    
    var human_artilery = unit.Unit {
        .name = "Human artilery",
        .size = 6,
        .tier = 1,
        .type = unit.UnitType.artilery,
        .atk = 3,
        .def = 10,
        .pow = 2,
        .tou = 8,
        .mor = 1,
        .com = 2,
        .dmg = 1,
        .slots = undefined,
        .active_slots = 0,
        .attacks = 1,
        .movement = 1,
        .ancestry = unit.Ancestry.human,
        .condition = undefined,
    };
    _ = human_artilery.assign_trait(.{.type = .adaptable});
    var human_cavalry = unit.Unit {
        .name = "Human Cavalry",
        .size = 6,
        .tier = 1,
        .type = unit.UnitType.cavalry,
        .atk = 3,
        .def = 12,
        .pow = 3,
        .tou = 10,
        .mor = 1,
        .com = 1,
        .dmg = 2,
        .slots = undefined,
        .active_slots = 0,
        .attacks = 1,
        .movement = 1,
        .ancestry = unit.Ancestry.human,
        .condition = undefined,
    };
     _ = human_cavalry.assign_trait(.{.type = .adaptable});
    var zombie_infantry = unit.Unit {
        .name = "Zombie Infantry",
        .size = 6,
        .tier = 1,
        .type = unit.UnitType.infantry,
        .atk = 2,
        .def = 11,
        .pow = 1,
        .tou = 13,
        .mor = 0,
        .com = 1,
        .slots = undefined,
        .active_slots = 0,
        .dmg = 1,
        .attacks = 1,
        .movement = 1,
        .ancestry = unit.Ancestry.undead,
        .condition = undefined,
    };
     _ = zombie_infantry.assign_trait(.{.type = .dead});
     _ = zombie_infantry.assign_trait(.{.type = .harrowing});
     _ = zombie_infantry.assign_trait(.{.type = .relentless});

    var skeletal_artilery = unit.Unit {
        .name = "Skeletal Archers",
        .size = 4,
        .tier = 1,
        .type = unit.UnitType.artilery,
        .atk = 3,
        .def = 9,
        .pow = 1,
        .tou = 8,
        .mor = 0,
        .com = 0,
        .slots = undefined,
        .active_slots = 0,
        .dmg = 1,
        .attacks = 1,
        .movement = 1,
        .ancestry = unit.Ancestry.undead,
        .condition = undefined,
    };

    var skeletal_cavalry = unit.Unit {
        .name = "Skeletal Cavalry",
        .size = 4,
        .tier = 1,
        .type = unit.UnitType.cavalry,
        .atk = 3,
        .def = 11,
        .pow = 2,
        .tou = 10,
        .mor = 0,
        .com = 0,
        .slots = undefined,
        .active_slots = 0,
        .dmg = 2,
        .attacks = 1,
        .movement = 1,
        .ancestry = unit.Ancestry.undead,
        .condition = undefined,
    };

    return .{
        human_infantry,
        human_artilery,
        human_cavalry,
        zombie_infantry,
        skeletal_artilery,
        skeletal_cavalry,
    };
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
                
                    // var argb_bitmap = std.ArrayList(u8).init(allocator);
                    var argb_bitmap = std.ArrayList(u8).init(allocator);
                    // defer argb_bitmap.deinit();
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
                    defer c.SDL_DestroyTexture(text_texture);
                
                    sdlAssertZero(c.SDL_UpdateTexture(text_texture, 0, result.bitmap.items.ptr, result.w*4));
                   
                    const text_src_rect = c.SDL_Rect{
                        .x = 0,
                        .y = 0,
                        .w = result.w,
                        .h = result.h ,
                    };
                    const text_dest_rect = c.SDL_Rect{
                        .x = x,
                        .y = y,
                        .w = result.w,
                        .h = result.h,
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
