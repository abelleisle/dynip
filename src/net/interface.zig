const std = @import("std");
const mem = std.mem;

const c = std.c;
const c_addr = @cImport({
    @cInclude("ifaddrs.h");
    @cInclude("arpa/inet.h");
    @cInclude("sys/socket.h");
    @cInclude("netdb.h");
});

// zig fmt: off
const Ip4 = @import("../types.zig").Ip4;
const Ip6 = @import("../types.zig").Ip6;

/// Interface Errors
pub const IfError = error {
    AddressAGAIN,
    AddressBADFLAGS,
    AddressFAIL,
    AddressFAMILY,
    AddressMEMORY,
    AddressNONAME,
    AddressOVERFLOW,
    AddressSYSTEM,
    IfGetifaddrsFailure,
    IfNoInterfaceFound,
    IfNoValidAddressFound,
    Unknown
};

// zig fmt: on

/// All convert "ifaddrs.h" error codes to zig errors
fn getAddrErrno(err: c_int) IfError {
    // zig fmt: off
    return switch (err) {
        c_addr.EAI_AGAIN    => IfError.AddressAGAIN,
        c_addr.EAI_BADFLAGS => IfError.AddressBADFLAGS,
        c_addr.EAI_FAIL     => IfError.AddressFAIL,
        c_addr.EAI_FAMILY   => IfError.AddressFAMILY,
        c_addr.EAI_MEMORY   => IfError.AddressMEMORY,
        c_addr.EAI_NONAME   => IfError.AddressNONAME,
        c_addr.EAI_OVERFLOW => IfError.AddressOVERFLOW,
        c_addr.EAI_SYSTEM   => @panic("errno error, please handle this!"),
        else                => @panic("Unknown error, please handle this!"),
    };
    // zig fmt: on
}

/// Gets the IP address of a system interface
///  Returns an allocated string containing the IP address of the chosen
///  interface. Up to the caller to free.
pub fn getIp(interface: []const u8, comptime addressType: type, filter_local: bool) !addressType {
    comptime if (addressType != Ip4 and addressType != Ip6) {
        @compileError("Only Ip4 and Ip6 types are supported");
    };

    var interface_exists = false;

    // C pointers for the interface addresses
    var ifaddr: [*c]c_addr.struct_ifaddrs = undefined; // Linked list
    var ifa: [*c]c_addr.struct_ifaddrs = undefined; // LL Active Node

    // The string that holds the ip address
    var address = std.mem.zeroes([@max(c_addr.NI_MAXHOST, c_addr.INET6_ADDRSTRLEN)]u8);

    // Get the list of interfaces and their IPs
    if (c_addr.getifaddrs(&ifaddr) == -1) {
        return IfError.IfGetifaddrsFailure;
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
            interface_exists = true; // This is used for error tracking

            // IPv4
            if (addressType == Ip4 and ifa.*.ifa_addr.*.sa_family == c_addr.AF_INET) {
                @memset(address[0..], 0);
                // Fill the `address` array
                const s = c_addr.getnameinfo(ifa.*.ifa_addr, @sizeOf(c_addr.sockaddr_in), address[0..].ptr, c_addr.NI_MAXHOST, null, 0, c_addr.NI_NUMERICHOST);
                if (s != 0) {
                    return getAddrErrno(s);
                }
            }
            // IPv6
            else if (addressType == Ip6 and ifa.*.ifa_addr.*.sa_family == c_addr.AF_INET6) {
                @memset(address[0..], 0);
                // Fill the `address` array
                const s = c_addr.getnameinfo(ifa.*.ifa_addr, @sizeOf(c_addr.sockaddr_in6), address[0..].ptr, c_addr.INET6_ADDRSTRLEN, null, 0, c_addr.NI_NUMERICHOST);
                if (s != 0) {
                    return getAddrErrno(s);
                }
            } else {
                continue;
            }

            const addr_len = std.mem.indexOf(u8, &address, &[1]u8{0}) orelse address.len;
            const interface_address = try addressType.init(address[0..addr_len]);

            if (filter_local and !interface_address.isPublic()) continue;

            return interface_address;
        }
    }

    if (!interface_exists) {
        return IfError.IfNoInterfaceFound;
    }

    return IfError.IfNoValidAddressFound;
}
