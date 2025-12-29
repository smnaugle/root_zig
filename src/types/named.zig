const std = @import("std");

const types = @import("../root.zig");
const util = @import("../utilities.zig");
const Cursor = @import("../cursor.zig");

pub const TNamed = struct {
    const TOBJ_LEN: u8 = 10;
    header: types.ClassHeader = undefined,
    t_object: [TOBJ_LEN]u8 = undefined,
    name: []u8 = undefined,
    title: []u8 = undefined,
    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TNamed {
        var tnamed = TNamed{};
        const start = cursor.seek;
        tnamed.header = types.ClassHeader.init(cursor);
        tnamed.name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, @truncate(cursor.seek + TOBJ_LEN));
        tnamed.title, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, @truncate(cursor.seek));
        tnamed.num_bytes = cursor.seek - start;
        return tnamed;
    }
};
