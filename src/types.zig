const std = @import("std");
const Allocator = std.mem.Allocator;

// zig fmt: off
pub const Ip4 = struct {
    add: std.net.Ip4Address,
    raw: u32,
    _str: [24]u8, // 21 - 255.255.255.255:65535
    _str_len: usize,

    pub fn init(string: []const u8) !Ip4 {
        const address = try std.net.Ip4Address.parse(string, 0);
        return Ip4.initAddress(address);
    }

    pub fn initAddress(address: std.net.Ip4Address) !Ip4 {
        const flipped = std.mem.bigToNative(u32, address.sa.addr);

        var ip = Ip4{
            .add = address,
            .raw = flipped,
            ._str = std.mem.zeroes([24]u8),
            ._str_len = 0,
        };

        const ip_str_slice = try std.fmt.bufPrint(&ip._str, "{}", .{address});
        ip._str_len = ip_str_slice.len - 2;
        ip._str[ip_str_slice.len] = 0; // Ensure string is null terminated

        return ip;
    }

    // TODO: find a way to modify the `raw` variable and have it update the
    // string. Use a union or something..
    pub fn initRaw(raw: u32) !Ip4 {
        const address = std.net.Ip4Address{
            .sa = std.os.sockaddr.in{
                .port = std.mem.nativeToBig(u16, 0),
                .addr = std.mem.nativeToBig(u32, raw),
            },
        };
        return Ip4.initAddress(address);
    }

    /// Return the string slice for the IP
    pub fn str(ip: *const Ip4) []const u8 {
        return ip._str[0..ip._str_len];
    }

    /// Is this a public IP address?
    pub fn isPublic(ip: *const Ip4) bool {
        const raw = ip.raw;

        const b0: u8 = @truncate((raw >> 24) & 0xff);
        const b1: u8 = @truncate((raw >> 16) & 0x0ff);
        // const b2: u8 = @truncate((raw >> 8) & 0x0ff);
        // const b3: u8 = @truncate(raw & 0x0ff);

        // 10.x.y.z
        if (b0 == 10)
            return false;

        // 172.16.0.0 - 172.31.255.255
        if ((b0 == 172) and (b1 >= 16) and (b1 <= 31))
            return false;

        // 192.168.0.0 - 192.168.255.255
        if ((b0 == 192) and (b1 == 168))
            return false;

        // 127.x.y.z
        if (b0 == 127)
            return false;

        // TODO: Add WAY more

        return true;
    }

    pub fn deinit() void {}
};

pub const Ip6 = struct {
    raw: u128,
    add: std.net.Ip6Address,
    _str: [64]u8, // 47 - [aaaa:bbbb:cccc:dddd:eeee:ffff:1234:5678]:65535
    _str_len: usize,

    pub fn init(string: []const u8) !Ip6 {
        const address = try std.net.Ip6Address.resolve(string, 0);
        return initAddress(address);
    }

    pub fn initAddress(address: std.net.Ip6Address) !Ip6 {
        const flipped = std.mem.bigToNative(
            u128,
            @as(*align(1) const u128, @ptrCast(&address.sa.addr)).*
        );

        var ip = Ip6{
            .add = address,
            .raw = flipped,
            ._str = std.mem.zeroes([64]u8),
            ._str_len = 0,
        };

        const ip_str_slice = try std.fmt.bufPrint(&ip._str, "{}", .{address});
        ip._str_len = ip_str_slice.len - 3;
        ip._str[ip_str_slice.len] = 0; // Ensure string is null terminated

        return ip;
    }

    // TODO: find a way to modify the `raw` variable and have it update the
    // string. Use a union or something..
    pub fn initRaw(raw: u128) !Ip6 {
        const flipped = std.mem.nativeToBig(u128, raw);
        const addr: [16]u8 = @bitCast(flipped);
        const address = std.net.Ip6Address.init(
            addr, std.mem.nativeToBig(u16, 0), 0, 0
        );
        return Ip6.initAddress(address);
    }

    /// Return the string slice for the IP
    pub fn str(ip: *const Ip6) []const u8 {
        return ip._str[1..ip._str_len]; // Remove the port and brackets
    }

    /// Is this a public IP address?
    pub fn isPublic(ip: *const Ip6) bool {
        // fe80::/10
        if ((ip.raw >> 118) == 0x3fa) // 0xfe80 >> 6 == 0x3fa
            return false;

        // fc00::/7
        if ((ip.raw >> 121) == 0x7e) // 0xfc00 >> 9 == 0x7e
            return false;

        // TODO: Make sure this is enough

        return true;
    }

    pub fn deinit() void {}
};
// zig fmt: on

