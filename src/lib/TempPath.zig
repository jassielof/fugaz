const std = @import("std");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const TempPath = @This();

allocator: Allocator,
path_buf: []u8,
kind: util.ArtifactKind,
retain: bool,
owns_path: bool = true,

pub fn init(allocator: Allocator, owned_path: []u8, kind: util.ArtifactKind, retain: bool) TempPath {
    return .{
        .allocator = allocator,
        .path_buf = owned_path,
        .kind = kind,
        .retain = retain,
    };
}

/// Returns the absolute path managed by this handle.
pub fn path(self: *const TempPath) []const u8 {
    return self.path_buf;
}

/// Removes the underlying artifact unless cleanup has been disabled.
/// Memory owned by the handle is always released.
pub fn close(self: *TempPath, io: Io) !void {
    if (self.path_buf.len == 0) {
        return;
    }

    if (!self.retain) {
        try util.deleteAbsolute(io, self.kind, self.path_buf);
    }

    self.releaseMemory();
}

/// Keeps the artifact on disk and transfers ownership of the absolute path.
pub fn keep(self: *TempPath) []u8 {
    self.retain = true;

    const owned_path = self.path_buf;
    self.path_buf = &.{};
    self.owns_path = false;
    return owned_path;
}

/// Renames the artifact to `new_path` and disables cleanup for the old path.
pub fn persist(self: *TempPath, io: Io, new_path: []const u8) !void {
    if (self.path_buf.len == 0) {
        return;
    }

    try util.renameAbsolute(io, self.path_buf, new_path);
    self.releaseMemory();
}

pub fn deinit(self: *TempPath, io: Io) void {
    if (self.path_buf.len != 0 and !self.retain) {
        util.deleteAbsolute(io, self.kind, self.path_buf) catch {};
    }
    self.releaseMemory();
}

fn releaseMemory(self: *TempPath) void {
    if (self.owns_path and self.path_buf.len != 0) {
        self.allocator.free(self.path_buf);
    }
    self.path_buf = &.{};
    self.owns_path = false;
}

test TempPath {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const parent_path = try sandbox.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(parent_path);

    const owned_path = try std.fs.path.join(allocator, &.{ parent_path, "owned.txt" });

    var dir = try Io.Dir.openDirAbsolute(io, parent_path, .{});
    defer dir.close(io);
    const file = try dir.createFile(io, "owned.txt", .{});
    file.close(io);

    var temp_path = TempPath.init(allocator, owned_path, .file, false);
    try temp_path.close(io);

    try std.testing.expectError(error.FileNotFound, dir.openFile(io, "owned.txt", .{}));
}
