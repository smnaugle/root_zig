const std = @import("std");

const types = @import("../root.zig");
const Cursor = @import("../cursor.zig");

pub const TTree = struct {
    header: types.ClassHeader = .{},
    named: types.TNamed = .{},
    att_line: types.TAttLine = .{},
    att_fill: types.TAttFill = .{},
    att_marker: types.TAttMarker = .{},
    entries: u64 = undefined,
    tot_bytes: u64 = undefined,
    zip_bytes: u64 = undefined,
    saved_bytes: u64 = undefined,
    flushed_bytes: u64 = undefined,
    weight: f64 = undefined,
    timer_interval: u32 = undefined,
    scan_field: u32 = undefined,
    update: u32 = undefined,
    default_entry_offset_len: u32 = undefined,
    n_cluster_range: u32 = undefined,
    max_entries: u64 = undefined,
    max_entry_loop: u64 = undefined,
    max_virtual_size: u64 = undefined,
    auto_save: u64 = undefined,
    auto_flush: u64 = undefined,
    estimate: u64 = undefined,
    branches: types.TObjArray = .{},

    num_bytes: u64 = undefined,
    _reader: std.fs.File.Reader = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TTree {
        var tree: TTree = .{};
        const start: u64 = cursor.seek;
        tree.header = types.ClassHeader.init(cursor);
        tree.named = try types.TNamed.init(cursor, allocator);
        tree.att_line = types.TAttLine.init(cursor);
        tree.att_fill = types.TAttFill.init(cursor);
        tree.att_marker = types.TAttMarker.init(cursor);
        tree.entries = cursor.get_bytes_as_int(@TypeOf(tree.entries));
        tree.tot_bytes = cursor.get_bytes_as_int(@TypeOf(tree.tot_bytes));
        tree.zip_bytes = cursor.get_bytes_as_int(@TypeOf(tree.zip_bytes));
        tree.saved_bytes = cursor.get_bytes_as_int(@TypeOf(tree.saved_bytes));
        tree.flushed_bytes = cursor.get_bytes_as_int(@TypeOf(tree.flushed_bytes));
        var weight_u64: u64 = undefined;
        weight_u64 = cursor.get_bytes_as_int(@TypeOf(weight_u64));
        tree.weight = @bitCast(weight_u64);
        tree.timer_interval = cursor.get_bytes_as_int(@TypeOf(tree.timer_interval));
        tree.scan_field = cursor.get_bytes_as_int(@TypeOf(tree.scan_field));
        tree.update = cursor.get_bytes_as_int(@TypeOf(tree.update));
        tree.default_entry_offset_len = cursor.get_bytes_as_int(@TypeOf(tree.default_entry_offset_len));
        tree.n_cluster_range = cursor.get_bytes_as_int(@TypeOf(tree.n_cluster_range));
        tree.max_entries = cursor.get_bytes_as_int(@TypeOf(tree.max_entries));
        tree.max_entry_loop = cursor.get_bytes_as_int(@TypeOf(tree.max_entry_loop));
        tree.max_virtual_size = cursor.get_bytes_as_int(@TypeOf(tree.max_virtual_size));
        tree.auto_save = cursor.get_bytes_as_int(@TypeOf(tree.auto_save));
        tree.auto_flush = cursor.get_bytes_as_int(@TypeOf(tree.auto_flush));
        tree.estimate = cursor.get_bytes_as_int(@TypeOf(tree.estimate));
        cursor.seek = cursor.seek + 13; // FIXME: skipping crap that is not in the documentation. See https://github.com/scikit-hep/uproot5/blob/ca05406536f23cb43b0d18c059a98920b31a8f20/src/uproot/models/TTree.py#L761
        tree.branches = .init(cursor, allocator);
        tree.num_bytes = cursor.seek - start;
        return tree;
    }
    // pub fn getArray(self: *TTree, name: []const u8, comptime T: type, allocator: std.mem.Allocator) !?types.Array {
    pub fn getArray(self: *TTree, name: []const u8, comptime T: type, allocator: std.mem.Allocator) !?[]T {
        // Add null terminator
        var name_null_term: []u8 = undefined;
        var len = name.len;
        if (name[name.len - 1] != 0x00) {
            len = name.len + 1;
        }
        name_null_term = allocator.alloc(u8, len) catch |err| {
            std.debug.panic("Could not create string: {}", .{err});
        };
        defer allocator.free(name_null_term);
        @memcpy(name_null_term[0..name.len], name);
        name_null_term[name_null_term.len - 1] = 0x00;

        for (self.branches.objects) |obj| {
            var branch: types.TBranch = undefined;
            switch (obj) {
                .tbranch => |tbranch| branch = tbranch,
                .tbranch_element => |t| branch = t.branch,
                else => std.debug.panic("Cannot get array from {}, expects a types.TBranch\n", .{std.meta.activeTag(obj)}),
            }
            if (std.mem.eql(u8, name_null_term, branch.tname.name)) {
                return try branch.toArray(&self._reader, allocator, T);
            }
        }
        return null;
    }
};
