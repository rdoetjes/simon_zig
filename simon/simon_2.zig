const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const rand = rp2040.rand;
const max_sequence_size = 31;

fn setup() void {
    for (2..6) |r| {
        var i: u5 = @truncate(r);
        gpio.num(i).set_function(.sio);
        gpio.num(i).set_direction(.out);
    }

    for (6..10) |r| {
        var i: u5 = @truncate(r);
        gpio.num(i).set_function(.sio);
        gpio.num(i).set_direction(.in);
        gpio.num(i).set_pull(.up);
    }
}

fn reset_game(sequence: *[max_sequence_size]u8) void {
    var ascon = rand.Ascon.init();
    var rng = ascon.random();
    rng.bytes(sequence[0..]);

    for (0..max_sequence_size) |i| {
        sequence[i] = sequence[i] & 3;
    }
}

fn play_move(move: u8, speed: u32) void {
    var pin: u5 = @truncate(move + 2);
    gpio.num(pin).toggle();
    time.sleep_ms(speed);
    gpio.num(pin).toggle();
    time.sleep_ms(speed);
}

fn simon(sequence: *[max_sequence_size]u8, step: usize, speed: u32) void {
    for (0..step + 1) |i| {
        play_move(sequence[i], speed);
    }
}

pub fn main() !void {
    var sequence: [max_sequence_size]u8 = undefined;
    setup();

    while (true) {
        reset_game(&sequence);
        for (0..5) |step| {
            simon(&sequence, step, 300);
            time.sleep_ms(500);
        }
        time.sleep_ms(1000);
    }
}
