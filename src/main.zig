const std = @import("std");
const tetris = @import("tetris.zig");
const GameServer = @import("server.zig").GameServer;

pub fn main() !void {
    var server = try GameServer.init();
    try server.serve();
}
