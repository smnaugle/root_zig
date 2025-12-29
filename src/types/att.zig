const types = @import("../root.zig");
const Cursor = @import("../cursor.zig");

pub const TAttLine = struct {
    header: types.ClassHeader = undefined,
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
    header: types.ClassHeader = undefined,
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
    header: types.ClassHeader = undefined,
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
