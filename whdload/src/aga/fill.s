; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The fills with the AGA view: each polygon is drawn from its own spans
; (hspans: the recorded corners projected with sub-pixel precision, or
; the game's spans), rows of bytes. 68020 instructions (chunky drawing:
; a 68040/060 only).

        machine 68020

; Span \1-\2 clamped to the row; to \3 when nothing is left.
HCLAMP  macro
        tst.w \1
        bpl.s .a\@
        moveq #0,\1
.a\@:   cmp.w #VIEW_W-1,\2
        ble.s .b\@
        move.w #VIEW_W-1,\2
.b\@:   cmp.w \2,\1
        bgt \3
        endm

c_poly_fill:
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt pe_drop
        movem.l d2-d7/a2-a6,-(sp)
        movem.w G_COLOUR,d0-d3
        lea ctab(pc),a0
        bsr ctable
        bsr tex_class
        bsr tex_poly
        sne d4
        bsr hspans
        move.w hs_y0(pc),d2
        move.w hs_y1(pc),d6
        sub.w d2,d6
        bmi.s .end
        move.w d2,d0
        bsr crow
        lea hs_l(pc),a1
        lea (a1,d2.w*2),a1
        tst.b d4
        bne.s .tex
        move.b ctab(pc),d5              ; the colour as a long
        move.b d5,d0
        lsl.w #8,d5
        move.b d0,d5
        move.w d5,d0
        swap d5
        move.w d0,d5
.row:   move.w (a1),d0
        move.w hs_r-hs_l(a1),d1
        addq.l #2,a1
        HCLAMP d0,d1,.rn
        movea.l a6,a0
        bsr hrow_solid
.rn:    lea VIEW_W(a6),a6
        dbra d6,.row
.end:   lea $dff000,a0                  ; blitter state as poly_fill leaves it
        move.w #$5ac,$40(a0)
        clr.w $42(a0)
        move.w #$ffff,$74(a0)
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
        rts
; Textured spans (tex_poly): each row from its left to its right pixel.
.tex:   lea tx_loc+TL_ROW(pc),a3        ; tspan: another surface (TROW0)
        move.w #TROW_NONE,(a3)
        lea tx_psurf(pc),a3
.trow:  move.w (a1),d0
        move.w hs_r-hs_l(a1),d1
        addq.l #2,a1
        HCLAMP d0,d1,.tn
        sub.w d0,d1
        addq.w #1,d1
        lea (a6,d0.w),a0
        bsr tspan
.tn:    lea VIEW_W(a6),a6
        addq.w #1,d2
        dbra d6,.trow
        bra.s .end

; The dither word of row r is the game's word of its first row YMIN,
; flipped by G_DITHER when r - YMIN is odd.
c_dither_fill:
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt pe_drop
        movem.l d2-d7/a2-a6,-(sp)
        move.w G_DITHER,d2
        move.w G_DITHER+2,d3
        eor.w d2,d3
        move.w d3,G_DITHER
        btst #0,d0
        bne.s .odd
        eor.w d3,d2
.odd:   move.w d2,G_DITHER_ROW
        movem.w G_COLOUR,d0-d3
        lea ctab(pc),a0
        bsr ctable
        bsr tex_class                   ; no texture (tex_wall lists a fence)
        bsr tex_tree                    ; the trees: leaves
        bsr hspans
        move.w G_DITHER,d7
        move.w G_DITHER_ROW,d3
        tst.b tr_on(pc)
        bne .tree
        move.w hs_y0(pc),d2
        move.w d2,d0
        sub.w G_SPAN_YMIN,d0
        btst #0,d0
        beq.s .w0
        eor.w d7,d3
.w0:    move.w hs_y1(pc),d6
        sub.w d2,d6
        bmi.s .end
        move.w d2,d0
        bsr crow
        lea hs_l(pc),a1
        lea (a1,d2.w*2),a1
        move.b ctab(pc),d4
.row:   move.w (a1),d0
        move.w hs_r-hs_l(a1),d1
        addq.l #2,a1
        HCLAMP d0,d1,.rn
        movea.l a6,a0
        bsr hrow_dither
.rn:    eor.w d7,d3
        lea VIEW_W(a6),a6
        dbra d6,.row
.end:   move.w G_SPAN_YMAX,d0           ; as the original leaves it: the
        sub.w G_SPAN_YMIN,d0            ; word after the last row, BLTADAT
        move.w G_DITHER_ROW,d5          ; the last row's
        btst #0,d0
        beq.s .e0
        eor.w d7,d5
.e0:    move.w d5,d1
        eor.w d7,d1
        move.w d1,G_DITHER_ROW
        lea $dff000,a0
        move.w #$5ac,$40(a0)
        clr.w $42(a0)
        move.w d5,$74(a0)
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
        rts
.tree:  move.w hs_y0(pc),d2             ; leaves (tex_tree) instead
        move.w hs_y1(pc),d6
        sub.w d2,d6
        bmi .end
        move.w d2,d0
        bsr crow
        lea hs_l(pc),a1
        lea (a1,d2.w*2),a1
        lea tx_loc+TL_ROW(pc),a3
        move.w #TROW_NONE,(a3)
        lea tx_psurf(pc),a3
.trow:  move.w (a1),d0
        move.w hs_r-hs_l(a1),d1
        addq.l #2,a1
        HCLAMP d0,d1,.tn
        sub.w d0,d1
        addq.w #1,d1
        lea (a6,d0.w),a0
        bsr tspan
