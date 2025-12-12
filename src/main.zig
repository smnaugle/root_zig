const std = @import("std");

const util = @import("utilities.zig");
const types = @import("root_types.zig");
const Cursor = @import("cursor.zig");

const Key = struct {
    //TKEY
    /// This is the number of bytes in the key+data sections
    num_bytes: u32 = undefined,
    version: u16 = undefined,
    object_len: u32 = undefined,
    date_time: u32 = undefined,
    /// This is the number of bytes in the key
    key_len: u16 = undefined,
    cycle: u16 = undefined,
    seek_key: u32 = undefined,
    seek_parent_dir: u32 = undefined,
    class_name_bytes: u8 = undefined,
    class_name: []u8 = undefined,
    object_name_bytes: u8 = undefined,
    object_name: []u8 = undefined,
    title_name_bytes: u8 = undefined,
    title_name: []u8 = undefined,

    pub fn init(cursor: *Cursor, allocator: std.mem.Allocator) !Key {
        var kl = Key{};
        kl.num_bytes = cursor.get_bytes_as_int(@TypeOf(kl.num_bytes));
        kl.version = cursor.get_bytes_as_int(@TypeOf(kl.version));
        kl.object_len = cursor.get_bytes_as_int(@TypeOf(kl.object_len));
        kl.date_time = cursor.get_bytes_as_int(@TypeOf(kl.date_time));
        kl.key_len = cursor.get_bytes_as_int(@TypeOf(kl.key_len));
        kl.cycle = cursor.get_bytes_as_int(@TypeOf(kl.cycle));
        kl.seek_key = cursor.get_bytes_as_int(@TypeOf(kl.seek_key));
        kl.seek_parent_dir = cursor.get_bytes_as_int(@TypeOf(kl.seek_parent_dir));
        kl.class_name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek);
        kl.class_name_bytes = @truncate(kl.class_name.len);
        kl.object_name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek);
        kl.object_name_bytes = @truncate(kl.object_name.len);
        kl.title_name, cursor.seek = try util.read_num_bytes_and_name(cursor.buffer, allocator, cursor.seek);
        kl.title_name_bytes = @truncate(kl.title_name.len);
        return kl;
    }
};

const Record = struct {
    num_keys: u32 = undefined,
    keys: []Key = undefined,
    pub fn init(buffer: []u8, allocator: std.mem.Allocator) !@This() {
        var record = Record{};
        var next_byte: u64 = 0;
        record.num_keys, next_byte = util.get_buffer_info(buffer, next_byte, @TypeOf(record.num_keys));
        record.keys = try allocator.alloc(Key, record.num_keys);
        for (0..record.num_keys) |ki| {
            var kcursor: Cursor = .init(buffer[next_byte..buffer.len]);
            record.keys[ki] = try Key.init(&kcursor, allocator);
            next_byte = next_byte + record.keys[ki].key_len;
        }
        return record;
    }
};

const FirstRecord = struct {
    key: Key = undefined,

    // DATA
    tfile_name: []u8 = undefined,
    tfile_name_end: u64 = undefined,
    tfile_title_name: []u8 = undefined,
    tfile_title_name_end: u64 = undefined,
    tdir_version: u8 = undefined,
    creation_time: u32 = undefined,
    modification_time: u32 = undefined,
    num_bytes_keys_list: u32 = undefined,
    num_bytes_named: u32 = undefined,
    seek_dir_offset: u32 = undefined,
    seek_parent_offset: u32 = undefined,
    seek_keys: u32 = undefined,

    pub fn init(record_buffer: []u8, allocator: std.mem.Allocator) !FirstRecord {
        var record: FirstRecord = FirstRecord{};

        var kcursor = Cursor.init(record_buffer);
        record.key = try Key.init(&kcursor, allocator);

        record.tfile_name, record.tfile_name_end = try util.read_num_bytes_and_name(
            record_buffer,
            allocator,
            @abs(record.key.key_len),
        );

        record.tfile_title_name, record.tfile_title_name_end = try util.read_num_bytes_and_name(
            record_buffer,
            allocator,
            @truncate(@abs(record.tfile_name_end)),
        );
        var next_byte: u64 = undefined;
        record.tdir_version, next_byte = util.get_buffer_info(record_buffer, record.tfile_title_name_end + 1, @TypeOf(record.tdir_version));
        record.creation_time, next_byte = util.get_buffer_info(record_buffer, next_byte, @TypeOf(record.creation_time));
        record.modification_time, next_byte = util.get_buffer_info(record_buffer, next_byte, @TypeOf(record.modification_time));
        record.num_bytes_keys_list, next_byte = util.get_buffer_info(record_buffer, next_byte, @TypeOf(record.num_bytes_keys_list));
        record.num_bytes_named, next_byte = util.get_buffer_info(record_buffer, next_byte, @TypeOf(record.num_bytes_named));
        record.seek_dir_offset, next_byte = util.get_buffer_info(record_buffer, next_byte, @TypeOf(record.seek_dir_offset));
        record.seek_parent_offset, next_byte = util.get_buffer_info(record_buffer, next_byte, @TypeOf(record.seek_parent_offset));
        record.seek_keys, next_byte = util.get_buffer_info(record_buffer, next_byte, @TypeOf(record.seek_keys));
        return record;
    }
};

