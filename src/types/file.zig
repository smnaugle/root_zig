const std = @import("std");

const Cursor = @import("../cursor.zig");
const types = @import("types.zig");
const util = @import("../utilities.zig");
const constants = @import("../constants.zig").Constants{};

pub const Key = struct {
    //TKEY
    /// This is the number of bytes in the key+data sections
    num_bytes: u32 = undefined,
    version: u16 = undefined,
    object_len: u32 = undefined,
    date_time: u32 = undefined,
    /// This is the number of bytes in the key
    key_len: u16 = undefined,
    cycle: u16 = undefined,
    seek_key: u64 = undefined,
    seek_parent_dir: u64 = undefined,
    class_name_bytes: u8 = undefined,
    class_name: []u8 = undefined,
    object_name_bytes: u8 = undefined,
    object_name: []u8 = undefined,
    title_name_bytes: u8 = undefined,
    title_name: []u8 = undefined,

    // Must outlive the Key
    _allocator: std.mem.Allocator = undefined,
    // This just needs to be something to read buffers from, currently we use same reader
    // as the RootFile. Is populated in RootFile.get_key()
    _parent: types.Parent = undefined,
    pub fn init(cursor: *Cursor, parent: types.Parent, allocator: std.mem.Allocator) !Key {
        var kl = Key{};

        //Manage some state
        kl._allocator = allocator;
        kl._parent = parent;

        // Read info
        kl.num_bytes = cursor.get_bytes_as_int(@TypeOf(kl.num_bytes));
        kl.version = cursor.get_bytes_as_int(@TypeOf(kl.version));
        kl.object_len = cursor.get_bytes_as_int(@TypeOf(kl.object_len));
        kl.date_time = cursor.get_bytes_as_int(@TypeOf(kl.date_time));
        kl.key_len = cursor.get_bytes_as_int(@TypeOf(kl.key_len));
        kl.cycle = cursor.get_bytes_as_int(@TypeOf(kl.cycle));
        if (kl.version < 1000) {
            kl.seek_key = cursor.get_bytes_as_int(u32);
            kl.seek_parent_dir = cursor.get_bytes_as_int(u32);
        } else {
            kl.seek_key = cursor.get_bytes_as_int(u64);
            kl.seek_parent_dir = cursor.get_bytes_as_int(u64);
        }
        kl.class_name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek);
        kl.class_name_bytes = @truncate(kl.class_name.len);
        kl.object_name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek);
        kl.object_name_bytes = @truncate(kl.object_name.len);
        kl.title_name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek);
        kl.title_name_bytes = @truncate(kl.title_name.len);
        return kl;
    }

    pub fn deinit(self: *Key) void {
        self._allocator.free(self.class_name);
        self._allocator.free(self.object_name);
        self._allocator.free(self.title_name);
    }

    pub fn read_data(self: *Key) !types.TaggedType {
        // Add key len to seek to start at data record
        var reader = self._parent.getReader();
        try reader.seekTo(self.seek_key + self.key_len);
        // No need to add 4 bytes here
        var data: []u8 = undefined;
        defer self._allocator.free(data);
        // Data records less than 256 bytes are not compressed
        if (self.object_len >= 256) {
            const data_buffer_compressed = try reader.interface.readAlloc(self._allocator, self.num_bytes - self.key_len);
            defer self._allocator.free(data_buffer_compressed);
            // Skip 9 bytes for root compression header
            var compressed_data: std.Io.Reader = .fixed(data_buffer_compressed[9..]);
            var buf: [std.compress.flate.max_window_len]u8 = undefined;
            var out: std.Io.Writer.Allocating = .init(self._allocator);
            defer out.deinit();
            var zstd_stream = std.compress.flate.Decompress.init(&compressed_data, .zlib, &buf);
            _ = try zstd_stream.reader.streamRemaining(&out.writer);
            data = try out.toOwnedSlice();
        } else {
            data = try reader.interface.readAlloc(self._allocator, self.num_bytes - self.key_len);
        }
        var cur: Cursor = .init(data);
        cur.set_origin(-1 * @as(i16, @bitCast(self.key_len)));
        return try types.TaggedType.init(self.class_name, &cur, self._allocator);
    }
};

