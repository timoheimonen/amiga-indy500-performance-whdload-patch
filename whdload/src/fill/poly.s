; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Polygon fills into the planes (installed on a 68040/060).
;
; poly_fill fills each span row with four one line blits (one per plane),
; waiting for the blitter before each. Most spans are a few words wide, so the
; blit setup costs more than the fill. Here the CPU writes the words itself,
; with the game's own mask and offset tables.
;
; poly_fill_pattern and poly_fill_dither work like poly_fill; the CPU takes
; each word from the pattern image or ANDs the row's dither word to the masks.

; Replaces poly_fill. Preserves A2-A6 like the original (and D2-D7 too).
cpu_poly_fill:
        btst #0,chunky_on(pc)
        bne c_poly_fill
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt .none
        movem.l d2-d7/a2-a6,-(sp)
        move.w d1,d6                    ; rows - 1
        btst #6,$dff002                 ; a blit may still write the buffer
.idle:  btst #6,$dff002
        bne.s .idle
        lea G_SPAN_LEFT,a1
        lea G_MASK_FIRST,a3
        lea G_MASK_LAST,a4
        lea G_WORD_OFFSET,a5
        moveq #0,d5
        move.w d0,d5
        add.w d0,d0
        adda.w d0,a1
        mulu.w #40,d5
        add.l #VIEW_TOP,d5
        add.l G_DRAW_BACK,d5            ; start of the first row
.row:   move.w $1fc(a1),d1
        move.w (a1)+,d0
        cmp.w d1,d0
        blt.s .ordered
        exg d0,d1
.ordered:
        add.w d0,d0
        add.w d1,d1
        moveq #0,d2
        move.w (a5,d0.w),d2             ; offset of the first word
        move.w (a5,d1.w),d7
        sub.w d2,d7
        lsr.w #1,d7                     ; words - 1
        movea.l d5,a0
        adda.l d2,a0
        move.w (a3,d0.w),d0
        move.w (a4,d1.w),d1
        lea G_COLOUR,a2
        moveq #3,d4
        subq.w #1,d7
        bpl.s .plane
        and.w d1,d0                     ; one word: both masks
.one:   move.w (a2)+,d2
        move.w (a0),d3
        eor.w d2,d3
        and.w d0,d3
        eor.w d3,(a0)
        lea FILL_PLANE(a0),a0
        dbra d4,.one
        bra.s .next
.plane: movea.l a0,a6
        move.w (a2)+,d2
        move.w (a6),d3                  ; first word under its mask
        eor.w d2,d3
        and.w d0,d3
        eor.w d3,(a6)+
        move.w d7,d3
        bra.s .mid_in
.mid:   move.w d2,(a6)+
.mid_in:
        dbra d3,.mid
        move.w (a6),d3                  ; last word under its mask
        eor.w d2,d3
        and.w d1,d3
        eor.w d3,(a6)
        lea FILL_PLANE(a0),a0
        dbra d4,.plane
.next:  moveq #40,d0
        add.l d0,d5
        dbra d6,.row
        lea $dff000,a0                  ; blitter state as poly_fill leaves it
        move.w #$5ac,$40(a0)
        clr.w $42(a0)
        move.w #$ffff,$74(a0)
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
.none:  rts

