const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zr = b.addModule(
        "zroot",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        },
    );
    const zrlib = b.addLibrary(.{ .name = "zroot", .root_module = zr, .linkage = .static });
    b.installArtifact(zrlib);

    const exe = b.addExecutable(.{
        .name = "reader",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);
}
