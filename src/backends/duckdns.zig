const std = @import("std");
const NetType = @import("../types.zig");

// This is a DNS backend service
const DuckDNS = @This();

pub fn build_request(
    domains: NetType.DomainList,
    token: NetType.String,
    ip4: ?NetType.Address,
    ip6: ?NetType.Address,
) NetType.DNSError!NetType.String {
    _ = token;
    _ = domains;
    if ((ip4 == null) and (ip6 == null)) {
        return NetType.DNSError.MissingArgument;
    }

    // var ip4_out = try NetType.StringManaged().initCapacity(256);
    // var ip6_out = try NetType.StringManaged().initCapacity(256);
    //
    // ip4.?.format("{s}", null, ip4_out.slice());
    // ip6.?.format("{s}", null, ip6_out.slice());
    //
    // var url = NetType.StringManaged().init();
    //
    // url.fmt("https://www.duckdns.org/update?domains={s}&token={s}&ip={s}&ipv6={s}",
    //         .{domains.get(0), token, ip4_out.slice(), ip6_out.slice()});

    // return url.slice();

    // return "https://www.duckdns.org/update?domains={YOURVALUE}&token={YOURVALUE}[&ip={YOURVALUE}][&ipv6={YOURVALUE}][&verbose=true][&clear=true]"

    const url = "https://duckdns.org";
    return url;
}

const exampleURL = "example.com";

test "default url builder" {
    var url_list = try NetType.DomainList.init(1);
    url_list.set(0, exampleURL);

    const token = "123456789!";

    const url = build_request(url_list, token, null, null);

    try std.testing.expectError(NetType.DNSError.MissingArgument, url);
}
