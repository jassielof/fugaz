//! Secure-ish and convenient temporary files and directories.
//!
//! The library centers around a small set of types:
//!
//! - `Builder` customizes names and retention policy.
//! - `TempDir` owns a temporary directory and removes it on cleanup.
//! - `TempFile` owns an open temporary file handle and its path.
//! - `TempPath` owns cleanup for a temporary path without an open handle.
//!
//! The API is intentionally path-based so it works well in both tests and
//! production code.

const std = @import("std");

pub const Builder = @import("Builder.zig");
pub const TempDir = @import("TempDir.zig");
pub const TempFile = @import("TempFile.zig");
pub const TempPath = @import("TempPath.zig");
pub const env = @import("env.zig");

const Io = std.Io;

/// Returns a builder with the default naming scheme.
pub fn builder() Builder {
    return Builder.init();
}

/// Creates a temporary directory inside the process temporary directory.
pub fn tempDir(io: Io, allocator: std.mem.Allocator) !TempDir {
    return Builder.init().tempDir(io, allocator);
}

/// Creates a temporary directory inside `parent_path`.
pub fn tempDirIn(io: Io, allocator: std.mem.Allocator, parent_path: []const u8) !TempDir {
    return Builder.init().tempDirIn(io, allocator, parent_path);
}

/// Creates a temporary file inside the process temporary directory.
pub fn tempFile(io: Io, allocator: std.mem.Allocator) !TempFile {
    return Builder.init().tempFile(io, allocator);
}

/// Creates a temporary file inside `parent_path`.
pub fn tempFileIn(io: Io, allocator: std.mem.Allocator, parent_path: []const u8) !TempFile {
    return Builder.init().tempFileIn(io, allocator, parent_path);
}

comptime {
    std.testing.refAllDecls(@This());
}