test "raw IP creation" {
    const ip4_raw: u32 = (172 << 24) | (18 << 16) | (57 << 8) | 99;
    const ip4 = try Ip4.initRaw(ip4_raw);
    try std.testing.expectEqualStrings("172.18.57.99", ip4.str());
    try std.testing.expectEqual(ip4_raw, ip4.raw);
    // zig fmt: off
    const ip6_raw: u128 = (0xfd32 << 112) |
                          (0x98b2 << 96) |
                          (0x67bc << 80) |
                          (0x7198 << 64) |
                          (0xabcd << 48) |
                          (0x1234 << 32) |
                          (0x5678 << 16) |
                          (0x9abc);
    // zig fmt: on
    const ip6 = try Ip6.initRaw(ip6_raw);
    try std.testing.expectEqualStrings("fd32:98b2:67bc:7198:abcd:1234:5678:9abc", ip6.str());
    try std.testing.expectEqual(ip6_raw, ip6.raw);
}

test "public IP addresses" {
    // zig fmt: off
    // IPv4
    const ip4s = .{
        .{"192.168.88.27", false},
        .{"127.1.0.5",     false},
        .{"11.53.68.12",   true },
        .{"10.5.35.1",     false},
        .{"172.17.14.53",  false},
    };

    // IPv6
    const ip6s = .{
        .{"fc00::",                                false},
        .{"fd17::234:f",                           false},
        .{"2601:813f:46::ab",                      true },
        .{"fe93:34::1",                            false},
        .{"fe80::a:b:c:d",                         false},
        .{"fdd3:9835:ed41::",                      false},
        .{"2101:db8:53fb:cdab:128f:237b:14e:efda", true }
    };
    // zig fmt: on

    inline for (.{
        .{ Ip4, ip4s },
        .{ Ip6, ip6s },
    }) |test_entry| {
        const T = test_entry[0];
        inline for (test_entry[1]) |ip| {
            const ip_string = ip[0];
            const test_ip = try T.init(ip_string);
            const expected = ip[1];
            const actual = test_ip.isPublic();
            std.testing.expectEqual(expected, actual) catch |err| {
                std.log.err("{s} {s} public!", .{ ip_string, if (actual) "is" else "is not" });
                return err;
            };
        }
    }
}

pub const Address = std.net.Address;
pub const String = []const u8;
pub const DomainList = std.BoundedArray(String, 16); // TODO: fix make this dynamic

pub const DNSError = error{ MissingArgument, InvalidBackend };

