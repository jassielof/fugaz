const std = @import("std");

const Allocator = std.mem.Allocator;

pub const ArtifactKind = enum {
    file,
    directory,
};

pub const CreatedFile = struct {
    file: std.fs.File,
    path: []u8,
};

pub const CreateError = Allocator.Error || std.fs.Dir.MakeError || std.fs.File.OpenError || std.fs.Dir.OpenError || error{ InvalidName, PathAlreadyExists };

pub fn validateNameComponent(component: []const u8) error{InvalidName}!void {
    for (component) |byte| {
        if (byte == 0 or byte == '/' or byte == '\\') {
            return error.InvalidName;
        }
    }
}

pub fn createTempDir(
    allocator: Allocator,
    parent_path: []const u8,
    prefix: []const u8,
    suffix: []const u8,
    random_len: usize,
    attempts: usize,
) CreateError![]u8 {
    try validateNameComponent(prefix);
    try validateNameComponent(suffix);

    var parent_dir = try std.fs.openDirAbsolute(parent_path, .{});
    defer parent_dir.close();

    var basename = try allocator.alloc(u8, prefix.len + random_len + suffix.len);
    defer allocator.free(basename);

    @memcpy(basename[0..prefix.len], prefix);
    @memcpy(basename[prefix.len + random_len ..], suffix);

    for (0..attempts) |_| {
        fillRandomName(basename[prefix.len .. prefix.len + random_len]);

        parent_dir.makeDir(basename) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };

        return try std.fs.path.join(allocator, &.{ parent_path, basename });
    }

    return error.PathAlreadyExists;
}

pub fn createTempFile(
    allocator: Allocator,
    parent_path: []const u8,
    prefix: []const u8,
    suffix: []const u8,
    random_len: usize,
    attempts: usize,
) CreateError!CreatedFile {
    try validateNameComponent(prefix);
    try validateNameComponent(suffix);

    var parent_dir = try std.fs.openDirAbsolute(parent_path, .{});
    defer parent_dir.close();

    var basename = try allocator.alloc(u8, prefix.len + random_len + suffix.len);
    defer allocator.free(basename);

    @memcpy(basename[0..prefix.len], prefix);
    @memcpy(basename[prefix.len + random_len ..], suffix);

    for (0..attempts) |_| {
        fillRandomName(basename[prefix.len .. prefix.len + random_len]);

        const file = parent_dir.createFile(basename, .{
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

pub fn deleteAbsolute(kind: ArtifactKind, absolute_path: []const u8) !void {
    const parent_path = std.fs.path.dirname(absolute_path) orelse return error.InvalidName;
    const basename = std.fs.path.basename(absolute_path);

    var parent_dir = try std.fs.openDirAbsolute(parent_path, .{ .iterate = kind == .directory });
    defer parent_dir.close();

    switch (kind) {
        .file => try parent_dir.deleteFile(basename),
        .directory => try parent_dir.deleteTree(basename),
    }
}

pub fn openFileAbsolute(absolute_path: []const u8, flags: std.fs.File.OpenFlags) !std.fs.File {
    const parent_path = std.fs.path.dirname(absolute_path) orelse return error.InvalidName;
    const basename = std.fs.path.basename(absolute_path);

    var parent_dir = try std.fs.openDirAbsolute(parent_path, .{});
    defer parent_dir.close();

    return parent_dir.openFile(basename, flags);
}

pub fn renameAbsolute(old_path: []const u8, new_path: []const u8) !void {
    try std.fs.renameAbsolute(old_path, new_path);
}

fn fillRandomName(buffer: []u8) void {
    const alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

    var random_bytes: [128]u8 = undefined;
    var index: usize = 0;
    while (index < buffer.len) {
        const chunk_len = @min(random_bytes.len, buffer.len - index);
        std.crypto.random.bytes(random_bytes[0..chunk_len]);
        for (random_bytes[0..chunk_len], 0..) |byte, offset| {
            buffer[index + offset] = alphabet[byte % alphabet.len];
        }
        index += chunk_len;
    }
}

test createTempDir {
    const allocator = std.testing.allocator;
    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const parent_path = try sandbox.dir.realpathAlloc(allocator, ".");
    defer allocator.free(parent_path);

    const path = try createTempDir(allocator, parent_path, "zig-", ".tmp", 10, 32);
    defer allocator.free(path);
    defer deleteAbsolute(.directory, path) catch {};

    try std.testing.expect(std.mem.startsWith(u8, std.fs.path.basename(path), "zig-"));
}

test createTempFile {
    const allocator = std.testing.allocator;
    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const parent_path = try sandbox.dir.realpathAlloc(allocator, ".");
    defer allocator.free(parent_path);

    var created = try createTempFile(allocator, parent_path, "zig-", ".tmp", 10, 32);
    defer created.file.close();
    defer allocator.free(created.path);
    defer deleteAbsolute(.file, created.path) catch {};

    try std.testing.expect(std.mem.endsWith(u8, created.path, ".tmp"));
}
