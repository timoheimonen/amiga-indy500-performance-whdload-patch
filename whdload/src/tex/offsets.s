; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Tables computed at assembly: smoothstep (sm32) and the brightness offsets of
; the asphalt, wall and grass texels per fade (tx_off, tx_woff, tx_goff).

; Smoothstep 0-256 for t = 0-31 / 32.
sm32:
tsi     set 0
        rept 32
        dc.w (96*tsi*tsi-2*tsi*tsi*tsi)/128
tsi     set tsi+1
        endr
; Offset (levels) per fade k (0-7) and texel: bits 7-6 grain (0, -1, +1,
; -2), bits 5-4 stain (-0.6, -0.2, 0.2, 0.6), bits 3-0 patch
; ((2 b - 15) / 15 x 1.3). k: footprint below 2^k units; grain fades at
; k 2, stains at k 3, patches at k 4-5 (weights in quarters).
tx_off:
tk      set 0
        rept 8
tcg     set 0
        iflt tk-2
tcg     set 4
        endif
        ifeq tk-2
tcg     set 2
        endif
tcs     set 0
        iflt tk-3
tcs     set 4
        endif
        ifeq tk-3
tcs     set 2
        endif
tcb     set 0
        iflt tk-4
tcb     set 4
        endif
        ifeq tk-4
tcb     set 3
        endif
        ifeq tk-5
tcb     set 1
        endif
tb      set 0
        rept 256
tgr     set tb>>6
tgv     set 0
        ifeq tgr-1
tgv     set -1
        endif
        ifeq tgr-2
tgv     set 1
        endif
        ifeq tgr-3
tgv     set -2
        endif
tsum    set tgv*150*tcg+(((tb>>4)&3)*4-6)*15*tcs+(2*(tb&15)-15)*13*tcb
        dc.b (tsum+6300)/600-10
tb      set tb+1
        endr
tk      set tk+1
        endr
; Walls: bits 7-6 grain (0, -1, +1, -3: the seams), bits 5-4 scuffs (-2,
; -1, 0, +0.5), bits 3-0 dirt ((2 b - 15) / 15); fades as tx_off.
tx_woff:
tk      set 0
        rept 8
tcg     set 0
        iflt tk-2
tcg     set 4
        endif
        ifeq tk-2
tcg     set 2
        endif
tcs     set 0
        iflt tk-3
tcs     set 4
        endif
        ifeq tk-3
tcs     set 2
        endif
tcb     set 0
        iflt tk-4
tcb     set 4
        endif
        ifeq tk-4
tcb     set 3
        endif
        ifeq tk-5
tcb     set 1
        endif
tb      set 0
        rept 256
tgr     set tb>>6
tgv     set 0
        ifeq tgr-1
tgv     set -1
        endif
        ifeq tgr-2
tgv     set 1
        endif
        ifeq tgr-3
tgv     set -3
        endif
tsr     set (tb>>4)&3
tst     set 5
        ifeq tsr
tst     set -20
        endif
        ifeq tsr-1
tst     set -10
        endif
        ifeq tsr-2
tst     set 0
        endif
tsum    set tgv*150*tcg+tst*15*tcs+(2*(tb&15)-15)*10*tcb
        dc.b (tsum+6300)/600-10
tb      set tb+1
        endr
tk      set tk+1
        endr
; Grass: bits 7-6 blades (0, -1, +1, -2), bits 5-4 clumps (-0.9, -0.3,
; 0.3, 0.9), bits 3-0 patches ((2 b - 15) / 15 x 2); fades as tx_off.
tx_goff:
tk      set 0
        rept 8
tcg     set 0
        iflt tk-2
tcg     set 4
        endif
        ifeq tk-2
tcg     set 2
        endif
tcs     set 0
        iflt tk-3
tcs     set 4
        endif
        ifeq tk-3
tcs     set 2
        endif
tcb     set 0
        iflt tk-4
tcb     set 4
        endif
        ifeq tk-4
tcb     set 3
        endif
        ifeq tk-5
tcb     set 1
        endif
tb      set 0
        rept 256
tgr     set tb>>6
tgv     set 0
        ifeq tgr-1
tgv     set -1
        endif
        ifeq tgr-2
tgv     set 1
        endif
        ifeq tgr-3
tgv     set -2
        endif
tsum    set tgv*150*tcg+(((tb>>4)&3)*4-6)*22*tcs+(2*(tb&15)-15)*20*tcb
        dc.b (tsum+6300)/600-10
tb      set tb+1
        endr
tk      set tk+1
        endr