pub const StringManaged = struct {
    const Self = @This();

    raw: ?[]u8, // Holds the raw string data
    len: usize, // Stores the length of the string contents
    allocator: Allocator, // The allocator used to allocate string data

    /// Create an empty string
    pub fn init(allocator: Allocator) Self {
        return Self{
            .raw = null,
            .len = 0,
            .allocator = allocator,
        };
    }

    /// Create an empty string, but pre-allocate data
    pub fn initCapacity(allocator: Allocator, length: usize) !Self {
        var self = Self.init(allocator);
        try self.allocate(length);
        return self;
    }

    /// Create a string with default contents
    pub fn initData(allocator: Allocator, literal: []const u8) !Self {
        var self = Self.init(allocator); // TODO: pre-allocate size
        try self.set(literal);
        return self;
    }

    /// Frees string memory
    pub fn deinit(self: Self) void {
        if (self.raw) |raw| self.allocator.free(raw);
    }

    /// Returns the allocated capacity of the string
    pub fn capacity(self: Self) usize {
        return if (self.raw) |raw| raw.len else 0;
    }

    /// Allocate required string memory
    pub fn allocate(self: *Self, len: usize) !void {
        if (self.raw) |raw| {
            // Already allocated raw buffer
            if (len < self.capacity()) return;
            self.raw = self.allocator.realloc(raw, len) catch {
                return error.OutOfMemory;
            };
        } else {
            // Internal buffer isn't allocated yet
            self.raw = self.allocator.alloc(u8, len) catch {
                return error.OutOfMemory;
            };
        }
    }

    /// Clears the string data contents
    pub fn clear(self: *Self, zeroOut: bool) void {
        self.len = 0; // By default we'll just set length to zero
        // Should string data be zeroed out?
        if (zeroOut) {
            // std.mem.zeroes(self.raw);
            if (self.raw) |raw| @memset(raw, 0);
        }
    }

    /// Append a string literal to the end of the string
    pub fn append(self: *Self, literal: []const u8) !void {
        const new_len = self.len + literal.len;
        if (self.capacity() < new_len) {
            try self.allocate(new_len * 2); // TODO: multiply by two
        }

        const raw = self.raw.?;

        // std.mem.copy(u8, self.raw.?[self.len..], literal);
        var i: usize = 0;
        while (i < literal.len) : (i += 1) {
            raw[self.len + i] = literal[i];
        }

        self.len += literal.len;
    }

    /// Set the contents of the string
    pub fn set(self: *Self, literal: []const u8) !void {
        self.clear(false);
        try self.append(literal);
    }

    /// Set the string to a formatted string
    pub fn fmt(self: *Self, comptime fmtStr: []const u8, args: anytype) !void {
        const size = std.math.cast(usize, std.fmt.count(fmtStr, args)) orelse return error.OutOfMemory;
        if (self.capacity() < size) {
            try self.allocate(size * 2);
        }
        _ = std.fmt.bufPrint(self.raw.?, fmtStr, args) catch |err| switch (err) {
            error.NoSpaceLeft => unreachable, // we just counted the size above
        };

        self.len = size;
    }

    /// Return a reference to the string
    pub fn str(self: Self) []const u8 {
        return if (self.raw) |raw| raw[0..self.len] else "";
    }

    /// Returns an owned copy of this string
    /// Note: The calling function must handle the freeing of the memory
    pub fn toOwned(self: Self) !?[]u8 {
        if (self.raw != null) {
            const original = self.str();
            const new = self.allocator.alloc(u8, original.len) catch {
                return error.OutOfMemory;
            };
            std.mem.copy(u8, new, original);
            return new;
        }

        return null;
    }
};

// zig fmt: off
// TODO: find a way to do this using to lower or something
const truthAndFalseTable = std.ComptimeStringMap(bool, .{
    .{ "True", true },
    .{ "False", false },
    .{ "true", true },
    .{ "false", false },
    .{ "yes", true},
    .{ "no", false},
    .{ "Yes", true},
    .{ "No", false},
    .{ "1", true },
    .{ "0", false },
});
// zig fmt: on

pub fn convert(comptime T: type, val: []const u8) !T {
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => try std.fmt.parseInt(T, val, 0),
        .Float, .ComptimeFloat => try std.fmt.parseFloat(T, val),
        .Bool => truthAndFalseTable.get(val).?,
        else => {
            const tn = @typeName(T);
            std.debug.print(tn, .{});
            if (std.mem.eql(u8, tn, "customAddress")) {
                return "0.0.0.0";
            } else {
                return @as(T, val);
            }
        },
    };
}

// zig fmt: off
const Option = union(enum) {
    address4: []const u8,
    address6: []const u8,
    domain: []const u8,

    pub fn parse(allocator: Allocator, key: []const u8, value: []const u8) ?Option {
        const O = std.meta.FieldEnum(Option);
        const t = std.meta.stringToEnum(O, key) orelse return null;
        return switch (t) {
            .address4 => {
                const address: std.net.Address = std.net.Address.resolveIp(value, 80) catch return null;
                const ret = Option {
                    .address4 = std.fmt.allocPrint(allocator, "{}", .{address}) catch return null
                };
                return ret;
            },
            .domain => .{ .domain = value },
            else => null,
        };
    }

    pub fn deinit(option: *Option, allocator: Allocator) void {
        _ = allocator;
        _ = option;
        // allocator.free(field)
    }
};
// zig fmt: on

