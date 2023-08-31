const Service = @This();
const Backends = @import("backends.zig");
const NetType = @import("types.zig");

const std = @import("std");

address4 : ?NetType.Address,
address6 : ?NetType.Address,
username : NetType.String,
password : NetType.String,
backend : Backends.backends,
domains : NetType.DomainList,

pub fn init(backend: Backends.backends) !Service {
    const init_add4 = try NetType.Address.parseIp4("127.0.0.1", 0);
    const init_add6 = try NetType.Address.parseIp6("::1", 0);

    return .{
        .address4 = init_add4,
        .address6 = init_add6,
        .username = "",
        .password = "",
        .backend = backend,
        .domains = try NetType.DomainList.init(1) // TODO: make this dynamic
    };
}

fn get_url(self: *const Service) !NetType.String {
    return switch (self.backend) {
        .DuckDNS => try Backends.DuckDNS.build_request(
                        self.domains,
                        self.password,
                        self.address4,
                        self.address6,
                    ),
        else => NetType.DNSError.InvalidBackend
    };
}

test "DuckDNS url" {
    const ddns = try Service.init(Backends.backends.DuckDNS);

    const url = try ddns.get_url();

    try std.testing.expectEqualStrings("https://duckdns.org", url);
}
