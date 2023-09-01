const Service = @This();
const NetType = @import("types.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const b_duckdns = @import("backends/duckdns.zig");
const b_namecheap = @import("backends/namecheap.zig");

const Backends = union(enum) {
    duckdns,
    namecheap,
};

const Options = struct {
    address4: ?NetType.String = null,
    address6: ?NetType.String = null,
    username: NetType.String = "",
    password: NetType.String = "",
    domain: NetType.String,
};

/// Struct Methods
allocator: Allocator,
backend: Backends,
options: Options,
url: []const u8,

pub fn init(allocator: Allocator, backend: Backends, options: Options) !Service {
    var self: Service = .{ .allocator = allocator, .backend = backend, .options = options, .url = "" };
    self.url = try self.get_url();
    return self;
}

pub fn deinit(self: *Service) void {
    self.allocator.free(self.url);
}

fn get_url(self: *Service) ![]const u8 {
    const o = self.options;
    // zig fmt: off
    return switch (self.backend) {
        .duckdns => try b_duckdns.request_url(
            self.allocator,
            o.domain,
            o.password,
            o.address4,
            o.address6
        ),
        .namecheap => try b_namecheap.request_url(
            self.allocator,
            o.domain,
            o.password,
            o.address4,
            o.address6
        ),
    };
    // zig fmt: on
}

test "DuckDNS url" {
    const alloc = std.testing.allocator;

    // zig fmt: off
    const options = .{
        .password = "1234",
        .domain   = "example",
        .address6 = "::1:2:3:4"
    };
    // zig fmt: on

    var dns = try Service.init(alloc, .duckdns, options);
    defer dns.deinit();

    const url = dns.url;

    const expected = "https://duckdns.org/update?domains=example&token=1234&ipv6=::1:2:3:4";
    try std.testing.expectEqualStrings(expected, url);
    try std.testing.expectEqual(@as(usize, 68), url.len);
}
