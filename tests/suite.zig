const std = @import("std");
const fugaz = @import("fugaz");

comptime {
    std.testing.refAllDecls(@This());
}

test "TempDir integration" {
    const allocator = std.testing.allocator;

    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const sandbox_path = try sandbox.dir.realpathAlloc(allocator, ".");
    defer allocator.free(sandbox_path);

    var temp_dir = try fugaz.builder()
        .prefix("suite-dir-")
        .suffix(".case")
        .tempDirIn(allocator, sandbox_path);

    const created_path = try allocator.dupe(u8, temp_dir.path());
    defer allocator.free(created_path);

    {
        var dir = try temp_dir.open(.{});
        defer dir.close();

        const file = try dir.createFile("note.txt", .{});
        file.close();
    }

    temp_dir.deinit();

    try std.testing.expectError(error.FileNotFound, std.fs.openDirAbsolute(created_path, .{}));
}

test "TempFile integration" {
    const allocator = std.testing.allocator;

    var sandbox = std.testing.tmpDir(.{});
    defer sandbox.cleanup();

    const sandbox_path = try sandbox.dir.realpathAlloc(allocator, ".");
    defer allocator.free(sandbox_path);

    var temp_file = try fugaz.builder()
        .prefix("suite-file-")
        .suffix(".txt")
        .tempFileIn(allocator, sandbox_path);
    defer temp_file.deinit();

    try temp_file.handle().writeAll("hello from tempfile");
    try temp_file.handle().seekTo(0);

    var reopened = try temp_file.reopen(.{ .mode = .read_only });
    defer reopened.close();

    var buffer: [64]u8 = undefined;
    const read_len = try reopened.readAll(&buffer);
    try std.testing.expectEqualStrings("hello from tempfile", buffer[0..read_len]);

    const persisted_path = try std.fs.path.join(allocator, &.{ sandbox_path, "persisted.txt" });
    defer allocator.free(persisted_path);

    try temp_file.persist(persisted_path);

    var persisted = try std.fs.openFileAbsolute(persisted_path, .{ .mode = .read_only });
    defer persisted.close();

    var persisted_buffer: [64]u8 = undefined;
    const persisted_len = try persisted.readAll(&persisted_buffer);
    try std.testing.expectEqualStrings("hello from tempfile", persisted_buffer[0..persisted_len]);
}
