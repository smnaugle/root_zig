const std = @import("std");

const Cursor = @import("../cursor.zig");
const types = @import("../root.zig");
const util = @import("../utilities.zig");

pub const TBasket = struct {
    nbytes: u32 = undefined,
    key_version: u16 = undefined,
    obj_len: u32 = undefined,
    date_time: u32 = undefined,
    key_len: u16 = undefined,
    cycle: u16 = undefined,

    version: u16 = undefined,
    buffer_size: u32 = undefined,
    nev_buf_size: u32 = undefined,
    nev_buf: u32 = undefined,
    last: u32 = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) TBasket {
        _ = allocator;
        var basket = TBasket{};
        basket.nbytes = cursor.get_bytes_as_int(@TypeOf(basket.nbytes));
        basket.key_version = cursor.get_bytes_as_int(@TypeOf(basket.key_version));
        basket.obj_len = cursor.get_bytes_as_int(@TypeOf(basket.obj_len));
        basket.date_time = cursor.get_bytes_as_int(@TypeOf(basket.date_time));
        basket.key_len = cursor.get_bytes_as_int(@TypeOf(basket.key_len));
        basket.cycle = cursor.get_bytes_as_int(@TypeOf(basket.cycle));
        // Skip over class name, name, title
        cursor.seek = cursor.seek + basket.key_len - 18 - 1;
        basket.version = cursor.get_bytes_as_int(@TypeOf(basket.version));
        basket.buffer_size = cursor.get_bytes_as_int(@TypeOf(basket.buffer_size));
        basket.nev_buf_size = cursor.get_bytes_as_int(@TypeOf(basket.nev_buf_size));
        basket.nev_buf = cursor.get_bytes_as_int(@TypeOf(basket.nev_buf));
        basket.last = cursor.get_bytes_as_int(@TypeOf(basket.last));
        cursor.seek += 1;
        return basket;
    }
};

