const std = @import("std");
const tetris = @import("tetris.zig");
const Game = tetris.Game;

const colored_cells = [_][]const u8{
    "<div class='color0 cell'></div>",
    "<div class='color1 cell'></div>",
    "<div class='color2 cell'></div>",
    "<div class='color3 cell'></div>",
    "<div class='color4 cell'></div>",
    "<div class='color5 cell'></div>",
    "<div class='color6 cell'></div>",
};

pub fn renderGame(g: ?*Game, out: *std.BoundedArray(u8, 10000)) !void {
    if (g) |game| {
        const state = game.state.get();

        try out.appendSlice("<div class='row'>");
        try out.appendSlice("<div class='column70'>");
        if (!state.alive) {
            try out.appendSlice("<div class='gameover'>⚔ GAME OVER ⚔</div>");
        }
        for (tetris.hidden_rows..tetris.rows) |row| {
            try out.appendSlice("<div>");
            for (0..tetris.cols) |col| {
                const block = state.getBlock(row, col);
                if (block == 0) {
                    try out.appendSlice("<div class='empty cell'></div>");
                } else {
                    const colored_cell = colored_cells[block % colored_cells.len];
                    try out.appendSlice(colored_cell);
                }
            }
            try out.appendSlice("</div>");
        }
        try out.appendSlice("</div>"); // end column
        try out.appendSlice("<div class='column30'><div id='score'>🟊");

        var buf: [10]u8 = undefined;
        const score_string = try std.fmt.bufPrint(&buf, "{}", .{state.score});
        try out.appendSlice(score_string);

        try out.appendSlice("</div><div id='block_preview'>");
        const pattern = tetris.block_patterns[state.next_block % 7];
        try out.appendSlice("<div>");
        for (0..16) |j| {
            if (pattern[j] == '1') {
                try out.appendSlice(colored_cells[state.next_block % 7]);
            } else {
                try out.appendSlice("<div class='hidden cell'></div>");
            }
            if ((j + 1) % 4 == 0) {
                try out.appendSlice("</div>"); // new row
                try out.appendSlice("<div>");
            }
        }
        try out.appendSlice("</div>");
        try out.appendSlice("</div></div>"); // end column
        try out.appendSlice("</div>"); // end row
    } else {
        try out.appendSlice("");
    }
}
