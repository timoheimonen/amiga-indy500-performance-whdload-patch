; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; fc_build: the atlases of the scenery materials, built once (from tex_build).

        machine 68020

; Once (tex_build): the atlases of the scenery materials (the rectangles
; of fm_paint over texel 1, the pylon's numbers), their mip levels (each
; block of 2, 4 and 8 texels the rounded mean of the level before) and
; the tables of fm_ramp (texel 1-15 -> colour and level).
fc_build:
        movem.l d0-d7/a0-a6,-(sp)
        move.l expmem(pc),d0
        add.l #TFACE_OFF+32768,d0
        lea tx_fhtex(pc),a0
        move.l d0,(a0)+                 ; H: the middle of R0
        add.l #$40000,d0
        move.l d0,(a0)+                 ; V
        add.l #$40000-32768,d0
        move.l d0,(a0)                  ; tables
        movea.l tx_fhtex(pc),a0
        bsr .clr
        movea.l tx_fvtex(pc),a0
        bsr .clr
        lea fm_paint(pc),a5
.p:     move.b FP_ATL(a5),d0
        bmi.s .pd
        movea.l tx_fhtex(pc),a0
        tst.b d0
        beq.s .pa
        movea.l tx_fvtex(pc),a0
.pa:    bsr .rect
        lea FP_SIZE(a5),a5
        bra.s .p
.pd:    bsr .pylon
        movea.l tx_fhtex(pc),a0
        bsr .mips
        movea.l tx_fvtex(pc),a0
        bsr .mips
        movea.l tx_flut(pc),a0
        lea fm_ramp(pc),a1
        moveq #FM_NLUT-1,d6
.t:     clr.b (a0)                      ; texel 0: unused
        lea 1(a0),a4
        moveq #14,d4
.t1:    moveq #0,d0
        move.b (a1)+,d0                 ; colour
        moveq #0,d1
        move.b (a1)+,d1                 ; level
        sub.w #9,d1
        andi.w #15,d1
        lsl.w #4,d1
        or.w d0,d1
        move.b d1,(a4)+
        dbra d4,.t1
        lea 256(a0),a0
        dbra d6,.t
        movem.l (sp)+,d0-d7/a0-a6
        rts
; R0 at A0 (its middle) to texel 1.
.clr:   lea -32768(a0),a1
        move.l #$01010101,d0
        move.w #65536/4-1,d1
.c:     move.l d0,(a1)+
        dbra d1,.c
        rts
; The rectangle at A5 into R0 at A0 (texel u, v at v x 256 + u from the
; middle, a signed word): every texel whose distances from the corner
; modulo the periods are below the widths.
.rect:  move.w FP_V0(a5),d5
        moveq #0,d7
.rv:    moveq #0,d0
        move.w d7,d0
        divu.w FP_PV(a5),d0
        swap d0
        cmp.w FP_TV(a5),d0
        bcc.s .rn
        moveq #0,d6
.ru:    moveq #0,d0
        move.w d6,d0
        divu.w FP_PU(a5),d0
        swap d0
        cmp.w FP_TU(a5),d0
        bcc.s .rs
        move.w d5,d1
        lsl.w #8,d1
        move.w FP_U0(a5),d2
        add.w d6,d2
        move.b d2,d1
        move.b FP_IDX(a5),(a0,d1.w)
.rs:    addq.w #1,d6
        cmp.w FP_W(a5),d6
        bcs.s .ru
.rn:    addq.w #1,d5
        addq.w #1,d7
        cmp.w FP_H(a5),d7
        bcs.s .rv
        rts
; The pylon (V, u 0-19, 2 units a texel): 33 rows of 6 texels from the
; top, the position at u 1 and the car number (fm_cars) at u 11.
.pylon: movea.l tx_fvtex(pc),a0
        lea fm_cars(pc),a1
        moveq #0,d7
.py:    move.w d7,d0
        mulu.w #6,d0
        move.w #203,d5
        sub.w d0,d5                     ; top row
        move.w d7,d0
        addq.w #1,d0
        moveq #1,d4
        moveq #FM_PNUM,d3
        bsr.s .num
        moveq #0,d0
        move.b (a1,d7.w),d0
        moveq #11,d4
        moveq #FM_CNUM,d3
        bsr.s .num
        addq.w #1,d7
        cmp.w #33,d7
        bcs.s .py
        rts
; Number D0 (1-99): tens (when not 0) at u D4, ones at u D4 + 4; top
; row D5, texel D3.
.num:   ext.l d0
        divu.w #10,d0
        tst.w d0
        beq.s .n1
        bsr.s .dig
.n1:    swap d0
        addq.w #4,d4
        bsr.s .dig
        subq.w #4,d4
        rts
; Digit D0.w (fm_font: 5 rows of 3 bits, top row and left first, bits
; 14-0) at u D4, top row D5, texel D3. Registers kept.
.dig:   movem.l d0-d2/d5-d7/a2,-(sp)
        lea fm_font(pc),a2
        move.w (a2,d0.w*2),d6
        moveq #14,d2
        moveq #4,d7
.dr:    moveq #0,d0
.dc:    btst d2,d6
        beq.s .dn
        move.w d5,d1
        lsl.w #8,d1
        move.b d4,d1
        add.b d0,d1
        move.b d3,(a0,d1.w)
.dn:    subq.w #1,d2
        addq.w #1,d0
        cmp.w #3,d0
        bcs.s .dc
        subq.w #1,d5
        dbra d7,.dr
        movem.l (sp)+,d0-d2/d5-d7/a2
        rts
; R1-R3 of the atlas at A0 (the middle of R0), $10000 apart: each block
; of 2 b texels the rounded mean of its 4 blocks of b in the level
; before (b = 1, 2, 4).
.mips:  moveq #1,d7
        movea.l a0,a1
.ml:    movea.l a1,a2
        adda.l #$10000,a2
        moveq #0,d5
.mv:    moveq #0,d4
.mu:    move.w d5,d1
        lsl.w #8,d1
        move.b d4,d1
        moveq #0,d0
        moveq #0,d2
        move.b (a1,d1.w),d2
        add.w d2,d0
        move.w d1,d3
        add.b d7,d3
        move.b (a1,d3.w),d2
        add.w d2,d0
        move.w d7,d6
        lsl.w #8,d6
        add.w d6,d1
        move.b (a1,d1.w),d2
        add.w d2,d0
        add.w d6,d3
        move.b (a1,d3.w),d2
        add.w d2,d0
        addq.w #2,d0
        lsr.w #2,d0
        move.w d7,d6
        add.w d6,d6                     ; 2 b
        move.w d5,d1
        lsl.w #8,d1
        move.b d4,d1
        move.w d6,d3
        subq.w #1,d3
.fr:    move.w d1,d2
        movea.w d6,a3
.fc:    move.b d0,(a2,d2.w)
        addq.w #1,d2
        subq.w #1,a3
        move.w a3,d6
        bne.s .fc
        move.w d7,d6
        add.w d6,d6
        add.w #256,d1
        dbra d3,.fr
        add.w d6,d4
        cmp.w #256,d4
        bcs .mu
        add.w d6,d5
        cmp.w #256,d5
        bcs .mv
        movea.l a2,a1
        add.w d7,d7
        cmp.w #8,d7
        bcs .ml
        rts

        machine 68000