const RootFileHeader = struct {
    const FTYPE_BYTES = [_]u8{ 0, 4 };
    const VERSION_BYTES = [_]u8{ 4, 8 };
    const REC_BEG_BYTES = [_]u8{ 8, 12 };
    const FILE_END_BYTES = [_]u8{ 12, 16 };
    const COMPRESSION_BYTES = [_]u8{ 33, 37 };
    const STR_BEG_BYTES = [_]u8{ 37, 41 };
    const STR_NB_BYTES = [_]u8{ 41, 45 };

    ftype: [4]u8 = undefined,
    version: i32 = undefined,
    data_record_begin: i64 = undefined,
    file_end: i64 = undefined,
    compression: i32 = undefined,
    streamer_begin_offset: i32 = undefined,
    streamer_nbytes: i32 = undefined,

    fn init(header_buffer: []u8) !RootFileHeader {
        const header: RootFileHeader = .{
            .ftype = header_buffer[FTYPE_BYTES[0]..FTYPE_BYTES[1]].*,
            .version = std.mem.readVarInt(i32, header_buffer[VERSION_BYTES[0]..VERSION_BYTES[1]], .big),
            .data_record_begin = std.mem.readVarInt(i32, header_buffer[REC_BEG_BYTES[0]..REC_BEG_BYTES[1]], .big),
            .file_end = std.mem.readVarInt(i64, header_buffer[FILE_END_BYTES[0]..FILE_END_BYTES[1]], .big),
            .compression = std.mem.readVarInt(i32, header_buffer[COMPRESSION_BYTES[0]..COMPRESSION_BYTES[1]], .big),
            .streamer_begin_offset = std.mem.readVarInt(i32, header_buffer[STR_BEG_BYTES[0]..STR_BEG_BYTES[1]], .big),
            .streamer_nbytes = std.mem.readVarInt(i32, header_buffer[STR_NB_BYTES[0]..STR_NB_BYTES[1]], .big),
        };
        return header;
    }
};