test "string creation" {
    const alloc = std.testing.allocator;

    // Empty string
    const str = StringManaged.init(alloc);
    defer str.deinit();

    try std.testing.expectEqual(@as(usize, 0), str.capacity());

    // Allocated string
    const str2 = try StringManaged.initCapacity(alloc, 187);
    defer str2.deinit();

    try std.testing.expectEqual(@as(usize, 187), str2.capacity());

    // Set string
    const str3 = try StringManaged.initData(alloc, "String tester");
    defer str3.deinit();

    try std.testing.expectEqualStrings("String tester", str3.str());
    try std.testing.expectEqual(@as(usize, 26), str3.capacity());
    try std.testing.expectEqual(@as(usize, 13), str3.len);
}

test "string format" {
    const alloc = std.testing.allocator;

    // Empty string
    var str = StringManaged.init(alloc);
    defer str.deinit();

    try str.fmt("https://example.com/?d={d},s={s}", .{ 43, "test" });

    try std.testing.expectEqualStrings("https://example.com/?d=43,s=test", str.str());
    try std.testing.expectEqual(@as(usize, 32), str.len);
    try std.testing.expectEqual(@as(usize, 64), str.capacity());

    // Allocated string
    var str2 = try StringManaged.initCapacity(alloc, 97);
    defer str2.deinit();

    try str2.fmt("https://example.com/?d={d},s={s}", .{ 43, "test" });

    try std.testing.expectEqualStrings("https://example.com/?d=43,s=test", str2.str());
    try std.testing.expectEqual(@as(usize, 32), str2.len);
    try std.testing.expectEqual(@as(usize, 97), str2.capacity());
}

test "string set" {
    const alloc = std.testing.allocator;

    // Empty string
    var str = StringManaged.init(alloc);
    defer str.deinit();

    try str.set("Heyo this is a string!");

    try std.testing.expectEqualStrings("Heyo this is a string!", str.str());
    try std.testing.expectEqual(@as(usize, 22), str.len);
    try std.testing.expectEqual(@as(usize, 44), str.capacity());

    // Allocated string
    var str2 = try StringManaged.initCapacity(alloc, 25);
    defer str2.deinit();

    try str2.set("Heyo this is a string!");

    try std.testing.expectEqualStrings("Heyo this is a string!", str2.str());
    try std.testing.expectEqual(@as(usize, 22), str2.len);
    try std.testing.expectEqual(@as(usize, 25), str2.capacity());
}

test "string append" {
    const alloc = std.testing.allocator;

    // Empty string
    var str = StringManaged.init(alloc);
    defer str.deinit();

    try str.set("Hello ");
    try str.append("world!");

    try std.testing.expectEqualStrings("Hello world!", str.str());
    try std.testing.expectEqual(@as(usize, 12), str.capacity());

    // Allocated string
    var str2 = try StringManaged.initCapacity(alloc, 11);
    defer str2.deinit();

    try str2.set("Hello ");
    try str2.append("world!");

    try std.testing.expectEqualStrings("Hello world!", str2.str());
    try std.testing.expectEqual(@as(usize, 24), str2.capacity());
}

test "converter" {
    const test_float: f64 = 3.141;
    try std.testing.expectEqual(test_float, try convert(@TypeOf(test_float), "3.141"));
}

test "parser" {
    // const alloc = std.testing.allocator;

    // var option = Option.parse(alloc, "address4", "192.168.1.1");
    // if (option) |*o| {
    //     defer o.deinit(alloc);
    //     try std.testing.expectEqual(.{ .address4 = "192.168.1.1" }, o);
    // } else {
    //     @panic("Uh oh");
    // }
}
