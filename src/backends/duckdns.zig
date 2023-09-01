const std = @import("std");
const Allocator = std.mem.Allocator;
const NetType = @import("../types.zig");
const String = NetType.String;
const StringManaged = NetType.StringManaged;

// This is a DNS backend service
const DuckDNS = @This();

pub fn request_url(
    allocator: Allocator,
    domains: NetType.String,
    token: NetType.String,
    ip4: ?NetType.String,
    ip6: ?NetType.String,
) !NetType.String {
    if ((ip4 == null) and (ip6 == null)) {
        return NetType.DNSError.MissingArgument;
    }

    // Temporary string
    var tmp = StringManaged.init(allocator);
    defer tmp.deinit();

    // Base URL
    var url = try StringManaged.initData(allocator, "https://duckdns.org/update?");
    defer url.deinit();

    try url.fmt("https://duckdns.org/update?domains={s}&token={s}", .{ domains, token });

    if (ip4) |ip4_s| {
        try tmp.fmt("&ip={s}", .{ip4_s});
        try url.append(tmp.str());
    }

    if (ip6) |ip6_s| {
        try tmp.fmt("&ipv6={s}", .{ip6_s});
        try url.append(tmp.str());
    }

    return try url.toOwned() orelse error.NoUrl;
}

test "default url builder" {
    const alloc = std.testing.allocator;

    const domain = "example";
    const token = "123456789!";

    if (request_url(alloc, domain, token, null, null)) |_| {
        @panic("Unexpected");
    } else |err| switch (err) {
        NetType.DNSError.MissingArgument => {},
        else => @panic("Unexpected"),
    }
}

test "url test" {
    const alloc = std.testing.allocator;

    const url = try request_url(alloc, "example", "123456789abcdef", "192.168.1.1", "::1:2:3:4");
    defer alloc.free(url);

    const test_url = "https://duckdns.org/update?domains=example&token=123456789abcdef&ip=192.168.1.1&ipv6=::1:2:3:4";

    try std.testing.expectEqualStrings(test_url, url);
}
