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

fn select_level() u8 {
    var level: u8 = 0;

    while (level == 0) {
        if (gpio.num(6).read() == 0) {
            level = 10;
        }

        if (gpio.num(7).read() == 0) {
            level = 15;
        }

        if (gpio.num(8).read() == 0) {
            level = 20;
        }

        if (gpio.num(9).read() == 0) {
            level = 30;
        }

        time.sleep_ms(50); // saves energy as we wait here a lot and debounces switch
    }

    return level;
}

fn game_over() void {
    for (0..10) |_| {
        for (2..6) |i| {
            var pin: u5 = @truncate(i);
            gpio.num(pin).toggle();
        }
        time.sleep_ms(100);
    }
}

fn you_won() void {
    for (0..10) |_| {
        gpio.num(2).toggle();
        gpio.num(4).toggle();
        time.sleep_ms(100);
        gpio.num(3).toggle();
        gpio.num(5).toggle();
        time.sleep_ms(100);
    }
}

fn key_down(pin: u5) void {
    gpio.num(pin - 4).toggle();
    while (gpio.num(pin).read() == 0) {
        time.sleep_ms(50);
    }
    gpio.num(pin - 4).toggle();
}

fn player(sequence: *[max_sequence_size]u8, step: usize) bool {
    for (0..step + 1) |i| {
        var count: u8 = 0;

        var move: i8 = -1;

        while (count < 30 and move == -1) {
            if (gpio.num(6).read() == 0) {
                key_down(6);
                move = 0;
            }

            if (gpio.num(7).read() == 0) {
                key_down(7);
                move = 1;
            }

            if (gpio.num(8).read() == 0) {
                key_down(8);
                move = 2;
            }

            if (gpio.num(9).read() == 0) {
                key_down(9);
                move = 3;
            }

            count += 1;
            time.sleep_ms(50);
        }

        if (count >= 30 or sequence[i] != move) return false;
    }
    return true;
}

fn game_loop(sequence: *[max_sequence_size]u8) void {
    var level = select_level();

    time.sleep_ms(1000);

    for (0..level) |step| {
        simon(sequence, step, 300);

        if (!player(sequence, step)) {
            game_over();
            break;
        } else if (step == level - 1) {
            you_won();
            break;
        }

        time.sleep_ms(800);
    }
}

pub fn main() !void {
    var sequence: [max_sequence_size]u8 = undefined;
    setup();

    while (true) {
        reset_game(&sequence);
        game_loop(&sequence);
        time.sleep_ms(1000);
    }
}
