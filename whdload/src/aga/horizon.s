; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Background of the AGA view at any angle: the horizon line from the view
; matrix (bg_choose, bg_line).

        machine 68020

; Replaces the choice of the background in frame_loop (aga_install): the
; game takes its tables only for a pitch index within 30 and a roll index
; within 27 and otherwise draws an octahedron around the camera (flat sky
; colour 11 and ground colour 7, so no sky gradient and no ground
; texture). The AGA view draws the background with bg_line whenever the
; ground is below the horizon line (Mzy > 0) and the line rises or falls
; at most one row per pixel, else the game's octahedron. Z set: drawn.
bg_choose:
        move.w G_VIEW_MATRIX+16,d0      ; Mzy
        ble.s .game
        move.w G_VIEW_MATRIX+14,d1      ; Mzx
        bpl.s .p
        neg.w d1
.p:     mulu.w #58723,d1                ; |Mzx| x C / 160 (16.16)
        swap d1
        cmp.w d0,d1
        bhi.s .game
        bsr cpu_background
        moveq #0,d0
        rts
.game:  moveq #1,d0
        rts

; The background of the AGA view, from the view matrix: plane 2 set at
; every pixel whose centre is below the horizon line, gnd_full = the first
; row all ground (the rows below are too), and for c_sky_tail the sky
; level of row 0, x 0 (sky_l0) and its step per pixel (sky_bpx), 16.16.
; The horizon is where a view direction has world z 0. With the matrix
; column of world z (Mzd, Mzx, Mzy) the pixel (x, r) is ground when
;   P (2r - 123) - 20480 Mzd > 64 Mzx (2x - 319),  P = 10240 Mzy / C,
; C = 124 x (17617 / 16384)^2 = 143.37 (the y scale of view_setup and the
; projection), so the horizon row at x is 62 + C (Mzd + Mzx (x - 160) /
; 160) / Mzy. Needs Mzy > 0 (bg_choose). Uses D0-D7, A0-A2.
bg_line:
        btst #6,$dff002                 ; a blit may still write the buffer
.idle:  btst #6,$dff002
        bne.s .idle
        movem.w G_VIEW_MATRIX+12,d5-d7  ; Mzd, Mzx, Mzy
        move.l d6,d0                    ; sky_bpx = C / 160 x SKY_K x Mzx / Mzy
        muls.w #15659,d0
        divs.l d7,d0
        move.l d0,d1                    ; a rise of less than half a row
        bpl.s .b0                       ; over the width: drawn level (the
        neg.l d1                        ; fast rows of c_sky_tail)
.b0:    cmp.l #25,d1
        bgt.s .b1
        moveq #0,d0
        moveq #0,d6
.b1:    lea sky_bpx(pc),a0
        move.l d0,(a0)
        move.l d5,d1                    ; horizon row at x 160 x 256
        muls.l #36702,d1
        divs.l d7,d1
        add.l #62*256,d1
        cmp.l #-170*256,d1              ; levels within -128..127
        bge.s .h0
        move.l #-170*256,d1
.h0:    cmp.l #294*256,d1
        ble.s .h1
        move.l #294*256,d1
.h1:    muls.l #SKY_K,d1
        asr.l #8,d1
        muls.l #160,d0
        sub.l d0,d1
        move.l d1,sky_l0-sky_bpx(a0)
        move.l d7,d0
        muls.w #18285,d0
        asr.l #8,d0                     ; P
        move.l d0,d4
        add.l d4,d4                     ; 2P: N per row
        muls.l #-123,d0
        muls.l #20480,d5
        sub.l d5,d0                     ; N of row 0
        asl.l #6,d6                     ; Q = 64 Mzx
        movea.l G_DRAW_BACK,a1
        adda.l #VIEW_TOP+2*FILL_PLANE,a1
        lea gnd_full(pc),a2
        move.w #VIEW_H,(a2)
        moveq #0,d7                     ; row
.row:   tst.l d6
        bne.s .tilt
        tst.l d0                        ; level: all ground or all sky
        bgt .full
        bra .sky
.tilt:  move.l d0,d1
        move.l d6,d2
        bpl.s .q
        neg.l d2
.q:     divsl.l d2,d3:d1                ; T = floor(N / |Q|)
        tst.l d3
        beq.s .t
        tst.l d0
        bpl.s .t
        subq.l #1,d1
.t:     cmp.l #319,d1
        ble.s .t0
        move.l #319,d1
.t0:    cmp.l #-321,d1
        bge.s .t1
        move.l #-321,d1
.t1:    add.w #321,d1
        asr.w #1,d1                     ; n: ground pixels from the low side
        beq.s .sky
        cmp.w #VIEW_W,d1
        beq.s .full
        tst.l d6
        bmi.s .right
        moveq #-1,d2                    ; Q > 0: ground at x 0 to n - 1
        move.w d1,d3
        lsr.w #5,d3
        move.w d3,d5
        bra.s .l1
.l0:    move.l d2,(a1)+
.l1:    dbra d3,.l0
        and.w #31,d1
        lsr.l d1,d2
        not.l d2
        move.l d2,(a1)+
        moveq #9,d3
        sub.w d5,d3
        moveq #0,d2
        bra.s .l3
.l2:    move.l d2,(a1)+
.l3:    dbra d3,.l2
        bra.s .next
.right: move.w #VIEW_W,d3               ; Q < 0: ground at x 320 - n to 319
        sub.w d1,d3
        move.w d3,d1
        lsr.w #5,d3
        move.w d3,d5
        moveq #0,d2
        bra.s .r1
.r0:    move.l d2,(a1)+
.r1:    dbra d3,.r0
        and.w #31,d1
        moveq #-1,d2
        lsr.l d1,d2
        move.l d2,(a1)+
        moveq #9,d3
        sub.w d5,d3
        moveq #-1,d2
        bra.s .r3
.r2:    move.l d2,(a1)+
.r3:    dbra d3,.r2
        bra.s .next
.sky:   moveq #0,d2
        moveq #9,d3
.s0:    move.l d2,(a1)+
        dbra d3,.s0
.next:  add.l d4,d0
        addq.w #1,d7
        cmp.w #VIEW_H,d7
        bne .row
        rts
.full:  move.w d7,(a2)                  ; this row and all below: ground
        move.w #VIEW_H,d3
        sub.w d7,d3
        mulu.w #10,d3
        moveq #-1,d2
        bra.s .f1
.f0:    move.l d2,(a1)+
.f1:    dbra d3,.f0
        rts

        machine 68000