const Record = struct {
    num_keys: u32 = undefined,
    keys: []Key = undefined,

    _allocator: std.mem.Allocator = undefined,
    pub fn init(cursor: *Cursor, parent: types.Parent, allocator: std.mem.Allocator) !@This() {
        var record = Record{};
        record._allocator = allocator;
        record.num_keys = cursor.get_bytes_as_int(@TypeOf(record.num_keys));
        record.keys = try allocator.alloc(Key, record.num_keys);
        for (0..record.num_keys) |ki| {
            record.keys[ki] = try Key.init(cursor, parent, allocator);
        }
        return record;
    }
    pub fn deinit(self: *Record) void {
        for (0..self.num_keys) |idx| {
            self.keys[idx].deinit();
        }
        self._allocator.free(self.keys);
    }
};

const FirstRecord = struct {
    // DATA
    tfile_name: []u8 = undefined,
    tfile_title_name: []u8 = undefined,
    tdir_version: u16 = undefined,
    creation_time: u32 = undefined,
    modification_time: u32 = undefined,
    num_bytes_keys_list: u32 = undefined,
    num_bytes_named: u32 = undefined,
    seek_dir_offset: u64 = undefined,
    seek_parent_offset: u64 = undefined,
    seek_keys: u64 = undefined,

    _allocator: std.mem.Allocator = undefined,
    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !FirstRecord {
        var record: FirstRecord = FirstRecord{};
        record._allocator = allocator;
        record.tfile_name = try cursor.read_u32_and_get_string(allocator);
        record.tfile_title_name = try cursor.read_u32_and_get_string(allocator);
        record.tdir_version = cursor.get_bytes_as_int(@TypeOf(record.tdir_version));
        record.creation_time = cursor.get_bytes_as_int(@TypeOf(record.creation_time));
        record.modification_time = cursor.get_bytes_as_int(@TypeOf(record.modification_time));
        record.num_bytes_keys_list = cursor.get_bytes_as_int(@TypeOf(record.num_bytes_keys_list));
        record.num_bytes_named = cursor.get_bytes_as_int(@TypeOf(record.num_bytes_named));
        if (record.tdir_version < 1000) {
            record.seek_dir_offset = cursor.get_bytes_as_int(u32);
            record.seek_parent_offset = cursor.get_bytes_as_int(u32);
            record.seek_keys = cursor.get_bytes_as_int(u32);
        } else {
            record.seek_dir_offset = cursor.get_bytes_as_int(u64);
            record.seek_parent_offset = cursor.get_bytes_as_int(u64);
            record.seek_keys = cursor.get_bytes_as_int(u64);
        }
        return record;
    }
    pub fn deinit(self: *FirstRecord) void {
        self._allocator.free(self.tfile_name);
        self._allocator.free(self.tfile_title_name);
    }
};

/// Root directory in a root file. Needs to be instantiated with an open call on an
/// already created instance because
pub const TDirectoryRoot = struct {
    key: Key = undefined,
    record: FirstRecord = undefined,

    _reader: std.fs.File.Reader = undefined,
    pub fn open(self: *TDirectoryRoot, cursor: *Cursor, reader: std.fs.File.Reader, allocator: std.mem.Allocator) !void {
        const parent = types.Parent{ .tdirectory_root = self };
        self._reader = reader;

        self.key = try .init(cursor, parent, allocator);
        self.record = try .init(cursor, allocator);
    }

    pub fn deinit(self: *TDirectoryRoot) void {
        self.key.deinit();
        self.record.deinit();
    }

    pub fn getReader(self: *TDirectoryRoot) std.fs.File.Reader {
        return self._reader;
    }
};