pub const RootFile = struct {
    file: std.fs.File = undefined,
    header: RootFileHeader = undefined,
    root_record: FirstRecord = undefined,
    root_key: Key = undefined,
    root_key_record: Record = undefined,
    streamer_key: Key = undefined,
    streamer_record: types.TList = undefined,

    pub fn open(filename: []u8, allocator: std.mem.Allocator) !RootFile {
        var root_file = RootFile{};
        root_file.file = try util.open_file(filename);
        const buffer: []u8 = try allocator.alloc(u8, 1024 * 1024);
        defer allocator.free(buffer);
        var reader = root_file.file.reader(buffer);
        try reader.seekTo(0);
        const header_buffer = try reader.interface.take(100);
        root_file.header = try RootFileHeader.init(header_buffer);
        if (root_file.header.version > 1000000) {
            return error.RootFileTooBigError;
        }
        const first_record_bytes, _ = util.get_buffer_info(try reader.interface.peek(4), 0, u32);
        const first_record_buffer = try reader.interface.readAlloc(allocator, first_record_bytes);
        root_file.root_record = try FirstRecord.init(first_record_buffer, allocator);

        try reader.seekTo(root_file.root_record.seek_keys);
        const first_key_bytes, _ = util.get_buffer_info(try reader.interface.peek(4), 0, u32);
        const first_key_buffer = try reader.interface.readAlloc(allocator, first_key_bytes);
        var kcursor: Cursor = Cursor.init(first_key_buffer);
        root_file.root_key = try Key.init(&kcursor, allocator);

        try reader.seekTo(root_file.root_record.seek_keys + root_file.root_key.key_len);
        const rec_buffer = try reader.interface.take(@abs(root_file.header.file_end) - reader.pos);
        root_file.root_key_record = try Record.init(rec_buffer, allocator);

        try reader.seekTo(@abs(root_file.header.streamer_begin_offset));
        const streamer_buffer = try reader.interface.take(@abs(root_file.header.streamer_nbytes));
        var skcursor: Cursor = .init(streamer_buffer);
        root_file.streamer_key = try .init(&skcursor, allocator);
        std.debug.print("Streamer key {}\n", .{root_file.streamer_key});
        var streamer_data_compressed: std.Io.Reader = .fixed(streamer_buffer[(root_file.streamer_key.key_len + 9)..streamer_buffer.len]);
        var buf: [std.compress.flate.max_window_len]u8 = undefined;
        var out: std.Io.Writer.Allocating = .init(allocator);
        defer out.deinit();
        var zstd_stream = std.compress.flate.Decompress.init(&streamer_data_compressed, .zlib, &buf);
        _ = try zstd_stream.reader.streamRemaining(&out.writer);
        const streamer_data = try out.toOwnedSlice();
        var streamer_cursor = Cursor.init(streamer_data);
        streamer_cursor.set_origin((-1 * @as(i16, @bitCast(root_file.streamer_key.key_len))));
        root_file.streamer_record = try .init(&streamer_cursor, allocator);

        return root_file;
    }

    pub fn init(filename: []u8) !RootFile {
        return try open(filename);
    }

    pub fn close(self: RootFile) void {
        self.file.close();
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print("Please specify filename", .{});
        return;
    }

    const root_file = try RootFile.open(args[1], allocator);
    defer root_file.close();

    try root_file.file.seekTo(100);
    var buf: [4096]u8 = undefined;
    _ = try root_file.file.read(&buf);
    // const record = try FirstRecord.init(&buf, allocator);
    const record = root_file.root_record;
    try root_file.file.seekTo(record.seek_keys);
    var num_bytes = try root_file.file.read(&buf);
    // const kl = try Key.init(&buf, allocator);
    const kl = root_file.root_key;
    _ = kl;
    const rec = root_file.root_key_record;
    // const rec = try Record.init(buf[kl.key_len..num_bytes], allocator);
    try root_file.file.seekTo(rec.keys[0].seek_key);
    num_bytes = try root_file.file.read(&buf);
    // const ttree_key = try Key.init(&buf, allocator);

    // var nbuf: [4096]u8 = undefined;
    // var rfile = root_file.file.reader(&nbuf);
    // try rfile.seekTo(root_file.root_key_record.keys[0].seek_key);
    // const nb, _ = util.get_buffer_info(try rfile.interface.peek(4), 0, u32);
    // const skbuf = try rfile.interface.readAlloc(allocator, nb);
    // var skcursor: Cursor = .init(skbuf);
    // const seeked_key = try Key.init(&skcursor, allocator);
    // const seeked_key_head = skbuf[(seeked_key.key_len + 9)..skbuf.len];
    // var comp_data: std.Io.Reader = .fixed(seeked_key_head);
    // var decomp_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    // var out: std.Io.Writer.Allocating = .init(allocator);
    // defer out.deinit();
    // var zstd_stream = std.compress.flate.Decompress.init(&comp_data, .zlib, &decomp_buffer);
    // _ = try zstd_stream.reader.streamRemaining(&out.writer);
    // const decomp = try out.toOwnedSlice();
    // const ttree = try types.TTree.init(decomp[0..decomp.len], allocator);
    // _ = ttree;
    // std.debug.print("{}\n", .{root_file.streamer_key});
    // std.debug.print("{d}\n", .{root_file.streamer_key.num_bytes - root_file.streamer_key.key_len});
    // std.debug.print("{}\n", .{root_file.streamer_record.nobjects});
    // std.debug.print("{}\n", .{root_file.streamer_record});
}
// 4002f78b00144000001a00010001000000000300000806
