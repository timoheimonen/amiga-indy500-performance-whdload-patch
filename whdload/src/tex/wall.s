; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Wall texture: the plane of a wall from the world coordinates of its corners
; (tex_wall, tw_plane).

        machine 68020

; poly_plane, colour 15 within 0.2 of vertical: when its three corners are
; track vertices, tx_psurf gets its plane from their world coordinates
; (the same every frame), u along the wall and v = world z, both doubled
; (1 unit per wall texel), and tx_mode 3.
tex_wall:
        movem.l d0-d7/a0-a4,-(sp)
        btst #1,tex_on(pc)
        beq .no
        bsr tw_plane
        bne .no
        move.w TS_P(a3),d2              ; footprint in texels
        subq.w #1,d2
        bpl.s .fp
        moveq #0,d2
.fp:    move.w d2,TS_FP(a3)
        move.l tx_wtex(pc),TS_TEX(a3)
        lea tx_mode(pc),a0
        move.b #3,(a0)
        btst #2,tex_on(pc)
        beq.s .no
        bsr fence_ends
.no:    movem.l (sp)+,d0-d7/a0-a4
        rts

; The plane of the recorded polygon from the world coordinates of its
; first three corners (track vertices transformed this frame): corners in
; tx_wc, unit normal (2.14) in tx_wnu, u axis (horizontal along the plane)
; in tx_weu and the surface in tx_psurf (A3) with u = u axis . P and v =
; world z, both doubled (1 unit per texel). Z set when done. Uses D0-D7,
; A0-A4.
tw_plane:
        tst.b tw_given(pc)              ; corners in tx_wc already (gr_seg)
        bne.s .uv0
        movea.l pe_base(pc),a1
        lea pe_vl(pc),a0
        lea tx_wc(pc),a2
        lea G_SHAPE_BASE,a3
        lea G_COORD_POOL,a4
        moveq #2,d7
.c:     move.w (a0)+,d0                 ; vertex_buf offset
        moveq #0,d1
        move.w (a1,d0.w),d1             ; its source record
        move.l d1,d2
        sub.l #TRACK_VTX_REL,d2
        bcs .no
        cmp.l #8*TRACK_VTX_N,d2
        bcc .no
        andi.w #7,d2
        bne .no
        cmp.w (a3,d1.l),d0              ; the record's cache word
        bne .no
        moveq #2,d6
.xyz:   move.w 2(a3,d1.l),d2            ; coord_pool offset
        move.w (a4,d2.w),d3
        add.w d3,d3
        asr.w #1,d3                     ; 15 bit coordinate
        move.w d3,(a2)+
        addq.l #2,d1
        dbra d6,.xyz
        dbra d7,.c
.uv0:   lea tx_wc(pc),a2                ; U = B - A, V = C - A
        lea tx_wv(pc),a0
        moveq #2,d7
.uv:    move.w 6(a2),d0
        sub.w (a2),d0
        ext.l d0
        move.l d0,(a0)
        move.w 12(a2),d0
        sub.w (a2)+,d0
        ext.l d0
        move.l d0,12(a0)
        addq.l #4,a0
        dbra d7,.uv
        lea tx_wv(pc),a0
        moveq #6,d7
        bsr tx_fit14
        movem.l (a0),d3-d5              ; U
        movem.l 12(a0),d6-d7            ; V x, y
        move.l 20(a0),d0                ; V z
        lea tx_wn(pc),a0                ; N = U x V
        move.w d4,d1
        muls.w d0,d1
        move.w d5,d2
        muls.w d7,d2
        sub.l d2,d1
        move.l d1,(a0)
        move.w d5,d1
        muls.w d6,d1
        move.w d3,d2
        muls.w d0,d2
        sub.l d2,d1
        move.l d1,4(a0)
        move.w d3,d1
        muls.w d7,d1
        move.w d4,d2
        muls.w d6,d2
        sub.l d2,d1
        move.l d1,8(a0)
        moveq #3,d7
        bsr tx_fit14
        movem.l (a0),d4-d6              ; N
        move.b tw_hor(pc),d0            ; flat (tex_face): axes from A, B
        bne .hor
        move.w d4,d2
        muls.w d2,d2
        move.w d5,d0
        muls.w d0,d0
        add.l d0,d2
        bsr tx_sqrt                     ; |N x, y|
        cmp.l #64,d1
        bcs .no
        move.l d1,d7
        lea tx_weu(pc),a0               ; u axis (-N y, N x) / |N x, y|
        moveq #14,d2
        move.l d5,d0
        neg.l d0
        asl.l d2,d0
        divs.l d7,d0
        move.w d0,(a0)+
        move.l d4,d0
        asl.l d2,d0
        divs.l d7,d0
        move.w d0,(a0)
.unit:  move.w d4,d2                    ; unit N
        muls.w d2,d2
        move.w d5,d0
        muls.w d0,d0
        add.l d0,d2
        move.w d6,d0
        muls.w d0,d0
        add.l d0,d2
        bsr tx_sqrt
        moveq #14,d2
        asl.l d2,d4
        divs.l d1,d4
        asl.l d2,d5
        divs.l d1,d5
        asl.l d2,d6
        divs.l d1,d6
        lea tx_wnu(pc),a0
        move.w d4,(a0)+
        move.w d5,(a0)+
        move.w d6,(a0)
        lea tx_wc(pc),a2                ; h = N . (camera - A)
        move.w G_CAM_POS,d0
        sub.w (a2)+,d0
        muls.w d4,d0
        move.w G_CAM_POS+2,d1
        sub.w (a2)+,d1
        muls.w d5,d1
        add.l d1,d0
        move.w G_CAM_POS+4,d1
        sub.w (a2),d1
        muls.w d6,d1
        add.l d1,d0
        lea cam_f(pc),a0                ; + N . the camera's fraction
        move.w (a0)+,d1
        muls.w d4,d1
        move.w (a0)+,d2
        muls.w d5,d2
        add.l d2,d1
        move.w (a0),d2
        muls.w d6,d2
        add.l d2,d1
        asr.l #8,d1
        add.l d1,d0
        bpl.s .hp
        neg.l d0                        ; N towards the camera
        neg.l d4
        neg.l d5
        neg.l d6
