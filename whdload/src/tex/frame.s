; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Per frame values of the textures (tex_frame), the fraction of the camera
; position (cam_view) and the setup of a textured surface (tsurf_init).

        machine 68020

; After view_setup: world up in camera space (tx_up), D for the frame and
; the road plane: world z = 0, in
; the cockpit view 15 units below the camera (the camera height on the
; straights; in the turns the game's camera is 90 units high and its road
; polygons do not form one plane).
; After view_setup: cam_f = the fraction of view_cam_pos x, y, z in 1/256
; unit (cam_fr of write_snapshot when view_cam_pos holds the blended
; position it belongs to, else 0; used once) and its offset in camera
; space: cam_m = view_matrix . cam_f / 256 as the transform sums (depth,
; x', y', 2^14 x unit), cam_mt the same for tx_m (the halving undone),
; cam_c = depth, x', true y x 256 (words). All registers kept.
cam_view:
        movem.l d0-d3/a0-a3,-(sp)
        lea cam_fr(pc),a1
        lea cam_f(pc),a0
        clr.l (a0)
        clr.w 4(a0)
        move.l G_CAM_POS,d0
        cmp.l 6(a1),d0                  ; cam_fi
        bne.s .z
        move.w G_CAM_POS+4,d0
        cmp.w 10(a1),d0
        bne.s .z
        move.l (a1),(a0)
        move.w 4(a1),4(a0)
.z:     clr.l (a1)
        clr.w 4(a1)
        lea G_VIEW_MATRIX,a1
        lea cam_m(pc),a2
        lea cam_c(pc),a3
        moveq #2,d3
.j:     move.w (a1),d0
        muls.w (a0),d0
        move.w 6(a1),d1
        muls.w 2(a0),d1
        add.l d1,d0
        move.w 12(a1),d1
        muls.w 4(a0),d1
        add.l d1,d0
        add.l #128,d0
        asr.l #8,d0
        move.l d0,(a2)                  ; cam_m
        move.l d0,d1
        asr.l #6,d1
        move.w d1,(a3)+                 ; cam_c (as the records: halved
        tst.w G_MATRIX_HALVED           ; with the matrix)
        beq.s .t
        add.l d0,d0
.t:     move.l d0,12(a2)                ; cam_mt
        addq.l #4,a2
        addq.l #2,a1
        dbra d3,.j
        move.l -4(a2),d0                ; y' x 256 = sum >> 5, true y:
        asr.l #5,d0                     ; x TX_YK / 32768 as VLOAD
        muls.w #TX_YK,d0
        moveq #15,d1
        asr.l d1,d0
        move.w d0,-(a3)
        movem.l (sp)+,d0-d3/a0-a3
        rts

; D0.w = the groups switched off (opt_off, a view begins): when it has
; changed, tex_on and tex_on2 from it, the sky flat or not, and the colours
; 16-255 written again. tex_on and tex_on2 are left alone otherwise.
opt_apply:
        movem.l d0-d3/a0-a1,-(sp)
        lea opt_cur(pc),a0
        cmp.w (a0),d0
        beq.s .same
        move.w d0,(a0)
        moveq #-1,d1                    ; tex_on
        moveq #15,d2                    ; tex_on2
        lea opt_map(pc),a1
        moveq #7,d3
.g:     lsr.w #1,d0
        bcc.s .on
        and.b (a1),d1
        and.b 1(a1),d2
.on:    addq.l #2,a1
        dbra d3,.g
        lea tex_on(pc),a1
        move.b d1,(a1)
        move.b d2,tex_on2-tex_on(a1)
        lsr.w #1,d0                     ; bit 8: the sky
        scs sky_flat-opt_cur(a0)
        lsr.w #1,d0                     ; bit 9: the sparks
        scs sp_off-opt_cur(a0)
        lsr.w #1,d0                     ; bit 10: the track in the mirrors
        scs mir_off-opt_cur(a0)
        lea aga_dirty(pc),a1
        st (a1)
.same:  movem.l (sp)+,d0-d3/a0-a1
        rts
