; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Textures of the ground and the road: the ground of the background
; (tex_ground, gnd_flush), the road polygons (tex_plane) and the panels across
; the track (tex_panel).

        machine 68020

; End of the background: the whole ground bytes of each row get the
; texture (the byte at the horizon stays flat). With gnd_mark the spans
; are only recorded for gnd_flush; if plane 2 has marked bytes outside
; them (gnd_cnt), the markers become colour 7 again and the spans are
; textured now.
tex_ground:
        btst #0,tx_ok(pc)
        beq .out
        movem.l d0-d4/a0/a2-a4,-(sp)
        lea tx_gnd(pc),a3
        tst.l TS_HS(a3)
        beq .done
.again: TROW0 a0
        lea gnd_list(pc),a4
        moveq #0,d3                     ; spans recorded
        moveq #0,d4                     ; their bytes above gnd_full
        movea.l G_DRAW_BACK,a2
        lea VIEW_TOP+2*FILL_PLANE(a2),a2
        moveq #0,d2
.row:   cmp.w gnd_full(pc),d2
        bcc.s .full
        moveq #0,d0
.l:     cmpi.b #$ff,(a2,d0.w)
        bne.s .le
        addq.w #1,d0
        cmp.w #40,d0
        bne.s .l
.le:    tst.w d0
        beq.s .right
        move.w d0,d1
        moveq #0,d0
        bra.s .part
.right: moveq #40,d0
.r:     cmpi.b #$ff,-1(a2,d0.w)
        bne.s .re
        subq.w #1,d0
        bne.s .r
.re:    moveq #40,d1
        sub.w d0,d1
        beq.s .next
.part:  add.w d1,d4
        bra.s .span
.full:  moveq #0,d0                     ; plane 2 all ones
        moveq #40,d1
.span:  lsl.w #3,d0
        lsl.w #3,d1
        btst #0,gnd_mark(pc)
        bne.s .rec
        movea.l chunky_base(pc),a0
        move.w d2,d3
        mulu.w #VIEW_W,d3
        adda.l d3,a0
        adda.w d0,a0
        bsr tspan
        bra.s .next
.rec:   move.w d0,(a4)+
        move.w d1,(a4)+
        move.w d2,(a4)+
        addq.w #1,d3
.next:  lea 40(a2),a2
        addq.w #1,d2
        cmp.w #VIEW_H,d2
        bne.s .row
        btst #0,gnd_mark(pc)
        beq.s .done
        cmp.w gnd_cnt(pc),d4
        bne.s .undo
        lea gnd_n(pc),a0
        move.w d3,(a0)
.done:  movem.l (sp)+,d0-d4/a0/a2-a4
.out:   rts
.undo:  lea gnd_mark(pc),a0
        sf (a0)
        movea.l chunky_base(pc),a0
        move.w #VIEW_H*VIEW_W/4-1,d0
        move.l #GND_MARK*$01010101,d1
.u:     cmp.l (a0)+,d1
        bne.s .un
        move.l #$07070707,-4(a0)
.un:    dbra d0,.u
        bra .again

; After the 3D view (view_flush, before the c2p): the ground spans that
; tex_ground recorded, with the texture where the markers are left.
gnd_flush:
        movem.l d0-d4/a0/a3-a4,-(sp)
        lea gnd_n(pc),a4
        move.w (a4),d3
        beq.s .out
        clr.w (a4)
        lea tx_loc+TL_MASK(pc),a4
        st (a4)
        move.w #TROW_NONE,TL_ROW-TL_MASK(a4)    ; TROW0
        lea tx_gnd(pc),a3
        lea gnd_list(pc),a4
        subq.w #1,d3
.span:  move.w (a4)+,d0
        move.w (a4)+,d1
        move.w (a4)+,d2
        movea.l chunky_base(pc),a0
        move.w d2,d4
        mulu.w #VIEW_W,d4
        adda.l d4,a0
        adda.w d0,a0
        bsr tspan
        dbra d3,.span
        lea tx_loc+TL_MASK(pc),a4
        sf (a4)
.out:   movem.l (sp)+,d0-d4/a0/a3-a4
        rts

; poly_plane, colour 7 or 8: tx_n = the normal (towards the camera), D1 =
; its length. tx_n becomes the unit normal, tx_h8 = the camera's height
; above the plane x 256.
tex_plane:
        movem.l d0/d2-d3/a0,-(sp)
        lea tx_n(pc),a0
        moveq #2,d2
.u:     move.w (a0),d0
        ext.l d0
        asl.l #8,d0
        asl.l #6,d0
        divs.w d1,d0
        move.w d0,(a0)+
        dbra d2,.u
        lea tx_n(pc),a0
        move.w (a0)+,d0
        muls.w pl_a(pc),d0
        move.w (a0)+,d2
        muls.w pl_a+2(pc),d2
        add.l d2,d0
        move.w (a0)+,d2
        muls.w pl_a+4(pc),d2
        add.l d2,d0
        neg.l d0
        asr.l #6,d0
        move.w tx_n(pc),d2              ; + N . the camera's fraction
        muls.w cam_c(pc),d2
        move.w tx_n+2(pc),d3
        muls.w cam_c+2(pc),d3
        add.l d3,d2
        move.w tx_n+4(pc),d3
        muls.w cam_c+4(pc),d3
        add.l d3,d2
        moveq #14,d3
        asr.l d3,d2
        add.l d2,d0
        move.l d0,(a0)                  ; tx_h8
        movem.l (sp)+,d0/d2-d3/a0
        rts

; poly_plane: a vertical colour 7 or 8 polygon reaching from at least 6
; units below the camera to between 3 below and 6 above it paints the
; ground beyond it (tx_mode 2).
tex_panel:
        movem.l d0-d4/a0,-(sp)
        lea pl_a(pc),a0
        move.l #-$8000,d2               ; highest
        move.l #$7fff,d3                ; lowest
        moveq #2,d4
.c:     move.w (a0)+,d0
        muls.w tx_up(pc),d0
        move.w (a0)+,d1
        muls.w tx_up+2(pc),d1
        add.l d1,d0
        move.w (a0)+,d1
        muls.w tx_up+4(pc),d1
        add.l d1,d0
        moveq #14,d1
        asr.l d1,d0                     ; height above the camera
        cmp.l d0,d2
        bge.s .hi
        move.l d0,d2
.hi:    cmp.l d0,d3
        ble.s .lo
        move.l d0,d3
.lo:    dbra d4,.c
        moveq #-3,d0
        cmp.l d0,d2
        blt.s .no
        moveq #6,d0
        cmp.l d0,d2
        bgt.s .no
        moveq #-6,d0
        cmp.l d0,d3
        bgt.s .no
        lea tx_mode(pc),a0
        move.b #2,(a0)
.no:    movem.l (sp)+,d0-d4/a0
        rts

        machine 68000
