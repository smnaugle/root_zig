const std = @import("std");
const mem = std.mem;

const types = @import("../root_types.zig");
const Cursor = @import("../cursor.zig");

pub const TStreamerElement = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    named: types.TNamed = undefined,
    dtype: u32 = undefined,
    size: u32 = undefined,
    array_length: u32 = undefined,
    array_dim: u32 = undefined,
    max_index: [5]u32 = undefined,
    type_name: []u8 = undefined,

    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerElement {
        const start = cursor.seek;
        var element: TStreamerElement = .{};
        element.header = .init(cursor);
        element.named = try .init(cursor, allocator);
        element.dtype = cursor.get_bytes_as_int(@TypeOf(element.dtype));
        element.size = cursor.get_bytes_as_int(@TypeOf(element.size));
        element.array_length = cursor.get_bytes_as_int(@TypeOf(element.array_length));
        element.array_dim = cursor.get_bytes_as_int(@TypeOf(element.array_dim));
        for (0..element.max_index.len) |idx| {
            element.max_index[idx] = cursor.get_bytes_as_int(std.meta.Child(@TypeOf(element.max_index)));
        }
        element.type_name = try cursor.read_u32_and_get_string(allocator);
        element.num_bytes = cursor.seek - start;
        return element;
    }
};

pub const TStreamerBase = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    // Specific info
    base_version: u32 = undefined,

    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerBase {
        const start = cursor.seek;
        var streamer_base: TStreamerBase = .{};
        streamer_base.header = .init(cursor);
        streamer_base.element = try .init(cursor, allocator);
        streamer_base.base_version = cursor.get_bytes_as_int(@TypeOf(streamer_base.base_version));
        streamer_base.num_bytes = cursor.seek - start;
        return streamer_base;
    }
};

pub const TStreamerBasicType = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerBasicType {
        const start = cursor.seek;
        var streamer: TStreamerBasicType = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerString = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerString {
        const start = cursor.seek;
        var streamer: TStreamerString = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerBasicPointer = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    // Specific info
    count_version: u32 = undefined,
    count_name: []u8 = undefined,
    count_class: []u8 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerBasicPointer {
        const start = cursor.seek;
        var streamer: TStreamerBasicPointer = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.count_version = cursor.get_bytes_as_int(@TypeOf(streamer.count_version));
        streamer.count_name = try cursor.read_u32_and_get_string(allocator);
        streamer.count_class = try cursor.read_u32_and_get_string(allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerObject = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerObject {
        const start = cursor.seek;
        var streamer: TStreamerObject = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerObjectPointer = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerObjectPointer {
        const start = cursor.seek;
        var streamer: TStreamerObjectPointer = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerLoop = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    // Specific info
    count_version: u32 = undefined,
    count_name: []u8 = undefined,
    count_class: []u8 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerLoop {
        const start = cursor.seek;
        var streamer: TStreamerLoop = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.count_version = cursor.get_bytes_as_int(@TypeOf(streamer.count_version));
        streamer.count_name = try cursor.read_u32_and_get_string(allocator);
        streamer.count_class = try cursor.read_u32_and_get_string(allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerObjectAny = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerObjectAny {
        const start = cursor.seek;
        var streamer: TStreamerObjectAny = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerSTL = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    element: TStreamerElement = undefined,

    // Specific info
    stl_type: u32 = undefined,
    ctype: u32 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerSTL {
        const start = cursor.seek;
        var streamer: TStreamerSTL = .{};
        streamer.header = .init(cursor);
        streamer.element = try .init(cursor, allocator);
        streamer.stl_type = cursor.get_bytes_as_int(@TypeOf(streamer.stl_type));
        streamer.ctype = cursor.get_bytes_as_int(@TypeOf(streamer.ctype));
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};

pub const TStreamerSTLstring = struct {
    // Class tag handled by reader - not currently included in structs
    header: types.ClassHeader = undefined,
    streamer_stl: TStreamerSTL = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: mem.Allocator) !TStreamerSTLstring {
        const start = cursor.seek;
        var streamer: TStreamerSTLstring = .{};
        streamer.header = .init(cursor);
        streamer.streamer_stl = try .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
        return streamer;
    }
};
