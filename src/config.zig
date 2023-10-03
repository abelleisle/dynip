const std = @import("std");
const builtin = @import("builtin");
const system = @import("system");
const fs = std.fs;

const NetType = @import("types.zig");
const Ip4 = NetType.Ip4;
const Ip6 = NetType.Ip6;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Service = @import("service.zig");

const ini = @import("ini");

const appName = "dynip";
const configEnd = appName ++ [_]u8{fs.path.sep} ++ appName ++ ".ini";

const StringManaged = NetType.StringManaged;

// zig fmt: off

/// Global config
pub const Global = struct {
    cache: bool, // Should the fetched IPs be cached
    period: isize, // How often should DNS entries be refreshed (minutes)

    ip4: union(enum) {
        static: Ip4,
        detect: *StringManaged,
        interface: *StringManaged,
    },

    ip6: union(enum) {
        static: Ip6,
        detect: *StringManaged,
        interface: *StringManaged,
    },

    ip6_prefix: union(enum) {
        disabled: void,
        enabled: u64
    },

    // Which allocator to use for allocating string memory?
    allocator: std.mem.Allocator,
    // These are used to avoid leaking memory
    _ip4Storage: StringManaged,
    _ip6Storage: StringManaged,

    pub fn init(allocator: std.mem.Allocator) !Global {
        var g: Global = .{
            .allocator = allocator,
            ._ip4Storage = try StringManaged.initData(allocator, "ifconfig.co"),
            ._ip6Storage = try StringManaged.initData(allocator, "br0"),

            .cache = true,
            .period = 60,
            .ip4 = .{ .detect = undefined },
            .ip6 = .{ .interface = undefined },
            .ip6_prefix = .{ .enabled = 64 }
        };

        g.ip4 = .{ .detect = &g._ip4Storage };
        g.ip6 = .{ .interface = &g._ip6Storage };

        return g;
    }

    pub fn deinit(go: *Global) void {
        go._ip4Storage.deinit();
        go._ip6Storage.deinit();
    }

    pub fn set(go: *Global, key: []const u8, value: []const u8) !void {
        var split_key = std.mem.split(u8, key, ".");
        const enum_key = split_key.first();
        const global_config_enum = std.meta.FieldEnum(Global);
        const key_enum_field = std.meta.stringToEnum(global_config_enum, enum_key) orelse return error.NoOption;
        switch (key_enum_field) {
            // Cache
            .cache => {
                const truthAndFalseTable = std.ComptimeStringMap(bool, .{
                    .{ "True", true },
                    .{ "False", false },
                    .{ "true", true },
                    .{ "false", false },
                    .{ "1", true },
                    .{ "0", false }
                });
                go.cache = truthAndFalseTable.get(value) orelse go.cache;
            },
            // Period
            .period => {
                go.period = try std.fmt.parseInt(@TypeOf(go.period), value, 0);
            },
            // IPv4
            .ip4 => {
                if (split_key.next()) |f| {
                    const ip4_enum = std.meta.FieldEnum(@TypeOf(go.ip4));
                    const ip4_enum_field = std.meta.stringToEnum(ip4_enum, f) orelse return error.NoOption;
                    try go._ip4Storage.set(value);
                    go.ip4 = switch (ip4_enum_field) {
                        .static => .{ .static = try Ip4.init(value) },
                        .detect => .{ .detect = &go._ip4Storage },
                        .interface => .{ .interface = &go._ip4Storage },
                    };
                }
            },
            // IPv6
            .ip6 => {
                if (split_key.next()) |f| {
                    const ip6_enum = std.meta.FieldEnum(@TypeOf(go.ip6));
                    const ip6_enum_field = std.meta.stringToEnum(ip6_enum, f) orelse return error.NoOption;
                    try go._ip6Storage.set(value);
                    go.ip6 = switch (ip6_enum_field) {
                        .static => .{ .static = try Ip6.init(value) },
                        .detect => .{ .detect = &go._ip6Storage },
                        .interface => .{ .interface = &go._ip6Storage },
                    };
                }
            },
            // IPv6 Prefix
            .ip6_prefix => {
                if (split_key.next()) |f| {
                    const ip6_enum = std.meta.FieldEnum(@TypeOf(go.ip6_prefix));
                    const ip6_enum_field = std.meta.stringToEnum(ip6_enum, f) orelse return error.NoOption;
                    go.ip6_prefix = switch (ip6_enum_field) {
                        .disabled => .disabled,
                        .enabled => .{ .enabled = try std.fmt.parseInt(@TypeOf(go.ip6_prefix.enabled), value, 0) }
                    };
                }
            },
            else => {}
        }
    }
};

