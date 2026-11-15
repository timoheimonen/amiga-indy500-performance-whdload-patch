; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; vnoise: value noise for tex_build.

        machine 68020

; Value noise: D0 = x, D1 = y (texels, 0-255), D2, D3 = log2 of the
; periods in x and y, A0 = lattice of 2^(8 - D2) x 2^(8 - D3) bytes
; (rows of 2^(8 - D2)). D4 = 0-255.
vnoise:
        movem.l d0-d3/d5-d7/a1,-(sp)
        move.w d0,d5
        lsr.w d2,d5                     ; ix
        move.w d1,d6
        lsr.w d3,d6                     ; iy
        moveq #1,d4
        lsl.w d2,d4
        subq.w #1,d4
        and.w d4,d0                     ; fx
        moveq #1,d4
        lsl.w d3,d4
        subq.w #1,d4
        and.w d4,d1                     ; fy
        lsl.w #5,d0
        lsr.w d2,d0
        lsl.w #5,d1
        lsr.w d3,d1
        add.w d0,d0
        add.w d1,d1
        lea sm32(pc),a1
        move.w (a1,d0.w),d0             ; wx (0-256)
        move.w (a1,d1.w),d1             ; wy
        ext.l d1
        neg.w d2
        addq.w #8,d2                    ; log2 of the row length
        neg.w d3
        addq.w #8,d3
        moveq #1,d7
        lsl.w d3,d7
        subq.w #1,d7                    ; row mask
        move.w d6,d4
        addq.w #1,d4
        and.w d7,d4
        lsl.w d2,d6                     ; row iy
        lsl.w d2,d4                     ; row iy + 1
        moveq #1,d7
        lsl.w d2,d7
        subq.w #1,d7                    ; column mask
        move.w d6,d2
        move.w d4,d6
        move.w d5,d4
        addq.w #1,d4
        and.w d7,d4                     ; ix + 1
        lea (a0,d2.w),a1
        moveq #0,d3
        moveq #0,d7
        move.b (a1,d5.w),d3             ; a
        move.b (a1,d4.w),d7             ; b
        sub.w d3,d7
        muls.w d0,d7
        lsl.l #8,d3
        add.l d7,d3                     ; top x 256
        lea (a0,d6.w),a1
        moveq #0,d2
        moveq #0,d7
        move.b (a1,d5.w),d2             ; c
        move.b (a1,d4.w),d7             ; d
        sub.w d2,d7
        muls.w d0,d7
        lsl.l #8,d2
        add.l d7,d2                     ; bottom x 256
        sub.l d3,d2
        muls.l d1,d2
        lsl.l #8,d3
        add.l d2,d3
        moveq #16,d4
        lsr.l d4,d3
        move.w d3,d4
        movem.l (sp)+,d0-d3/d5-d7/a1
        rts

        machine 68000
