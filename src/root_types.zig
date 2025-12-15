const std = @import("std");

const main = @import("main.zig");
const util = @import("utilities.zig");
const Cursor = @import("cursor.zig");
const types = @import("types/types.zig");
const streamers = types.streamers;

pub const Constants = struct {
    kByteCountMask: u32 = 0x40000000,
    kClassMask: u32 = 0x80000000,
    kMapOffset: u32 = 2,
    kFileHeaderSize: u32 = 100,
    kNewClassFlag: u32 = 0xFFFFFFFF,
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

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor) TAttLine {
        var tattline: TAttLine = .{};
        const start: u64 = cursor.seek;
        tattline.header = .init(cursor);
        tattline.line_color = cursor.get_bytes_as_int(@TypeOf(tattline.line_color));
        tattline.line_style = cursor.get_bytes_as_int(@TypeOf(tattline.line_style));
        tattline.line_width = cursor.get_bytes_as_int(@TypeOf(tattline.line_width));

        tattline.num_bytes = cursor.seek - start;
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

    num_bytes: u64 = undefined,
    pub fn init(cursor: *Cursor) TAttMarker {
        var tattmarker: TAttMarker = .{};
        const start = cursor.seek;
        tattmarker.header = .init(cursor);
        tattmarker.marker_color = cursor.get_bytes_as_int(@TypeOf(tattmarker.marker_color));
        tattmarker.marker_style = cursor.get_bytes_as_int(@TypeOf(tattmarker.marker_style));
        var marker_size_u32: u32 = 0;
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
    ttree: TTree,
    tbranch: TBranch,
    tbasket: TBasket,
    tbranch_element: TBranchElement,
    tleaf: TLeaf,
    tleaf_element: TLeafElement,
    tleafi: TLeafI,
    tleafd: TLeafD,
    tleafo: TLeafO,
    tleafl: TLeafL,
    tstreamer_info: TStreamerInfo,
    tstreamer_base: streamers.TStreamerBase,
    tstreamer_basic_type: streamers.TStreamerBasicType,
    tstreamer_string: streamers.TStreamerString,
    tstreamer_basic_pointer: streamers.TStreamerBasicPointer,
    tstreamer_object: streamers.TStreamerObject,
    tstreamer_object_pointer: streamers.TStreamerObjectPointer,
    tstreamer_loop: streamers.TStreamerLoop,
    tstreamer_object_any: streamers.TStreamerObjectAny,
    tstreamer_stl: streamers.TStreamerSTL,
    tstreamer_stl_string: streamers.TStreamerSTLstring,
    tobj_string: TObjString,
    tlist: TList,
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
        streamer.named = try .init(cursor, allocator);
        streamer.checksum = cursor.get_bytes_as_int(@TypeOf(streamer.checksum));
        streamer.class_version = cursor.get_bytes_as_int(@TypeOf(streamer.class_version));
        // NOTE: ROOT docs show that this tag is here, I am not sure how uproot gets around this...
        _ = ObjectTag.init(cursor, allocator);
        streamer.obj_array = .init(cursor, allocator);
        streamer.num_bytes = cursor.seek - start;
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

    num_bytes: u64 = undefined,
    _allocator: std.mem.Allocator = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) TList {
        const start = cursor.seek;
        var list = TList{};
        list._allocator = allocator;
        list.byte_count = cursor.get_bytes_as_int(@TypeOf(list.byte_count));
        list.byte_count = list.byte_count ^ constants.kByteCountMask;
        list.version = cursor.get_bytes_as_int(@TypeOf(list.version));
        list.object = .init(cursor);
        list.name, cursor.seek = util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek) catch |err| {
            std.debug.panic("Could not read TList name: {}", .{err});
        };
        list.nobjects = cursor.get_bytes_as_int(@TypeOf(list.nobjects));
        list.objects = allocator.alloc(TaggedType, list.nobjects) catch |err| {
            std.debug.panic("Could not allocate TList objects: {}, object: {}. nobjects: {}", .{ err, list.object, list.nobjects });
        };
        for (0..list.nobjects) |idx| {
            var tag = ObjectTag{};
            tag = .init(cursor, allocator);

            list.objects[idx] = TaggedType.init(tag.class_name, cursor, allocator) catch |err| {
                std.log.warn("Cannot make object {s}, returned {}. Skipping object creation.", .{ tag.class_name, err });
                cursor.seek = cursor.seek - tag.num_bytes + 4 + tag.byte_count;
                continue;
            };
            // FIXME: Speedbump, why do I need this plus 1?
            cursor.seek += 1;
        }
        list.num_bytes = cursor.seek - start;
        return list;
    }

    pub fn deinit(self: *TList) void {
        // FIXME: Add object deinit
        // self.object.deinit();
        self._allocator.free(self.name);
        //FIXME: Deinit to TaggedType
        // for (0..self.nobjects) |idx| {
        //     self.objects[idx].deinit();
        // }
        self._allocator.free(self.objects);
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
            tag = ObjectTag.init(cursor, allocator);
            obj_array.objects[idx] = TaggedType.init(tag.class_name, cursor, allocator) catch |err| {
                std.log.warn("Cannot make object {}\n", .{err});
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
        // const basket_header = ClassHeader.init(cursor);
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
            inline .tleafo, .tleafd, .tleafi, .tleafl => |obj| {
                const leaf = obj.leaf;
                bytes_per_elem = leaf.len_type;
            },
            else => std.debug.panic("Trying to get array from obj with no leaves.", .{}),
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
            const key: main.Key = try .init(&cursor, undefined, allocator);
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
    header: ClassHeader = undefined,
    branch: TBranch = undefined,
    class_name: TString = undefined,
    parent_name: TString = undefined,
    clones_name: TString = undefined,
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

pub const TLeaf = struct {
    header: ClassHeader = undefined,
    named: TNamed = undefined,
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
    header: ClassHeader = undefined,
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
    header: ClassHeader = undefined,
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
    header: ClassHeader = undefined,
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
    header: ClassHeader = undefined,
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
    header: ClassHeader = undefined,
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

pub const TTree = struct {
    header: ClassHeader = .{},
    named: TNamed = .{},
    att_line: TAttLine = .{},
    att_fill: TAttFill = .{},
    att_marker: TAttMarker = .{},
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
    branches: TObjArray = .{},

    num_bytes: u64 = undefined,
    _reader: std.fs.File.Reader = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !TTree {
        var tree: TTree = .{};
        const start: u64 = cursor.seek;
        tree.header = ClassHeader.init(cursor);
        tree.named = try TNamed.init(cursor, allocator);
        tree.att_line = TAttLine.init(cursor);
        tree.att_fill = TAttFill.init(cursor);
        tree.att_marker = TAttMarker.init(cursor);
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
            var branch: TBranch = undefined;
            switch (obj) {
                .tbranch => |tbranch| branch = tbranch,
                // .tbranch_element => |t| branch = t.branch,
                else => std.debug.panic("Cannot get array from {}, expects a TBranch\n", .{std.meta.activeTag(obj)}),
            }
            if (std.mem.eql(u8, name_null_term, branch.tname.name)) {
                return try branch.toArray(&self._reader, allocator, T);
            }
        }
        return null;
    }
};