pub const TBranch = struct {
    header: types.ClassHeader = undefined,
    tname: types.TNamed = undefined,
    att_fill: types.TAttFill = undefined,
    compress: u32 = undefined,
    basket_size: u32 = undefined,
    entry_offset_len: u32 = undefined,
    write_basket: u32 = undefined,
    entry_number: u64 = undefined,
    offset: u32 = undefined,
    max_baskets: u32 = undefined,
    split_level: u32 = undefined,
    entries: u64 = undefined,
    first_entry: u64 = undefined,
    tot_bytes: u64 = undefined,
    zip_bytes: u64 = undefined,
    branches: types.TObjArray = undefined,
    leaves: types.TObjArray = undefined,
    baskets: types.TObjArray = undefined,
    basket_bytes: []u32 = undefined,
    basket_entry: []u64 = undefined,
    basket_seek: []u64 = undefined,
    filename: []u8 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TBranch {
        var branch: TBranch = .{};
        const start = cursor.seek;
        branch.header = .init(cursor);
        branch.tname = try .init(cursor, allocator);
        branch.att_fill = .init(cursor);
        branch.compress = cursor.get_bytes_as_int(@TypeOf(branch.compress));
        branch.basket_size = cursor.get_bytes_as_int(@TypeOf(branch.compress));

        branch.entry_offset_len = cursor.get_bytes_as_int(@TypeOf(branch.compress));
        branch.write_basket = cursor.get_bytes_as_int(@TypeOf(branch.write_basket));
        branch.entry_number = cursor.get_bytes_as_int(@TypeOf(branch.entry_number));
        cursor.seek = cursor.seek + 11; // FIXME: skipping crap that is not in the documentation. See https://github.com/scikit-hep/uproot5/blob/ca05406536f23cb43b0d18c059a98920b31a8f20/src/uproot/models/TTree.py#L761
        // FIO feautures is 11 bytes based on uproot docs
        branch.offset = cursor.get_bytes_as_int(@TypeOf(branch.offset));
        branch.max_baskets = cursor.get_bytes_as_int(@TypeOf(branch.max_baskets));
        branch.split_level = cursor.get_bytes_as_int(@TypeOf(branch.split_level));
        branch.entries = cursor.get_bytes_as_int(@TypeOf(branch.entries));
        branch.first_entry = cursor.get_bytes_as_int(@TypeOf(branch.first_entry));
        branch.tot_bytes = cursor.get_bytes_as_int(@TypeOf(branch.tot_bytes));
        branch.zip_bytes = cursor.get_bytes_as_int(@TypeOf(branch.zip_bytes));
        branch.branches = .init(cursor, allocator);
        branch.leaves = .init(cursor, allocator);
        // FIXME: Skipping branch.baskets for now, no root info on how to parse
        // const basket_header = types.ClassHeader.init(cursor);
        // cursor.seek = cursor.seek - basket_header.num_bytes + 4 + basket_header.byte_counts;
        branch.baskets = .init(cursor, allocator);
        cursor.seek = cursor.seek + 1; // FIXME: Speedbump?
        branch.basket_bytes = try allocator.alloc(std.meta.Child(@TypeOf(branch.basket_bytes)), branch.max_baskets);
        for (0..branch.max_baskets) |idx| {
            branch.basket_bytes[idx] = cursor.get_bytes_as_int(@TypeOf(branch.basket_bytes[0]));
        }
        cursor.seek = cursor.seek + 1; // FIXME: Speedbump?
        branch.basket_entry = try allocator.alloc(std.meta.Child(@TypeOf(branch.basket_entry)), branch.max_baskets);
        for (0..branch.max_baskets) |idx| {
            branch.basket_entry[idx] = cursor.get_bytes_as_int(@TypeOf(branch.basket_entry[0]));
        }
        cursor.seek += 1; // FIXME: Speedbump?
        branch.basket_seek = try allocator.alloc(std.meta.Child(@TypeOf(branch.basket_seek)), branch.max_baskets);
        for (0..branch.max_baskets) |idx| {
            branch.basket_seek[idx] = cursor.get_bytes_as_int(@TypeOf(branch.basket_seek[0]));
        }
        // FIXME: Implement TString class with this as the init
        var idx: u32 = 0;
        for (cursor.buffer[cursor.seek..cursor.buffer.len]) |b| {
            idx = idx + 1;
            if (b == 0x00) break;
        }
        branch.filename = try allocator.alloc(u8, idx);
        @memcpy(branch.filename, cursor.buffer[cursor.seek..(cursor.seek + idx)]);
        cursor.seek += idx;
        branch.num_bytes = cursor.seek - start;
        return branch;
    }

    // pub fn toArray(self: *TBranch, reader: *std.fs.File.Reader, allocator: std.mem.Allocator, comptime T: type) !types.Array {
    pub fn toArray(self: *TBranch, reader: *std.fs.File.Reader, allocator: std.mem.Allocator, comptime T: type) ![]T {
        if (self.leaves.nobjects > 1) std.debug.panic(
            "Cannot handle branches with more than one leaf, {s} has {d}",
            .{ self.tname.name, self.leaves.nobjects },
        );

        // Some basic type checking
        var bytes_per_elem: u32 = 0;
        switch (self.leaves.objects[0]) {
            .tleaf => |leaf| {
                bytes_per_elem = leaf.len_type;
            },
            inline .tleaf_element, .tleafo, .tleafd, .tleafi, .tleafl => |obj| {
                const leaf = obj.leaf;
                bytes_per_elem = leaf.len_type;
            },
            else => |obj| std.debug.panic("Cannot parse leaf information for {}", .{obj}),
        }
        if (bytes_per_elem != @sizeOf(T)) {
            std.debug.panic(
                "Cannot cast branch element to a type of wrong size, {d} and {d}",
                .{ bytes_per_elem, @sizeOf(T) },
            );
        }
        var last_entry: u64 = 0;
        var total_num_elements: u64 = 0;
        var entries_in_branch: []u64 = try allocator.alloc(u64, self.basket_seek.len);
        defer allocator.free(entries_in_branch);
        for (self.basket_entry[1..], 1..) |entry, idx| {
            std.debug.print("{d}, {d}\n", .{ entry, last_entry });
            if (entry == 0) {
                continue;
            }
            entries_in_branch[idx - 1] = entry - last_entry;
            total_num_elements += entries_in_branch[idx - 1];
            last_entry = entry;
        }
        const array: types.Array = try .init(T, total_num_elements, allocator);
        const item_ptr: [*]T = @ptrCast(@alignCast(array.items));
        var items: []T = item_ptr[0..array.len];
        const type_info = @typeInfo(T);
        comptime var bits = 0;
        comptime switch (type_info) {
            inline else => |info| bits = info.bits,
        };
        var appends: u64 = 0;
        const bit_type = @Type(.{ .int = .{ .bits = bits, .signedness = .unsigned } });
        for (self.basket_seek, self.basket_bytes, 0..) |seek, bytes, bi| {
            if (bytes == 0) {
                continue;
            }
            try reader.seekTo(seek);
            const data_len: u32 = std.mem.readInt(u32, try reader.interface.peekArray(4), .big);
            const compressed_data = try reader.interface.readAlloc(allocator, data_len);
            defer allocator.free(compressed_data);
            var cursor = Cursor.init(compressed_data);
            const key: types.Key = try .init(&cursor, undefined, allocator);
            var data = try allocator.alloc(u8, key.object_len);
            defer allocator.free(data);
            data = try util.unzip_and_allocate(compressed_data[(key.key_len + 9)..], data);
            const entries = entries_in_branch[bi];
            for (0..(entries)) |idx| {
                items[appends] = @bitCast(std.mem.readVarInt(bit_type, data[(bytes_per_elem * idx)..(bytes_per_elem * (idx + 1))], .big));
                appends += 1;
            }
        }
        // return array;
        return items;
    }
};

