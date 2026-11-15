; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; xw_sum: the sums of xform_vertex_world and xform_vertex_rel rounded to
; nearest (see geom/xform.s).

        machine 68020

XWSUM   macro                           ; \1 = matrix words \2-\4 . D1-D3
        move.w G_VIEW_MATRIX+\2,d0
        muls.w d1,d0
        move.l d0,\1
        move.w G_VIEW_MATRIX+\3,d0
        muls.w d2,d0
        add.l d0,\1
        move.w G_VIEW_MATRIX+\4,d0
        muls.w d3,d0
        add.l d0,\1
        endm
xw_sum:
        XWSUM d5,2,8,14
        asl.l #2,d5
        add.l #$8000,d5
        swap d5
        move.w d5,4(a3,d6.l)            ; x'
        XWSUM d7,4,10,16
        asl.l #3,d7
        add.l #$8000,d7
        swap d7
        move.w d7,6(a3,d6.l)            ; y'
        XWSUM d4,0,6,12
        asl.l #2,d4
        add.l #$8000,d4
        swap d4
        move.w d4,2(a3,d6.l)            ; depth
        jmp F_XW_SUM+$72                ; outcode and projection

        machine 68000
