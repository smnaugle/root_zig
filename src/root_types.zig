const std = @import("std");

const util = @import("utilities.zig");
const Cursor = @import("cursor.zig");

pub const Constants = struct {
    kByteCountMask: u32 = 0x40000000,
    kClassMask: u32 = 0x80000000,
    kMapOffset: u32 = 2,
};

const constants = Constants{};

pub const ClassHeader = struct {
    byte_counts: u32 = undefined,
    version: u16 = undefined,
    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor) ClassHeader {
        var header: ClassHeader = .{};
        const start = cursor.seek;
        header.byte_counts = cursor.get_bytes_as_int(@TypeOf(header.byte_counts));
        header.byte_counts = header.byte_counts ^ constants.kByteCountMask;
        header.version = cursor.get_bytes_as_int(@TypeOf(header.version));
        header.num_bytes = cursor.seek - start;
        return header;
    }
};

pub const TNamed = struct {
    const TOBJ_LEN: u8 = 10;
    header: ClassHeader = undefined,
    t_object: [TOBJ_LEN]u8 = undefined,
    name: []u8 = undefined,
    title: []u8 = undefined,
    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TNamed {
        var tnamed = TNamed{};
        const start = cursor.seek;
        tnamed.header = ClassHeader.init(cursor);
        tnamed.name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, @truncate(cursor.seek + TOBJ_LEN));
        tnamed.title, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, @truncate(cursor.seek));
        tnamed.num_bytes = cursor.seek - start;
        return tnamed;
    }
};

pub const TAttLine = struct {
    header: ClassHeader = undefined,
    line_color: u16 = undefined,
    line_style: u16 = undefined,
    line_width: u16 = undefined,
    num_bytes: u32 = undefined,

    pub fn init(buffer: []u8) TAttLine {
        var tattline: TAttLine = .{};
        var next_byte: u32 = 0;
        tattline.header = .init(buffer);
        next_byte = next_byte + tattline.header.num_bytes;
        tattline.line_color, next_byte = util.get_buffer_info(buffer, next_byte, u16);
        tattline.line_style, next_byte = util.get_buffer_info(buffer, next_byte, u16);
        tattline.line_width, next_byte = util.get_buffer_info(buffer, next_byte, u16);
        tattline.num_bytes = next_byte;
        return tattline;
    }
};

pub const TAttFill = struct {
    header: ClassHeader = undefined,
    fill_color: u16 = undefined,
    fill_style: u16 = undefined,
    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor) TAttFill {
        var tattfill: TAttFill = .{};
        const start = cursor.seek;
        tattfill.header = .init(cursor);
        tattfill.fill_color = cursor.get_bytes_as_int(@TypeOf(tattfill.fill_color));
        tattfill.fill_style = cursor.get_bytes_as_int(@TypeOf(tattfill.fill_style));
        tattfill.num_bytes = cursor.seek - start;
        return tattfill;
    }
};

pub const TAttMarker = struct {
    header: ClassHeader = undefined,
    marker_color: u16 = undefined,
    marker_style: u16 = undefined,
    marker_size: f32 = undefined,
    num_bytes: u32 = undefined,

    pub fn init(cursor: *Cursor) TAttMarker {
        var tattmarker: TAttMarker = .{};
        const start = cursor.seek;
        tattmarker.header = .init(cursor);
        tattmarker.marker_color = cursor.get_bytes_as_int(@TypeOf(tattmarker.marker_color));
        tattmarker.marker_style = cursor.get_bytes_as_int(@TypeOf(tattmarker.marker_style));
        const marker_size_u32: u32 = 0;
        marker_size_u32 = cursor.get_bytes_as_int(@TypeOf(marker_size_u32));
        tattmarker.marker_size = @bitCast(marker_size_u32);
        tattmarker.num_bytes = cursor.seek - start;
        return tattmarker;
    }
};

pub const TObject = struct {
    version: u16 = undefined,
    unique_id: u32 = undefined,
    // bits: [4]u8 = undefined,
    num_bytes: u32 = undefined,
    // NOTE: pidf not needed by us currently
    // but perhaps in the future? This makes tobj 10 bytes rather than 12

    pub fn init(cursor: *Cursor) TObject {
        var tobj = TObject{};
        const start = cursor.seek;
        tobj.version = cursor.get_bytes_as_int(@TypeOf(tobj.version));
        tobj.unique_id = cursor.get_bytes_as_int(@TypeOf(tobj.unique_id));
        //FIXME: Get other info
        tobj.num_bytes = 10;
        cursor.seek = start + tobj.num_bytes;
        return tobj;
    }
};

