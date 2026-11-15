; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; tspan: one span of a textured surface into the chunky view.

        machine 68020

; A0 = first byte, D0 = x, D1 = pixels (1-320), D2 = view row, A3 =
; surface. All registers kept. Pass 1: the fade k and u, v (x 2^p) at
; each chunk end (every 16 pixels and the span end) into tx_bnd, u and v
; only where a chunk next to it may be textured (TL_MASK: only the ends
; next to a chunk with markers); pass 2: each chunk textured, flat or as
; haze.
; Fade: k with footprint f < 2^k units (walls: texels) per pixel, f =
; h (|GX| + |GY| + G / 160) / G^2 (the larger step, roughly). With GX = 0
; G is the same along the span, so k is computed once.
tspan:
        movem.l d0-d7/a0-a6,-(sp)
        lea tx_loc(pc),a4
        ext.l d0
        ext.l d2
        move.w d1,TL_LEFT(a4)
        move.l TS_GX(a3),d5
        muls.l d0,d5
        move.l TS_GY(a3),d3
        muls.l d2,d3
        add.l d3,d5
        add.l TS_GA(a3),d5              ; G
        move.l TS_UX(a3),d6
        muls.l d0,d6
        move.l TS_UY(a3),d3
        muls.l d2,d3
        add.l d3,d6
        add.l TS_UA(a3),d6              ; D . u
        move.l TS_VX(a3),d7
        muls.l d0,d7
        move.l TS_VY(a3),d3
        muls.l d2,d3
        add.l d3,d7
        add.l TS_VA(a3),d7              ; D . v
        tst.l TS_GX(a3)
        bne.s .steps
        tst.b TS_MESH(a3)
        beq .row
.steps: moveq #5,d3                     ; k from which the chunks on both
        tst.b TS_MESH(a3)               ; sides are flat (mesh: haze), so
        beq.s .kt                       ; u and v are not needed
        moveq #7,d3                     ; trees, crowd: u and v up to k 6,
        cmpi.b #2,TS_MESH(a3)           ; no haze
        beq.s .kt
        cmpi.b #3,TS_MESH(a3)
        beq.s .kt
        cmpi.b #5,TS_MESH(a3)           ; guardrails: no haze
        beq.s .kt
        cmpi.b #4,TS_MESH(a3)
        bne.s .hzk
        move.w tx_fk(pc),d3             ; materials: flat from their k
        bra.s .kt
.hzk:   move.w d2,d4                    ; haze: 1 pixel in 4 on a diamond
        andi.w #1,d4                    ; lattice, (x + 2 (row & 1)) & 3 = 0;
        add.w d4,d4                     ; chunks start 16 pixels apart
        add.w d0,d4
        neg.w d4
        andi.w #3,d4
        move.w d4,TL_HZ(a4)
        moveq #2,d3
.kt:    move.w d3,TL_KT(a4)
        moveq #32,d0
        sub.w TS_FP(a3),d0
        move.w d0,TL_C(a4)
        move.l TS_GX(a3),d0             ; steps for 16 pixels
        lsl.l #TCHS,d0
        movea.l d0,a1
        move.l TS_UX(a3),d0
        lsl.l #TCHS,d0
        movea.l d0,a2
        move.l TS_VX(a3),d0
        lsl.l #TCHS,d0
        movea.l d0,a6
        move.w d1,d4
        moveq #TCH-1,d0
        and.w d4,d0
        move.w d0,TL_N(a4)              ; pixels of a last, shorter chunk
        lsr.w #TCHS,d4                  ; chunks of TCH pixels
        lea tx_bnd(pc),a5
        tst.b TL_MASK(a4)
        bne .mb1
        bra.s .b1
.adv:   add.l a1,d5
        add.l a2,d6
        add.l a6,d7
        lea TB_SIZE(a5),a5
.b1:    BEND
        dbra d4,.adv
.last:  move.w TL_N(a4),d0              ; the last chunk, shorter
        beq .pass2
        bsr .lstep
        bra .b1
        ; TL_MASK: the class of each chunk (0 covered, 1 markers only, 2
        ; some markers) with its left end; an end between two covered
        ; chunks is not computed.
.mb1:   move.w TL_N(a4),d2              ; chunk length: TCH while whole
        tst.w d4                        ; chunks are left, then TL_N (0:
        beq.s .mbn                      ; none)
        moveq #TCH,d2
