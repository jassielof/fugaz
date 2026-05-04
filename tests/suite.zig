const std = @import("std");
const fugaz = @import("fugaz");

const Io = std.Io;

comptime {
    std.testing.refAllDecls(@This());
}

test "TempDir integration" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const sandbox_path = try sandbox.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(sandbox_path);

    var temp_dir = try fugaz.builder()
        .prefix("suite-dir-")
        .suffix(".case")
        .tempDirIn(io, allocator, sandbox_path);

    const created_path = try allocator.dupe(u8, temp_dir.path());
    defer allocator.free(created_path);

    {
        var dir = try temp_dir.open(io, .{});
        defer dir.close(io);

        const file = try dir.createFile(io, "note.txt", .{});
        file.close(io);
    }

    temp_dir.deinit(io);

    try std.testing.expectError(error.FileNotFound, Io.Dir.openDirAbsolute(io, created_path, .{}));
}

test "TempFile integration" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const sandbox_path = try sandbox.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(sandbox_path);

    var temp_file = try fugaz.builder()
        .prefix("suite-file-")
        .suffix(".txt")
        .tempFileIn(io, allocator, sandbox_path);
    defer temp_file.deinit(io);

    try temp_file.handle().writeStreamingAll(io, "hello from tempfile");
    
    var reopened = try temp_file.reopen(io, .{ .mode = .read_only });
    defer reopened.close(io);

    var buffer: [64]u8 = undefined;
    const read_len = try reopened.readPositionalAll(io, &buffer, 0);
    try std.testing.expectEqualStrings("hello from tempfile", buffer[0..read_len]);

    const persisted_path = try std.fs.path.join(allocator, &.{ sandbox_path, "persisted.txt" });
    defer allocator.free(persisted_path);

    try temp_file.persist(io, persisted_path);

    var persisted = try Io.Dir.openFileAbsolute(io, persisted_path, .{ .mode = .read_only });
    defer persisted.close(io);

    var persisted_buffer: [64]u8 = undefined;
    const persisted_len = try persisted.readPositionalAll(io, &persisted_buffer, 0);
    try std.testing.expectEqualStrings("hello from tempfile", persisted_buffer[0..persisted_len]);
}
