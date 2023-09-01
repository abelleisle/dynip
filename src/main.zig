const std = @import("std");
const service = @import("service.zig");
const NetType = @import("types.zig");

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

    const test_ip = try NetType.Address.resolveIp("172.16.50.100", 100);

    std.debug.print("IP address to print: {}\n", .{test_ip});
}

test "test all" {
    @import("std").testing.refAllDecls(@This());
    @import("std").testing.refAllDecls(service);
    @import("std").testing.refAllDecls(NetType);
}
