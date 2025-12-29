const std = @import("std");

const types = @import("root.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // const buffer = try std.heap.smp_allocator.alloc(u8, 1024 * 1024 * 1024 * 4);
    // defer std.heap.smp_allocator.free(buffer);
    // var fba = std.heap.FixedBufferAllocator.init(buffer);
    // const allocator = fba.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print("Please specify filename", .{});
        return;
    }

    var root_file = try types.RootFile.open(args[1], allocator);
    defer root_file.close();
    var tree = root_file.get("output").?.ttree;
    const energy = (try tree.getArray("energy", f64, allocator)).?;
    defer allocator.free(energy);
    for (energy) |e| {
        std.debug.print("{d:.6}\n", .{e});
    }
}
