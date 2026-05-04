const std = @import("std");
const TempPath = @import("TempPath.zig");

const Io = std.Io;

pub const TempDir = @This();

temp_path: TempPath,

pub fn initOwned(allocator: std.mem.Allocator, owned_path: []u8, retain: bool) TempDir {
    return .{
        .temp_path = TempPath.init(allocator, owned_path, .directory, retain),
    };
}

/// Returns the absolute path to the managed directory.
pub fn path(self: *const TempDir) []const u8 {
    return self.temp_path.path();
}

/// Opens the directory.
pub fn open(self: *const TempDir, io: Io, options: Io.Dir.OpenOptions) !Io.Dir {
    return Io.Dir.openDirAbsolute(io, self.path(), options);
}

/// Deletes the directory tree immediately.
pub fn close(self: *TempDir, io: Io) !void {
    try self.temp_path.close(io);
}

/// Keeps the directory and returns its absolute path.
pub fn keep(self: *TempDir) []u8 {
    return self.temp_path.keep();
}

pub fn deinit(self: *TempDir, io: Io) void {
    self.temp_path.deinit(io);
}

test TempDir {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const Builder = @import("Builder.zig");

    var dir = try Builder.init().prefix("dir-").suffix(".case").tempDir(io, allocator);
    defer dir.deinit(io);

    try std.testing.expect(std.mem.startsWith(u8, std.fs.path.basename(dir.path()), "dir-"));
}
