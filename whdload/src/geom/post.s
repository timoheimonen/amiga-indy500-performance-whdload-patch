; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Posts (tex_on2 bit 1, from xline): a segment of a solid colour with a
; width in pst_tab (half width, 1/16 unit) and an end near enough for that
; to be wider than a pixel, not camera relative, 8 to 300
; units long and upright in the world (its ends in camera space, hl_c, at
; most 1 unit or 1/8 of its length off world up: the posts, poles, stand
; legs and the slightly leaning tree trunks, not the branches) gets that
; half width in pst_hw (else 0). Uses D0-D7, A0-A1.

        machine 68020

pst_chk:
        lea pst_hw(pc),a1
        clr.w (a1)
        btst #1,tex_on2(pc)
        beq .x
        moveq #15,d1                    ; a post colour (pixel 0)
        and.b ctab(pc),d1
        lea pst_tab(pc),a0
        move.b (a0,d1.w),d7
        beq .x
        moveq #0,d0                     ; an end nearer than 320 x the half
        move.b d7,d0                    ; width (wider than a pixel)
        mulu.w #320,d0
        lea hl_c(pc),a0
        cmp.l (a0),d0
        bgt.s .nr
        cmp.l 12(a0),d0
        ble .x
.nr:    tst.b ls_rel(pc)
        bne .x
        btst #0,tx_ok(pc)
        beq .x
        lea ctab(pc),a0                 ; in all 16 pixels
        move.l (a0)+,d0
        cmp.l (a0)+,d0
        bne .x
        cmp.l (a0)+,d0
        bne .x
        cmp.l (a0)+,d0
        bne .x
        move.l d0,d1
        rol.l #8,d1
        cmp.l d0,d1
        bne .x
        lea hl_c(pc),a0                 ; d = B - A (1/16 unit, y' halved)
        move.l 12(a0),d0
        sub.l (a0),d0
        move.l 16(a0),d1
        sub.l 4(a0),d1
        move.l 20(a0),d2
        sub.l 8(a0),d2
        asr.l #1,d2
        move.l d0,d4                    ; mostly along y': |depth| + |x'|
        bpl.s .a0                       ; at most |y'|
        neg.l d4
.a0:    move.l d1,d5
        bpl.s .a1
        neg.l d5
.a1:    add.l d5,d4
        move.l d2,d5
        bpl.s .a2
        neg.l d5
.a2:    cmp.l d5,d4
        bgt .x
        cmp.l #16*300,d5                ; within 300 units (words)
        bgt .x
        move.l d7,-(sp)                 ; |d x r| / 2^14, r = world up in
        movem.w tx_m+12(pc),d4-d6       ; camera space (the matrix row, its
        move.l d1,d3                    ; y' scaled as the corners')
        muls.w d6,d3
        move.l d2,d7
        muls.w d5,d7
        sub.l d7,d3
        moveq #14,d7
        asr.l d7,d3
        muls.w d3,d3
        movea.l d3,a0
        move.l d2,d3
        muls.w d4,d3
        move.l d0,d7
        muls.w d6,d7
        sub.l d7,d3
        moveq #14,d7
        asr.l d7,d3
        muls.w d3,d3
        adda.l d3,a0
        move.l d0,d3
        muls.w d5,d3
        move.l d1,d7
        muls.w d4,d7
        sub.l d7,d3
        moveq #14,d7
        asr.l d7,d3
        muls.w d3,d3
        add.l a0,d3                     ; the part off up, squared
        muls.w d0,d0                    ; |d|^2
        muls.w d1,d1
        muls.w d2,d2
        add.l d1,d0
        add.l d2,d0
        move.l (sp)+,d7
        cmp.l #128*128,d0               ; 8 units or more
        blt.s .x
        lsr.l #6,d0
        cmp.l #256,d0
        bcc.s .t
        move.l #256,d0
.t:     cmp.l d0,d3
        bgt.s .x
        ext.w d7
        move.w d7,(a1)
.x:     rts
pst_tab:        dc.b 24,0,0,0,0,0,48,24,24,0,0,0,0,0,0,0 ; by colour
pst_hw:         dc.w 0
        even

; The post (pst_hw) from the projected ends hp_p (x 16, y x 256) and their
; depths (hl_c, after the clipping): on each row between them the pixels
; whose centres lie within the half width (160 pst_hw / depth at the ends,
; along the rows in between) of the line's x at the row's middle, at least
; the pixel there, in ctab's colours. Z clear (nothing drawn) when the ends
; are less than two rows apart or the half width is below half a pixel at
; both. Uses D0-D7, A0-A1, A5.
pst_fill:
        movem.l hp_p(pc),d0-d3
        lea hl_c(pc),a0
        move.l (a0),d4                  ; depths
        move.l 12(a0),d5
        cmp.l d1,d3                     ; A on top
        bge.s .o
        exg d0,d2
        exg d1,d3
        exg d4,d5
.o:     move.l d3,d6
        sub.l d1,d6
        cmp.l #512,d6
        bge.s .go
        moveq #1,d0                     ; Z clear: the thin line
        rts
.go:    move.w pst_hw(pc),d7            ; half widths x 4096 / pixel
        ext.l d7
        mulu.l #655360,d7
        move.l d7,a1
        divs.l d4,d7                    ; at A
        move.l a1,d4
        divs.l d5,d4                    ; at B
        cmp.l #2048,d7                  ; both below half a pixel: the
        bge.s .wd                       ; thin line
        cmp.l #2048,d4
        bge.s .wd
        moveq #1,d0
        rts
.wd:    lea pst_s(pc),a0
        asl.l #8,d0                     ; x at A x 4096
        asl.l #8,d2
        move.l d0,(a0)                  ; X0
        move.l d7,4(a0)                 ; W0
        sub.l d0,d2                     ; per row: dx x 256 / dy
        asl.l #8,d2
        divs.l d6,d2
        sub.l d7,d4
        asl.l #8,d4
        divs.l d6,d4
        move.l d2,8(a0)                 ; X step
        move.l d4,12(a0)                ; W step
        move.l d1,d5                    ; first row: centre at or below A
        add.l #127,d5
        asr.l #8,d5
        bpl.s .r0
        moveq #0,d5
.r0:    move.l d3,d6                    ; last: centre at or above B
        sub.l #128,d6
        asr.l #8,d6
        cmp.l #VIEW_H-1,d6
        ble.s .r1
        moveq #VIEW_H-1,d6
.r1:    sub.l d5,d6
        bmi .x
        move.l d5,d0                    ; from A to the first centre (1/256)
        asl.l #8,d0
        add.l #128,d0
        sub.l d1,d0
        move.l d0,d1
        lsr.l #8,d1                     ; whole rows
        andi.l #255,d0                  ; and the rest
        move.l d2,d3
        muls.l d1,d3
        add.l d3,(a0)
        move.l d2,d3
        muls.l d0,d3
        asr.l #8,d3
        add.l d3,(a0)
        move.l d4,d3
        muls.l d1,d3
        add.l d3,4(a0)
        move.l d4,d3
        muls.l d0,d3
        asr.l #8,d3
        add.l d3,4(a0)
        movea.l chunky_base(pc),a1
        mulu.w #VIEW_W,d5
        adda.l d5,a1
        lea ctab(pc),a5
        movem.l (a0),d4-d5              ; X, W
.row:   move.l d4,d0                    ; first pixel: ceil(left - 1/2)
        sub.l d5,d0
        add.l #2047,d0
        asr.l #8,d0
        asr.l #4,d0
        move.l d4,d1                    ; last
        add.l d5,d1
        add.l #2047,d1
        asr.l #8,d1
        asr.l #4,d1
        subq.l #1,d1
        cmp.l d0,d1
        bge.s .in
        move.l d4,d0                    ; none: the pixel at x
        asr.l #8,d0
        asr.l #4,d0
        move.l d0,d1
.in:    tst.l d0
        bpl.s .l0
        moveq #0,d0
.l0:    cmp.l #VIEW_W-1,d1
        ble.s .l1
        move.l #VIEW_W-1,d1
.l1:    sub.l d0,d1
        bmi.s .nx
.px:    moveq #15,d3
        and.w d0,d3
        move.b (a5,d3.w),(a1,d0.w)
        addq.w #1,d0
        dbra d1,.px
.nx:    add.l 8(a0),d4
        add.l 12(a0),d5
        lea VIEW_W(a1),a1
        dbra d6,.row
.x:     moveq #0,d0                     ; Z set: drawn
        rts
pst_s:          ds.l 4                  ; X, W, their steps per row

        machine 68000