.tn:    lea VIEW_W(a6),a6
        addq.w #1,d2
        dbra d6,.trow
        bra .end

; As cpu_pattern_fill: the colours of word w of a row (pixels 16 w to
; 16 w + 15) come from the four pattern words at its source.
c_pattern_fill:
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt pe_drop
        movem.l d2-d7/a2-a6,-(sp)
        bsr tex_crowd                   ; the grandstands' crowd
        bsr hspans
        tst.b cr_on(pc)
        bne .crowd
        move.w hs_y0(pc),d2
        move.w hs_y1(pc),d6
        sub.w d2,d6
        bmi .end
        move.w d2,d0
        bsr crow
        lea hs_l(pc),a1
        lea (a1,d2.w*2),a1
        mulu.w #40,d2
        add.l #VIEW_TOP,d2
        add.l G_DRAW_BACK,d2
        movea.l d2,a4                   ; planar row: the pattern source uses it
        lea ptab(pc),a2
.row:   move.w (a1),d0
        move.w hs_r-hs_l(a1),d1
        addq.l #2,a1
        HCLAMP d0,d1,.rn
        move.l a4,d3                    ; source of word 0 as the blit's C
        andi.l #$ff,d3
        add.w G_PATTERN_X,d3
        add.l G_PATTERN_BASE,d3
        bclr #0,d3
        move.w d0,d4
        lsr.w #4,d4                     ; first and last word
        move.w d1,d5
        lsr.w #4,d5
.wd:    move.w d4,d7
        add.w d7,d7
        movea.l d3,a3
        adda.w d7,a3
        bsr .ptab
        move.w d4,d7
        lsl.w #4,d7                     ; its pixels within the span
        move.w d7,d2
        add.w #15,d2
        cmp.w d0,d7
        bge.s .p0
        move.w d0,d7
.p0:    cmp.w d1,d2
        ble.s .p1
        move.w d1,d2
.p1:    sub.w d7,d2
        lea (a6,d7.w),a0
        andi.w #15,d7
        lea (a2,d7.w),a5
.pb:    move.b (a5)+,(a0)+
        dbra d2,.pb
        addq.w #1,d4
        cmp.w d5,d4
        ble.s .wd
.rn:    lea 40(a4),a4
        lea VIEW_W(a6),a6
        dbra d6,.row
.end:   lea $dff000,a0                  ; blitter state as the original leaves it
        move.w #$7ac,$40(a0)
        clr.w $42(a0)
        move.w #$ffff,$74(a0)
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
        rts
.crowd: move.w hs_y0(pc),d2             ; the crowd (tex_crowd) instead
        move.w hs_y1(pc),d6
        sub.w d2,d6
        bmi .end
        move.w d2,d0
        bsr crow
        lea hs_l(pc),a1
        lea (a1,d2.w*2),a1
        lea tx_loc+TL_ROW(pc),a3
        move.w #TROW_NONE,(a3)
        lea tx_psurf(pc),a3
.krow:  move.w (a1),d0
        move.w hs_r-hs_l(a1),d1
        addq.l #2,a1
        HCLAMP d0,d1,.kn
        sub.w d0,d1
        addq.w #1,d1
        lea (a6,d0.w),a0
        bsr tspan
.kn:    lea VIEW_W(a6),a6
        addq.w #1,d2
        dbra d6,.krow
        bra .end
; Colours of the pattern word at A3 into ptab (A2). Keeps D0/D1.
.ptab:  movem.l d0-d3/a0,-(sp)
        move.w (a3),d0
        move.w PATTERN_PLANE(a3),d1
        move.w 2*PATTERN_PLANE(a3),d2
        move.w 3*PATTERN_PLANE(a3),d3
        movea.l a2,a0
        bsr ctable
        movem.l (sp)+,d0-d3/a0
        rts

; A0 = row, D0-D1 = first and last x (D0 <= D1), D5 = the colour in each
; byte. Uses D0, D1, A0.
hrow_solid:
        sub.w d0,d1
        addq.w #1,d1                    ; pixels
        adda.w d0,a0
.h:     move.w a0,d0                    ; bytes up to a long boundary
        andi.w #3,d0
        beq.s .l
        move.b d5,(a0)+
        subq.w #1,d1
        bne.s .h
        rts
.l:     move.w d1,d0
        lsr.w #4,d0
        bra.s .li
.ll:    move.l d5,(a0)+
        move.l d5,(a0)+
        move.l d5,(a0)+
        move.l d5,(a0)+
.li:    dbra d0,.ll
        move.w d1,d0
        andi.w #15,d0
        lsr.w #2,d0
        bra.s .mi
.ml:    move.l d5,(a0)+
.mi:    dbra d0,.ml
        andi.w #3,d1
        bra.s .ti
.tl:    move.b d5,(a0)+
.ti:    dbra d1,.tl
        rts

; A0 = row, D0-D1 = first and last x (D0 <= D1), D3 = dither word (bit
; 15 - (x & 15) for pixel x), D4 = colour. Uses D0-D2, D5, A0.
hrow_dither:
        sub.w d0,d1                     ; pixels - 1
        adda.w d0,a0
        move.w d3,d5
        swap d5
        move.w d3,d5
        move.w d0,d2
        andi.w #15,d2
        rol.l d2,d5                     ; bit 31: the pixel at D0
.p:     tst.l d5
        bpl.s .s
        move.b d4,(a0)
.s:     addq.l #1,a0
        rol.l #1,d5
        dbra d1,.p
        rts
        machine 68000
