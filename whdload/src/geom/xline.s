; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Line primitives (aga_install): the transforms of the second and later
; vertices in lines_track, lines_world, lines_rel and draw_line_pairs
; record the segment (the vertex before in G_LINE_PREV, the new one in D6)
; and their line_draw_to calls (ls_draw) mark it for cpu_line_draw, which
; then draws it from its exact ends in the chunky view (xline). The flags
; are the transform's (outcode in D0).

        machine 68020

lx_track:
        jsr F_XFORM_TRACK
        move.l a0,-(sp)
        lea ls_rel(pc),a0
        sf (a0)
        bsr.s lx_rec
        bsr gr_seg                      ; a rail of a turn guardrail
        movea.l (sp)+,a0
        tst.w d0
        rts
lx_world:
        jsr F_XFORM_WORLD
        move.l a0,-(sp)
        lea ls_rel(pc),a0
        sf (a0)
        bra.s lx_seg
lx_rel:
        jsr F_XFORM_REL
        move.l a0,-(sp)
        lea ls_rel(pc),a0
        st (a0)                         ; camera relative (hcorner: pe_rel)
lx_seg: bsr.s lx_rec
        movea.l (sp)+,a0
        tst.w d0
        rts
lx_rec: cmpa.l #G_SHAPE_BASE,a4         ; hcorner takes the sources from there
        seq ls_ok-ls_rel(a0)
        move.l a3,ls_base-ls_rel(a0)
        move.w G_LINE_PREV,ls_a-ls_rel(a0)
        move.w d6,ls_b-ls_rel(a0)
        rts
ls_draw:
        move.l a0,-(sp)
        lea ls_on(pc),a0
        move.b ls_ok-ls_on(a0),(a0)
        movea.l (sp)+,a0
        jmp F_LINE_DRAW
ls_base:        dc.l 0                  ; vertex_buf (A3)
ls_a:           dc.w 0                  ; the segment: record offsets of its ends
ls_b:           dc.w 0
ls_rel:         dc.b 0                  ; ends camera relative (lines_rel)
ls_ok:          dc.b 0                  ; recorded with A4 = shape_base
ls_on:          dc.b 0                  ; the line being drawn is the segment
        even
xl_ck:          dc.l -1                 ; xline: key of the last B (-1: none,
                ds.l 3                  ; set by each view) and its corner

; The segment ls_a - ls_b into the chunky view: its ends in camera space
; (hcorner, 1/16 unit) clipped to the near plane at depth 1 and the cone
; twice the view (as hspans), projected with 1/16 pixel and 1/256 row
; precision (hproj). Drawn are the pixels of the two ends and, in each
; column between them (each row when steeper), the pixel at the line's y
; (x) at the column's (row's) middle, in ctab's colours. All registers
; kept.
xline:
        movem.l d0-d7/a0-a6,-(sp)
        lea pe_rel(pc),a1
        move.b (a1),d7                  ; the polygons' pe_rel
        move.b ls_rel(pc),(a1)
        movea.l ls_base(pc),a2
        lea hl_c(pc),a0
        move.w ls_a(pc),d0              ; A: in a line strip the B before
        move.w (a2,d0.w),d1
        swap d1
        clr.w d1
        move.b ls_rel(pc),d1            ; key: source, camera relative
        lea xl_ck(pc),a3
        cmp.l (a3)+,d1
        bne.s .ha
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        bra.s .hb
.ha:    bsr hcorner
.hb:    move.w ls_b(pc),d0
        move.w (a2,d0.w),d6
        swap d6
        clr.w d6
        move.b ls_rel(pc),d6
        bsr hcorner
        lea xl_ck(pc),a3
        move.l d6,(a3)+
        move.l -12(a0),(a3)+
        move.l -8(a0),(a3)+
        move.l -4(a0),(a3)+
        lea pe_rel(pc),a1
        move.b d7,(a1)
        bsr pst_chk                     ; a post: pst_hw
        lea hl_c(pc),a0                 ; both in front and in the cone: no
        moveq #1,d6                     ; clipping
