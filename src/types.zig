const std = @import("std");
const Allocator = std.mem.Allocator;

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
