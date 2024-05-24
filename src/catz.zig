const std = @import("std");
const File = std.fs.File;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const local_allocator = gpa.allocator();
const print = std.debug.print;
const cwd = std.fs.cwd();

pub fn main() !void {
    try cat();
}

pub fn cat() !void {
    var options = std.ArrayList([]u8).init(local_allocator);
    var files_content = std.ArrayList([]u8).init(local_allocator);
    var args = std.process.args();
    const stdout = std.io.getStdOut();

    //skips the calling (cat)
    _ = args.skip();

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            try options.append(@ptrCast(@constCast(arg)));
        } else {
            const file_path = arg;

            var file = cwd.openFile(file_path, .{ .mode = .read_only }) catch {
                _ = try stdout.write("Error while opening the file\n");
                return;
            };

            const meta = file.metadata() catch {
                _ = try stdout.write("Error while reading the file metadata\n");
                return;
            };

            const file_buffer = try local_allocator.alloc(u8, meta.size());

            _ = file.read(file_buffer) catch {
                _ = try stdout.write("Error while reading the file\n");
                return;
            };

            try files_content.append(file_buffer);
        }
    }

    for (files_content.items) |file_buffer| {
        if (options.items.len == 0) {
            _ = try stdout.write(file_buffer);
            continue;
        }
        for (options.items) |f_arg| {
            if (std.mem.eql(u8, f_arg, "-n") or std.mem.eql(u8, f_arg, "--numbers")) {
                var itt = std.mem.split(u8, file_buffer, "\n");

                var counter: u16 = 1;
                while (itt.next()) |line| {
                    if (itt.peek() == null) break;

                    const num_str = try std.fmt.allocPrint(
                        local_allocator,
                        "{d}",
                        .{counter},
                    );

                    const left_pad = try local_allocator.alloc(u8, 6 - num_str.len);

                    for (0..left_pad.len) |index| {
                        left_pad[index] = " ".*[0];
                    }

                    const new_str = try std.fmt.allocPrint(
                        local_allocator,
                        "{s}{s}  {s}\n",
                        .{ left_pad, num_str, line },
                    );
                    _ = try stdout.write(new_str);
                    counter += 1;
                }
            }
        }
    }
}
