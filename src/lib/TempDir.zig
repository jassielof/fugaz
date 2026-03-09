const std = @import("std");
const TempPath = @import("TempPath.zig");

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
pub fn open(self: *const TempDir, options: std.fs.Dir.OpenOptions) !std.fs.Dir {
    return std.fs.openDirAbsolute(self.path(), options);
}

/// Deletes the directory tree immediately.
pub fn close(self: *TempDir) !void {
    try self.temp_path.close();
}

/// Keeps the directory and returns its absolute path.
pub fn keep(self: *TempDir) []u8 {
    return self.temp_path.keep();
}

pub fn deinit(self: *TempDir) void {
    self.temp_path.deinit();
}

test TempDir {
    const allocator = std.testing.allocator;
    const Builder = @import("Builder.zig");

    var dir = try Builder.init().prefix("dir-").suffix(".case").tempDir(allocator);
    defer dir.deinit();

    try std.testing.expect(std.mem.startsWith(u8, std.fs.path.basename(dir.path()), "dir-"));
}
