const std = @import("std");
const DateTime = @import("./deps/zig-datetime/src/datetime.zig");

pub fn main() !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    defer bw.flush() catch unreachable;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) stdout.print("memory leak detected\n", .{}) catch unreachable;
    }

    std.fs.cwd().makeDir("log") catch |err| {
        if (err == error.PathAlreadyExists) {
            // ignore
        } else {
            try stdout.print("failed to create log directory: {s}\n", .{@errorName(err)});
            return;
        }
    };

    var now = DateTime.Datetime.now();
    now = now.shiftTimezone(&DateTime.timezones.Canada.Pacific);
    const fname = try std.fmt.allocPrint(alloc, "log/{d}-{d}-{d}.txt", .{ now.date.year, now.date.month, now.date.day });
    defer alloc.free(fname);

    _ = std.fs.cwd().statFile(fname) catch |err| {
        if (err == error.FileNotFound) {
            const f = try std.fs.cwd().createFile(fname, .{});
            f.close();
        } else {
            try stdout.print("failed to stat log file: {s}\n", .{@errorName(err)});
            return;
        }
    };

    const editor = std.os.getenv("EDITOR") orelse {
        try stdout.print("EDITOR environment variable not set\n", .{});
        return;
    };

    // Note: I don't think the defer stmts get executed since execve replaces the current process
    // with the editor process. Not sure how to handle this, but the OS will clean up the memory
    // anyway so not super concerned.

    return std.process.execve(alloc, &[_][]const u8{ editor, fname }, null);
}