opt_map:                                ; per group: tex_on and tex_on2 kept
        dc.b %11110110,15              ; asphalt and ground, grass
        dc.b %11111001,15              ; walls, fences
        dc.b %11101111,15              ; trees
        dc.b %10011111,15              ; crowd, grandstand roofs
        dc.b %01111111,15              ; buildings
        dc.b $ff,%1100                  ; turn guardrails, posts
        dc.b $ff,%1011                  ; 3D cars
        dc.b $ff,%0111                  ; team liveries

; The frame values are made when any texture, the guardrails or the posts
; are on (tx_ok); asphalt and ground need tex_on bit 0 (tex_class and the
; ground surface below).
tex_frame:
        movem.l d0-d7/a0-a3,-(sp)
        lea tx_ok(pc),a0
        sf (a0)
        clr.w tx_fn-tx_ok(a0)
        clr.w gnd_n-tx_ok(a0)
        btst #0,aga_on(pc)
        beq .out
        tst.b tex_on(pc)
        bne.s .any
        moveq #3,d0
        and.b tex_on2(pc),d0
        beq .out
.any:
        lea G_VIEW_MATRIX+12,a1         ; world up: the z column (depth, x',
        lea tx_up(pc),a2                ; true y, 2.14)
        move.w (a1)+,(a2)+
        move.w (a1)+,(a2)+
        move.w (a1),d0
        muls.w #TX_KINV,d0
        add.l d0,d0
        swap d0
        move.w d0,(a2)
        tst.w G_MATRIX_HALVED
        beq.s .uf
        lea tx_up(pc),a2
        asl.w (a2)+
        asl.w (a2)+
        asl.w (a2)
.uf:    lea G_VIEW_MATRIX,a1
        lea tx_m(pc),a2
        moveq #8,d1
.cp:    move.w (a1)+,d0
        tst.w G_MATRIX_HALVED
        beq.s .f
        add.w d0,d0
.f:     move.w d0,(a2)+
        dbra d1,.cp
        lea tx_m(pc),a1
        lea tx_da(pc),a2
        bsr.s .axis                     ; world x
        addq.l #6,a1
        bsr.s .axis                     ; world y
        addq.l #6,a1
        bsr.s .axis                     ; world z
        lea tx_gnd(pc),a3
        movem.w tx_up(pc),d0-d2
        bsr .hz                         ; ground: world z = 0
        btst #0,G_VIEW_FLAGS            ; cockpit: the road 15 units below
        beq.s .h
        moveq #15,d3
        moveq #0,d4
.h:     moveq #7,d5
        movea.l tx_lut(pc),a0
        bsr tsurf_init
        btst #0,tex_on(pc)
        bne.s .gon
        clr.l TS_HS(a3)                 ; no ground texture
.gon:   lea tx_grs(pc),a3               ; grass: world z = 0
        bsr .hz
        moveq #5,d5
        lea 3*2048(a0),a0
        bsr tsurf_init
        move.l tx_grtex(pc),TS_TEX(a3)
        addq.w #1,TS_P(a3)              ; 4 units per texel: u, v and the
        addq.w #1,TS_FP(a3)             ; footprint halved
        lea tx_ok(pc),a0
        st (a0)
.out:   movem.l (sp)+,d0-d7/a0-a3
        rts
; D3 = the camera's height above world z = 0 x 2^D4 (D4 = 8).
.hz:    moveq #0,d4
        move.w cam_f+4(pc),d4
        move.w G_CAM_POS+4,d3
        ext.l d3
        asl.l #8,d3
        add.l d4,d3
        moveq #8,d4
        rts
