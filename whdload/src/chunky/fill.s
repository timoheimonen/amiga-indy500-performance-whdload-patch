; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Polygon fills of the chunky view without INTERP: the game's spans written as
; bytes. With INTERP aga/fill.s takes the place of this module.

c_poly_fill:
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt .none
        movem.l d2-d7/a2-a6,-(sp)
        move.w d1,d6                    ; rows - 1
        movem.w G_COLOUR,d0-d3
        lea ctab(pc),a0
        bsr ctable
        lea ctab(pc),a2
        move.w G_SPAN_YMIN,d0
        lea G_SPAN_LEFT,a1
        adda.w d0,a1
        adda.w d0,a1
        bsr crow
        lea G_MASK_FIRST,a3
        lea G_MASK_LAST,a4
        lea G_WORD_OFFSET,a5
.row:   move.w $1fc(a1),d1
        move.w (a1)+,d0
        cmp.w d1,d0
        blt.s .ordered
        exg d0,d1
.ordered:
        add.w d0,d0
        add.w d1,d1
        moveq #0,d2
        move.w (a5,d0.w),d2
        move.w (a5,d1.w),d7
        sub.w d2,d7
        lsr.w #1,d7                     ; words - 1
        move.w (a3,d0.w),d0
        move.w (a4,d1.w),d1
        moveq #-1,d5
        bsr cspan
        lea VIEW_W(a6),a6
        dbra d6,.row
.end:   lea $dff000,a0                  ; blitter state as poly_fill leaves it
        move.w #$5ac,$40(a0)
        clr.w $42(a0)
        move.w #$ffff,$74(a0)
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
.none:  rts

c_dither_fill:
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt .none
        movem.l d2-d7/a2-a6,-(sp)
        move.w d1,d6                    ; rows - 1
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
        lea ctab(pc),a2
        move.w G_SPAN_YMIN,d0
        lea G_SPAN_LEFT,a1
        adda.w d0,a1
        adda.w d0,a1
        bsr crow
        lea G_MASK_FIRST,a3
        lea G_MASK_LAST,a4
        lea G_WORD_OFFSET,a5
.row:   move.w G_DITHER_ROW,d5          ; this row's dither word
        move.w G_DITHER,d2
        eor.w d2,G_DITHER_ROW
        move.w $1fc(a1),d1
        move.w (a1)+,d0
        cmp.w d1,d0
        blt.s .ordered
        exg d0,d1
.ordered:
        add.w d0,d0
        add.w d1,d1
        moveq #0,d2
        move.w (a5,d0.w),d2
        move.w (a5,d1.w),d7
        sub.w d2,d7
        lsr.w #1,d7                     ; words - 1
        move.w (a3,d0.w),d0
        and.w d5,d0
        move.w (a4,d1.w),d1
        and.w d5,d1
        bsr cspan
        lea VIEW_W(a6),a6
        dbra d6,.row
        lea $dff000,a0                  ; blitter state as the original leaves it
        move.w #$5ac,$40(a0)
        clr.w $42(a0)
        move.w d5,$74(a0)               ; the last row's dither word
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
.none:  rts

; As cpu_pattern_fill: each word's colours come from the four pattern words.
c_pattern_fill:
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt .none
        movem.l d2-d7/a2-a6,-(sp)
        move.w d1,d6                    ; rows - 1
        lea G_SPAN_LEFT,a1
        adda.w d0,a1
        adda.w d0,a1
        moveq #0,d5
        move.w d0,d5
        bsr crow
        mulu.w #40,d5
        add.l #VIEW_TOP,d5
        add.l G_DRAW_BACK,d5
        movea.l d5,a4                   ; planar row: the pattern source uses it
        lea G_WORD_OFFSET,a5
.row:   move.w $1fc(a1),d1
        move.w (a1)+,d0
        cmp.w d1,d0
        blt.s .ordered
        exg d0,d1
.ordered:
        add.w d0,d0
        add.w d1,d1
        moveq #0,d2
        move.w (a5,d0.w),d2
        move.w (a5,d1.w),d7
        sub.w d2,d7
        lsr.w #1,d7                     ; words - 1
        move.l a4,d3                    ; pattern source as the blit's C
        andi.l #$ff,d3
        add.w G_PATTERN_X,d3
        add.w d2,d3
        add.l G_PATTERN_BASE,d3
        bclr #0,d3
        movea.l d3,a3
        lea G_MASK_FIRST,a0
        move.w (a0,d0.w),d0
        lea G_MASK_LAST,a0
        move.w (a0,d1.w),d1
        movea.l a6,a0                   ; first word
        ext.l d2
        lsl.l #3,d2
        adda.l d2,a0
        lea ptab(pc),a2
        tst.w d7
        bgt.s .multi
        and.w d1,d0
        bsr.s .ptab
        move.w d0,d4
        bsr cword
        bra.s .next
.multi: bsr.s .ptab
        move.w d0,d4
        bsr cword
        subq.w #1,d7
        bra.s .in
.mid:   lea 16(a0),a0
        addq.l #2,a3
        bsr.s .ptab
        moveq #-1,d4
        bsr cword
.in:    dbra d7,.mid
        lea 16(a0),a0
        addq.l #2,a3
        bsr.s .ptab
        move.w d1,d4
        bsr cword
.next:  lea 40(a4),a4
        lea VIEW_W(a6),a6
        dbra d6,.row
        lea $dff000,a0                  ; blitter state as the original leaves it
        move.w #$7ac,$40(a0)
        clr.w $42(a0)
        move.w #$ffff,$74(a0)
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
.none:  rts
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