pub const TBranchElement = struct {
    header: types.ClassHeader = undefined,
    branch: TBranch = undefined,
    class_name: types.TString = undefined,
    parent_name: types.TString = undefined,
    clones_name: types.TString = undefined,
    checksum: i32 = undefined,
    class_version: u16 = undefined,
    id: i32 = undefined,
    type: u32 = undefined,
    streamer_type: u32 = undefined,
    maximum: u32 = undefined,
    // FIXME: v both are fed through read_object_any in uproot
    branch_count: u32 = undefined,
    branch_count2: u32 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TBranchElement {
        var branch_element = TBranchElement{};
        const start = cursor.seek;
        branch_element.header = .init(cursor);
        branch_element.branch = try .init(cursor, allocator);
        branch_element.class_name = try .init(cursor, allocator);
        branch_element.parent_name = try .init(cursor, allocator);
        branch_element.clones_name = try .init(cursor, allocator);
        // FIXME: Why -1 here??
        cursor.seek = cursor.seek - 1;
        branch_element.checksum = cursor.get_bytes_as_int(@TypeOf(branch_element.checksum));
        branch_element.class_version = cursor.get_bytes_as_int(@TypeOf(branch_element.class_version));
        branch_element.id = cursor.get_bytes_as_int(@TypeOf(branch_element.id));
        branch_element.type = cursor.get_bytes_as_int(@TypeOf(branch_element.type));
        branch_element.streamer_type = cursor.get_bytes_as_int(@TypeOf(branch_element.streamer_type));
        branch_element.maximum = cursor.get_bytes_as_int(@TypeOf(branch_element.maximum));
        branch_element.branch_count = cursor.get_bytes_as_int(@TypeOf(branch_element.branch_count));
        branch_element.branch_count2 = cursor.get_bytes_as_int(@TypeOf(branch_element.branch_count2));
        branch_element.num_bytes = cursor.seek - start;
        return branch_element;
    }
};
