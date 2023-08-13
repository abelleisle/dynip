const std = @import("std");

pub fn testme() !void {
    std.debug.print("DuckDNS test!\n", .{});
}

pub fn url_str() []const u8 {
    // return "https://www.duckdns.org/update?domains={YOURVALUE}&token={YOURVALUE}[&ip={YOURVALUE}][&ipv6={YOURVALUE}][&verbose=true][&clear=true]"
    const url = "https://www.duckdns.org";
    return url;
}
