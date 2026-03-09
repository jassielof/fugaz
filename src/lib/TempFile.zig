const std = @import("std");
const TempPath = @import("TempPath.zig");
const util = @import("util.zig");

pub const TempFile = @This();

file_handle: std.fs.File,
temp_path: TempPath,
open: bool = true,

pub fn initOwned(allocator: std.mem.Allocator, file_handle: std.fs.File, owned_path: []u8, retain: bool) TempFile {
    return .{
        .file_handle = file_handle,
        .temp_path = TempPath.init(allocator, owned_path, .file, retain),
    };
}

/// Returns the absolute path to the managed file.
pub fn path(self: *const TempFile) []const u8 {
    return self.temp_path.path();
}

/// Returns the owned file handle.
pub fn handle(self: *TempFile) *std.fs.File {
    return &self.file_handle;
}

/// Opens a second handle to the same path.
pub fn reopen(self: *const TempFile, flags: std.fs.File.OpenFlags) !std.fs.File {
    return util.openFileAbsolute(self.path(), flags);
}

/// Persists the file at `new_path` and disables cleanup for the old path.
pub fn persist(self: *TempFile, new_path: []const u8) !void {
    self.closeHandle();
    try self.temp_path.persist(new_path);
}

/// Keeps the file on disk and returns the owned absolute path.
pub fn keep(self: *TempFile) []u8 {
    self.closeHandle();
    return self.temp_path.keep();
}

/// Closes the file handle and removes the file unless retention is enabled.
pub fn close(self: *TempFile) !void {
    self.closeHandle();
    try self.temp_path.close();
}

pub fn deinit(self: *TempFile) void {
    self.closeHandle();
    self.temp_path.deinit();
}

fn closeHandle(self: *TempFile) void {
    if (self.open) {
        self.file_handle.close();
        self.open = false;
    }
}

test TempFile {
    const allocator = std.testing.allocator;
    const Builder = @import("Builder.zig");

    var temp_file = try Builder.init().prefix("file-").suffix(".txt").tempFile(allocator);
    defer temp_file.deinit();

    try temp_file.handle().writeAll("hello");
    try temp_file.handle().seekTo(0);

    var reopened = try temp_file.reopen(.{ .mode = .read_only });
    defer reopened.close();

    var buffer: [5]u8 = undefined;
    const read_len = try reopened.readAll(&buffer);
    try std.testing.expectEqualStrings("hello", buffer[0..read_len]);
}
