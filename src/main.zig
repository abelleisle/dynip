const std = @import("std");
const backends = @import("backends.zig");
const service = @import("service.zig");

pub fn main() !void {
    // // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    //
    // // stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();
    //
    // try stdout.print("Run `zig build test` to run the tests.\n", .{});
    //
    // try bw.flush(); // don't forget to flush!
}

test "test all" {
    // const test_backend = @import("backends.zig");
    @import("std").testing.refAllDecls(@This());
    // @import("std").testing.refAllDecls(test_backend);
}

test "test backend creation" {
    const duckdns = try service.init(backends.backends.DuckDNS);

    std.log.debug("Token: {s}", .{duckdns.password});
}
