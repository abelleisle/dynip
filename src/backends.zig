const std = @import("std");
const address = std.net.Address;
const Backend = @This();

pub const DuckDNS = @import("backends/duckdns.zig");

pub const backends = enum {
    DuckDNS,
    NoBackend
};

test "test all backends" {
    @import("std").testing.refAllDecls(Backend);
}