.mbn:   moveq #0,d0
        tst.w d2
        beq.s .mbc
        MCLASS .mba,.mbp
        bra.s .mbc
.mba:   moveq #1,d0
        bra.s .mbc
.mbp:   moveq #2,d0
.mbc:   move.w d0,10(a5)
        or.w -2(a5),d0                  ; and the chunk before
        beq.s .mbs
        BEND
.mbs:   dbra d4,.madv
        move.w TL_N(a4),d0
        beq.s .mp2
        bsr.s .lstep
        bra .mb1
.madv:  add.l a1,d5
        add.l a2,d6
        add.l a6,d7
        lea TB_SIZE(a5),a5
        lea TCH(a0),a0
        bra .mb1
.mp2:   movea.l 32(sp),a0               ; the span's start
        bra.s .pass2
        ; To the end of the last, shorter chunk of D0 pixels.
.lstep: clr.w TL_N(a4)
        moveq #0,d4
        ext.l d0
        move.l TS_GX(a3),d1
        muls.l d0,d1
        add.l d1,d5
        move.l TS_UX(a3),d1
        muls.l d0,d1
        add.l d1,d6
        move.l TS_VX(a3),d1
        muls.l d0,d1
        add.l d1,d7
        lea TB_SIZE(a5),a5
        rts
.pass2: movea.l TS_TEX(a3),a1
        lea tx_bnd(pc),a5
        tst.b TL_MASK(a4)
        bne .mchunk
.chunk: moveq #TCH,d7
        cmp.w TL_LEFT(a4),d7
        ble.s .n16
        move.w TL_LEFT(a4),d7
.n16:   sub.w d7,TL_LEFT(a4)
        move.w 8(a5),d0                 ; k: the larger of the two ends
        cmp.w TB_SIZE+8(a5),d0
        bcc.s .kmax
        move.w TB_SIZE+8(a5),d0
.kmax:  tst.b TS_MESH(a3)
        beq.s .opq
        cmpi.b #2,TS_MESH(a3)
        beq .tree
        cmpi.b #3,TS_MESH(a3)
        beq .crowd
        cmpi.b #4,TS_MESH(a3)
        beq .face
        cmpi.b #5,TS_MESH(a3)
        beq .grd
        cmp.w #2,d0                     ; mesh: wires below 2 texels a pixel
        bcc .haze
        bra.s .uv
.opq:   cmp.w #5,d0
        bcc .flat
        movea.l TS_LUT(a3),a2
        lsl.w #8,d0
        adda.w d0,a2
.uv:    TUV
        tst.b TS_MESH(a3)
        bne .mesh
        moveq #0,d2                     ; x 16 bytes
        jmp .px(pc,d0.w)
.px:    rept TCH
        TPX
        endr
        bra .next
.mesh:  lea TCH(a0),a0                  ; A0 to the chunk end, copy c
        suba.w d2,a0                    ; writes at c - 16
        add.w d2,d2
        add.w d2,d0                     ; x 18 bytes
        jmp .mpx(pc,d0.w)
.mpx:
MPX     set -TCH
        rept TCH                        ; colour or a hole (bit 7)
        move.w d3,d0
        move.b d1,d0
        move.b (a1,d0.w),d2
        bmi.s *+6
        move.b d2,MPX(a0)
        add.l d5,d3
        addx.b d7,d1
MPX     set MPX+1
        endr
        bra .next
        ; Trees (mesh mode 2): the leaves of the mip level for k (tr_reg,
        ; the coarsest from k 3 on), texel 0 a hole that keeps what is
        ; behind, levels through TS_LUT; flat at k 7 (far or edge on).
        ; The crowd (mode 3) the same with its levels (cr_reg), no holes;
        ; the materials (mode 4, tex_face) too, flat from their k (TL_KT).
.crowd: cmp.w #7,d0
        bcc .cfar
        lea cr_reg(pc),a2
        bra.s .trk
.face:  cmp.w TL_KT(a4),d0
        bcc .flat
        lea cr_reg(pc),a2
        bra.s .tk3
.tree:  lea tr_reg(pc),a2
.trk:   cmp.w #7,d0
        bcc .flat
.tk3:   cmp.w #3,d0
        bls.s .tr3
        moveq #3,d0
.tr3:   movea.l TS_TEX(a3),a1
        adda.l (a2,d0.w*4),a1
        movea.l TS_LUT(a3),a2
        TUV
        lea TCH(a0),a0                  ; as .mesh
        suba.w d2,a0
        lsl.w #2,d2
        add.w d2,d0                     ; x 20 bytes
        moveq #0,d2
        jmp .tpx(pc,d0.w)
