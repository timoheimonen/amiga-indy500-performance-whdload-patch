; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Polygon clipping in camera space (fclip).

        machine 68020

; Clip the polygon at A0 (D6 corners: depth, x', y' longs) to plane D7
; (0 near at depth fc_zn, 1-4 right, left, top, bottom of a cone twice the
; view) into A1. D6 = corners out.
fclip:
        movem.l d0-d5/a1-a4,-(sp)
        moveq #0,d5
        move.w d6,d0
        beq .x
        subq.w #1,d0
        mulu.w #12,d0
        lea (a0,d0.l),a2                ; previous: the last corner
        movea.l a2,a4
        bsr .f
        move.l d0,d3
        movea.l a0,a3
        move.w d6,d4
        subq.w #1,d4
.e:     movea.l a3,a4
        bsr .f
        move.l d0,d2
        tst.l d3
        bmi.s .po
        move.l (a2),(a1)+               ; previous inside
        move.l 4(a2),(a1)+
        move.l 8(a2),(a1)+
        addq.w #1,d5
        tst.l d2
        bpl.s .nx
        bra.s .cut
.po:    tst.l d2
        bmi.s .nx
.cut:   move.l d3,d0                    ; crossing at t = fp / (fp - fc)
        sub.l d2,d0
        move.l d3,d1
.cn:    cmp.l #32767,d0                 ; |fp| <= |fp - fc| < 2^15
        ble.s .cp
.cs:    asr.l #1,d0
        asr.l #1,d1
        bra.s .cn
.cp:    cmp.l #-32767,d0
        blt.s .cs
        asl.l #8,d1
        asl.l #7,d1
        divs.l d0,d1                    ; t x 32768
        moveq #0,d0
.ci:    move.l (a3,d0.w),d2             ; prev + (cur - prev) t, split at
        sub.l (a2,d0.w),d2              ; bit 15 to stay in 32 bits
        move.l d2,d3
        asr.l #8,d3
        asr.l #7,d3
        muls.l d1,d3
        and.l #$7fff,d2
        muls.l d1,d2
        asr.l #8,d2
        asr.l #7,d2
        add.l d3,d2
        add.l (a2,d0.w),d2
        move.l d2,(a1)+
        addq.w #4,d0
        cmp.w #12,d0
        bne.s .ci
        addq.w #1,d5
        movea.l a3,a4                   ; f of the current corner again
        bsr .f
        move.l d0,d2
.nx:    move.l d2,d3
        movea.l a3,a2
        lea 12(a3),a3
        dbra d4,.e
.x:     move.w d5,d6
        movem.l (sp)+,d0-d5/a1-a4
        rts
.f:     move.l (a4),d0
        tst.w d7
        bne.s .f1
        sub.l fc_zn(pc),d0
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

        machine 68000
