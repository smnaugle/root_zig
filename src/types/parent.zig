const std = @import("std");

const types = @import("types.zig");

pub const Parent = union(enum) {
    tdirectory_root: *types.TDirectoryRoot,
    tdirectory: *types.TDirectory,
    none,

    pub fn getReader(self: Parent) std.fs.File.Reader {
        switch (self) {
            .none => std.debug.panic("Cannot return reader from {}", .{self}),
            inline else => |parent| return parent.getReader(),
        }
    }
};