.tpx:
TPXO    set -TCH
        rept TCH
        move.w d3,d0
        move.b d1,d0
        move.b (a1,d0.w),d2
        beq.s *+8
        move.b (a2,d2.w),TPXO(a0)
        add.l d5,d3
        addx.b d7,d1
TPXO    set TPXO+1
        endr
        bra .next
        ; The far crowd (k 7, u and v unknown): its coarsest level read at
        ; a hash of the pixel's address, noise in screen space like the
        ; game's pattern.
.cfar:  movea.l TS_TEX(a3),a1
        adda.l cr_reg+12(pc),a1
        movea.l TS_LUT(a3),a2
        move.w a0,d1
        mulu.w #9,d1
        moveq #9,d3
        moveq #0,d2
        subq.w #1,d7
.cf:    move.b (a1,d1.w),d2
        move.b (a2,d2.w),(a0)+
        add.w d3,d1
        dbra d7,.cf
        bra .next
        ; Guardrails (mode 5): the mesh below k GR_KFAR; farther the beams
        ; only (u fixed between the posts), nothing at k 7 (u and v not
        ; known; the game's rail lines stay).
.grd:   cmp.w #7,d0
        bcc.s .gsk
        cmp.w #GR_KFAR,d0
        bcs .uv
        TUV
        moveq #8,d1
        andi.l #$ffff,d5                ; no u step
        moveq #0,d7
        bra .mesh
.gsk:   adda.w d7,a0
        bra .next
.haze:  move.w TL_HZ(a4),d0             ; far mesh (see .steps)
        moveq #FENCE_COL,d1
        cmp.w #TCH,d7
        bne.s .hz
        move.b d1,(a0,d0.w)
        move.b d1,4(a0,d0.w)
        move.b d1,8(a0,d0.w)
        move.b d1,12(a0,d0.w)
        bra.s .hzd
.hz:    cmp.w d7,d0
        bcc.s .hzd
        move.b d1,(a0,d0.w)
        addq.w #4,d0
        bra.s .hz
.hzd:   adda.w d7,a0
        bra.s .next
.flat:  moveq #0,d0
        move.b TS_FLAT(a3),d0
        cmp.w #TCH,d7
        bne.s .flb
        mulu.l #$01010101,d0            ; a whole chunk: longs
        move.l d0,(a0)+
        move.l d0,(a0)+
        move.l d0,(a0)+
        move.l d0,(a0)+
        bra.s .next
.flb:   subq.w #1,d7
.fl:    move.b d0,(a0)+
        dbra d7,.fl
.next:  lea TB_SIZE(a5),a5
        tst.w TL_LEFT(a4)
        bne .chunk
        movem.l (sp)+,d0-d7/a0-a6
        rts
        ; TL_MASK (gnd_flush, the ground after the 3D view, tx_gnd): a chunk
        ; without a marker is covered, one of markers only is drawn whole, in
        ; the others only the markers get the texture or the flat colour;
        ; the pixels straight from the ground colours of fade k (tx_gsh).
.mchunk:
        moveq #TCH,d7
        cmp.w TL_LEFT(a4),d7
        ble.s .m16
        move.w TL_LEFT(a4),d7
.m16:   sub.w d7,TL_LEFT(a4)
        move.w 10(a5),d0                ; class (pass 1)
        beq .mcov
        subq.w #1,d0
        bne .mpart
.mall:  move.w 8(a5),d0                 ; k: the larger of the two ends
        cmp.w TB_SIZE+8(a5),d0
        bcc.s .ma
        move.w TB_SIZE+8(a5),d0
.ma:    cmp.w #5,d0
        bcc .mflat
        swap d0                         ; the ground colours of fade k
        clr.w d0
        movea.l tx_gsh(pc),a1
        adda.l d0,a1
        TUV
        lsl.w #2,d2
        sub.w d2,d0                     ; x 12 bytes
        jmp .apx(pc,d0.w)
.apx:   rept TCH
        TPXG
        endr
        bra .mnext
.mpart: move.w 8(a5),d0
        cmp.w TB_SIZE+8(a5),d0
        bcc.s .mp
        move.w TB_SIZE+8(a5),d0
.mp:    cmp.w #5,d0
        bcc .mpflat
        swap d0
        clr.w d0
        movea.l tx_gsh(pc),a1
        adda.l d0,a1
        TUV
        add.w d2,d2
        add.w d2,d0                     ; x 18 bytes
        moveq #GND_MARK,d2
        jmp .gpx(pc,d0.w)
.gpx:   rept TCH
        GPXG
        endr
        bra.s .mnext
.mflat: moveq #0,d0
        move.b TS_FLAT(a3),d0
        cmp.w #TCH,d7
        bne.s .mflb
        mulu.l #$01010101,d0            ; a whole chunk: longs
        move.l d0,(a0)+
        move.l d0,(a0)+
        move.l d0,(a0)+
        move.l d0,(a0)+
        bra.s .mnext
.mflb:  subq.w #1,d7
.mfl:   move.b d0,(a0)+
        dbra d7,.mfl
        bra.s .mnext
.mcov:  adda.w d7,a0                    ; covered
        bra.s .mnext
.mpflat:
        move.b TS_FLAT(a3),d0
        subq.w #1,d7
.mpf:   cmpi.b #GND_MARK,(a0)+
        bne.s .mps
        move.b d0,-1(a0)
.mps:   dbra d7,.mpf
.mnext: lea TB_SIZE(a5),a5
        tst.w TL_LEFT(a4)
        bne .mchunk
        movem.l (sp)+,d0-d7/a0-a6
        rts
        ; G the same along the span (dG/dx = 0: the ground and the road
        ; polygons without roll), so u and v are linear in x: exact at the
        ; start, steps per 16 pixels from one division each, every chunk of
        ; 16 pixels starts from the summed steps (within 1 / 2^p unit per
        ; chunk of the exact value). k and flat for the whole span.
.row:   move.l d5,d0
        asr.l #8,d0                     ; g
        cmp.l #TX_GMIN,d0
        blt .rflat
        move.l d6,d1
        asr.l #8,d1
        muls.l TS_HS(a3),d1
        divs.l d0,d1
        add.l TS_CXP(a3),d1
        lsl.l #8-TEX_SHIFT,d1
        movea.l d1,a5                   ; u
        move.l d7,d1
        asr.l #8,d1
        muls.l TS_HS(a3),d1
        divs.l d0,d1
        add.l TS_CYP(a3),d1
        lsl.l #8-TEX_SHIFT,d1
        movea.l d1,a6                   ; v
        move.l TS_UX(a3),d1
        lsl.l #4,d1
        asr.l #8,d1
        muls.l TS_HS(a3),d1
        divs.l d0,d1
        lsl.l #8-TEX_SHIFT,d1
        move.l d1,TL_U16(a4)
        move.l TS_VX(a3),d1
        lsl.l #4,d1
        asr.l #8,d1
        muls.l TS_HS(a3),d1
        divs.l d0,d1
        lsl.l #8-TEX_SHIFT,d1
        move.l d1,TL_V16(a4)
        asr.l #4,d0                     ; k as in pass 1
        move.l d0,d1
        mulu.w #410,d1
        clr.w d1
        swap d1
        add.w TS_GY12(a3),d1
        muls.l TS_HS(a3),d1
        mulu.w d0,d0
        lsr.l #8,d0
        lsr.l #4,d0
        divu.l d0,d1
        move.w TS_FP(a3),d2
        lsr.l d2,d1
        bfffo d1{0:32},d2
        moveq #32,d3
        sub.w d2,d3
        cmp.w #5,d3
        bcc .rflat
        movea.l TS_LUT(a3),a2
        lsl.w #8,d3
        adda.w d3,a2
        movea.l TS_TEX(a3),a1
        move.w TS_P(a3),d0
        addq.w #4,d0
        move.l TL_U16(a4),d5
        asr.l d0,d5                     ; per pixel, 8.8 texels
        move.l TL_V16(a4),d6
        asr.l d0,d6
        move.w d5,d7
        lsr.w #8,d7
        lsl.w #8,d5                     ; the steps as in TUV
        swap d5
        move.w d6,d5
        moveq #0,d6
        move.w TS_P(a3),d6              ; for RANCH: p and the u step per
        movea.l TL_U16(a4),a3           ; 16 pixels (the surface is done)
        tst.b TL_MASK(a4)
        bne .rmset
        ; Chunks of 16 pixels (D2, the last one D2 = the rest, TL_LEFT
        ; counted down by 16 and cleared at the last). D2.w stays below 256
        ; for TPX's colour index.
.rc:    moveq #16,d2
        sub.w d2,TL_LEFT(a4)
        bgt.s .r16
        add.w TL_LEFT(a4),d2
        ble .rend
        clr.w TL_LEFT(a4)
.r16:   RANCH
        moveq #16,d0
        sub.w d2,d0
        beq.s .rpx
        move.w d0,d2
        lsl.w #4,d0                     ; x 16 bytes
        jmp .rpx(pc,d0.w)
.rpx:   rept 16
        TPX
        endr
        bra .rc
.rflat: move.b TS_FLAT(a3),d5
        tst.b TL_MASK(a4)
        bne .rmfset
        move.w TL_LEFT(a4),d7
.rfa:   move.w a0,d1                    ; bytes up to a long boundary
        andi.w #3,d1
        beq.s .rfl
        move.b d5,(a0)+
        subq.w #1,d7
        bne.s .rfa
        bra.s .rend
.rfl:   move.b d5,d0                    ; then longs
        lsl.w #8,d0
        move.b d5,d0
        move.w d0,d1
        swap d0
        move.w d1,d0
        move.w d7,d1
        lsr.w #2,d1
        bra.s .rfli
.rfll:  move.l d0,(a0)+
.rfli:  dbra d1,.rfll
        andi.w #3,d7
        bra.s .rfbi
.rfb:   move.b d5,(a0)+
.rfbi:  dbra d7,.rfb
.rend:  movem.l (sp)+,d0-d7/a0-a6
        rts
        ; TL_MASK (only the ground, tx_gnd: colour 7, r 0): per chunk as
        ; .mchunk, the pixels straight from the ground colours of fade k
        ; (tx_gsh, the same as texture and offset table), A2 the marker.
.rmset: lsl.l #8,d3                     ; k x 65536
        movea.l tx_gsh(pc),a1
        adda.l d3,a1
        movea.l #GND_MARK*$01010101,a2
.rm:    moveq #16,d2                    ; a chunk of 16 with more after it
        sub.w d2,TL_LEFT(a4)
        ble .rml
        cmpa.l (a0),a2
        bne .rmc
        cmpa.l 4(a0),a2
        bne .rmc
        cmpa.l 8(a0),a2
        bne .rmc
        cmpa.l 12(a0),a2
        bne .rmc
        RANCH                           ; all markers
.rmpx:  rept 16
        TPXG
        endr
        bra .rm
.rml:   add.w TL_LEFT(a4),d2            ; the last chunk
        ble .rend
        clr.w TL_LEFT(a4)
        MCLASS2 .rmall,.rmpart
        bra.s .rmcov
.rmc:   move.l a2,d3
        moveq #15,d1
.rms:   cmp.b (a0,d1.w),d3
        dbeq d1,.rms
        beq.s .rmpart
.rmcov: adda.w d2,a0                    ; covered
        adda.l a3,a5
        adda.l TL_V16(a4),a6
        bra .rm
.rmall: RANCH
        moveq #16,d0
        sub.w d2,d0
        lsl.w #2,d0
        move.w d0,d2
        add.w d0,d0
        add.w d2,d0                     ; x 12 bytes
        jmp .rmpx(pc,d0.w)
.rmpart:
        RANCH
        moveq #16,d0
        sub.w d2,d0
        move.w d0,d2
        lsl.w #4,d0
        add.w d2,d2
        add.w d2,d0                     ; x 18 bytes
        moveq #GND_MARK,d2
        jmp .rgpx(pc,d0.w)
.rgpx:  rept 16
        GPXG
        endr
        bra .rm
.rmfset:
        movea.l #GND_MARK*$01010101,a2
.rmf:   moveq #16,d2
        sub.w d2,TL_LEFT(a4)
        bgt.s .rmf16
        add.w TL_LEFT(a4),d2
        ble .rend
        clr.w TL_LEFT(a4)
.rmf16: MCLASS2 .rmfa,.rmfp
        adda.w d2,a0                    ; covered
        bra.s .rmf
.rmfa:  subq.w #1,d2
.rmfb:  move.b d5,(a0)+
        dbra d2,.rmfb
        bra.s .rmf
.rmfp:  subq.w #1,d2
.rmfq:  cmpi.b #GND_MARK,(a0)+
        bne.s .rmfs
        move.b d5,-1(a0)
.rmfs:  dbra d2,.rmfq
        bra.s .rmf

        machine 68000
