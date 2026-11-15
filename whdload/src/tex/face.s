; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Materials of the scenery on the polygons inside the boxes of fm_tab
; (tex_face; the tables are in tex/materials.s).

        machine 68020

; tex_face (tex_class, colours 0, 7, 8 and 11): a polygon of the scenery
; whose first corner lies in the box of a material of its colour in
; fm_tab (with its tex_on bit set) gets that material on its plane
; (tw_plane), drawn by tspan in mesh mode 4 (mip levels, flat at k 7):
; a vertical face u along the plane from the end of its extent on the
; viewer's left, v = world z from the material's z (or the polygon's
; lowest); a flat one (the roofs) u along the stand and v from corner A
; along A -> B (front to back). Scales and the origin's place in the atlas
; from the material. tx_mode 5 when so. All registers kept.
tex_face:
        movem.l d0-d7/a0-a6,-(sp)
        lea pe_n(pc),a0
        cmpi.w #3,(a0)
        bcs .no
        tst.b pe_bad-pe_n(a0)
        bne .no
        tst.b pe_rel-pe_n(a0)
        bne .no
        movea.l pe_base(pc),a1          ; corner A: a track vertex
        move.w pe_vl(pc),d0             ; transformed this frame
        moveq #0,d1
        move.w (a1,d0.w),d1
        move.l d1,d2
        sub.l #TRACK_VTX_REL,d2
        bcs .no
        cmp.l #8*TRACK_VTX_N,d2
        bcc .no
        andi.w #7,d2
        bne .no
        lea G_SHAPE_BASE,a3
        cmp.w (a3,d1.l),d0
        bne .no
        lea G_COORD_POOL,a4
        move.w 2(a3,d1.l),d2
        move.w (a4,d2.w),d3
        add.w d3,d3
        asr.w #1,d3                     ; x
        move.w 4(a3,d1.l),d2
        move.w (a4,d2.w),d4
        add.w d4,d4
        asr.w #1,d4                     ; y
        move.w 6(a3,d1.l),d2
        move.w (a4,d2.w),d5
        add.w d5,d5
        asr.w #1,d5                     ; z
        moveq #15,d0
        and.b ctab(pc),d0
        lea fm_tab(pc),a2
.m:     move.b FM_COL(a2),d1
        bmi .no
        cmp.b d1,d0
        bne.s .mn
        move.b FM_BIT(a2),d1
        btst d1,tex_on(pc)
        beq.s .mn
        cmp.w FM_BOX(a2),d3
        blt.s .mn
        cmp.w FM_BOX+2(a2),d3
        bgt.s .mn
        cmp.w FM_BOX+4(a2),d4
        blt.s .mn
        cmp.w FM_BOX+6(a2),d4
        bgt.s .mn
        cmp.w FM_BOX+8(a2),d5
        blt.s .mn
        cmp.w FM_BOX+10(a2),d5
        ble.s .hit
.mn:    lea FM_SIZE(a2),a2
        bra.s .m
.hit:   moveq #FMF_FLAT,d0
        and.b FM_FLG(a2),d0
        lea tw_hor(pc),a0
        move.b d0,(a0)
        move.l a2,-(sp)
        bsr tw_plane
        movea.l (sp)+,a2
        lea tw_hor(pc),a0
        sf (a0)
        tst.l d0
        bne .no
        move.w tx_wnu+4(pc),d0          ; |n z|: vertical below 0.2, flat
        bpl.s .nz                       ; above 0.95
        neg.w d0
.nz:    btst #0,FM_FLG(a2)
        bne.s .fz
        cmp.w #3277,d0
        bcc .no
        bra.s .ori
.fz:    cmp.w #15565,d0
        bcs .no
.ori:   lea tx_psurf(pc),a3
        move.w TS_P(a3),d7              ; p
        moveq #13,d6                    ; x 2^14 -> x 2^(p + 1)
        sub.w d7,d6
        btst #0,FM_FLG(a2)
        beq.s .vert
        lea tx_wc(pc),a0                ; flat: the origin at corner A
        movem.w tx_weu(pc),d0-d1
        bsr .dot
        asr.l d6,d2
        movea.l d2,a4
        movem.w tx_wev(pc),d0-d1
        bsr .dot
        asr.l d6,d2
        movea.l d2,a5
        move.w FM_SU(a2),d3
        ext.l d3
        bra .map
