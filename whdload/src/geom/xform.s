; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Transforms that round to nearest (xt_x, xt_y, xt_z here, xw_sum in
; geom/xform_world.s) and the view angles at full precision (view_sincos).

        machine 68020

; The game's transforms round the products down (muls, shift, swap), so
; every vertex is on average 1.5 units nearer and to the left and below in
; each coordinate (track vertices up to 3, 5 pixels near the camera).
; xt_x/y/z replace the three products of a new coord_pool value in
; xform_track_vertex and xw_sum the sums of xform_vertex_world and
; xform_vertex_rel, rounding to nearest (track vertices up to 1.5 units,
; 1.5 pixels). The lines, the clipping and the outcodes use these values.
XTAX    macro                           ; \1: camera word, \2: matrix row
        add.w d0,d0                     ; D0 = the coord_pool value
        asr.w #1,d0
        sub.w G_CAM_POS+\1,d0
        move.w d0,d1
        muls.w G_VIEW_MATRIX+\2,d1
        add.l d1,d1
        add.l d1,d1
        add.l #$8000,d1
        swap d1
        move.w d1,(a1)                  ; depth
        move.w d0,d1
        muls.w G_VIEW_MATRIX+\2+2,d1
        add.l d1,d1
        add.l d1,d1
        add.l #$8000,d1
        swap d1
        move.w d1,2(a1)                 ; x'
        muls.w G_VIEW_MATRIX+\2+4,d0
        add.l d0,d0
        add.l d0,d0
        add.l d0,d0
        add.l #$8000,d0
        swap d0
        move.w d0,4(a1)                 ; y'
        rts
        endm
xt_x:   XTAX 0,0
xt_y:   XTAX 2,6
xt_z:   XTAX 4,12

; sincos rounds the angle to 1024 steps (0.35 degrees), so the view turns
; in steps of up to 2 pixels at its edges. view_sincos replaces the three
; calls of view_setup (yaw, roll, pitch; the simulation keeps sincos):
; D0 = angle -> D2 = cos, D1 = sin (2.14), interpolated between the table
; entries with the 6 fraction bits. Keeps the other registers.
view_sincos:
        movem.l d3-d4/a0,-(sp)
        lea G_COS_TABLE,a0
        moveq #63,d4
        and.w d0,d4                     ; fraction
        lsr.w #6,d0
        add.w d0,d0
        bsr.s .ip
        move.w d3,d2                    ; cos
        add.w #$600,d0                  ; + 270 degrees
        bsr.s .ip
        move.w d3,d1                    ; sin
        movem.l (sp)+,d3-d4/a0
        rts
.ip:    and.w #$7fe,d0
        move.w (a0,d0.w),d3
        move.w d0,d1
        addq.w #2,d1
        and.w #$7fe,d1
        move.w (a0,d1.w),d1
        sub.w d3,d1
        muls.w d4,d1
        add.w #32,d1
        asr.w #6,d1
        add.w d1,d3
        rts

        machine 68000
