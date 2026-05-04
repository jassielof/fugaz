const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const ArtifactKind = enum {
    file,
    directory,
};

pub const CreatedFile = struct {
    file: Io.File,
    path: []u8,
};

pub const CreateError = Allocator.Error || Io.Dir.CreateDirError || Io.File.OpenError || Io.Dir.OpenError || error{ InvalidName, PathAlreadyExists };

pub fn validateNameComponent(component: []const u8) error{InvalidName}!void {
    for (component) |byte| {
        if (byte == 0 or byte == '/' or byte == '\\') {
            return error.InvalidName;
        }
    }
}

pub fn createTempDir(
    io: Io,
    allocator: Allocator,
    parent_path: []const u8,
    prefix: []const u8,
    suffix: []const u8,
    random_len: usize,
    attempts: usize,
) CreateError![]u8 {
    try validateNameComponent(prefix);
    try validateNameComponent(suffix);

    var parent_dir = try Io.Dir.openDirAbsolute(io, parent_path, .{});
    defer parent_dir.close(io);

    var basename = try allocator.alloc(u8, prefix.len + random_len + suffix.len);
    defer allocator.free(basename);

    @memcpy(basename[0..prefix.len], prefix);
    @memcpy(basename[prefix.len + random_len ..], suffix);

    for (0..attempts) |_| {
        fillRandomName(io, basename[prefix.len .. prefix.len + random_len]);

        parent_dir.createDir(io, basename, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };

        return try std.fs.path.join(allocator, &.{ parent_path, basename });
    }

    return error.PathAlreadyExists;
}

pub fn createTempFile(
    io: Io,
    allocator: Allocator,
    parent_path: []const u8,
    prefix: []const u8,
    suffix: []const u8,
    random_len: usize,
    attempts: usize,
) CreateError!CreatedFile {
    try validateNameComponent(prefix);
    try validateNameComponent(suffix);

    var parent_dir = try Io.Dir.openDirAbsolute(io, parent_path, .{});
    defer parent_dir.close(io);

    var basename = try allocator.alloc(u8, prefix.len + random_len + suffix.len);
    defer allocator.free(basename);

    @memcpy(basename[0..prefix.len], prefix);
    @memcpy(basename[prefix.len + random_len ..], suffix);

    for (0..attempts) |_| {
        fillRandomName(io, basename[prefix.len .. prefix.len + random_len]);

        const file = parent_dir.createFile(io, basename, .{
            .exclusive = true,
            .read = true,
        }) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };

        return .{
            .file = file,
            .path = try std.fs.path.join(allocator, &.{ parent_path, basename }),
        };
    }

    return error.PathAlreadyExists;
}

pub fn deleteAbsolute(io: Io, kind: ArtifactKind, absolute_path: []const u8) !void {
    const parent_path = std.fs.path.dirname(absolute_path) orelse return error.InvalidName;
    const basename = std.fs.path.basename(absolute_path);

    var parent_dir = try Io.Dir.openDirAbsolute(io, parent_path, .{});
    defer parent_dir.close(io);

    switch (kind) {
        .file => try parent_dir.deleteFile(io, basename),
        .directory => try parent_dir.deleteTree(io, basename),
    }
}

pub fn openFileAbsolute(io: Io, absolute_path: []const u8, flags: Io.File.OpenFlags) !Io.File {
    const parent_path = std.fs.path.dirname(absolute_path) orelse return error.InvalidName;
    const basename = std.fs.path.basename(absolute_path);

    var parent_dir = try Io.Dir.openDirAbsolute(io, parent_path, .{});
    defer parent_dir.close(io);

    return parent_dir.openFile(io, basename, flags);
}

pub fn renameAbsolute(io: Io, old_path: []const u8, new_path: []const u8) !void {
    try Io.Dir.renameAbsolute(old_path, new_path, io);
}

fn fillRandomName(io: Io, buffer: []u8) void {
    const alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

    var random_bytes: [128]u8 = undefined;
    var index: usize = 0;
    while (index < buffer.len) {
        const chunk_len = @min(random_bytes.len, buffer.len - index);
        io.random(random_bytes[0..chunk_len]);
        for (random_bytes[0..chunk_len], 0..) |byte, offset| {
            buffer[index + offset] = alphabet[byte % alphabet.len];
        }
        index += chunk_len;
    }
}

test createTempDir {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const parent_path = try sandbox.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(parent_path);

    const path = try createTempDir(io, allocator, parent_path, "zig-", ".tmp", 10, 32);
    defer allocator.free(path);
    defer deleteAbsolute(io, .directory, path) catch {};

    try std.testing.expect(std.mem.startsWith(u8, std.fs.path.basename(path), "zig-"));
}

test createTempFile {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const parent_path = try sandbox.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(parent_path);

    var created = try createTempFile(io, allocator, parent_path, "zig-", ".tmp", 10, 32);
    defer created.file.close(io);
    defer allocator.free(created.path);
    defer deleteAbsolute(io, .file, created.path) catch {};

    try std.testing.expect(std.mem.endsWith(u8, created.path, ".tmp"));
}