.hp:    asr.l #6,d0
        move.l d0,d3                    ; h x 256
        lea tx_m(pc),a1                 ; N in camera space
        lea tx_wnc(pc),a2
        moveq #2,d7
.nc:    move.w (a1),d0
        muls.w d4,d0
        move.w 6(a1),d1
        muls.w d5,d1
        add.l d1,d0
        move.w 12(a1),d1
        muls.w d6,d1
        add.l d1,d0
        moveq #14,d1
        asr.l d1,d0
        move.l d0,(a2)+
        addq.l #2,a1
        dbra d7,.nc
        move.l -(a2),d0                 ; y' carries k
        muls.w #TX_KINV,d0
        add.l d0,d0
        swap d0
        ext.l d0
        move.l d0,(a2)
        lea tx_wnc(pc),a2
        movem.l (a2),d0-d2
        moveq #8,d4
        moveq #15,d5
        suba.l a0,a0
        lea tx_psurf(pc),a3
        bsr tsurf_init
        tst.l TS_HS(a3)
        beq .no
        lea tx_da(pc),a1                ; D . u axis x 2, D . z x 2
        movem.w tx_weu(pc),d4-d5
        lea TS_UA(a3),a2
        moveq #2,d7
.co:    move.l (a1),d0
        asr.l #8,d0
        muls.l d4,d0
        move.l 4(a1),d1
        asr.l #8,d1
        muls.l d5,d1
        add.l d1,d0
        asr.l #5,d0
        move.l d0,(a2)
        move.l 8(a1),d0
        add.l d0,d0
        move.l d0,12(a2)
        addq.l #4,a2
        lea 12(a1),a1
        dbra d7,.co
        tst.b tw_hor(pc)
        beq.s .cz
        lea tx_da(pc),a1                ; flat: v = v axis . P as u
        movem.w tx_wev(pc),d4-d5
        lea TS_VA(a3),a2
        moveq #2,d7
.cv:    move.l (a1),d0
        asr.l #8,d0
        muls.l d4,d0
        move.l 4(a1),d1
        asr.l #8,d1
        muls.l d5,d1
        add.l d1,d0
        asr.l #5,d0
        move.l d0,(a2)+
        lea 12(a1),a1
        dbra d7,.cv
        movem.w tx_weu(pc),d4-d5
.cz:    move.w TS_P(a3),d2
        move.w G_CAM_POS,d0             ; camera u, v x 2^(p + 1)
        muls.w d4,d0
        move.w G_CAM_POS+2,d1
        muls.w d5,d1
        add.l d1,d0
        move.w cam_f(pc),d1
        muls.w d4,d1
        move.w cam_f+2(pc),d3
        muls.w d5,d3
        add.l d3,d1
        asr.l #8,d1
        add.l d1,d0
        moveq #13,d1
        sub.w d2,d1
        asr.l d1,d0
        move.l d0,TS_CXP(a3)
        tst.b tw_hor(pc)
        bne.s .hcy
        move.w G_CAM_POS+4,d0
        ext.l d0
        addq.w #1,d2
        lsl.l d2,d0
        moveq #0,d1
        move.w cam_f+4(pc),d1
        lsl.l d2,d1
        asr.l #8,d1
        add.l d1,d0
        move.l d0,TS_CYP(a3)
        moveq #0,d0
        rts
.no:    moveq #-1,d0
        rts
.hcy:   movem.w tx_wev(pc),d4-d5        ; flat: camera v as u
        move.w G_CAM_POS,d0
        muls.w d4,d0
        move.w G_CAM_POS+2,d1
        muls.w d5,d1
        add.l d1,d0
        move.w cam_f(pc),d1
        muls.w d4,d1
        move.w cam_f+2(pc),d3
        muls.w d5,d3
        add.l d3,d1
        asr.l #8,d1
        add.l d1,d0
        moveq #13,d1
        sub.w d2,d1
        asr.l d1,d0
        move.l d0,TS_CYP(a3)
        moveq #0,d0
        rts
        ; Flat: v axis along A -> B (horizontal), u axis (-v y, v x).
.hor:   movem.l tx_wv(pc),d0-d1         ; U x, y
        move.l d0,d2
        muls.w d2,d2
        move.l d1,d3
        muls.w d3,d3
        add.l d3,d2
        movem.l d0-d1,-(sp)
        bsr tx_sqrt
        move.l d1,d7
        movem.l (sp)+,d0-d1
        cmp.l #64,d7
        bcs .no
        moveq #14,d2
        asl.l d2,d0
        divs.l d7,d0
        asl.l d2,d1
        divs.l d7,d1
        lea tx_wev(pc),a0
        move.w d0,(a0)+
        move.w d1,(a0)
        lea tx_weu(pc),a0
        neg.w d1
        move.w d1,(a0)+
        move.w d0,(a0)
        bra .unit

        machine 68000