pub const TDirectory = struct {
    key: Key = undefined,
    record: Record = undefined,

    _reader: std.fs.File.Reader = undefined,
    pub fn open(self: *TDirectory, cursor: *Cursor, reader: std.fs.File.Reader, allocator: std.mem.Allocator) !void {
        const parent = types.Parent{ .tdirectory = self };
        self._reader = reader;

        self.key = try .init(cursor, parent, allocator);
        self.record = try .init(cursor, parent, allocator);
    }

    pub fn deinit(self: *TDirectory) void {
        self.key.deinit();
        self.record.deinit();
    }

    pub fn getReader(self: *TDirectory) std.fs.File.Reader {
        return self._reader;
    }
};

// Attempted an interface for header types, but that was overkill
// const Header = struct {
//     // Use an interface to allow for different sized headers depending on file size
//     ptr: *anyopaque,
//     initFn: *const fn (ptr: *anyopaque, buffer: []u8) anyerror!*anyopaque,
//
//     pub fn init(self: Header, buffer: []u8) !void {
//         const init_ptr = try self.initFn(self.ptr, buffer);
//         self.ptr = init_ptr;
//     }
// };

const Header = struct {
    ftype: [4]u8 = undefined,
    version: i32 = undefined,
    data_record_begin: u32 = undefined,
    file_end: i64 = undefined,
    compression: i32 = undefined,
    streamer_begin_offset: i64 = undefined,
    streamer_nbytes: i32 = undefined,

    fn init(cursor: *Cursor) !Header {
        var header: Header = .{};
        @memcpy(&header.ftype, cursor.buffer[0..(header.ftype.len)]);
        cursor.seek += header.ftype.len;
        header.version = cursor.get_bytes_as_int(@TypeOf(header.version));
        header.data_record_begin = cursor.get_bytes_as_int(@TypeOf(header.data_record_begin));
        if (header.version < 1000000) {
            // For small files
            header.file_end = cursor.get_bytes_as_int(u32);
            // FIXME: Skip a bunch of stuff
            cursor.seek += 17;
            header.compression = cursor.get_bytes_as_int(@TypeOf(header.compression));
            header.streamer_begin_offset = cursor.get_bytes_as_int(u32);
            header.streamer_nbytes = cursor.get_bytes_as_int(@TypeOf(header.streamer_nbytes));
        } else {
            // For big files
            header.file_end = cursor.get_bytes_as_int(i64);
            // FIXME: Skip a bunch of stuff
            cursor.seek += 21;
            header.compression = cursor.get_bytes_as_int(@TypeOf(header.compression));
            header.streamer_begin_offset = cursor.get_bytes_as_int(i64);
            header.streamer_nbytes = cursor.get_bytes_as_int(@TypeOf(header.streamer_nbytes));
        }
        return header;
    }

    pub fn deinit(self: *Header) void {
        _ = self;
        return;
    }
};

