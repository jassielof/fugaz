const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;

pub const TempDirPathError = Allocator.Error || error{ NameTooLong, Unexpected };

/// Returns the process temporary directory as an owned absolute path.
pub fn tempDirPathAlloc(allocator: Allocator) TempDirPathError![]u8 {
    if (builtin.os.tag == .windows) {
        return windowsTempDirPathAlloc(allocator);
    }

    const path = std.posix.getenv("TMPDIR") orelse "/tmp";
    return allocator.dupe(u8, path);
}

fn windowsTempDirPathAlloc(allocator: Allocator) TempDirPathError![]u8 {
    const windows = std.os.windows;

    var wide_buffer: [32767]u16 = undefined;
    const wide_len = GetTempPathW(@intCast(wide_buffer.len), &wide_buffer);
    if (wide_len == 0) {
        return windows.unexpectedError(windows.GetLastError());
    }
    if (wide_len > wide_buffer.len) {
        return error.NameTooLong;
    }

    const utf8_path = try allocator.alloc(u8, wide_len * 3);
    errdefer allocator.free(utf8_path);

    var end_index: usize = 0;
    var iterator = std.unicode.Utf16LeIterator.init(wide_buffer[0..wide_len]);
    while (iterator.nextCodepoint() catch return error.Unexpected) |codepoint| {
        end_index += std.unicode.utf8Encode(codepoint, utf8_path[end_index..]) catch {
            return error.Unexpected;
        };
    }

    const exact_path = try allocator.realloc(utf8_path, end_index);
    const trimmed_len = trimmedLength(exact_path);
    return allocator.realloc(exact_path, trimmed_len);
}

fn trimmedLength(path: []const u8) usize {
    var end = path.len;
    while (end > minPathLen(path) and isPathSeparator(path[end - 1])) : (end -= 1) {}
    return end;
}

fn minPathLen(path: []const u8) usize {
    if (builtin.os.tag == .windows and path.len >= 3 and std.ascii.isAlphabetic(path[0]) and path[1] == ':' and isPathSeparator(path[2])) {
        return 3;
    }
    return 1;
}

fn isPathSeparator(byte: u8) bool {
    return byte == '/' or byte == '\\';
}

extern "kernel32" fn GetTempPathW(
    nBufferLength: std.os.windows.DWORD,
    lpBuffer: [*]u16,
) callconv(.winapi) std.os.windows.DWORD;

test tempDirPathAlloc {
    const allocator = std.testing.allocator;

    const path = try tempDirPathAlloc(allocator);
    defer allocator.free(path);

    try std.testing.expect(path.len > 0);
}