// zig fmt: on

test "set global config" {
    const alloc = std.testing.allocator;

    var go = try Global.init(alloc);
    defer go.deinit();

    try go.set("cache", "False");
    try std.testing.expectEqual(false, go.cache);
    try go.set("cache", "1");
    try std.testing.expectEqual(true, go.cache);

    try go.set("period", "5600");
    try std.testing.expect(5600 == go.period);
    try std.testing.expectError(error.InvalidCharacter, go.set("period", "ab"));

    try std.testing.expectError(error.InvalidCharacter, go.set("ip4.static", "hello"));
    try go.set("ip4.static", "185.88.53.2");
    try std.testing.expect(3109565698 == go.ip4.static.raw);
    try std.testing.expectEqualStrings("185.88.53.2", go.ip4.static.str());

    try go.set("ip4.detect", "ifconfig.co");
    try std.testing.expectEqualStrings("ifconfig.co", go.ip4.detect.str());

    try go.set("ip4.interface", "br0");
    try std.testing.expectEqualStrings("br0", go.ip4.interface.str());

    try std.testing.expectError(error.InvalidCharacter, go.set("ip6.static", "hello"));
    try go.set("ip6.static", "2001:db8:23ab:53::1");
    try std.testing.expectEqualStrings("2001:db8:23ab:53::1", go.ip6.static.str());

    try go.set("ip6.detect", "ifconfig.co");
    try std.testing.expectEqualStrings("ifconfig.co", go.ip6.detect.str());

    try go.set("ip6.interface", "br1");
    try std.testing.expectEqualStrings("br1", go.ip6.interface.str());

    try go.set("ip6_prefix.disabled", "");
    try std.testing.expect(go.ip6_prefix == .disabled);

    try std.testing.expectError(error.InvalidCharacter, go.set("ip6_prefix.enabled", "z,"));
    try go.set("ip6_prefix.enabled", "64");
    try std.testing.expect(64 == go.ip6_prefix.enabled);
}

/// Get the path of the config
pub fn getPath() []const u8 {
    return switch (builtin.os.tag) {
        .linux => "/etc/" ++ configEnd,
        .windows => "C:\\Program Files\\" ++ configEnd,
        .macos => "/etc/" ++ configEnd,
        else => @panic("OS Unsupported"),
    };
}

// zig fmt: off
pub const Storage = struct {
    global: Global,
    services: ArrayList(Service),

    allocator: Allocator,

    pub fn init(allocator: Allocator) !Storage {
        return .{
            .global = try Global.init(allocator),
            .services = ArrayList(Service).init(allocator),
            .allocator = allocator
        };
    }

    pub fn deinit(storage: *Storage) void {
        for (storage.services.items) |*s| {
            s.deinit();
        }
        storage.services.deinit();
        storage.global.deinit();
    }
};
// zig fmt: on

/// Reads the contents of the config file
/// The caller is responsible for freeing the allocated services item
pub fn read(allocator: Allocator, filepath: []const u8) !Storage {
    const file = try std.fs.openFileAbsolute(filepath, .{});
    defer file.close();

    var parser = ini.parse(allocator, file.reader());
    defer parser.deinit();

    var writer = std.io.getStdErr().writer();
    _ = writer;

    var storage = try Storage.init(allocator);

    var processing_global = true;
    var service: ?Service = null;

    while (try parser.next()) |record| {
        switch (record) {
            .section => |heading| {
                if (processing_global) {
                    processing_global = false;
                }

                if (service) |s| {
                    try storage.services.append(s);
                    service = null;
                }
                service = try Service.init(allocator, heading, .{});
            },
            .property => |kv| {
                if (processing_global) {
                    try storage.global.set(kv.key, kv.value);
                } else {
                    if (service) |*s| {
                        try s.options.set(kv.key, kv.value);
                    } else {
                        @panic("Can't set a service value without a service");
                    }
                }
            },
            .enumeration => @panic("What the hecka is an enumeration??"),
        }
    }

    // Write the current service to the config storage
    if (service) |s| {
        try storage.services.append(s);
        service = null;
    }

    return storage;
}

