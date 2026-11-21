; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Car images of the chunky view.

; As cpu_car_sprite, the spans written as bytes.
c_car_sprite:
        ifd INTERP
        btst #0,c3_ok(pc)               ; the 3D car instead
        bne c3_car
        endif
        movem.l d2-d7/a2-a6,-(sp)
        move.w d1,G_SPR_Y
        move.w d3,G_SPR_COLOURS
        lea G_SPR_FIRST,a3
        lea G_SPR_LAST,a4
        lea G_SPR_OFFSET,a5
        add.w d0,d0
        adda.w d0,a3
        adda.w d0,a4
        adda.w d0,a5
        move.b -1(a1),G_SPR_RELOAD
        lea spr_mirror(pc),a6
        tst.w d7
        smi (a6)
        move.b (a0)+,d2
        subq.w #1,d2
.group: move.w d2,-(sp)
        moveq #0,d0
        move.b (a0)+,d0
        cmp.b #12,d0
        bne.s .c9
        ifd INTERP
        moveq #0,d1                     ; a livery: its primary
        btst #0,liv_ok(pc)
        bne.s .liv
        endif
        move.b G_SPR_COLOURS,d0
        bra.s .col
.c9:    cmp.b #9,d0
        bne.s .col
        ifd INTERP
        moveq #1,d1                     ; and its secondary
        btst #0,liv_ok(pc)
        bne.s .liv
        endif
        move.b G_SPR_COLOURS+1,d0
.col:   jsr F_SET_COLOUR
        movem.l d0-d3/a0,-(sp)
        movem.w G_COLOUR,d0-d3
        lea ctab(pc),a0
        bsr ctable
        movem.l (sp)+,d0-d3/a0
        ifd INTERP
        bra.s .cd
.liv:   lea liv_cols(pc),a2             ; the AGA colour byte in all 16
        move.b (a2,d1.w),d0             ; pixels of a word
        move.b d0,d1
        lsl.w #8,d1
        move.b d0,d1
        move.w d1,d0
        swap d1
        move.w d0,d1
        lea ctab(pc),a2
        move.l d1,(a2)+
        move.l d1,(a2)+
        move.l d1,(a2)+
        move.l d1,(a2)
.cd:
        endif
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
        move.w d5,d0
        bsr crow                        ; A6 = the screen row
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
        move.w (a5,d0.w),d2
        move.w (a5,d1.w),d7
        sub.w d2,d7
        asr.w #1,d7                     ; words - 1
        move.w (a3,d0.w),d0
        move.w (a4,d1.w),d1
        lea ctab(pc),a2
        moveq #-1,d5
        move.l d6,-(sp)
        bsr cspan
        move.l (sp)+,d6
        movea.l (sp)+,a0
        lea VIEW_W(a6),a6
        dbra d6,.row
        bra.s .done
.drop:  addq.l #2,a0
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
        ifd INTERP
        btst #0,sp_ok(pc)               ; the sparks of this car
        bne sp_far
        endif
        rts
