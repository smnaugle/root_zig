const std = @import("std");

const types = @import("types.zig");
const util = @import("../utilities.zig");
const Cursor = @import("../cursor.zig");
const constants = @import("../constants.zig").Constants{};

pub const TList = struct {
    byte_count: u32 = undefined,
    version: u16 = undefined,
    object: types.TObject = undefined,
    name: []u8 = undefined,
    nobjects: u32 = undefined,
    objects: []types.TaggedType = undefined,

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
        list.objects = allocator.alloc(types.TaggedType, list.nobjects) catch |err| {
            std.debug.panic("Could not allocate TList objects: {}, object: {}. nobjects: {}", .{ err, list.object, list.nobjects });
        };
        for (0..list.nobjects) |idx| {
            var tag = types.ObjectTag{};
            tag = .init(cursor, allocator);

            list.objects[idx] = types.TaggedType.init(tag.class_name, cursor, allocator) catch |err| {
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
        //FIXME: Deinit to types.TaggedType
        // for (0..self.nobjects) |idx| {
        //     self.objects[idx].deinit();
        // }
        self._allocator.free(self.objects);
    }
};

pub const TObjArray = struct {
    header: types.ClassHeader = undefined,
    object: types.TObject = undefined,
    name: []u8 = undefined,
    nobjects: u32 = undefined,
    lower_bound: u32 = undefined,
    objects: []types.TaggedType = undefined,
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
        obj_array.objects = allocator.alloc(types.TaggedType, obj_array.nobjects) catch |err| {
            std.debug.panic("Cannot make object array {}", .{err});
        };
        var tag = types.ObjectTag{};
        for (0..obj_array.nobjects) |idx| {
            tag = types.ObjectTag.init(cursor, allocator);
            obj_array.objects[idx] = types.TaggedType.init(tag.class_name, cursor, allocator) catch |err| {
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