; Replaces poly_fill_pattern: as poly_fill, but each word of the span comes
; from a pattern image (the blit's C source) instead of the colour. Row source:
; low byte of the row address + pattern_x + word offset (word adds), + the
; pattern base; the planes of the image are PATTERN_PLANE bytes apart.
cpu_pattern_fill:
        btst #0,chunky_on(pc)
        bne c_pattern_fill
        move.w G_SPAN_YMAX,d1
        move.w G_SPAN_YMIN,d0
        sub.w d0,d1
        blt .none
        movem.l d2-d7/a2-a6,-(sp)
        move.w d1,d6                    ; rows - 1
        btst #6,$dff002
.idle:  btst #6,$dff002
        bne.s .idle
        lea G_SPAN_LEFT,a1
        lea G_WORD_OFFSET,a5
        moveq #0,d5
        move.w d0,d5
        add.w d0,d0
        adda.w d0,a1
        mulu.w #40,d5
        add.l #VIEW_TOP,d5
        add.l G_DRAW_BACK,d5
        movea.l d5,a4                   ; start of the row
.row:   move.w $1fc(a1),d1
        move.w (a1)+,d0
        cmp.w d1,d0
        blt.s .ordered
        exg d0,d1
.ordered:
        add.w d0,d0
        add.w d1,d1
        moveq #0,d2
        move.w (a5,d0.w),d2             ; offset of the first word
        move.w (a5,d1.w),d7
        sub.w d2,d7
        lsr.w #1,d7                     ; words - 1
        movea.l a4,a0
        adda.l d2,a0
        move.l a4,d3                    ; pattern source as the blit's C
        andi.l #$ff,d3
        add.w G_PATTERN_X,d3
        add.w d2,d3
        add.l G_PATTERN_BASE,d3
        bclr #0,d3
        movea.l d3,a2
        lea G_MASK_FIRST,a6
        move.w (a6,d0.w),d0
        lea G_MASK_LAST,a6
        move.w (a6,d1.w),d1
        moveq #3,d5
        subq.w #1,d7
        bpl.s .plane
        and.w d1,d0                     ; one word: both masks
.one:   move.w (a2),d2
        move.w (a0),d4
        eor.w d2,d4
        and.w d0,d4
        eor.w d4,(a0)
        lea FILL_PLANE(a0),a0
        lea PATTERN_PLANE(a2),a2
        dbra d5,.one
        bra.s .next
.plane: movea.l a0,a6
        movea.l a2,a3
        move.w (a3)+,d2
        move.w (a6),d4                  ; first word under its mask
        eor.w d2,d4
        and.w d0,d4
        eor.w d4,(a6)+
        move.w d7,d3
        bra.s .mid_in
.mid:   move.w (a3)+,(a6)+
.mid_in:
        dbra d3,.mid
        move.w (a3),d2
        move.w (a6),d4                  ; last word under its mask
        eor.w d2,d4
        and.w d1,d4
        eor.w d4,(a6)
        lea FILL_PLANE(a0),a0
        lea PATTERN_PLANE(a2),a2
        dbra d5,.plane
.next:  lea 40(a4),a4
        dbra d6,.row
        lea $dff000,a0                  ; blitter state as the original leaves it
        move.w #$7ac,$40(a0)
        clr.w $42(a0)
        move.w #$ffff,$74(a0)
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
.none:  rts

; Replaces poly_fill_dither (from $C14982): as poly_fill, with the dither word
; of the row ANDed to every word's mask. The dither words and the row word are
; updated in memory as the original does.
cpu_dither_fill:
        btst #0,chunky_on(pc)
        bne c_dither_fill
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
        btst #6,$dff002
.idle:  btst #6,$dff002
        bne.s .idle
        lea G_SPAN_LEFT,a1
        lea G_MASK_FIRST,a3
        lea G_WORD_OFFSET,a5
        moveq #0,d5
        move.w d0,d5
        add.w d0,d0
        adda.w d0,a1
        mulu.w #40,d5
        add.l #VIEW_TOP,d5
        add.l G_DRAW_BACK,d5
        movea.l d5,a4                   ; start of the row
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
        move.w (a5,d0.w),d2             ; offset of the first word
        move.w (a5,d1.w),d7
        sub.w d2,d7
        lsr.w #1,d7                     ; words - 1
        movea.l a4,a0
        adda.l d2,a0
        move.w (a3,d0.w),d0
        and.w d5,d0
        lea G_MASK_LAST,a6
        move.w (a6,d1.w),d1
        and.w d5,d1
        lea G_COLOUR,a2
        subq.w #1,d7
        bpl.s .plane
        and.w d1,d0                     ; one word: both masks
.one:   move.w (a2)+,d2
        move.w (a0),d4
        eor.w d2,d4
        and.w d0,d4
        eor.w d4,(a0)
        lea FILL_PLANE(a0),a0
        cmpa.l #G_COLOUR+8,a2
        bne.s .one
        bra.s .next
.plane: movea.l a0,a6
        move.w (a2)+,d2
        move.w (a6),d4                  ; first word under its mask
        eor.w d2,d4
        and.w d0,d4
        eor.w d4,(a6)+
        move.w d7,d3
        bra.s .mid_in
.mid:   move.w (a6),d4
        eor.w d2,d4
        and.w d5,d4
        eor.w d4,(a6)+
.mid_in:
        dbra d3,.mid
        move.w (a6),d4                  ; last word under its mask
        eor.w d2,d4
        and.w d1,d4
        eor.w d4,(a6)
        lea FILL_PLANE(a0),a0
        cmpa.l #G_COLOUR+8,a2
        bne.s .plane
.next:  lea 40(a4),a4
        dbra d6,.row
        lea $dff000,a0                  ; blitter state as the original leaves it
        move.w #$5ac,$40(a0)
        clr.w $42(a0)
        move.w d5,$74(a0)               ; the last row's dither word
        move.l #$ffffffff,$44(a0)
        movem.l (sp)+,d2-d7/a2-a6
.none:  rts
