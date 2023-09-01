const std = @import("std");
const Allocator = std.mem.Allocator;

const NetType = @import("../types.zig");
const String = NetType.String;
const StringManaged = NetType.StringManaged;

// This is a DNS backend service
const Namecheap = @This();

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
    var url = try StringManaged.initData(allocator, "https://namecheap.com/update?");
    defer url.deinit();

    try url.fmt("https://namecheap.com/update?domains={s}&token={s}", .{ domains, token });

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
