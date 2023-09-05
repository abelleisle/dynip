const std = @import("std");
const c = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("curl/curl.h");
    @cInclude("string.h");
});

const Allocator = std.mem.Allocator;

// zig fmt: off
pub const curlError = error {
    Error,               // Generic error (for use by external files)
    InitializationError, // Error initializing libcurl
    OptError             // Option error
};

pub const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,
};

pub const Request = struct {
    allocator: Allocator,
    body: ?[]u8 = null,
};

pub const Response = u32;
// zig fmt: on

pub fn get(allocator: Allocator, url: []const u8) curlError!?[]const u8 {
    return send(allocator, .GET, url);
}

pub fn errorString(allocator: std.mem.Allocator, err: u32) []const u8 {
    const msg = c.curl_easy_strerror(err);
    const len = c.strlen(msg);

    var mem = allocator.alloc(u8, len + 1) catch return "";
    var i: usize = 0;
    while (i <= len) : (i += 1) {
        mem[i] = msg[i];
    }
    return mem;
}

fn send(allocator: Allocator, method: Method, url: []const u8) curlError!?[]const u8 {
    const ctx = Request{ .allocator = allocator, .body = null };

    const cb = struct {
        fn cb(ptr: [*]const u8, size: usize, nmemb: usize, req: *Request) usize {
            const data = ptr[0 .. size * nmemb];
            req.body = req.allocator.alloc(u8, data.len) catch {
                return 0;
            };
            std.mem.copy(u8, req.body.?, data);
            return data.len;
        }
    }.cb;

    var curl: ?*c.CURL = c.curl_easy_init();
    if (curl == null) {
        return curlError.InitializationError;
    }
    defer c.curl_easy_cleanup(curl);

    const m_str = @tagName(method);
    var code = switch (method) {
        .GET => @as(c_uint, c.CURLE_OK), // Default is GET request
        .POST => c.curl_easy_setopt(curl, c.CURLOPT_POST, @as(c_long, 1)),
        else => c.curl_easy_setopt(curl, c.CURLOPT_CUSTOMREQUEST, m_str.ptr),
    };

    if (code != 0) {
        return curlError.OptError;
    }

    // TODO: SSL support

    // Set the URL
    code = c.curl_easy_setopt(curl, c.CURLOPT_URL, url.ptr);
    code = c.curl_easy_setopt(curl, c.CURLOPT_FOLLOWLOCATION, @as(c_long, 1));

    code = c.curl_easy_setopt(curl, @bitCast(c.CURLOPT_WRITEFUNCTION), cb);
    code = c.curl_easy_setopt(curl, @bitCast(c.CURLOPT_WRITEDATA), &ctx);

    // std.log.info("Before perform", .{});
    code = c.curl_easy_perform(curl);
    // std.log.info("After perform", .{});
    // std.log.debug("Response: {s}", .{body});
    if (ctx.body) |b| {
        return b;
    } else {
        return null;
    }
}
