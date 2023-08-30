const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;

fn setup() void {
    for (2..6) |r| {
        var i: u5 = @truncate(r);
        gpio.num(i).set_function(.sio);
        gpio.num(i).set_direction(.out);
    }
}

pub fn main() !void {
    setup();
    while (true) {
        for (2..6) |r| {
            var i: u5 = @truncate(r);
            gpio.num(i).put(1);
            time.sleep_ms(100);
            gpio.num(i).put(0);
            time.sleep_ms(100);
        }
        for (1..3) |r| {
            var i: u5 = @truncate(r);
            gpio.num(5 - i).put(1);
            time.sleep_ms(100);
            gpio.num(5 - i).put(0);
            time.sleep_ms(100);
        }
    }
}
