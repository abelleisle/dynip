const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn URLBuilder() type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        buffer: []u8,

        pub fn init(allocator: Allocator) void {
            return Self {
                .allocator = allocator,
                .buffer = &[_]u8{}
            };
        }

        pub fn deinit(self: Self) void {
            if (self.buffer) |buf| {
                self.allocator.free(buf);
            }
        }
    };
}