pub const ObjectTag = struct {
    // TODO: This should live in the TaggedType object since

    // When deserializating objects, every object comes with this tag at the beginning.
    // Hence it's presence in TObjArray.init()
    byte_count: u32 = undefined,
    class_tag: i32 = undefined,
    class_name: []u8 = undefined,
    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !ObjectTag {
        var tag: ObjectTag = .{};
        const start = cursor.seek;
        tag.byte_count = cursor.get_bytes_as_int(@TypeOf(tag.byte_count));
        tag.byte_count = tag.byte_count ^ constants.kByteCountMask;
        // NOTE: This comes after the byte counts have been read.
        const displacement = cursor.displacement();
        tag.class_tag = cursor.get_bytes_as_int(@TypeOf(tag.class_tag));
        std.log.debug("Original class byte_count and class tag: {d}, {d}", .{ tag.byte_count, tag.class_tag });
        if (tag.class_tag != -1) {
            const lookup: u64 = @abs(tag.class_tag & ~constants.kClassMask);
            const name = cursor.record.get(lookup);
            if (name == null) {
                std.debug.panic("No name for {d}/{d}\n", .{ tag.class_tag, lookup });
            }
            tag.class_name = name.?;
            tag.num_bytes = 8;
        } else if (tag.class_tag == -1) {
            var idx: u64 = 0;
            for (cursor.buffer[cursor.seek..cursor.buffer.len]) |b| {
                idx = idx + 1;
                if (b == 0x00) break;
            }
            tag.class_name = try allocator.alloc(u8, idx);
            @memcpy(tag.class_name, cursor.buffer[cursor.seek..(cursor.seek + idx)]);
            cursor.seek += idx;
            tag.num_bytes = cursor.seek - start;
            try cursor.record.put(allocator, @abs(displacement + constants.kMapOffset), tag.class_name);
            std.log.debug("Adding record: {d}, {s}", .{ displacement + constants.kMapOffset, tag.class_name });
        }
        std.log.debug("Returning tag {}", .{tag});
        return tag;
    }
};

const TaggedType = union(enum) {
    tbranch: TBranch,
    tleaf: TLeaf,
    tstreamer_info: TStreamerInfo,
    none,
    pub fn init(class_name: []u8, cursor: *Cursor, allocator: std.mem.Allocator) !TaggedType {
        if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TBranch")) {
            const tagged = TaggedType{ .tbranch = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 2)], "TLeaf")) {
            const tagged = TaggedType{ .tleaf = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerInfo")) {
            const tagged = TaggedType{ .tstreamer_info = try .init(cursor, allocator) };
            return tagged;
        } else {
            std.debug.print("{s}\n", .{class_name});
            return error.UnimplementedClass;
        }
    }

    pub fn num_bytes(self: TaggedType) u64 {
        switch (self) {
            .none => return 0,
            inline else => |tagged_type| return tagged_type.num_bytes,
        }
    }
    //FIXME: Add in function here to get object size (num_bytes)
};

pub fn tagged_init(tagged_type: TaggedType, buffer: []u8, allocator: std.mem.Allocator) !void {
    switch (tagged_type) {
        .tbranch => |*branch| branch.*.init(buffer, allocator),
    }
}

