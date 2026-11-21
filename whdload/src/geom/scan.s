; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Corners at 1/16 unit from their sources (hcorner), the rows and spans of a
; projected polygon (hscan) and the fill of a polygon with tspan (fscan).

        machine 68020

; Corner D0 (vertex_buf offset from A2) -> (A0)+: depth, x', y' as longs
; in 1/16 units. The game's transform keeps whole units and rounds every
; product (track vertices: each of the nine), so a corner moves back and
; forth by up to a few units while the camera moves one way. Here the
; sums are made again from the source vertex without rounding: a track
; vertex (coord_pool values), else the record of xform_vertex_rel
; (pe_rel) or of xform_vertex_world, used only when rounding them as
; xw_sum does gives the stored values; otherwise the stored values. Uses
; D0-D4, A3-A5.
hcorner:
        lea (a2,d0.w),a5                ; the record
        moveq #0,d0
        move.w (a5),d0                  ; its source (from shape_base)
        lea G_SHAPE_BASE,a3
        adda.l d0,a3
        lea G_VIEW_MATRIX,a4
        sub.l #TRACK_VTX_REL,d0
        cmp.l #2282*8,d0
        bcc .wr
        movea.l a3,a5                   ; track vertex: as the game, without
        lea G_COORD_POOL,a3             ; the flag in bit 15
        move.w 2(a5),d0
        move.w (a3,d0.w),d1
        add.w d1,d1
        asr.w #1,d1
        sub.w G_CAM_POS,d1
        move.w 4(a5),d0
        move.w (a3,d0.w),d2
        add.w d2,d2
        asr.w #1,d2
        sub.w G_CAM_POS+2,d2
        move.w 6(a5),d0
        move.w (a3,d0.w),d3
        add.w d3,d3
        asr.w #1,d3
        sub.w G_CAM_POS+4,d3
        HSUM 0,6,12                     ; depth
        sub.l cam_m(pc),d4
        asr.l #8,d4
        asr.l #2,d4
        move.l d4,(a0)+
        HSUM 2,8,14                     ; x'
        sub.l cam_m+4(pc),d4
        asr.l #8,d4
        asr.l #2,d4
        move.l d4,(a0)+
        HSUM 4,10,16                    ; y' (2.13)
        sub.l cam_m+8(pc),d4
        asr.l #8,d4
        asr.l #1,d4
        move.l d4,(a0)+
        rts
.wr:    move.w 2(a3),d1
        move.w 4(a3),d2
        move.w 6(a3),d3
        lea cam_z0(pc),a3
        tst.b pe_rel(pc)
        bne.s .rel                      ; camera relative
        sub.w G_CAM_POS,d1
        sub.w G_CAM_POS+2,d2
        sub.w G_CAM_POS+4,d3
        lea cam_m(pc),a3
.rel:   HSUM 0,6,12
        move.l d4,d0                    ; the game's rounding of the sums
        asl.l #2,d0
        add.l #$8000,d0
        swap d0
        cmp.w 2(a5),d0
        bne.s .game
        sub.l (a3)+,d4
        asr.l #8,d4
        asr.l #2,d4
        move.l d4,(a0)
        HSUM 2,8,14
        move.l d4,d0
        asl.l #2,d0
        add.l #$8000,d0
        swap d0
        cmp.w 4(a5),d0
        bne.s .game
        sub.l (a3)+,d4
        asr.l #8,d4
        asr.l #2,d4
        move.l d4,4(a0)
        HSUM 4,10,16
        move.l d4,d0
        asl.l #3,d0
        add.l #$8000,d0
        swap d0
        cmp.w 6(a5),d0
        bne.s .game
        sub.l (a3),d4
        asr.l #8,d4
        asr.l #1,d4
        move.l d4,8(a0)
        lea 12(a0),a0
        rts
.game:  moveq #2,d0                     ; the stored values
.gw:    move.w (a5,d0.w),d1
        ext.l d1
        asl.l #4,d1
        move.l d1,(a0)+
        addq.w #2,d0
        cmp.w #8,d0
        bne.s .gw
        rts

