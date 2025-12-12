const std = @import("std");

/// Returns a file from a relative for full path.
/// Caller owns the file.
pub fn open_file(rel_path: []u8) !std.fs.File {
    const cur_dir = std.fs.cwd();
    var scratch: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = cur_dir.realpath(rel_path, &scratch) catch |err| {
        std.log.err("{any}", .{err});
        return err;
    };
    const file = try std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only });
    return file;
}

// Assumes start byte is the size of the next object to read
pub fn read_num_bytes_and_name(buffer: []u8, allocator: std.mem.Allocator, start_byte: u64) !struct { []u8, u64 } {
    const object_name_bytes = std.mem.readVarInt(u8, buffer[start_byte..(start_byte + 1)], .big);
    const object_name = try allocator.alloc(u8, @intCast(object_name_bytes + 1));
    const object_name_start_byte = start_byte + 1;
    @memcpy(object_name[0..object_name_bytes], buffer[@intCast(object_name_start_byte)..@intCast(object_name_start_byte + object_name_bytes)]);
    // Add a null terminator
    object_name[object_name.len - 1] = 0;
    const object_end_bytes = object_name_start_byte + object_name_bytes;
    return .{ object_name, object_end_bytes };
}

pub fn get_buffer_info(buffer: []u8, start_byte: u64, comptime T: type) struct { T, u64 } {
    const fsize = comptime @sizeOf(T);
    const field: T = std.mem.readVarInt(
        T,
        buffer[start_byte..@intCast(start_byte + fsize)],
        .big,
    );
    return .{ field, start_byte + fsize };
}

pub fn date_time(root_date_time: u32) struct { year: u32, month: u32, day: u32, hour: u32, minute: u32, second: u32 } {
    const year = ((root_date_time & 0b11111100000000000000000000000000) >> 26) + 1995;
    const month = ((root_date_time & 0b00000011110000000000000000000000) >> 22);
    const day = ((root_date_time & 0b00000000001111100000000000000000) >> 17);
    const hour = ((root_date_time & 0b00000000000000011111000000000000) >> 12);
    const minute = ((root_date_time & 0b00000000000000000000111111000000) >> 6);
    const second = (root_date_time & 0b00000000000000000000000000111111);
    return .{ .year = year, .month = month, .day = day, .hour = hour, .minute = minute, .second = second };
}