pub const TStreamerInfo = struct {
    header: ClassHeader = undefined,
    named: TNamed = undefined,
    checksum: u32 = undefined,
    class_version: u32 = undefined,
    obj_array: TObjArray = undefined,

    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TStreamerInfo {
        var streamer: TStreamerInfo = .{};
        const start = cursor.seek;
        streamer.header = .init(cursor);
        std.debug.print("streamer header: {}\n", .{streamer.header});
        streamer.named = try .init(cursor, allocator);
        streamer.checksum = cursor.get_bytes_as_int(@TypeOf(streamer.checksum));
        streamer.class_version = cursor.get_bytes_as_int(@TypeOf(streamer.class_version));
        std.debug.print("next byte: {d}\n", .{cursor.seek});
        const tag = try ObjectTag.init(cursor, allocator);
        std.debug.print("mys tag: {}\n", .{tag});
        streamer.obj_array = .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
        std.debug.print("streamer: {}\n", .{streamer});
        return streamer;
    }
};
pub const TList = struct {
    byte_count: u32 = undefined,
    version: u16 = undefined,
    object: TObject = undefined,
    name: []u8 = undefined,
    nobjects: u32 = undefined,
    objects: []TaggedType = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TList {
        // WARN: This probably cannot fail for similar reasons to TObjArray, but seems fine for now
        var list = TList{};
        list.byte_count = cursor.get_bytes_as_int(@TypeOf(list.byte_count));
        list.byte_count = list.byte_count ^ constants.kByteCountMask;
        list.version = cursor.get_bytes_as_int(@TypeOf(list.version));
        list.object = .init(cursor);
        list.name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek);
        list.nobjects = cursor.get_bytes_as_int(@TypeOf(list.nobjects));
        list.objects = try allocator.alloc(TaggedType, list.nobjects);
        std.debug.print("List name: {s}, list nobjects: {d}\n", .{ list.name, list.nobjects });
        for (0..list.nobjects) |idx| {
            var tag = ObjectTag{};
            tag = try .init(cursor, allocator);
            list.objects[idx] = TaggedType.init(tag.class_name, cursor, allocator) catch |err| {
                std.log.warn("Cannot make object {s}, returned {}. Skipping object creation.", .{ tag.class_name, err });
                cursor.seek = cursor.seek - tag.num_bytes + 4 + tag.byte_count;
                continue;
            };
            // FIXME: Speedbump, why do I need this plus 1?
            cursor.seek += 1;
        }
        return list;
    }
};

pub const TObjArray = struct {
    header: ClassHeader = undefined,
    object: TObject = undefined,
    name: []u8 = undefined,
    nobjects: u32 = undefined,
    lower_bound: u32 = undefined,
    objects: []TaggedType = undefined,
    num_bytes: u64 = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) TObjArray {
        // NOTE: This cannot return an error since it is called recursively during the creation of objects, i.e. if an
        // object has a TObjArray inside of it.
        var obj_array: TObjArray = .{};
        const start = cursor.seek;
        obj_array.header = .init(cursor);
        obj_array.object = .init(cursor);
        obj_array.name, cursor.seek = util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek) catch |err| {
            std.debug.panic("Cannot get name {}", .{err});
        };
        obj_array.nobjects = cursor.get_bytes_as_int(@TypeOf(obj_array.nobjects));
        obj_array.lower_bound = cursor.get_bytes_as_int(@TypeOf(obj_array.lower_bound));
        // NOTE: Some nontrivial class binding has to occur to the tags
        // see: https://github.com/scikit-hep/uproot5/blob/ca05406536f23cb43b0d18c059a98920b31a8f20/src/uproot/deserialization.py#L187
        obj_array.objects = allocator.alloc(TaggedType, obj_array.nobjects) catch |err| {
            std.debug.panic("Cannot make object array {}", .{err});
        };
        var tag = ObjectTag{};
        for (0..obj_array.nobjects) |idx| {
            tag = ObjectTag.init(cursor, allocator) catch |err| {
                std.debug.panic("Cannot make tag {}", .{err});
            };
            obj_array.objects[idx] = TaggedType.init(tag.class_name, cursor, allocator) catch |err| {
                std.debug.print("Cannot make object {}\n", .{err});
                cursor.seek = cursor.seek - tag.num_bytes + 4 + tag.byte_count;
                continue;
            };
        }
        obj_array.num_bytes = cursor.seek - start;
        // Crashes
        // std.log.debug("Returing TObjArray {}", .{obj_array});
        return obj_array;
    }
};

