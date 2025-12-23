const std = @import("std");

const Cursor = @import("../cursor.zig");

pub const TString = struct {
    string: []u8 = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TString {
        var string: TString = .{};
        var idx: u32 = 0;
        for (cursor.buffer[cursor.seek..]) |b| {
            idx = idx + 1;
            if (b == 0x00) break;
        }
        string.string = try allocator.alloc(u8, idx);
        @memcpy(string.string, cursor.buffer[cursor.seek..(cursor.seek + idx)]);
        cursor.seek += idx;
        return string;
    }
};
