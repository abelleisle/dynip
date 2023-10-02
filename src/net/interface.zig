const std = @import("std");
const mem = std.mem;

const c = std.c;
const c_addr = @cImport({
    @cInclude("ifaddrs.h");
    @cInclude("arpa/inet.h");
    @cInclude("sys/socket.h");
    @cInclude("netdb.h");
});

/// Interface Errors
pub const IfError = error{ ADDR_AGAIN, ADDR_BADFLAGS, ADDR_FAIL, ADDR_FAMILY, ADDR_MEMORY, ADDR_NONAME, ADDR_OVERFLOW, ADDR_UNKNOWN, UNKNOWN };

/// Address type
///  IPv4 and IPv6
pub const AddrType = enum {
    INET4, // IPv4
    INET6, // IPv6
};

/// All convert "ifaddrs.h" error codes to zig errors
fn getAddrErrno(err: c_int) IfError {
    return switch (err) {
        c_addr.EAI_AGAIN => IfError.ADDR_AGAIN,
        c_addr.EAI_BADFLAGS => IfError.ADDR_BADFLAGS,
        c_addr.EAI_FAIL => IfError.ADDR_FAIL,
        c_addr.EAI_FAMILY => IfError.ADDR_FAMILY,
        c_addr.EAI_MEMORY => IfError.ADDR_MEMORY,
        c_addr.EAI_NONAME => IfError.ADDR_NONAME,
        c_addr.EAI_OVERFLOW => IfError.ADDR_OVERFLOW,
        c_addr.EAI_SYSTEM => IfError.ADDR_UNKNOWN,
        else => IfError.UNKNOWN,
    };
}

/// Gets the IP address of a system interface
///  Returns an allocated string containing the IP address of the chosen
///  interface. Up to the caller to free.
pub fn getIp(allocator: mem.Allocator, interface: []const u8, addressType: AddrType) ![]const u8 {
    // C pointers for the interface addresses
    var ifaddr: [*c]c_addr.struct_ifaddrs = undefined; // Linked list
    var ifa: [*c]c_addr.struct_ifaddrs = undefined; // LL Active Node

    // The string that holds the ip address
    var address = std.mem.zeroes([@max(c_addr.NI_MAXHOST, c_addr.INET6_ADDRSTRLEN)]u8);

    // Get the list of interfaces and their IPs
    if (c_addr.getifaddrs(&ifaddr) == -1) {
        return error.getifaddrsFailure;
    }
    defer c_addr.freeifaddrs(ifaddr);

    // Loop through all interfaces and ips
    ifa = ifaddr;
    while (ifa != null) : ({
        ifa = ifa.*.ifa_next;
    }) {
        if (ifa.*.ifa_addr == 0) // Don't handle non-existant IP entries
            continue;

        if (std.mem.len(ifa.*.ifa_name) != interface.len) // Not the same length
            continue;

        // Only check for the same interface
        if (std.mem.eql(u8, ifa.*.ifa_name[0..interface.len], interface)) {
            // IPv4
            if (addressType == AddrType.INET4 and ifa.*.ifa_addr.*.sa_family == c_addr.AF_INET) {
                @memset(address[0..], 0);
                // Fill the `address` array
                const s = c_addr.getnameinfo(ifa.*.ifa_addr, @sizeOf(c_addr.sockaddr_in), address[0..].ptr, c_addr.NI_MAXHOST, null, 0, c_addr.NI_NUMERICHOST);
                if (s != 0) {
                    return getAddrErrno(s);
                }
            }
            // IPv6
            else if (addressType == AddrType.INET6 and ifa.*.ifa_addr.*.sa_family == c_addr.AF_INET6) {
                @memset(address[0..], 0);
                // Fill the `address` array
                const s = c_addr.getnameinfo(ifa.*.ifa_addr, @sizeOf(c_addr.sockaddr_in6), address[0..].ptr, c_addr.INET6_ADDRSTRLEN, null, 0, c_addr.NI_NUMERICHOST);
                if (s != 0) {
                    return getAddrErrno(s);
                }
            } else {
                continue;
            }

            // Allocate the IP string for returning and copy the address to it
            var interface_ip = try allocator.alloc(u8, address.len);
            std.mem.copy(u8, interface_ip, address[0..]);
            return interface_ip;
        }
    }

    return error.NoInterfaceFound;
}