; The polygon hp_p (D6 corners, at least 3) -> rows hs_y0-hs_y1 (none when
; hs_y1 < hs_y0) and their first and last x in hs_l / hs_r (not clipped
; to the row), as the game's spans with exact corners: the rows from the
; one of the top corner to the one of the bottom corner, in each row the
; x of the edges at the row's middle and of the corners in the row, and
; the pixels from the one of the leftmost x to the one of the rightmost
; (x from 100.0 to 200.9 is pixels 100-200; every row keeps a pixel).
; Pixel x covers x to x + 1, row y covers y to y + 1. All registers kept.
hscan:
        movem.l d0-d7/a0-a6,-(sp)
        lea hp_p(pc),a0
        move.l #$7fffffff,d2
        move.l #$80000000,d3
        move.w d6,d7
        subq.w #1,d7
        movea.l a0,a1
.mm:    move.l 4(a1),d1
        cmp.l d2,d1
        bge.s .m1
        move.l d1,d2
.m1:    cmp.l d3,d1
        ble.s .m2
        move.l d1,d3
.m2:    addq.l #8,a1
        dbra d7,.mm
        asr.l #8,d2
        asr.l #8,d3
        tst.l d2
        bpl.s .y0
        moveq #0,d2
.y0:    cmp.l #VIEW_H-1,d3
        ble.s .y1
        moveq #VIEW_H-1,d3
.y1:    lea hs_y0(pc),a6
        move.w d2,(a6)+
        move.w d3,(a6)
        cmp.l d3,d2
        bgt .out
        lea hs_l(pc),a4
        lea hs_r(pc),a5
        lea (a4,d2.w*2),a2
        lea (a5,d2.w*2),a3
        sub.w d2,d3
        move.w #$7fff,d0
        move.w #-$8000,d1
.in:    move.w d0,(a2)+
        move.w d1,(a3)+
        dbra d3,.in
        lea -8(a0,d6.w*8),a1            ; edges, from the last corner
        move.w d6,d7
        subq.w #1,d7
.e:     movem.l (a1),d0-d1              ; xa, ya
        movem.l (a0),d2-d3              ; xb, yb
        cmp.l d1,d3
        bge.s .ord
        exg d0,d2
        exg d1,d3
.ord:   move.l d1,d4
        asr.l #8,d4                     ; rows of the ends
        move.l d3,d5
        asr.l #8,d5
        cmp.l #VIEW_H,d4
        bcc.s .na
        move.l d0,d6
        asr.l #4,d6
        HSUPD d4,d6,a4,a5
.na:    cmp.l #VIEW_H,d5
        bcc.s .nb
        move.l d2,d6
        asr.l #4,d6
        HSUPD d5,d6,a4,a5
.nb:    cmp.l d1,d3
        beq.s .ne                       ; level
        move.l d1,d4                    ; rows with the middle from ya to yb
        add.l #127,d4
        asr.l #8,d4
        move.l d3,d5
        sub.l #128,d5
        asr.l #8,d5
        tst.l d4
        bpl.s .x0
        moveq #0,d4
.x0:    cmp.l #VIEW_H-1,d5
        ble.s .x1
        moveq #VIEW_H-1,d5
.x1:    cmp.l d5,d4
        bgt.s .ne
        move.l #128,d6                  ; middles at y = row + 0.5
        bsr.s .step
        lea (a4,d4.w*2),a2
        lea (a5,d4.w*2),a3
.xl:    move.l d6,d0                    ; the pixel
        swap d0
        cmp.w (a2)+,d0
        bge.s .xu
        move.w d0,-2(a2)
.xu:    cmp.w (a3)+,d0
        ble.s .xv
        move.w d0,-2(a3)
.xv:    add.l d2,d6
        dbra d5,.xl
.ne:    movea.l a0,a1
        addq.l #8,a0
        dbra d7,.e
.out:   movem.l (sp)+,d0-d7/a0-a6
        rts
; Edge (D0, D1) to (D2, D3), first row D4 (sample y = 256 D4 + D6), last
; row D5 -> D6 = x x 65536 at the first, D2 = its step per row (only
; valid when the edge has more than one row), D5 = rows - 1. D3 is lost.
.step:  sub.l d0,d2                     ; dx (x 16)
        sub.l d1,d3                     ; dy (x 256), > 0
        move.l d4,-(sp)
        lsl.l #8,d4
        add.l d4,d6
        sub.l d1,d6
        muls.l d2,d6
        divs.l d3,d6
        add.l d0,d6
        lsl.l #8,d6
        lsl.l #4,d6
        swap d2
        clr.w d2
        divs.l d3,d2
        lsl.l #4,d2
        move.l (sp)+,d4
        sub.w d4,d5
        rts

