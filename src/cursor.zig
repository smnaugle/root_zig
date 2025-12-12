const std = @import("std");

const util = @import("utilities.zig");

const Cursor = @This();

buffer: []u8 = undefined,
seek: u64 = 0,
origin: i64 = 0,
record: std.AutoHashMapUnmanaged(u64, []u8) = .{},

pub fn init(buffer: []u8) Cursor {
    var cursor = Cursor{};
    cursor.buffer = buffer;
    return cursor;
}

pub fn set_origin(self: *Cursor, origin: i64) void {
    self.origin = origin;
}

pub fn displacement(self: *Cursor) i64 {
    return @as(i64, @bitCast(self.seek)) - self.origin;
}

pub fn get_bytes_as_int(self: *Cursor, comptime T: type) T {
    const value, const next_byte = util.get_buffer_info(self.buffer, self.seek, T);
    self.seek = next_byte;
    return value;
}

pub fn read_u32_and_get_string(self: *Cursor, allocator: std.mem.Allocator) ![]u8 {
    const buffer, self.seek = try util.read_num_bytes_and_name(self.buffer, allocator, self.seek);
    return buffer;
}
