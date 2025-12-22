const std = @import("std");

pub const Array = struct {
    items: *anyopaque = undefined,
    len: usize = 0,
    _bits: u16 = 0,

    _allocator: std.mem.Allocator = undefined,
    pub fn init(comptime T: type, len: usize, allocator: std.mem.Allocator) !Array {
        var array = Array{};
        array.items = (try allocator.alloc(T, len)).ptr;
        array.len = len;
        array._allocator = allocator;
        var bits: u16 = 0;
        const ti = @typeInfo(T);
        switch (ti) {
            inline else => |t| bits = t.bits,
        }
        std.debug.assert((bits % 8) == 0);
        array._bits = bits;
        return array;
    }

    pub fn deinit(self: *Array) void {
        // Here we do not care about type, just the range of memory that must be removed
        const item_ptr: [*]u8 = @ptrCast(@alignCast(self.items));
        const items: []u8 = item_ptr[0..(self.len * (self._bits / 8))];
        self._allocator.free(items);
        self.* = undefined;
    }

    // pub fn asSlice(self: Array) []T {
    //
    // }
};
