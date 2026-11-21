; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Interpolated rendering (assembled with INTERP defined).
;
; The game simulates every 4th CIA-A timer B tick (14.9 Hz) and renders a frame
; only after a new step. Here the frame loop also renders between steps: the
; camera snapshot and the car draw list are built from the last two simulation
; states, blended by the time since the last step request (sub-tick precision
; from the timer B counter). The display runs one step behind the simulation.
; The simulation itself is unchanged.
;
; Frame loop sites:
;   $C08D5E  wait for a step   -> interp_loop_top (renders between steps)
;   $C08E50  camera snapshot   -> interp_new_step (keeps two states)
;   $C08E76  jsr car list      -> interp_cars
;
; Triple buffering: in that mode the finished frame waits for the vertical blank
; in a third buffer while the next frame is drawn, instead of frame_end waiting
; for the swap. Sites: frame_end entry, the swap in the VBL handler and the
; screen transition dispatcher (which first returns to the game's two buffers).

        include "interp/defs.i"
        include "interp/install.s"
        include "interp/blend.s"
        include "interp/triple.s"
        include "interp/gauges.s"
        include "interp/state.s"
