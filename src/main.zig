const std = @import("std");
const service = @import("service.zig");
const NetType = @import("types.zig");
const Config = @import("config.zig");
const Ini = @import("ini.zig");

const Allocator = std.mem.Allocator;

const curl = @import("curl/curl.zig");

pub fn main() void {
    const test_ip = NetType.Address.resolveIp("172.16.50.100", 100) catch |err| {
        std.log.err("Error while resolving IP: {}", .{err});
        return;
    };

    std.debug.print("IP address to print: {}\n", .{test_ip});

    curl_test() catch |err| {
        std.log.err("Error while testing curl: {}", .{err});
        return;
    };

    const dir = Config.getPath();

    std.log.debug("Config Dir: {s}", .{dir});
}

fn curl_test() !void {
    const allocator = std.heap.page_allocator;
    const response = curl.get(allocator, "https://example.com/") catch {
        return curl.curlError.Error;
    };

    if (response) |res| {
        defer allocator.free(res);

        std.log.debug("Response: {s}", .{res});
    }
}

test "test all" {
    @import("std").testing.refAllDecls(@This());
    @import("std").testing.refAllDecls(service);
    @import("std").testing.refAllDecls(NetType);
    @import("std").testing.refAllDecls(Config);
    @import("std").testing.refAllDecls(Ini);
}

test "curl simple test" {
    const allocator = std.testing.allocator;
    const response = curl.get(allocator, "https://example.com/") catch {
        return curl.curlError.Error;
    };

    if (response) |res| {
        defer allocator.free(res);

        const index = std.mem.indexOf(u8, res, "<h1>Example Domain</h1>");
        try std.testing.expect(index != null);
    }
}