.ck:    move.l (a0)+,d0
        cmp.l #16,d0
        blt.s .clip
        add.l d0,d0
        move.l (a0)+,d1
        bpl.s .k1
        neg.l d1
.k1:    cmp.l d0,d1
        bgt.s .clip
        move.l (a0)+,d1
        bpl.s .k2
        neg.l d1
.k2:    cmp.l d0,d1
        bgt.s .clip
        dbra d6,.ck
        bra.s .proj
.clip:  lea hl_c(pc),a0
        moveq #0,d7                     ; plane: near, right, left, top, bottom
.pl:    movea.l a0,a4
        bsr xl_f
        move.l d0,d2                    ; f of A
        lea 12(a0),a4
        bsr xl_f
        move.l d0,d3                    ; of B
        movea.l a0,a2
        lea 12(a0),a3
        tst.l d2
        bpl.s .ai
        tst.l d3
        bmi .x                          ; both outside
        bsr xl_cut                      ; A outside
        bra.s .np
.ai:    tst.l d3
        bpl.s .np
        exg a2,a3                       ; B outside
        exg d2,d3
        bsr xl_cut
.np:    addq.w #1,d7
        cmp.w #5,d7
        bne.s .pl
.proj:  lea hl_c(pc),a0
        moveq #2,d6
        bsr hproj
        tst.w pst_hw(pc)
        beq.s .thin
        bsr pst_fill                    ; a post with its width
        beq .x
.thin:  movem.l hp_p(pc),d0-d3          ; A x x 16, y x 256, B x, y
        movea.l chunky_base(pc),a1
        lea ctab(pc),a5
        move.l d2,d4
        sub.l d0,d4
        bpl.s .x0
        neg.l d4
.x0:    asl.l #4,d4                     ; |dx| in rows' units
        move.l d3,d5
        sub.l d1,d5
        bpl.s .y0
        neg.l d5
.y0:    cmp.l d5,d4
        bcs .ym
        cmp.l d2,d0                     ; one pixel per column, left to right
        ble.s .xo
        exg d0,d2
        exg d1,d3
.xo:    move.l d0,d4
        asr.l #4,d4
        move.l d1,d5
        asr.l #8,d5
        bsr xl_pt                       ; the ends
        move.l d2,d4
        asr.l #4,d4
        move.l d3,d5
        asr.l #8,d5
        bsr xl_pt
        move.l d0,d4                    ; the columns between, in the view
        asr.l #4,d4
        addq.l #1,d4
        bpl.s .c1
        moveq #0,d4
.c1:    move.l d2,d6
        asr.l #4,d6
        subq.l #1,d6
        cmp.l #VIEW_W-1,d6
        ble.s .c2
        move.l #VIEW_W-1,d6
.c2:    sub.l d4,d6
        bmi .x
        move.l d3,d5                    ; rows x 65536 per column
        sub.l d1,d5
        asl.l #8,d5
        asl.l #4,d5
        move.l d2,d7
        sub.l d0,d7
        divs.l d7,d5
        move.l d4,d7                    ; y x 65536 at the first one's middle
        asl.l #4,d7
        addq.l #8,d7
        sub.l d0,d7
        muls.l d5,d7
        asr.l #4,d7
        asl.l #8,d1
        add.l d1,d7
.xl:    move.l d7,d0
        swap d0
        cmp.w #VIEW_H,d0
        bcc.s .xs
        mulu.w #VIEW_W,d0
        add.l d4,d0
        moveq #15,d1
        and.w d4,d1
        move.b (a5,d1.w),(a1,d0.l)
.xs:    add.l d5,d7
        addq.l #1,d4
        dbra d6,.xl
        bra .x
.ym:    cmp.l d3,d1                     ; one pixel per row, top to bottom
        ble.s .yo
        exg d0,d2
        exg d1,d3
