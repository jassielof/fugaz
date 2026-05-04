const std = @import("std");
const TempPath = @import("TempPath.zig");
const util = @import("util.zig");

const Io = std.Io;

pub const TempFile = @This();

file_handle: Io.File,
temp_path: TempPath,
open: bool = true,

pub fn initOwned(allocator: std.mem.Allocator, file_handle: Io.File, owned_path: []u8, retain: bool) TempFile {
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
pub fn handle(self: *TempFile) *Io.File {
    return &self.file_handle;
}

/// Opens a second handle to the same path.
pub fn reopen(self: *const TempFile, io: Io, flags: Io.File.OpenFlags) !Io.File {
    return util.openFileAbsolute(io, self.path(), flags);
}

/// Persists the file at `new_path` and disables cleanup for the old path.
pub fn persist(self: *TempFile, io: Io, new_path: []const u8) !void {
    self.closeHandle(io);
    try self.temp_path.persist(io, new_path);
}

/// Keeps the file on disk and returns the owned absolute path.
pub fn keep(self: *TempFile, io: Io) []u8 {
    self.closeHandle(io);
    return self.temp_path.keep();
}

/// Closes the file handle and removes the file unless retention is enabled.
pub fn close(self: *TempFile, io: Io) !void {
    self.closeHandle(io);
    try self.temp_path.close(io);
}

pub fn deinit(self: *TempFile, io: Io) void {
    self.closeHandle(io);
    self.temp_path.deinit(io);
}

fn closeHandle(self: *TempFile, io: Io) void {
    if (self.open) {
        self.file_handle.close(io);
        self.open = false;
    }
}

test TempFile {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const Builder = @import("Builder.zig");

    var temp_file = try Builder.init().prefix("file-").suffix(".txt").tempFile(io, allocator);
    defer temp_file.deinit(io);

    try temp_file.handle().writeStreamingAll(io, "hello");
}
