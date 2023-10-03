const std = @import("std");
const service = @import("service.zig");
const NetType = @import("types.zig");
const Config = @import("config.zig");

const Allocator = std.mem.Allocator;

const curl = @import("curl/curl.zig");
const interface = @import("net/interface.zig");

// The config will look something like this:
//
// period = 3600
// cache = true
// ip4 = detect
// ip6 = interface
//
// [ip4.detect]
// url = ifconfig.co
//
// [ip6.interface]
// if = eth0
// prefix = 56
//
// ;Instead these could be
// ;ip4.detect = ifconfig.co
// ;ip6.interface, idk
//
// [nginx]
// backend = duckdns
// address6 = ::1:2:3:4
// domain = web
// password = 1234567890abcdef
//
// [minecraft]
// backend = namecheap

// The whole ip4 and ip6 thing could be done something like so
// const global = struct {
//     period: usize
//     cache: bool
//     ip4: union(enum) {
//         detect: []const u8
//         interface: []const u8
//     }
//     ip6: union(enum) {
//         detect: []const u8
//         interface: struct {
//             prefix: u64,
//             if: []const u8
//         }
//     }
// }

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    _ = alloc;

    curl_test() catch |err| {
        std.log.err("Error while testing curl: {}", .{err});
        return;
    };

    const dir = Config.getPath();

    std.log.info("Config Dir: {s}", .{dir});

    const O = std.meta.FieldEnum(Config.Global);
    inline for (std.meta.fieldNames(O)) |o| {
        std.log.debug("{s}", .{o});
    }

    inline for (.{ NetType.Ip4, NetType.Ip6 }) |at| {
        const ip = interface.getIp("en0", at) catch |err| {
            std.log.err("Error while obtaining IP for en0: {}", .{err});
            return;
        };
        std.log.info("en0 ip: {s}", .{ip.str()});
    }
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
