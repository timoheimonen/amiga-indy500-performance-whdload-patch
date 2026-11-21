# Changelog

## V1.1 21-11-2026

- Rows of seats on the grandstands the game leaves without a crowd (all in
  practice, some in qualifying), switched with the grandstands option.
- 64-bit AGA bitplane fetches for the 3D view and a 4-plane view when all
  options that use the extra colours are switched off.
- Faster textured span set-up and paired chunky-to-planar stores, reducing
  divisions, multiplications and chip bus waits.

## V1.0 15-11-2026

First release.

- WHDLoad install of the original disk (IPF image), written by `patch.py`.
- 3D view at up to 50 frames per second: frames between the game's 15
  simulation steps per second.
- 256 colour view: textured road, grass, walls with fences, grandstands with
  a crowd, trees and buildings, and a graded sky.
- 3D cars in team colours, sparks under them and the track behind the car in
  the mirrors.
- Every group of graphics can be switched back to the original in WHDLoad's
  start window, with `CUSTOM2` or with a key while driving.
- `CUSTOM1` detail option; GRAPHICS DETAIL starts as HIGH.
- Car settings and the instant replay are saved to files in the install
  directory.