.yo:    move.l d0,d4
        asr.l #4,d4
        move.l d1,d5
        asr.l #8,d5
        bsr xl_pt
        move.l d2,d4
        asr.l #4,d4
        move.l d3,d5
        asr.l #8,d5
        bsr xl_pt
        move.l d1,d4                    ; the rows between, in the view
        asr.l #8,d4
        addq.l #1,d4
        bpl.s .r1
        moveq #0,d4
.r1:    move.l d3,d6
        asr.l #8,d6
        subq.l #1,d6
        cmp.l #VIEW_H-1,d6
        ble.s .r2
        moveq #VIEW_H-1,d6
.r2:    sub.l d4,d6
        bmi.s .x
        move.l d2,d5                    ; columns x 16384 per row
        sub.l d0,d5
        moveq #18,d7
        asl.l d7,d5
        move.l d3,d7
        sub.l d1,d7
        divs.l d7,d5
        move.l d4,d7                    ; x x 16384 at the first one's middle
        asl.l #8,d7
        add.l #128,d7
        sub.l d1,d7
        muls.l d5,d7
        asr.l #8,d7
        asl.l #8,d0
        asl.l #2,d0
        add.l d0,d7
        move.l d4,d0
        mulu.w #VIEW_W,d0
        adda.l d0,a1
.yl:    move.l d7,d0
        asr.l #8,d0
        asr.l #6,d0
        cmp.l #VIEW_W,d0
        bcc.s .ys
        moveq #15,d1
        and.w d0,d1
        move.b (a5,d1.w),(a1,d0.l)
.ys:    add.l d5,d7
        lea VIEW_W(a1),a1
        dbra d6,.yl
.x:     movem.l (sp)+,d0-d7/a0-a6
        rts
; Plane D7 of xline at the corner A4 -> D0 (inside from 0).
xl_f:   move.l (a4),d0
        tst.w d7
        bne.s .f1
        sub.l #16,d0                    ; near: depth 1
        rts
.f1:    add.l d0,d0
        cmp.w #2,d7
        bcc.s .f2
        sub.l 4(a4),d0                  ; right
        rts
.f2:    bne.s .f3
        add.l 4(a4),d0                  ; left
        rts
.f3:    cmp.w #3,d7
        bne.s .f4
        sub.l 8(a4),d0                  ; top
        rts
.f4:    add.l 8(a4),d0                  ; bottom
        rts
; Moves the corner A2 (outside, f D2 < 0) on the line to A3 (f D3 >= 0)
; to the plane, at t = D2 / (D2 - D3) as fclip. Uses D0-D3.
xl_cut: move.l d2,d0
        sub.l d3,d0
        move.l d2,d1
.cn:    cmp.l #-32767,d0                ; |D2| <= |D2 - D3| < 2^15
        bge.s .cp
        asr.l #1,d0
        asr.l #1,d1
        bra.s .cn
.cp:    asl.l #8,d1
        asl.l #7,d1
        divs.l d0,d1                    ; t x 32768
        moveq #0,d0
.ci:    move.l (a3,d0.w),d2             ; split at bit 15 to stay in 32 bits
        sub.l (a2,d0.w),d2
        move.l d2,d3
        asr.l #8,d3
        asr.l #7,d3
        muls.l d1,d3
        and.l #$7fff,d2
        muls.l d1,d2
        asr.l #8,d2
        asr.l #7,d2
        add.l d3,d2
        add.l d2,(a2,d0.w)
        addq.w #4,d0
        cmp.w #12,d0
        bne.s .ci
        rts
; The pixel in column D4, row D5 (longs) of the chunky view A1 when in the
; view, colour from ctab (A5). Uses D6, D7.
xl_pt:  cmp.l #VIEW_W,d4
        bcc.s .o
        cmp.l #VIEW_H,d5
        bcc.s .o
        move.l d5,d6
        mulu.w #VIEW_W,d6
        add.l d4,d6
        moveq #15,d7
        and.w d4,d7
        move.b (a5,d7.w),(a1,d6.l)
.o:     rts

        machine 68000