; A1 = depth, x', y' k of one world axis: D at (0, 0), per pixel, per row.
.axis:  move.w (a1),d0
        ext.l d0
        moveq #10,d3
        asl.l d3,d0                     ; depth axis x 2^10
        move.w 2(a1),d1
        ext.l d1
        move.l d1,d2
        muls.l #65331,d1
        asr.l #6,d1                     ; x' axis x 2^10 x 159.5 / 160
        sub.l d1,d0
        muls.l #52429,d2
        asr.l #8,d2
        asr.l #5,d2                     ; x' axis x 2^10 / 160
        move.w 4(a1),d1
        muls.w #TX_KINV,d1
        add.l d1,d1
        swap d1
        ext.l d1                        ; up axis (the y' row carries k)
        move.l d1,d3
        muls.l #30226,d1
        asr.l #6,d1                     ; up axis x 2^10 x 61.5 / 133.34
        add.l d1,d0
        muls.l #31456,d3
        asr.l #8,d3
        asr.l #4,d3
        neg.l d3                        ; - up axis x 2^10 / 133.34
        move.l d0,(a2)
        move.l d2,12(a2)
        move.l d3,24(a2)
        addq.l #4,a2
        rts

; A3 = surface: D0-D2 = unit normal (depth, x', true y, 2.14, longs)
; towards the camera, D3 = h x 2^D4 (long), A0 = offset table, D5 = flat
; colour; u, v = world x, y, asphalt. TS_HS = 0 when h does not fit.
tsurf_init:
        movem.l d0-d7/a1,-(sp)
        move.b d5,TS_FLAT(a3)
        clr.b TS_MESH(a3)
        move.l a0,TS_LUT(a3)
        move.l d0,d5
        moveq #10,d6
        asl.l d6,d5
        neg.l d5                        ; - n0 x 2^10
        move.l d1,d6
        muls.l #65331,d6
        asr.l #6,d6
        add.l d6,d5                     ; - n1 x 2^10 x (-159.5 / 160)
        move.l d2,d6
        muls.l #30226,d6
        asr.l #6,d6
        sub.l d6,d5                     ; - n2 x 2^10 x 61.5 / 133.34
        move.l d5,TS_GA(a3)
        move.l d1,d6
        muls.l #52429,d6
        asr.l #8,d6
        asr.l #5,d6
        neg.l d6
        move.l d6,TS_GX(a3)
        bpl.s .gx
        neg.l d6
.gx:    move.l d6,d7
        move.l d2,d6
        muls.l #31456,d6
        asr.l #8,d6
        asr.l #4,d6
        move.l d6,TS_GY(a3)
        bpl.s .gp
        neg.l d6
.gp:    add.l d7,d6
        moveq #12,d7
        lsr.l d7,d6
        move.w d6,TS_GY12(a3)
        lea tx_da(pc),a1
        move.l (a1),TS_UA(a3)
        move.l 12(a1),TS_UX(a3)
        move.l 24(a1),TS_UY(a3)
        move.l 4(a1),TS_VA(a3)
        move.l 16(a1),TS_VX(a3)
        move.l 28(a1),TS_VY(a3)
        move.l tx_tex(pc),TS_TEX(a3)
        clr.l TS_HS(a3)
        tst.l d3
        ble.s .off
.lo:    cmp.l #4096,d3
        bcc.s .hi
        add.l d3,d3
        addq.w #1,d4
        bra.s .lo
.hi:    cmp.l #8192,d3
        bcs.s .fit
        lsr.l #1,d3
        subq.w #1,d4
        bra.s .hi
.fit:   tst.w d4
        bmi.s .off
        cmp.w #12,d4
        bgt.s .off
        move.l d3,TS_HS(a3)
        move.w d4,TS_P(a3)
        move.w d4,TS_FP(a3)
        move.w G_CAM_POS,d0             ; camera u, v x 2^p
        ext.l d0
        lsl.l d4,d0
        moveq #0,d1
        move.w cam_f(pc),d1
        lsl.l d4,d1
        asr.l #8,d1
        add.l d1,d0
        move.l d0,TS_CXP(a3)
        move.w G_CAM_POS+2,d0
        ext.l d0
        lsl.l d4,d0
        moveq #0,d1
        move.w cam_f+2(pc),d1
        lsl.l d4,d1
        asr.l #8,d1
        add.l d1,d0
        move.l d0,TS_CYP(a3)
.off:   movem.l (sp)+,d0-d7/a1
        rts

        machine 68000
