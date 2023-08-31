const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Address = std.net.Address;
pub const String = []const u8;
pub const DomainList = std.BoundedArray(String, 16); // TODO: fix make this dynamic

pub const DNSError = error {
    MissingArgument,
    InvalidBackend
};

pub fn StringManaged() type {
    return struct {
        const Self = @This();

        raw : []u8,
        len : usize,
        capacity : usize,
        allocator: Allocator,

        pub const Slice = []u8;

        pub fn init(allocator: Allocator) Self {
            return Self {
                .raw = &[_]u8{},
                .len = 0,
                .capacity = 0,
                .allocator = allocator,
            };
        }

        pub fn initCapacity(allocator: Allocator, length: usize) Allocator.Error!Self {
            var self = Self.init(allocator);
            self.raw = try self.allocator.alloc(u8, length);
            self.capacity = length;
            return self;
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.allocatedSlice());
        }

        pub fn set(self: *Self, literal: []const u8) !void {
            if (self.capacity < literal.len) {
                self.raw = self.allocator.realloc(self.raw, literal.len * 2) catch {
                    return error.OutOfMemory;
                };
                self.capacity = literal.len * 2;
            }

            std.mem.copy(u8, self.raw, literal);
            self.len = literal.len;
        }

        pub fn fmt(self: *Self, comptime fmtStr: []const u8, args: anytype) !void {
            const size = std.math.cast(usize, std.fmt.count(fmtStr, args)) orelse return error.OutOfMemory;
            if (self.capacity < size) {
                self.raw = self.allocator.realloc(self.raw, size) catch {
                    return error.OutOfMemory;
                };

                self.capacity = size;
            }
            _ = std.fmt.bufPrint(self.raw, fmtStr, args) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable, // we just counted the size above
            };

            // std.mem.copy(u8, self.raw, newRaw);
            self.len = size;
        }

        pub fn allocatedSlice(self: Self) Slice {
            return self.raw.ptr[0..self.capacity];
        }

        pub fn slice(self: Self) Slice {
            return self.raw.ptr[0..self.len];
        }
    };
}

test "empty string creation" {
    const alloc = std.testing.allocator;

    const str = StringManaged().init(alloc);
    defer str.deinit();
}

test "sized string creation" {
    const alloc = std.testing.allocator;

    const str = try StringManaged().initCapacity(alloc, 187);
    defer str.deinit();

    const slice = str.allocatedSlice();
    const len = slice.len;
    try std.testing.expectEqual(@as(usize, 187), len);
}

test "string format empty string" {
    const alloc = std.testing.allocator;

    var str = StringManaged().init(alloc);
    defer str.deinit();

    try str.fmt("https://example.com/?d={d},s={s}", .{43, "test"});

    try std.testing.expectEqualStrings("https://example.com/?d=43,s=test", str.slice());
    try std.testing.expectEqual(@as(usize, 32), str.len);
    try std.testing.expectEqual(@as(usize, 32), str.capacity);
}

test "string format allocated string" {
    const alloc = std.testing.allocator;

    var str = try StringManaged().initCapacity(alloc, 97);
    defer str.deinit();

    try str.fmt("https://example.com/?d={d},s={s}", .{43, "test"});

    try std.testing.expectEqualStrings("https://example.com/?d=43,s=test", str.slice());
    try std.testing.expectEqual(@as(usize, 32), str.len);
    try std.testing.expectEqual(@as(usize, 97), str.capacity);
}

test "string set" {
    const alloc = std.testing.allocator;

    var str = StringManaged().init(alloc);
    defer str.deinit();

    try str.set("Heyo this is a string!");

    try std.testing.expectEqualStrings("Heyo this is a string!", str.slice());
    try std.testing.expectEqual(@as(usize, 22), str.len);
    try std.testing.expectEqual(@as(usize, 44), str.capacity);

    var str2 = try StringManaged().initCapacity(alloc, 25);
    defer str2.deinit();

    try str2.set("Heyo this is a string!");

    try std.testing.expectEqualStrings("Heyo this is a string!", str2.slice());
    try std.testing.expectEqual(@as(usize, 22), str2.len);
    try std.testing.expectEqual(@as(usize, 25), str2.capacity);
}
