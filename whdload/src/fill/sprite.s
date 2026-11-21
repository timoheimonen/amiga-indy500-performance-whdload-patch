; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Car images into the planes (installed on a 68040/060).
;
; draw_car_sprite draws each image row as a span like those of poly_fill (one
; blit per plane); the CPU version decodes the same image and scale tables.

; Replaces draw_car_sprite. A0 = image, A1 = scale table, D0/D1 = screen
; position, D3 = body colours, D7 < 0 mirrors. The image is a count byte and
; groups of colour, source row, height and height x pairs; the scale table
; maps source rows (bytes at -$7D) and x values (words), and a row is dropped
; whenever the row counter (reloaded from -1(a1)) runs out. Each drawn row is a
; span like poly_fill, with the sprite mask and offset tables. A0 ends after
; the image as in the original; D2-D7 are kept.
cpu_car_sprite:
        btst #0,chunky_on(pc)
        bne c_car_sprite
        movem.l d2-d7/a2-a6,-(sp)
        move.w d1,G_SPR_Y
        move.w d3,G_SPR_COLOURS
        btst #6,$dff002
.idle:  btst #6,$dff002
        bne.s .idle
        lea G_SPR_FIRST,a3
        lea G_SPR_LAST,a4
        lea G_SPR_OFFSET,a5
        add.w d0,d0
        adda.w d0,a3
        adda.w d0,a4
        adda.w d0,a5
        move.b -1(a1),G_SPR_RELOAD
        lea spr_mirror(pc),a6           ; the slave has no relocations
        tst.w d7
        smi (a6)
        move.b (a0)+,d2                 ; groups (word count as the original)
        subq.w #1,d2
.group: move.w d2,-(sp)
        moveq #0,d0
        move.b (a0)+,d0
        cmp.b #12,d0
        bne.s .c9
        move.b G_SPR_COLOURS,d0
        bra.s .col
.c9:    cmp.b #9,d0
        bne.s .col
        move.b G_SPR_COLOURS+1,d0
.col:   jsr F_SET_COLOUR
        moveq #0,d3
        move.b (a0)+,d3
        subi.w #$7d,d3
        move.b -$7d(a1,d3.w),G_SPR_COUNT
        moveq #0,d5
        move.b (a1,d3.w),d5
        add.w G_SPR_Y,d5
        bmi .skip
        cmp.w #$7b,d5
        bgt .skip
        move.l a0,-(sp)
        moveq #0,d6
        move.b (a0)+,d6
        add.w d5,d6
        cmp.w #$7c,d6
        ble.s .clip
        moveq #$7c,d6
.clip:  sub.w d5,d6
        subq.w #1,d6                    ; source rows - 1
        mulu.w #40,d5
        addi.w #VIEW_TOP,d5
        add.l G_DRAW_BACK,d5            ; start of the screen row
.row:   subq.b #1,G_SPR_COUNT
        beq .drop
        moveq #0,d0
        moveq #0,d1
        btst #0,spr_mirror(pc)
        bne.s .mir
        move.b (a0)+,d0
        move.b (a0)+,d1
        add.w d0,d0
        add.w d1,d1
        move.w (a1,d0.w),d0
        move.w (a1,d1.w),d1
        bra.s .xs
.mir:   move.b (a0)+,d1
        move.b (a0)+,d0
        add.w d0,d0
        add.w d1,d1
        move.w (a1,d0.w),d0
        neg.w d0
        subq.w #2,d0
        move.w (a1,d1.w),d1
        neg.w d1
        subq.w #2,d1
.xs:    move.l a0,-(sp)
        moveq #0,d2
        move.w (a5,d0.w),d2             ; offset of the first word
        move.w (a5,d1.w),d7
        sub.w d2,d7
        asr.w #1,d7                     ; words - 1
        movea.l d5,a0
        adda.l d2,a0
        move.w (a3,d0.w),d0
        move.w (a4,d1.w),d1
        lea G_COLOUR,a2
        subq.w #1,d7
        bpl.s .plane
        and.w d1,d0                     ; one word: both masks
.one:   move.w (a2)+,d2
        move.w (a0),d3
        eor.w d2,d3
        and.w d0,d3
        eor.w d3,(a0)
        lea FILL_PLANE(a0),a0
        cmpa.l #G_COLOUR+8,a2
        bne.s .one
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
        cmpa.l #G_COLOUR+8,a2
        bne.s .plane
.next:  movea.l (sp)+,a0
        moveq #40,d0
        add.l d0,d5
        dbra d6,.row
        bra.s .done
.drop:  addq.l #2,a0                    ; source row dropped
        move.b G_SPR_RELOAD,G_SPR_COUNT
        dbra d6,.row
.done:  movea.l (sp)+,a0
.skip:  moveq #0,d0
        move.b (a0)+,d0
        add.w d0,d0
        adda.w d0,a0
        move.w (sp)+,d2
        dbra d2,.group
        lea $dff000,a2                  ; blitter state as the original leaves it
        move.w #$5ac,$40(a2)
        clr.w $42(a2)
        move.w #$ffff,$74(a2)
        move.l #$ffffffff,$44(a2)
        movem.l (sp)+,d2-d7/a2-a6
        rts

spr_mirror:     dc.b 0
        even