.vert:  lea fm_ext(pc),a0               ; u extent over the corners (u axis
        move.l #$7fffffff,d0            ; . (x, y) x 2^14), the lowest z
        move.l d0,(a0)
        not.l d0
        move.l d0,4(a0)
        move.w #$7fff,8(a0)
        movea.l pe_base(pc),a1
        lea G_SHAPE_BASE,a4
        lea G_COORD_POOL,a5
        lea pe_vl(pc),a6
        move.w pe_n(pc),d5
        subq.w #1,d5
.cn:    move.w (a6)+,d0
        moveq #0,d1
        move.w (a1,d0.w),d1
        move.l d1,d2
        sub.l #TRACK_VTX_REL,d2
        bcs .no
        cmp.l #8*TRACK_VTX_N,d2
        bcc .no
        andi.w #7,d2
        bne .no
        cmp.w (a4,d1.l),d0
        bne .no
        move.w 2(a4,d1.l),d2
        move.w (a5,d2.w),d3
        add.w d3,d3
        asr.w #1,d3
        muls.w tx_weu(pc),d3
        move.w 4(a4,d1.l),d2
        move.w (a5,d2.w),d4
        add.w d4,d4
        asr.w #1,d4
        muls.w tx_weu+2(pc),d4
        add.l d4,d3                     ; u x 2^14
        move.w 6(a4,d1.l),d2
        move.w (a5,d2.w),d4
        add.w d4,d4
        asr.w #1,d4                     ; z
        cmp.l (a0),d3
        bge.s .e1
        move.l d3,(a0)
.e1:    cmp.l 4(a0),d3
        ble.s .e2
        move.l d3,4(a0)
.e2:    cmp.w 8(a0),d4
        bge.s .e3
        move.w d4,8(a0)
.e3:    dbra d5,.cn
        lea tx_wc(pc),a0                ; s = n . (camera - A): u from the
        move.w G_CAM_POS,d0             ; end on the viewer's left
        sub.w (a0)+,d0
        muls.w tx_wnu(pc),d0
        move.w G_CAM_POS+2,d1
        sub.w (a0)+,d1
        muls.w tx_wnu+2(pc),d1
        add.l d1,d0
        move.w G_CAM_POS+4,d1
        sub.w (a0),d1
        muls.w tx_wnu+4(pc),d1
        add.l d1,d0
        lea fm_ext(pc),a0
        move.w FM_SU(a2),d3
        ext.l d3
        move.l (a0),d1                  ; u min
        tst.l d0
        bmi.s .ul
        neg.l d3
        move.l 4(a0),d1                 ; or u max, mirrored
.ul:    asr.l d6,d1
        movea.l d1,a4                   ; u origin
        move.w FM_Z0(a2),d1
        btst #1,FM_FLG(a2)
        beq.s .z0
        move.w 8(a0),d1                 ; the lowest z
.z0:    ext.l d1
        move.w d7,d0
        addq.w #1,d0
        lsl.l d0,d1
        movea.l d1,a5                   ; v origin
        ; A4, A5: the origin (x 2^(p + 1)), D3: S u (signed).
.map:   move.l TS_CXP(a3),d4
        sub.l a4,d4
        bsr .mul
        move.w FM_UO(a2),d0
        ext.l d0
        move.w d7,d1
        addq.w #1,d1
        lsl.l d1,d0
        add.l d0,d4
        move.l d4,TS_CXP(a3)
        lea TS_UA(a3),a1
        bsr .sc3
        move.w FM_SV(a2),d3
        ext.l d3
        move.l TS_CYP(a3),d4
        sub.l a5,d4
        bsr .mul
        move.w FM_VO(a2),d0
        ext.l d0
        move.w d7,d1
        addq.w #1,d1
        lsl.l d1,d0
        add.l d0,d4
        move.l d4,TS_CYP(a3)
        lea TS_VA(a3),a1
        bsr .sc3
        move.w FM_SU(a2),d0             ; footprint: k = mip level, p + 9 -
        cmp.w FM_SV(a2),d0              ; log2 of 1.41 x the larger S
        bcc.s .sm
        move.w FM_SV(a2),d0
.sm:    mulu.w #181,d0
        lsr.l #7,d0
        bfffo d0{0:32},d1
        moveq #31,d2
        sub.w d1,d2
        move.w d7,d0
        add.w #9,d0
        sub.w d2,d0
        bpl.s .fp
        moveq #0,d0
.fp:    move.w d0,TS_FP(a3)
        moveq #0,d0
        move.b FM_LUT(a2),d0
        lsl.w #8,d0
        movea.l tx_flut(pc),a0
        adda.l d0,a0
        move.l a0,TS_LUT(a3)
        moveq #0,d0
        move.b FM_FLAT(a2),d0
        move.b (a0,d0.w),TS_FLAT(a3)
        move.b FM_KMAX(a2),d0
        lea tx_fk(pc),a0
        move.w d0,(a0)
        move.l tx_fhtex(pc),d0
        btst #2,FM_FLG(a2)
        beq.s .h
        move.l tx_fvtex(pc),d0
.h:     move.l d0,TS_TEX(a3)
        move.b #4,TS_MESH(a3)
        lea tx_mode(pc),a0
        move.b #5,(a0)
.no:    movem.l (sp)+,d0-d7/a0-a6
        rts
; D2 = x, y at A0 . (D0, D1) (words). D3 lost.
.dot:   move.w (a0),d2
        muls.w d0,d2
        move.w 2(a0),d3
        muls.w d1,d3
        add.l d3,d2
        rts
; D4 x D3 / 256 -> D4 (D4 within 2^30, D3 within 2^10). D0 lost.
.mul:   move.l d4,d0
        asr.l #8,d0
        muls.l d3,d0
        andi.l #255,d4
        muls.l d3,d4
        asr.l #8,d4
        add.l d0,d4
        rts
; The three longs at A1 x D3 / 256. D0, D1, D4 lost.
.sc3:   moveq #2,d1
.s3:    move.l (a1),d4
        bsr.s .mul
        move.l d4,(a1)+
        dbra d1,.s3
        rts

        machine 68000
