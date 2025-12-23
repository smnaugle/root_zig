const std = @import("std");

const types = @import("types.zig");
const Cursor = @import("../cursor.zig");

const constants = @import("../constants.zig").Constants{};

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

pub const TObjString = struct {
    header: ClassHeader = undefined,
    object: TObject = undefined,
    string: []u8 = undefined,

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TObjString {
        var str = TObjString{};
        const start = cursor.seek;
        str.header = .init(cursor);
        str.object = .init(cursor);
        str.string = try cursor.read_u32_and_get_string(allocator);
        str.num_bytes = cursor.seek - start;
        return str;
    }
};

pub const ObjectTag = struct {
    // TODO: This should live in the TaggedType object since

    // When deserializating objects, every object comes with this tag at the beginning.
    // Hence it's presence in TObjArray.init()
    byte_count: u32 = undefined,
    class_tag: i32 = undefined,
    class_name: []u8 = undefined,
    num_bytes: u64 = 0,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) ObjectTag {
        var tag: ObjectTag = .{};
        const start = cursor.seek;
        tag.byte_count = cursor.get_bytes_as_int(@TypeOf(tag.byte_count));
        if (((tag.byte_count & constants.kByteCountMask) == 0) or (tag.byte_count == constants.kNewClassFlag)) {
            tag.byte_count = 0;
            tag.class_tag = @bitCast(tag.byte_count);
            if (tag.class_tag == 1) {
                std.debug.panic("Path not implemented\n", .{});
            }
            tag.class_name = allocator.alloc(u8, 5) catch |err| {
                std.debug.panic("{}", .{err});
            };
            @memcpy(tag.class_name, "NONE\x00");
            return tag;
        } else {
            tag.byte_count = tag.byte_count ^ constants.kByteCountMask;
        }
        // NOTE: This comes after the byte counts have been read.
        const displacement = cursor.displacement();
        tag.class_tag = cursor.get_bytes_as_int(@TypeOf(tag.class_tag));
        if (tag.class_tag != -1) {
            const lookup: u64 = @abs(tag.class_tag & ~constants.kClassMask);
            const name = cursor.record.get(lookup);
            if (name == null) {
                std.log.err("tag {}\n", .{tag});
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
            tag.class_name = allocator.alloc(u8, idx) catch |err| {
                std.debug.panic("{}", .{err});
            };
            @memcpy(tag.class_name, cursor.buffer[cursor.seek..(cursor.seek + idx)]);
            cursor.seek += idx;
            tag.num_bytes = cursor.seek - start;
            cursor.record.put(allocator, @abs(displacement + constants.kMapOffset), tag.class_name) catch |err| {
                std.debug.panic("{}", .{err});
            };
        }
        return tag;
    }
};

pub const TaggedType = union(enum) {
    ttree: types.TTree,
    tbranch: types.TBranch,
    tbasket: types.TBasket,
    tbranch_element: types.TBranchElement,
    tleaf: types.TLeaf,
    tleaf_element: types.TLeafElement,
    tleafi: types.TLeafI,
    tleafd: types.TLeafD,
    tleafo: types.TLeafO,
    tleafl: types.TLeafL,
    tstreamer_info: types.TStreamerInfo,
    tstreamer_base: types.TStreamerBase,
    tstreamer_basic_type: types.TStreamerBasicType,
    tstreamer_string: types.TStreamerString,
    tstreamer_basic_pointer: types.TStreamerBasicPointer,
    tstreamer_object: types.TStreamerObject,
    tstreamer_object_pointer: types.TStreamerObjectPointer,
    tstreamer_loop: types.TStreamerLoop,
    tstreamer_object_any: types.TStreamerObjectAny,
    tstreamer_stl: types.TStreamerSTL,
    tstreamer_stl_string: types.TStreamerSTLstring,
    tobj_string: types.TObjString,
    tlist: types.TList,
    none,
    pub fn init(class_name: []u8, cursor: *Cursor, allocator: std.mem.Allocator) !TaggedType {
        if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "NONE")) {
            const tagged = TaggedType{ .none = {} };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TBranch")) {
            const tagged = TaggedType{ .tbranch = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TLeaf")) {
            const tagged = TaggedType{ .tleaf = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TLeafElement")) {
            const tagged = TaggedType{ .tleaf_element = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TLeafI")) {
            const tagged = TaggedType{ .tleafi = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TLeafD")) {
            const tagged = TaggedType{ .tleafd = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TLeafO")) {
            const tagged = TaggedType{ .tleafo = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TLeafL")) {
            const tagged = TaggedType{ .tleafl = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerInfo")) {
            const tagged = TaggedType{ .tstreamer_info = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerBase")) {
            const tagged = TaggedType{ .tstreamer_base = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerBasicType")) {
            const tagged = TaggedType{ .tstreamer_basic_type = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerString")) {
            const tagged = TaggedType{ .tstreamer_string = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerBasicPointer")) {
            const tagged = TaggedType{ .tstreamer_basic_pointer = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerObject")) {
            const tagged = TaggedType{ .tstreamer_object = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerObjectPointer")) {
            const tagged = TaggedType{ .tstreamer_object_pointer = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerLoop")) {
            const tagged = TaggedType{ .tstreamer_loop = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerObjectAny")) {
            const tagged = TaggedType{ .tstreamer_object_any = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerSTL")) {
            const tagged = TaggedType{ .tstreamer_stl = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TStreamerSTLstring")) {
            const tagged = TaggedType{ .tstreamer_stl_string = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TList")) {
            const tagged = TaggedType{ .tlist = .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TObjString")) {
            const tagged = TaggedType{ .tobj_string = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TBranchElement")) {
            const tagged = TaggedType{ .tbranch_element = try .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TBasket")) {
            const tagged = TaggedType{ .tbasket = .init(cursor, allocator) };
            return tagged;
        } else if (std.mem.eql(u8, class_name[0..(class_name.len - 1)], "TTree")) {
            const tagged = TaggedType{ .ttree = try .init(cursor, allocator) };
            return tagged;
        } else {
            std.log.warn("{s} is not implemented\n", .{class_name});
            return error.UnimplementedClass;
        }
    }

    pub fn num_bytes(self: TaggedType) u64 {
        switch (self) {
            .none => return 0,
            inline else => |tagged_type| return tagged_type.num_bytes,
        }
    }

    pub fn deinit(self: TaggedType) void {
        switch (self) {
            .none => return,
            inline else => |tagged_type| return tagged_type.deinit(),
        }
    }
    //FIXME: Add in function here to get object size (num_bytes)
};
