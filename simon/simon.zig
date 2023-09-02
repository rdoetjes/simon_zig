const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const pwm = rp2040.pwm;
const pinsc = rp2040.pins;
const rand = rp2040.rand;

const max_sequence_size = 31;

const pin_config = rp2040.pins.GlobalConfiguration{
    .GPIO10 = .{ .name = "piezo", .function = .PWM5_A },
};

var piezo: rp2040.pwm.Pwm(5, .a) = undefined;

// setup the pins
// 2,3,4,5 are LEDs red,green,yellow,blue
// 6,7,8,9 are switches that correspond with LEDs, red,green,yellow,blue
// 10 is the piezo
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

    piezo.set_level(6000);
    piezo.slice().set_wrap(65000);
    piezo.slice().set_clk_div(4, 0);
    piezo.slice().disable();
}

// set the game into a known state
// generate a random sequence for simon, for this game
fn reset_game(sequence: *[max_sequence_size]u8) void {
    var ascon = rand.Ascon.init();
    var rng = ascon.random();
    rng.bytes(sequence[0..]);

    for (0..max_sequence_size) |i| {
        sequence[i] = sequence[i] & 3;
    }
}

// stop the pwm to prevent the sound from playing
fn stop_beep() void {
    piezo.slice().disable();
}

// plays a beep with the frequene corresponding to the move
// moves are 0,1,2,3 and other value sets pwm wrap to 0
// in affect making frequence so high that it's inaudinle
fn play_beep(move: u8) void {
    piezo.slice().set_clk_div(4, 0);
    switch (move) {
        0 => piezo.slice().set_wrap(45000),
        1 => piezo.slice().set_wrap(55000),
        2 => piezo.slice().set_wrap(60000),
        3 => piezo.slice().set_wrap(65500),
        4 => {
            piezo.slice().set_wrap(65500);
            piezo.slice().set_clk_div(10, 0);
        },
        else => piezo.slice().set_wrap(0),
    }
    piezo.slice().enable();
}

// simon calls this to show a move to the player with a specified duration
// speed is the time it shows/sounds the move
fn play_move(move: u8, speed: u32) void {
    var pin: u5 = @truncate(move + 2);
    play_beep(move);
    gpio.num(pin).toggle();
    time.sleep_ms(speed);
    stop_beep();
    gpio.num(pin).toggle();
    time.sleep_ms(speed);
}

// simon's move, simon will play through the sequence up to the current step + 1
fn simon(sequence: *[max_sequence_size]u8, step: usize, speed: u32) void {
    for (0..step + 1) |i| {
        play_move(sequence[i], speed);
    }
}

// select level, red switch = 10 steps, green switch = 15, yellow = 20 steps (pfff), blue = 30 steps (goodluck!!!)
fn select_level() u8 {
    while (true) {
        if (gpio.num(6).read() == 0) {
            return 10;
        } else if (gpio.num(7).read() == 0) {
            return 15;
        } else if (gpio.num(8).read() == 0) {
            return 20;
        } else if (gpio.num(9).read() == 0) {
            return 30;
        }
        time.sleep_ms(50); // debounces switch and saves a bit of energt
    }
}

// plays the game over, light and sound cue
fn game_over() void {
    play_beep(4);
    for (0..10) |_| {
        for (2..6) |i| {
            var pin: u5 = @truncate(i);
            gpio.num(pin).toggle();
        }
        time.sleep_ms(100);
    }
    stop_beep();
}

// plays the, win light and sound cue.
fn you_won() void {
    time.sleep_ms(300);
    for (0..10) |_| {
        gpio.num(2).toggle();
        play_beep(0);
        gpio.num(4).toggle();
        play_beep(1);
        time.sleep_ms(100);
        play_beep(2);
        gpio.num(3).toggle();
        play_beep(3);
        gpio.num(5).toggle();
        time.sleep_ms(100);
    }
    stop_beep();
}

// lights up the led and plays the sound of the corresponding pin when the key is down
// this allows you to cheat ;) you can think when you hold down the key.
// the first revision SIMON had this bug too.
fn key_down(pin: u5) void {
    play_beep(pin - 6);
    gpio.num(pin - 4).toggle();
    while (gpio.num(pin).read() == 0) {
        time.sleep_ms(50);
    }
    gpio.num(pin - 4).toggle();
    stop_beep();
}

// player's turn they have to play all the steps SIMON has just shown them.
// if you wait more than 1500ms for the next button press return false.
// if you enter the wrong move return false.
// if you get the move correct within 1500ms return true
fn player(sequence: *[max_sequence_size]u8, step: usize) bool {
    for (0..step + 1) |i| {
        const timeout_ms = 1500;
        const loop_delay_ms = 50;
        const max_loop = timeout_ms / 50;

        var count: u8 = 0; // count time debounce ms is the time out

        var move: i8 = -1; // no move yet

        while (count < max_loop and move == -1) {
            if (gpio.num(6).read() == 0) {
                key_down(6);
                move = 0;
            } else if (gpio.num(7).read() == 0) {
                key_down(7);
                move = 1;
            } else if (gpio.num(8).read() == 0) {
                key_down(8);
                move = 2;
            } else if (gpio.num(9).read() == 0) {
                key_down(9);
                move = 3;
            }

            count += 1;
            time.sleep_ms(loop_delay_ms);
        }

        if (count >= max_loop or sequence[i] != move) return false;
    }
    return true;
}

// sets the game spede based on the step
// SIMON grows impatient the further we get in the game and shows the moves shorter
fn set_game_speed(step: usize) u32 {
    var result: u32 = 300;
    if (step < 4) {
        result = 300;
    } else if (step >= 4 and step < 10) {
        result = 250;
    } else if (step >= 10 and step < 15) {
        result = 225;
    } else if (step >= 15 and step < 20) {
        result = 200;
    } else if (step >= 20) {
        result = 175;
    }
    return result;
}

// the game loop that handles GAME_RESET, SIMON, PLAYER, WIN AND LOOSE LOGIC.
fn game_loop(sequence: *[max_sequence_size]u8) void {
    reset_game(sequence);

    var level = select_level();

    time.sleep_ms(1000);

    for (0..level) |step| {
        var time_out = set_game_speed(step);
        simon(sequence, step, time_out);

        if (!player(sequence, step)) {
            game_over();
            break;
        } else if (step == level - 1) {
            you_won();
            break;
        }
        time.sleep_ms(500);
    }
}

// Enrty point
pub fn main() !void {
    var sequence: [max_sequence_size]u8 = undefined;
    const pins = pin_config.apply();
    piezo = pins.piezo;

    setup();
    while (true) {
        game_loop(&sequence);
    }
}