test "read config" {
    const alloc = std.testing.allocator;

    const filepath = try std.fs.cwd().realpathAlloc(alloc, "src/tests/example.ini");
    defer alloc.free(filepath);

    var configuration = try read(alloc, filepath);
    defer configuration.deinit();

    try std.testing.expect(configuration.global.cache == false);
    try std.testing.expect(configuration.global.period == 5600);
    try std.testing.expectEqualStrings("ifconfig.co", configuration.global.ip4.detect.str());

    const service = configuration.services.items[0];
    try std.testing.expectEqualStrings("nginx", service.name.str());
}

test "build config" {
    // const test_config = @embedFile("tests/example.ini");
    // _ = test_config;

    const file = try std.fs.cwd().openFile("src/tests/example.ini", .{});
    defer file.close();

    var parser = ini.parse(std.testing.allocator, file.reader());
    defer parser.deinit();

    var writer = std.io.getStdErr().writer();

    while (try parser.next()) |record| {
        switch (record) {
            .section => |heading| try writer.print("[{s}]\n", .{heading}),
            .property => |kv| try writer.print("{s} = {s}\n", .{ kv.key, kv.value }),
            .enumeration => |value| try writer.print("{s}\n", .{value}),
        }
    }
}

// test "build config" {
//     const String = @import("types.zig").StringManaged;
//     const alloc = std.testing.allocator;
//
//     var actual = String.init(alloc);
//     defer actual.deinit();
//
//     var config = Config.init(alloc);
//     defer config.deinit();
//
//     var section: ?[]const u8 = null;
//     var key: ?[]const u8 = null;
//
//     var state: ini.State = .normal;
//     var pos: usize = 0;
//     while (ini.getTok(ini.test_ini, &pos, &state)) |tok| {
//         switch (tok) {
//             .section => |s| {
//                 section = s;
//                 // TODO: This is really gross. Look into using writers
//                 var tmp = try std.fmt.allocPrint(alloc, "[{s}]\n", .{s});
//                 defer alloc.free(tmp);
//                 try actual.append(tmp);
//             },
//             .key => |k| {
//                 key = k;
//             },
//             .value => |v| {
//                 if (key) |k| {
//                     if (section) |_| {
//                         var tmp = try std.fmt.allocPrint(alloc, "  {s} = {s}\n", .{ k, v });
//                         defer alloc.free(tmp);
//                         try actual.append(tmp);
//                     } else {
//                         var tmp = try std.fmt.allocPrint(alloc, "{s} = {s}\n", .{ k, v });
//                         defer alloc.free(tmp);
//                         try actual.append(tmp);
//                     }
//                     key = null;
//                 }
//             },
//             .comment => {},
//         }
//     }
//
//     const expected =
//         \\a = 1
//         \\b = 2
//         \\c = 3
//         \\[core]
//         \\  repositoryformatversion = 0
//         \\  filemode = true
//         \\  bare = false
//         \\  logallrefupdates = true
//         \\[remote "origin"]
//         \\  url = https://github.com/ziglang/zig
//         \\  fetch = +refs/heads/master:refs/remotes/origin/master
//         \\[branch "master"]
//         \\  remote = origin
//         \\  merge = refs/heads/master
//         \\
//     ;
//     try std.testing.expectEqualStrings(expected, actual.str());
// }

test "config path" {
    const path = getPath();
    switch (builtin.os.tag) {
        .linux => try std.testing.expectEqualStrings("/etc/dynip/dynip.ini", path),
        .windows => try std.testing.expectEqualStrings("C:\\Program Files\\dynip\\dynip.ini", path),
        .macos => try std.testing.expectEqualStrings("/etc/dynip/dynip.ini", path),
        else => @panic("OS Unsupported"),
    }
}
