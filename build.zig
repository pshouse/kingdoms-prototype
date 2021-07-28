const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("kingdoms", "src/main.zig");
    exe.addCSourceFile("deps/stb_image.c", &[_][]const u8{ "-std=c99"});
    exe.addCSourceFile("deps/stb_easy_font.c", &[_][]const u8{ "-std=c99"});
    exe.addIncludeDir("deps");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    if (target.getOsTag() == .windows and target.getAbi() == .gnu) {
        @import("deps/zig-sdl/build.zig").linkArtifact(b, .{
            .artifact = exe,
            .prefix = "deps/zig-sdl",
            .override_mode = .ReleaseFast,
        });
    } else {
        exe.linkSystemLibrary("SDL2");
    }
    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
