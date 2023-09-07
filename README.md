Ziggy Says
==========

You will find the source code for each lesson in the directory simon/ 

You will nede to rename the lesson to simon.zig in order to build it with
```
zig build
```

# simon_1.zig
Lesson on doing GPIO output

# simon_2.zig
Lesson on creating the logic for SIMON, to show his commands to us using the LEDs

# simon_3.zig
Lesson on doing the GPIO input and making the game logic, where the player can
follow SIMON's(uhmm Ziggy's) commands.

# simon_4.zig adding the PWM sound and the speed up when progressing through the levels

# simon.zig
This is the refactored code, where we use an in_p and out_p array that holds the pins.
So you can easily reoganize the pins, as the moves (0,1,2,3) match the indeces of the input and output pin arrays.
We introduced the get_handle_player_input() function in order to reduce code.