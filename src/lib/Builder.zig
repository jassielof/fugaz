const std = @import("std");
const env = @import("env.zig");
const util = @import("util.zig");
const TempDir = @import("TempDir.zig");
const TempFile = @import("TempFile.zig");

const Allocator = std.mem.Allocator;

pub const Builder = @This();

name_prefix: []const u8 = ".tmp-",
name_suffix: []const u8 = "",
random_length: usize = 12,
retain_on_cleanup: bool = false,
max_attempts: usize = 256,

/// Returns a builder with the default configuration.
pub fn init() Builder {
    return .{};
}

/// Sets the filename prefix.
pub fn prefix(self: Builder, value: []const u8) Builder {
    var next = self;
    next.name_prefix = value;
    return next;
}

/// Sets the filename suffix.
pub fn suffix(self: Builder, value: []const u8) Builder {
    var next = self;
    next.name_suffix = value;
    return next;
}

/// Sets the number of random characters appended between prefix and suffix.
pub fn randomLength(self: Builder, value: usize) Builder {
    var next = self;
    next.random_length = value;
    return next;
}

/// Keeps the artifact on cleanup instead of removing it.
pub fn retain(self: Builder, value: bool) Builder {
    var next = self;
    next.retain_on_cleanup = value;
    return next;
}

/// Limits how many unique-name attempts are made before failing.
pub fn attempts(self: Builder, value: usize) Builder {
    var next = self;
    next.max_attempts = value;
    return next;
}

/// Creates a temporary directory in the process temporary directory.
pub fn tempDir(self: Builder, allocator: Allocator) !TempDir {
    const parent_path = try env.tempDirPathAlloc(allocator);
    defer allocator.free(parent_path);

    const path = try util.createTempDir(
        allocator,
        parent_path,
        self.name_prefix,
        self.name_suffix,
        self.random_length,
        self.max_attempts,
    );
    return TempDir.initOwned(allocator, path, self.retain_on_cleanup);
}

/// Creates a temporary directory in `parent_path`.
pub fn tempDirIn(self: Builder, allocator: Allocator, parent_path: []const u8) !TempDir {
    const resolved_parent = try std.fs.cwd().realpathAlloc(allocator, parent_path);
    defer allocator.free(resolved_parent);

    const path = try util.createTempDir(
        allocator,
        resolved_parent,
        self.name_prefix,
        self.name_suffix,
        self.random_length,
        self.max_attempts,
    );
    return TempDir.initOwned(allocator, path, self.retain_on_cleanup);
}

/// Creates a temporary file in the process temporary directory.
pub fn tempFile(self: Builder, allocator: Allocator) !TempFile {
    const parent_path = try env.tempDirPathAlloc(allocator);
    defer allocator.free(parent_path);

    const created = try util.createTempFile(
        allocator,
        parent_path,
        self.name_prefix,
        self.name_suffix,
        self.random_length,
        self.max_attempts,
    );
    errdefer allocator.free(created.path);

    return TempFile.initOwned(allocator, created.file, created.path, self.retain_on_cleanup);
}

/// Creates a temporary file in `parent_path`.
pub fn tempFileIn(self: Builder, allocator: Allocator, parent_path: []const u8) !TempFile {
    const resolved_parent = try std.fs.cwd().realpathAlloc(allocator, parent_path);
    defer allocator.free(resolved_parent);

    const created = try util.createTempFile(
        allocator,
        resolved_parent,
        self.name_prefix,
        self.name_suffix,
        self.random_length,
        self.max_attempts,
    );
    errdefer allocator.free(created.path);

    return TempFile.initOwned(allocator, created.file, created.path, self.retain_on_cleanup);
}

test Builder {
    const allocator = std.testing.allocator;

    var builder = Builder.init()
        .prefix("case-")
        .suffix(".zig")
        .randomLength(8);

    var temp_file = try builder.tempFile(allocator);
    defer temp_file.deinit();

    try std.testing.expect(std.mem.startsWith(u8, std.fs.path.basename(temp_file.path()), "case-"));
    try std.testing.expect(std.mem.endsWith(u8, std.fs.path.basename(temp_file.path()), ".zig"));
}