pub const TBranch = struct {
    header: ClassHeader = undefined,
    tname: TNamed = undefined,
    att_fill: TAttFill = undefined,
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
    branches: TObjArray = undefined,
    leaves: TObjArray = undefined,
    baskets: TObjArray = undefined,
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
        std.debug.print("TBranch entry_number: {}\n", .{branch.entry_number});
        cursor.seek = cursor.seek + 11; // FIXME: skipping crap that is not in the documentation. See https://github.com/scikit-hep/uproot5/blob/ca05406536f23cb43b0d18c059a98920b31a8f20/src/uproot/models/TTree.py#L761
        // FIO feautures is 11 bytes based on uproot docs
        branch.offset = cursor.get_bytes_as_int(@TypeOf(branch.offset));
        branch.max_baskets = cursor.get_bytes_as_int(@TypeOf(branch.max_baskets));
        branch.split_level = cursor.get_bytes_as_int(@TypeOf(branch.split_level));
        branch.entries = cursor.get_bytes_as_int(@TypeOf(branch.entries));
        branch.first_entry = cursor.get_bytes_as_int(@TypeOf(branch.first_entry));
        branch.tot_bytes = cursor.get_bytes_as_int(@TypeOf(branch.tot_bytes));
        branch.zip_bytes = cursor.get_bytes_as_int(@TypeOf(branch.zip_bytes));
        std.debug.print("TBranch zip_bytes {d}\n", .{branch.zip_bytes});
        branch.branches = .init(cursor, allocator);
        branch.leaves = .init(cursor, allocator);
        // FIXME: Skipping branch.baskets for now, no root info on how to parse
        const basket_header = ClassHeader.init(cursor);
        cursor.seek += basket_header.byte_counts;
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
};

pub const TLeaf = struct {
    header: ClassHeader = undefined,
    named: TNamed = undefined,
    len: u32 = undefined,
    len_type: u32 = undefined,
    offset: u32 = undefined,
    is_range: u8 = undefined,
    is_unsigned: u8 = undefined,
    leaf_counts: u64 = undefined,

    num_bytes: u32 = undefined,

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
        _ = start;
        leaf.num_bytes = leaf.header.byte_counts + 4;
        std.log.debug("Returning TLeaf: {}\n", .{leaf});
        return leaf;
    }
};

pub const TTree = struct {
    header: ClassHeader = undefined,
    named: TNamed = undefined,
    att_line: TAttLine = undefined,
    att_fill: TAttFill = undefined,
    att_marker: TAttMarker = undefined,
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
    branches: TObjArray = undefined,

    pub fn init(buffer: []u8, allocator: std.mem.Allocator) !TTree {
        var tree: TTree = .{};
        var next_byte: u32 = 0;
        tree.header = ClassHeader.init(buffer);
        next_byte = next_byte + tree.header.num_bytes;
        tree.named = try TNamed.init(buffer[next_byte..buffer.len], allocator);
        next_byte = next_byte + tree.named.num_bytes;
        tree.att_line = TAttLine.init(buffer[(next_byte)..buffer.len]);
        next_byte = next_byte + tree.att_line.num_bytes;
        tree.att_fill = TAttFill.init(buffer[(next_byte)..buffer.len]);
        next_byte = next_byte + tree.att_fill.num_bytes;
        tree.att_marker = TAttMarker.init(buffer[(next_byte)..buffer.len]);
        next_byte = next_byte + tree.att_marker.num_bytes;
        tree.entries, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.tot_bytes, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.zip_bytes, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.saved_bytes, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.flushed_bytes, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        const weight_u64, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.weight = @bitCast(weight_u64);
        tree.timer_interval, next_byte = util.get_buffer_info(buffer, next_byte, u32);
        tree.scan_field, next_byte = util.get_buffer_info(buffer, next_byte, u32);
        tree.update, next_byte = util.get_buffer_info(buffer, next_byte, u32);
        tree.default_entry_offset_len, next_byte = util.get_buffer_info(buffer, next_byte, u32);
        tree.n_cluster_range, next_byte = util.get_buffer_info(buffer, next_byte, u32);
        tree.max_entries, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.max_entry_loop, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.max_virtual_size, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.auto_save, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.auto_flush, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        tree.estimate, next_byte = util.get_buffer_info(buffer, next_byte, u64);
        next_byte = next_byte + 13; // FIXME: skipping crap that is not in the documentation. See https://github.com/scikit-hep/uproot5/blob/ca05406536f23cb43b0d18c059a98920b31a8f20/src/uproot/models/TTree.py#L761
        tree.branches = .init(buffer[next_byte..buffer.len], allocator);
        std.log.debug("Returing TTree {}", .{TTree});
        return tree;
    }
};
