const std = @import("std");
const Command = @import("tetris.zig").Command;
const Game = @import("tetris.zig").Game;
const renderGame = @import("render.zig").renderGame;

pub const GameServer = @This();

const ServerErrors = error{CommandParseError};

address: std.net.Address,
game: ?Game,
game_mutex: std.Thread.Mutex,

pub fn init() !GameServer {
    const address = try std.net.Address.parseIp4("127.0.0.1", 8080);

    return GameServer{
        .address = address,
        .game = null,
        .game_mutex = std.Thread.Mutex{},
    };
}

pub fn serve(self: *GameServer) !void {
    const listen_thread = try std.Thread.spawn(.{}, listen, .{self});
    const game_loop_thread = try std.Thread.spawn(.{}, game_loop, .{self});
    // _ = listen_thread;
    // _ = game_loop_thread;
    listen_thread.join();
    game_loop_thread.join();
}

fn game_loop(self: *GameServer) void {
    while (true) {
        self.game_mutex.lock();
        errdefer self.game_mutex.unlock();
        if (self.game) |*game| {
            _ = game.tick();
            // if (!alive) {
            //     self.game = null;
            // }
        }
        self.game_mutex.unlock();
        std.time.sleep(std.time.ns_per_ms * 10);
    }
}

fn listen(self: *GameServer) !void {
    var server = try self.address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();
    while (true) {
        const connection = try server.accept();
        defer connection.stream.close();
        // TODO allocate necessary memory on heap
        var header_buffer: [4000]u8 = undefined;
        var http_server = std.http.Server.init(connection, &header_buffer);
        // TODO allocate necessary memory on heap
        var data_buffer: [4000]u8 = undefined;
        // TODO handle
        var request = try http_server.receiveHead();
        // std.debug.print("{s}\n", .{header_buffer});
        var reader = try request.reader();
        const len = try reader.readAll(&data_buffer);
        try handleRequest(self, &request, data_buffer[0..len]);
    }
}

fn handleRequest(self: *GameServer, request: *std.http.Server.Request, message: []const u8) !void {
    if (match(request, .GET, "/")) {
        // TODO make sure this is big enough
        var file_content: [10000]u8 = undefined;
        const html = try std.fs.cwd().readFile("static/index.html", &file_content);
        try request.respond(html, .{ .status = .ok });
    } else if (match(request, .GET, "/gamestate")) {
        self.game_mutex.lock();
        defer self.game_mutex.unlock();
        var buffer = try std.BoundedArray(u8, 10000).init(0);
        if (self.game) |*game| {
            try renderGame(game, &buffer);
        } else {
            try renderGame(null, &buffer);
        }
        try request.respond(buffer.constSlice(), .{ .status = .ok });
    } else if (match(request, .POST, "/start")) {
        self.game_mutex.lock();
        defer self.game_mutex.unlock();
        self.game = try Game.init();
        try request.respond("▶ Game started", .{ .status = .ok });
    } else if (match(request, .POST, "/command")) {
        if (parseCommand(message)) |command| {
            self.game_mutex.lock();
            defer self.game_mutex.unlock();
            var buffer = try std.BoundedArray(u8, 10000).init(0);
            if (self.game) |*game| {
                game.sendCommand(command);
                try renderGame(game, &buffer);
            } else {
                try renderGame(null, &buffer);
            }
            try request.respond(buffer.constSlice(), .{ .status = .ok });
        } else |_| {
            try request.respond("Nah", .{ .status = .bad_request });
        }
    } else {
        try request.respond("404 File not found", .{ .status = .not_found });
    }
}

fn parseCommand(message: []const u8) !Command {
    if (std.mem.eql(u8, message, "ArrowLeft")) return .Left;
    if (std.mem.eql(u8, message, "ArrowRight")) return .Right;
    if (std.mem.eql(u8, message, "ArrowDown")) return .Down;
    if (std.mem.eql(u8, message, "ArrowUp")) return .Rotate;
    if (std.mem.eql(u8, message, " ")) return .Drop;
    if (std.mem.eql(u8, message, "Enter")) return .Drop;
    return ServerErrors.CommandParseError;
}

fn match(request: *std.http.Server.Request, method: std.http.Method, target: []const u8) bool {
    return request.head.method == method and std.mem.eql(u8, request.head.target, target);
}
