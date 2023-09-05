const Service = @This();
const NetType = @import("types.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const b_duckdns = @import("backends/duckdns.zig");
const b_namecheap = @import("backends/namecheap.zig");

const Backends = enum { duckdns, namecheap, none };

const Options = struct {
    backend: Backends = .none,
    address4: ?NetType.String = null,
    address6: ?NetType.String = null,
    username: NetType.String = "",
    password: NetType.String = "",
    domain: NetType.String = "",

    pub fn set(options: *Options, key: []const u8, value: []const u8) !void {
        // inline for (std.meta.fields(@TypeOf(cb.configOptions))) |f| {
        //     if (std.mem.eql(u8, f.name, key)) {
        //         const my_type = @TypeOf(@field(cb, f.name));
        //         @field(cb, f.name) = try cb.convert(my_type, value);
        //     }
        // }
        const O = std.meta.FieldEnum(Options);
        const t = std.meta.stringToEnum(O, key) orelse {
            return; // TODO: report issue
        };
        switch (t) {
            .backend => {
                options.backend = std.meta.stringToEnum(Backends, value) orelse .none;
            },
            else => @panic("Please implement"),
        }
    }
};

/// Struct Methods
allocator: Allocator,

// Passed in
name: []const u8,
options: Options,

// Generated
url: []const u8,

pub fn init(allocator: Allocator, name: []const u8, options: Options) !Service {
    // zig fmt: off
    var self: Service = .{
        .allocator = allocator,
        .name      = name,
        .options   = options,
        .url       = ""
    };
    // zig fmt: on
    self.url = try self.get_url();
    return self;
}

pub fn deinit(self: *Service) void {
    self.allocator.free(self.url);
}

fn get_url(self: *Service) ![]const u8 {
    const o = self.options;
    // zig fmt: off
    return switch (self.options.backend) {
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
        else => @panic("Uh oh")
    };
    // zig fmt: on
}

//////////////////////////////////////////////////
//                    CONFIG                    //
//////////////////////////////////////////////////

pub const ConfigBuilder = struct {
    const CB = ConfigBuilder;
    configName: []const u8,
    configOptions: Options,

    fn create(name: []const u8) ConfigBuilder {
        var cb = ConfigBuilder{
            .configName = name,
            .configOptions = Options,
        };
        return cb;
    }

    fn setValue(cb: *CB, key: []const u8, value: []const u8) void {
        // inline for (std.meta.fields(@TypeOf(cb.configOptions))) |f| {
        //     if (std.mem.eql(u8, f.name, key)) {
        //         const my_type = @TypeOf(@field(cb, f.name));
        //         @field(cb, f.name) = try cb.convert(my_type, value);
        //     }
        // }
        const O = std.meta.FieldEnum(Options);
        const t = std.meta.stringToEnum(O, key) orelse {
            return; // TODO: report issue
        };
        switch (t) {
            .backend => {
                cb.configOptions.backend = std.meta.stringToEnum(Backends, value) orelse .none;
            },
            else => @panic("Please implement"),
        }
    }
};

/////////////////////////////////////////////////
//                    TESTS                    //
/////////////////////////////////////////////////

test "DuckDNS url" {
    const alloc = std.testing.allocator;

    // zig fmt: off
    const options = .{
        .backend  = .duckdns,
        .password = "1234",
        .domain   = "example",
        .address6 = "::1:2:3:4"
    };
    // zig fmt: on

    var dns = try Service.init(alloc, "tester", options);
    defer dns.deinit();

    const url = dns.url;

    const expected = "https://duckdns.org/update?domains=example&token=1234&ipv6=::1:2:3:4";
    try std.testing.expectEqualStrings(expected, url);
    try std.testing.expectEqual(@as(usize, 68), url.len);
}