pub const RootFile = struct {
    file: std.fs.File = undefined,
    allocator: std.mem.Allocator = undefined,
    header: Header = undefined,
    // My understanding is that a TDirectory and a KeysList live together,
    // We should abstract these to be loaded together
    root_directory: TDirectoryRoot = undefined,
    root_keys_list: TDirectory = undefined,
    streamer_key: Key = undefined,
    streamer_record: types.TList = undefined,

    _reader: std.fs.File.Reader = undefined,

    pub fn open(filename: []u8, allocator: std.mem.Allocator) !RootFile {
        var root_file = RootFile{};
        root_file.file = try util.open_file(filename);
        root_file.allocator = allocator;
        // TODO: Add reader options
        const buffer: []u8 = try allocator.alloc(u8, 1024 * 1024);
        defer allocator.free(buffer);
        root_file._reader = root_file.file.reader(buffer);
        try root_file._reader.seekTo(0);
        const header_buffer = try root_file._reader.interface.take(constants.kFileHeaderSize);
        var header_cursor = Cursor.init(header_buffer);
        root_file.header = try .init(&header_cursor);
        const first_record_bytes, _ = util.get_buffer_info(try root_file._reader.interface.peek(4), 0, u32);
        const first_record_buffer = try root_file._reader.interface.readAlloc(allocator, first_record_bytes + 4);
        defer allocator.free(first_record_buffer);
        var first_record_cursor = Cursor.init(first_record_buffer);
        try root_file.root_directory.open(&first_record_cursor, root_file._reader, allocator);

        try root_file._reader.seekTo(root_file.root_directory.record.seek_keys);
        const first_key_bytes, _ = util.get_buffer_info(try root_file._reader.interface.peek(4), 0, u32);
        const first_key_buffer = try root_file._reader.interface.readAlloc(allocator, first_key_bytes);
        defer allocator.free(first_key_buffer);
        var kcursor: Cursor = Cursor.init(first_key_buffer);
        try root_file.root_keys_list.open(&kcursor, root_file._reader, allocator);

        try root_file._reader.seekTo(@abs(root_file.header.streamer_begin_offset));
        const streamer_buffer = try root_file._reader.interface.readAlloc(allocator, @abs(root_file.header.streamer_nbytes));
        defer allocator.free(streamer_buffer);
        var skcursor: Cursor = .init(streamer_buffer);
        const parent_dir = types.Parent{ .tdirectory_root = &root_file.root_directory };
        root_file.streamer_key = try .init(&skcursor, parent_dir, allocator);
        var streamer_data_compressed: std.Io.Reader = .fixed(streamer_buffer[(root_file.streamer_key.key_len + 9)..streamer_buffer.len]);
        var buf: [std.compress.flate.max_window_len]u8 = undefined;
        var out: std.Io.Writer.Allocating = .init(allocator);
        defer out.deinit();
        var zstd_stream = std.compress.flate.Decompress.init(&streamer_data_compressed, .zlib, &buf);
        _ = try zstd_stream.reader.streamRemaining(&out.writer);
        const streamer_data = try out.toOwnedSlice();
        defer allocator.free(streamer_data);
        var streamer_cursor = Cursor.init(streamer_data);
        streamer_cursor.set_origin((-1 * @as(i16, @bitCast(root_file.streamer_key.key_len))));
        root_file.streamer_record = .init(&streamer_cursor, allocator);
        return root_file;
    }

    pub fn init(filename: []u8) !RootFile {
        return try open(filename);
    }

    pub fn close(self: *RootFile) void {
        self.header.deinit();
        self.root_directory.deinit();
        self.root_keys_list.deinit();
        self.streamer_key.deinit();
        self.streamer_record.deinit();
        self.file.close();
    }

    pub fn deinit(self: *RootFile) void {
        self.close();
    }

    pub fn get_key(self: *RootFile, key_name: []const u8) ?Key {
        // Add null terminator if not provided
        var key_name_null_term: []u8 = undefined;
        var key_len = key_name.len;
        if (key_name[key_name.len - 1] != 0x00) {
            key_len = key_name.len + 1;
        }
        key_name_null_term = self.allocator.alloc(u8, key_len) catch |err| {
            std.debug.panic("Could not create string: {}", .{err});
        };
        defer self.allocator.free(key_name_null_term);
        @memcpy(key_name_null_term[0..key_name.len], key_name);
        key_name_null_term[key_name_null_term.len - 1] = 0x00;

        // Now search for key
        for (0..self.root_keys_list.record.num_keys) |idx| {
            const key = self.root_keys_list.record.keys[idx];
            if (std.mem.eql(u8, key.object_name, key_name_null_term)) {
                return key;
            }
        }
        std.log.warn("Could not find key {s}, available keys are: ", .{key_name_null_term});
        for (self.root_keys_list.record.keys) |key| {
            std.log.info("{s}: {s}\t{s}", .{ key.class_name, key.title_name, key.object_name });
        }
        return null;
    }

    pub fn get(self: *RootFile, name: []const u8) ?types.TaggedType {
        var key = get_key(self, name);
        if (key == null) {
            return null;
        }
        var key_data = key.?.read_data() catch |err| {
            std.log.warn("Issue getting key data for {s}, {}", .{ name, err });
            return null;
        };
        // Add in parent info for those that care
        switch (key_data) {
            .ttree => |*tree| tree._reader = self._reader,
            inline else => |t| std.debug.panic("{} wants parent info", .{t}),
        }
        return key_data;
    }
};
