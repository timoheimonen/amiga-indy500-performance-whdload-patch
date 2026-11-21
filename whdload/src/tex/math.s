; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Arithmetic helpers of the textures (tx_fit14, tx_sqrt).

        machine 68020

; A0 = D7 longs, shifted right together until each is within $4000.
tx_fit14:
        movem.l d0-d3/a1,-(sp)
        movea.l a0,a1
        moveq #0,d1
        move.w d7,d2
        subq.w #1,d2
.m:     move.l (a1)+,d0
        bpl.s .p
        neg.l d0
.p:     or.l d0,d1
        dbra d2,.m
        moveq #0,d3
.s:     cmp.l #$3fff,d1
        bls.s .d
        lsr.l #1,d1
        addq.w #1,d3
        bra.s .s
.d:     movea.l a0,a1
        move.w d7,d2
        subq.w #1,d2
.r:     move.l (a1),d0
        asr.l d3,d0
        move.l d0,(a1)+
        dbra d2,.r
        movem.l (sp)+,d0-d3/a1
        rts

; D1 = sqrt(D2) (D0, D2 and D3 used).
tx_sqrt:
        moveq #0,d1
        move.l #$40000000,d3
.i1:    cmp.l d2,d3
        bls.s .i2
        lsr.l #2,d3
        bne.s .i1
.i2:    move.l d1,d0
        add.l d3,d0
        lsr.l #1,d1
        cmp.l d0,d2
        bcs.s .i3
        sub.l d0,d2
        add.l d3,d1
.i3:    lsr.l #2,d3
        bne.s .i2
        rts

        machine 68000
