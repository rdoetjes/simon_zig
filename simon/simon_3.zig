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
    while(true){
        if (gpio.num(6).read() == 0) { return 10; }
        if (gpio.num(7).read() == 0) { return 15; }
        if (gpio.num(8).read() == 0) { return 20; }
        if (gpio.num(9).read() == 0) { return 30; }
        time.sleep_ms(50);
    }
}

fn game_over() void {
    for (0..10) |_|{
        for(2..6) |i| {
            var pin: u5 = @truncate(i);
            gpio.num(pin).toggle();
        }
        time.sleep_ms(100);
    }
}

fn you_won() void {
    for(0..10) |_| {
        gpio.num(2).toggle();
        gpio.num(4).toggle();
        time.sleep_ms(100);
        gpio.num(3).toggle();
        gpio.num(5).toggle();
        time.sleep_ms(100);
    }
}

fn calc_max_count(loop_delay_ms: u32, timeout_ms: u32) u32{    
    return timeout_ms/loop_delay_ms;
}

fn key_down(pin: u5, timeout_ms: u32) bool {
    const loop_delay_ms: u32 = 50;
    var max_loop = calc_max_count(loop_delay_ms, timeout_ms);
    var count: u32 = 0;

    gpio.num(pin - 4).toggle();
    while(count < max_loop and gpio.num(pin).read() == 0) : ( count +=1 ){
        time.sleep_ms(loop_delay_ms);
    }
    gpio.num(pin - 4).toggle();

    if (count >= max_loop) return false else return true;
}

fn get_handle_player_input(timeout_ms: u32) i8 {
    for (6..10) |i| {
        var pin: u5 = @truncate(i);
        if (gpio.num(pin).read() == 0) { if (key_down(pin, timeout_ms)) return pin - 6 else return -2;}
    }
    return -1;
}

fn is_player_worthy(sequence: *[max_sequence_size]u8, step: usize, timeout_ms: u32) bool {
    for (0..step + 1) |i| { 
        const loop_delay_ms: u32 = 50;
        var max_loop = calc_max_count(loop_delay_ms, timeout_ms);
        var count: u32 = 0;
        var move: i8 = -1;

        while(count < max_loop and move == -1) : ( count +=1 ){
            move = get_handle_player_input(timeout_ms);
            time.sleep_ms(loop_delay_ms);
        }

        if (count >= max_loop or sequence[i] != move) return false;
    }
    return true;
}

fn game_loop(sequence: *[max_sequence_size]u8) void {
    var level = select_level();
    reset_game(sequence);
    time.sleep_ms(1000);

    for (0..level) |step| {
        simon(sequence, step, 300);
        if (!is_player_worthy(sequence, step, 1500)){
            game_over();
            break;
        } else if (step == level - 1 ){
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
        game_loop(&sequence);
        time.sleep_ms(1000);
    }
}
