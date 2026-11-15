; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; tex_poly: the surface of the polygon being filled (from c_poly_fill).

        machine 68020

; After tex_class in c_poly_fill: Z clear when the polygon gets the
; texture (tx_psurf).
tex_poly:
        movem.l d0-d5/a0-a3,-(sp)
        move.b tx_mode(pc),d0
        beq .no
        btst #0,tx_ok(pc)
        beq .no
        lea ctab(pc),a0                 ; one colour
        move.b (a0)+,d1
        moveq #14,d2
.s:     cmp.b (a0)+,d1
        bne .no
        dbra d2,.s
        lea tx_psurf(pc),a3
        cmp.b #5,d0                     ; a material: from tex_face
        beq.s .test
        moveq #0,d5
        move.b d1,d5                    ; colour 7, 8, 15 or 5
        moveq #0,d2                     ; its tables
        cmp.b #8,d5
        bne.s .c15
        move.w #2048,d2
.c15:   cmp.b #15,d5
        bne.s .c5
        move.w #4096,d2
.c5:    cmp.b #5,d5
        bne.s .c7
        move.w #3*2048,d2
.c7:    movea.l tx_lut(pc),a2
        adda.l d2,a2
        lea tx_psurf(pc),a3
        cmp.b #3,d0
        beq.s .wall
        cmp.b #2,d0
        beq.s .gnd
        cmp.b #4,d0
        beq.s .grs
        movem.w tx_n(pc),d0-d2
        move.l tx_h8(pc),d3
        moveq #8,d4
        movea.l a2,a0
        bsr tsurf_init
        bra.s .test
.grs:   lea tx_grs(pc),a0
        bra.s .gcp
.gnd:   lea tx_gnd(pc),a0
.gcp:   movea.l a3,a1
        moveq #TS_SIZE/2-1,d2
.cp:    move.w (a0)+,(a1)+
        dbra d2,.cp
        move.l a2,TS_LUT(a3)
        move.b d5,TS_FLAT(a3)
        bra.s .test
.wall:  move.l a2,TS_LUT(a3)            ; the rest from tex_wall
        move.b d5,TS_FLAT(a3)
.test:  tst.l TS_HS(a3)
        beq.s .no
        moveq #1,d0
        movem.l (sp)+,d0-d5/a0-a3
        rts
.no:    moveq #0,d0
        movem.l (sp)+,d0-d5/a0-a3
        rts

        machine 68000