; Fill the polygon tx_fp (D6 corners: x, y words) row by row with tspan
; (A3 = surface).
fscan:
        movem.l d0-d7/a0-a2/a4-a5,-(sp)
        lea tx_fp(pc),a0
        move.w #$7fff,d2                ; rows
        move.w #-$8000,d3
        move.w d6,d0
        subq.w #1,d0
        movea.l a0,a1
.mm:    move.w 2(a1),d1
        cmp.w d2,d1
        bge.s .m1
        move.w d1,d2
.m1:    cmp.w d3,d1
        ble.s .m2
        move.w d1,d3
.m2:    addq.l #4,a1
        dbra d0,.mm
        tst.w d2
        bpl.s .c0
        moveq #0,d2
.c0:    cmp.w #VIEW_H-1,d3
        ble.s .c1
        move.w #VIEW_H-1,d3
.c1:    cmp.w d3,d2
        bgt .x
        lea tx_fl(pc),a1
        lea tx_fr(pc),a2
        move.w d2,d0
.in:    move.w #$7fff,(a1,d0.w*2)
        move.w #-$8000,(a2,d0.w*2)
        addq.w #1,d0
        cmp.w d3,d0
        ble.s .in
        lea -4(a0,d6.w*4),a4            ; edges: from the last corner
        movea.l a0,a5
        move.w d6,d7
        subq.w #1,d7
.e:     movem.w (a4),d0-d1              ; xa, ya
        movem.w (a5),d4-d5              ; xb, yb
        cmp.w d1,d5
        bge.s .ord
        exg d0,d4
        exg d1,d5
.ord:   sub.w d1,d5                     ; dy
        sub.w d0,d4                     ; dx
        tst.w d5
        bne.s .sl
        cmp.w d2,d1                     ; level edge: its row
        blt .ne
        cmp.w d3,d1
        bgt .ne
        add.w d0,d4
        cmp.w (a1,d1.w*2),d0
        bge.s .h0
        move.w d0,(a1,d1.w*2)
.h0:    cmp.w (a2,d1.w*2),d0
        ble.s .h1
        move.w d0,(a2,d1.w*2)
.h1:    cmp.w (a1,d1.w*2),d4
        bge.s .h2
        move.w d4,(a1,d1.w*2)
.h2:    cmp.w (a2,d1.w*2),d4
        ble .ne
        move.w d4,(a2,d1.w*2)
        bra .ne
.sl:    ext.l d4
        swap d4
        clr.w d4
        ext.l d5
        divs.l d5,d4                    ; x step per row (16.16)
        add.w d1,d5                     ; last row
        cmp.w d3,d5
        ble.s .l1
        move.w d3,d5
.l1:    move.w d1,d6                    ; first row
        cmp.w d2,d6
        bge.s .l0
        move.w d2,d6
.l0:    sub.w d6,d1
        neg.w d1
        ext.l d1
        muls.l d4,d1
        ext.l d0
        swap d0
        clr.w d0
        add.l d1,d0
        add.l #$8000,d0
.rl:    cmp.w d5,d6
        bgt.s .ne
        move.l d0,d1
        swap d1
        cmp.w (a1,d6.w*2),d1
        bge.s .r1
        move.w d1,(a1,d6.w*2)
.r1:    cmp.w (a2,d6.w*2),d1
        ble.s .r2
        move.w d1,(a2,d6.w*2)
.r2:    add.l d4,d0
        addq.w #1,d6
        bra.s .rl
.ne:    movea.l a5,a4
        addq.l #4,a5
        dbra d7,.e
        TROW0 a0
        move.w d2,d6                    ; spans
.sp:    move.w (a1,d6.w*2),d0
        move.w (a2,d6.w*2),d1
        tst.w d0
        bpl.s .s0
        moveq #0,d0
.s0:    cmp.w #VIEW_W-1,d1
        ble.s .s1
        move.w #VIEW_W-1,d1
.s1:    sub.w d0,d1
        bmi.s .sn
        addq.w #1,d1
        movea.l chunky_base(pc),a0
        move.w d6,d7
        mulu.w #VIEW_W,d7
        adda.l d7,a0
        adda.w d0,a0
        move.w d6,d2
        bsr tspan
.sn:    addq.w #1,d6
        cmp.w d3,d6
        ble.s .sp
.x:     movem.l (sp)+,d0-d7/a0-a2/a4-a5
        rts

        machine 68000
