const std = @import("std");

const types = @import("../root.zig");
const Cursor = @import("../cursor.zig");

pub const TLeaf = struct {
    header: types.ClassHeader = undefined,
    named: types.TNamed = undefined,
    len: u32 = undefined,
    len_type: u32 = undefined,
    offset: u32 = undefined,
    is_range: u8 = undefined,
    is_unsigned: u8 = undefined,
    // FIXME: v Uproot uses read_object_any for this, perhaps the bcnt==0 branch?
    leaf_counts: u32 = undefined,

    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TLeaf {
        var leaf = TLeaf{};
        const start = cursor.seek;
        leaf.header = .init(cursor);
        leaf.named = try .init(cursor, allocator);
        leaf.len = cursor.get_bytes_as_int(@TypeOf(leaf.len));
        leaf.len_type = cursor.get_bytes_as_int(@TypeOf(leaf.len_type));
        leaf.offset = cursor.get_bytes_as_int(@TypeOf(leaf.offset));
        leaf.is_range = cursor.get_bytes_as_int(@TypeOf(leaf.is_range));
        leaf.is_unsigned = cursor.get_bytes_as_int(@TypeOf(leaf.is_unsigned));
        leaf.leaf_counts = cursor.get_bytes_as_int(@TypeOf(leaf.leaf_counts));
        // leaf.num_bytes = next_byte;
        // FIXME: Something wrong with leaf counts parsing
        leaf.num_bytes = cursor.seek - start;
        // leaf.num_bytes = leaf.header.byte_counts + 4;
        // cursor.seek = start + leaf.num_bytes;
        return leaf;
    }
};

pub const TLeafElement = struct {
    header: types.ClassHeader = undefined,
    leaf: TLeaf = undefined,
    id: u32 = undefined,
    type: u32 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TLeafElement {
        var leaf_element: TLeafElement = .{};
        const start = cursor.seek;
        leaf_element.header = .init(cursor);
        leaf_element.leaf = try .init(cursor, allocator);
        leaf_element.id = cursor.get_bytes_as_int(@TypeOf(leaf_element.id));
        leaf_element.type = cursor.get_bytes_as_int(@TypeOf(leaf_element.type));
        leaf_element.num_bytes = cursor.seek - start;
        return leaf_element;
    }
};

pub const TLeafI = struct {
    header: types.ClassHeader = undefined,
    leaf: TLeaf = undefined,
    minimum: u32 = undefined,
    maximum: u32 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TLeafI {
        var leafi = TLeafI{};
        const start = cursor.seek;
        leafi.header = .init(cursor);
        leafi.leaf = try .init(cursor, allocator);
        leafi.minimum = cursor.get_bytes_as_int(@TypeOf(leafi.minimum));
        leafi.maximum = cursor.get_bytes_as_int(@TypeOf(leafi.maximum));
        leafi.num_bytes = cursor.seek - start;
        return leafi;
    }
};

pub const TLeafL = struct {
    header: types.ClassHeader = undefined,
    leaf: TLeaf = undefined,
    minimum: u64 = undefined,
    maximum: u64 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TLeafL {
        var leafl = TLeafL{};
        const start = cursor.seek;
        leafl.header = .init(cursor);
        leafl.leaf = try .init(cursor, allocator);
        leafl.minimum = cursor.get_bytes_as_int(@TypeOf(leafl.minimum));
        leafl.maximum = cursor.get_bytes_as_int(@TypeOf(leafl.maximum));
        leafl.num_bytes = cursor.seek - start;
        return leafl;
    }
};

pub const TLeafD = struct {
    header: types.ClassHeader = undefined,
    leaf: TLeaf = undefined,
    minimum: f64 = undefined,
    maximum: f64 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TLeafD {
        var leafd = TLeafD{};
        const start = cursor.seek;
        leafd.header = .init(cursor);
        leafd.leaf = try .init(cursor, allocator);
        var minimum_u64: u64 = undefined;
        minimum_u64 = cursor.get_bytes_as_int(@TypeOf(minimum_u64));
        leafd.minimum = @bitCast(minimum_u64);
        var maximum_u64: u64 = undefined;
        maximum_u64 = cursor.get_bytes_as_int(@TypeOf(maximum_u64));
        leafd.maximum = @bitCast(maximum_u64);
        leafd.num_bytes = cursor.seek - start;
        return leafd;
    }
};

pub const TLeafO = struct {
    header: types.ClassHeader = undefined,
    leaf: TLeaf = undefined,
    minimum: bool = undefined,
    maximum: bool = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TLeafO {
        var leafo = TLeafO{};
        const start = cursor.seek;
        leafo.header = .init(cursor);
        leafo.leaf = try .init(cursor, allocator);
        var minimum_u8: u8 = undefined;
        minimum_u8 = cursor.get_bytes_as_int(@TypeOf(minimum_u8));
        leafo.minimum = minimum_u8 != 0;
        var maximum_u8: u8 = undefined;
        maximum_u8 = cursor.get_bytes_as_int(@TypeOf(maximum_u8));
        leafo.maximum = maximum_u8 != 0;
        leafo.num_bytes = cursor.seek - start;
        return leafo;
    }
};
