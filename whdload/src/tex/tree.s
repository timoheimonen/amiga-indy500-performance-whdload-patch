; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Leaves on the dither polygons of the trees (tex_tree).

        machine 68020

; c_dither_fill: a dither polygon of colour 5 or 10 whose corners are track
; vertices in a vertical plane (the trees: two crossed leaf shapes each)
; gets leaves instead of the checker (tex_on bit 4): tx_psurf with the
; leaf texture laid over the polygon's extent (u along the plane, v =
; world z, 124 x 124 texels from texel 2), mirrored for the polygons of 6
; corners, drawn by tspan in mesh mode 2. tr_on set when so.
tex_tree:
        movem.l d0-d7/a0-a6,-(sp)
        lea tr_on(pc),a0
        sf (a0)
        btst #4,tex_on(pc)
        beq .no
        btst #0,tx_ok(pc)
        beq .no
        moveq #15,d0
        and.b ctab(pc),d0
        lea tr_lut5(pc),a2
        cmp.b #5,d0
        beq.s .col
        lea tr_lut10(pc),a2
        cmp.b #10,d0
        bne .no
.col:   lea pe_n(pc),a0
        cmpi.w #3,(a0)
        bcs .no
        tst.b pe_bad-pe_n(a0)
        bne .no
        tst.b pe_rel-pe_n(a0)
        bne .no
        move.l a2,-(sp)
        bsr tw_plane
        movea.l (sp)+,a2
        bne .no
        move.w tx_wnu+4(pc),d0          ; vertical: |n z| below 0.2
        bpl.s .nz
        neg.w d0
.nz:    cmp.w #3277,d0
        bcc .no
        lea tr_ext(pc),a0               ; extent over the corners: u axis
        move.l #$7fffffff,d0            ; . (x, y) x 2^14 and z
        move.l d0,(a0)
        move.l d0,8(a0)
        not.l d0
        move.l d0,4(a0)
        move.l d0,12(a0)
        movea.l pe_base(pc),a1
        lea G_SHAPE_BASE,a3
        lea G_COORD_POOL,a4
        lea pe_vl(pc),a5
        move.w pe_n(pc),d7
        subq.w #1,d7
.cn:    move.w (a5)+,d0                 ; vertex_buf offset
        moveq #0,d1
        move.w (a1,d0.w),d1             ; its source record
        move.l d1,d2
        sub.l #TRACK_VTX_REL,d2
        bcs .no
        cmp.l #8*TRACK_VTX_N,d2
        bcc .no
        andi.w #7,d2
        bne .no
        cmp.w (a3,d1.l),d0              ; transformed this frame
        bne .no
        move.w 2(a3,d1.l),d2            ; world x, y, z from coord_pool
        move.w (a4,d2.w),d3
        add.w d3,d3
        asr.w #1,d3
        muls.w tx_weu(pc),d3
        move.w 4(a3,d1.l),d2
        move.w (a4,d2.w),d4
        add.w d4,d4
        asr.w #1,d4
        muls.w tx_weu+2(pc),d4
        add.l d4,d3                     ; u x 2^14
        move.w 6(a3,d1.l),d2
        move.w (a4,d2.w),d4
        add.w d4,d4
        asr.w #1,d4
        ext.l d4                        ; z
        cmp.l (a0),d3
        bge.s .e1
        move.l d3,(a0)
.e1:    cmp.l 4(a0),d3
        ble.s .e2
        move.l d3,4(a0)
.e2:    cmp.l 8(a0),d4
        bge.s .e3
        move.l d4,8(a0)
.e3:    cmp.l 12(a0),d4
        ble.s .e4
        move.l d4,12(a0)
.e4:    dbra d7,.cn
        move.l 4(a0),d0                 ; S u, S v: 124 texels over the
        sub.l (a0),d0                   ; extent (texels per unit x 256)
        moveq #14,d1
        asr.l d1,d0
        cmp.l #32,d0
        blt .no
        cmp.l #4000,d0
        bgt .no
        move.l #124*256,d5
        divu.w d0,d5
        andi.l #$ffff,d5
        move.l 12(a0),d0
        sub.l 8(a0),d0
        cmp.l #32,d0
        blt .no
        cmp.l #4000,d0
        bgt .no
        move.l #124*256,d6
        divu.w d0,d6
        andi.l #$ffff,d6
        lea tx_psurf(pc),a3
        move.w TS_P(a3),d7              ; p (0-12)
        move.l d5,d3                    ; u from the extent's start, or
        moveq #13,d1                    ; mirrored (6 corners) from its
        sub.w d7,d1                     ; end
        btst #0,pe_n+1(pc)
        bne.s .un
        neg.l d3
        move.l 4(a0),d0
        bra.s .uo
.un:    move.l (a0),d0
.uo:    asr.l d1,d0                     ; x 2^(p + 1), as TS_CXP
        move.l TS_CXP(a3),d4
        sub.l d0,d4
        bsr.s .mul
        bsr .marg
        move.l d4,TS_CXP(a3)
        lea TS_UA(a3),a1
        bsr .sc3
        move.l d6,d3                    ; v from the lowest z
        move.l 8(a0),d0
        move.w d7,d1
        addq.w #1,d1
        lsl.l d1,d0
        move.l TS_CYP(a3),d4
        sub.l d0,d4
        bsr.s .mul
        bsr.s .marg
        move.l d4,TS_CYP(a3)
        lea TS_VA(a3),a1
        bsr.s .sc3
        move.l d5,d0                    ; footprint: k = mip level (k 0:
        cmp.l d6,d0                     ; below 2 texels a pixel, k 1: 2-4
        bcc.s .sm                       ; ...), 2 above walls (p - 1 at S
        move.l d6,d0                    ; 256): p + 9 - log2 of the larger
.sm:    mulu.w #181,d0                  ; S, rounded
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
        move.l a2,TS_LUT(a3)
        move.b 8(a2),TS_FLAT(a3)        ; far: flat, level 8
        move.l tx_trtex(pc),TS_TEX(a3)
        move.b #2,TS_MESH(a3)
        lea tr_on(pc),a0
        st (a0)
.no:    movem.l (sp)+,d0-d7/a0-a6
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
; D4 + 2 texels (2^(p + 2)). D0 lost.
.marg:  moveq #4,d0
        lsl.l d7,d0
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
