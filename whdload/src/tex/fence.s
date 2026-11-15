; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Catch fences above the walls and the guardrails of the turns: collected
; during the 3D view (fence_ends, gr_seg), drawn after it (fence_flush,
; fence_draw).

        machine 68020

; tex_wall: a wall 10 to 20 units high at both ends gets a fence on its top
; edge (tx_fq), added to the frame's list with the wall's surface. The ends are the x, y of the corners A, B, C
; (consecutive) and D, the fourth corner of a quad, A + C - B. The track's
; wall triangles start with their top edge and have C below A: there
; D = B + C - A, the bottom below B for the same height.
fence_ends:
        movem.l d0-d7/a0-a1,-(sp)
        lea tx_wc(pc),a0
        move.l (a0),d0                  ; C at the x, y of A: a triangle
        cmp.l 12(a0),d0
        beq.s .tri
        moveq #2,d7
.d:     move.w (a0),d0
        add.w 12(a0),d0
        sub.w 6(a0),d0
        move.w d0,18(a0)
        addq.l #2,a0
        dbra d7,.d
        bra.s .grp
.tri:   moveq #2,d7
.dt:    move.w 6(a0),d0
        add.w 12(a0),d0
        sub.w (a0),d0
        move.w d0,18(a0)
        addq.l #2,a0
        dbra d7,.dt
.grp:
        lea tx_wc(pc),a0
        lea tx_fq(pc),a1
        move.w (a0),d4                  ; end 1: x, y of A
        move.w 2(a0),d5
        move.w #$7fff,d0                ; lowest and highest z at end 1
        move.w #-$8000,d1
        move.w d0,d2                    ; and at end 2
        move.w d1,d3
        moveq #3,d7
.k:     move.w 4(a0),d6
        cmp.w (a0),d4
        bne.s .o
        cmp.w 2(a0),d5
        bne.s .o
        cmp.w d0,d6
        bge.s .k1
        move.w d6,d0
.k1:    cmp.w d1,d6
        ble.s .n
        move.w d6,d1
        bra.s .n
.o:     move.l (a0),6(a1)               ; end 2: x, y
        cmp.w d2,d6
        bge.s .k2
        move.w d6,d2
.k2:    cmp.w d3,d6
        ble.s .n
        move.w d6,d3
.n:     addq.l #6,a0
        dbra d7,.k
        move.w d1,d6
        sub.w d0,d6
        cmp.w #10,d6
        blt .x
        cmp.w #20,d6
        bgt .x
        move.w d3,d6
        sub.w d2,d6
        cmp.w #10,d6
        blt .x
        cmp.w #20,d6
        bgt .x
        move.w d4,(a1)                  ; the top edge
        move.w d5,2(a1)
        move.w d1,4(a1)
        move.w d3,10(a1)
        move.w tx_fn(pc),d0
        cmp.w #FENCE_MAX,d0
        bcc.s .x
        lea tx_fn(pc),a0
        addq.w #1,(a0)
        mulu.w #FL_SIZE,d0
        movea.l tx_flist(pc),a0
        adda.l d0,a0
        movem.w (a1),d0-d2              ; key: depth of the middle
        movem.w 6(a1),d3-d5
        add.l d3,d0
        add.l d4,d1
        add.l d5,d2
        move.w G_CAM_POS,d3
        ext.l d3
        add.l d3,d3
        sub.l d3,d0
        move.w G_CAM_POS+2,d3
        ext.l d3
        add.l d3,d3
        sub.l d3,d1
        move.w G_CAM_POS+4,d3
        ext.l d3
        add.l d3,d3
        sub.l d3,d2
        asr.l #1,d0
        asr.l #1,d1
        asr.l #1,d2
        muls.w tx_m(pc),d0
        muls.w tx_m+6(pc),d1
        muls.w tx_m+12(pc),d2
        add.l d1,d0
        add.l d2,d0
        move.l d0,(a0)+                 ; FL_KEY
        move.l (a1),(a0)+               ; FL_FQ
        move.l 4(a1),(a0)+
        move.l 8(a1),(a0)+
        lea tx_psurf(pc),a1             ; FL_SURF
        moveq #64/4-1,d0
.cs:    move.l (a1)+,(a0)+
        dbra d0,.cs
        move.w #FENCE_H,(a0)            ; FL_H
.x:     movem.l (sp)+,d0-d7/a0-a1
        rts

; After the transform of a line segment's second end (lx_track): a
; segment of colour 7 between two track vertices at world z GR_Z (the
; lower rail of the guardrails inside the four turns) adds a guardrail
; to the frame's fences (tex_on2 bit 0): its vertical plane from the
; ground below the segment up GR_H units, drawn by fence_draw with the
; rows 0 to GR_H of the mesh texture (two beams and posts, holes
; between). All registers kept.
gr_seg:
        btst #0,tex_on2(pc)
        beq.s .r
        btst #0,tx_ok(pc)
        beq.s .r
        btst #0,ls_ok(pc)
        beq.s .r
        cmpi.l #-1,G_COLOUR             ; colour 7: planes 0-2 set
        bne.s .r
        cmpi.l #$ffff0000,G_COLOUR+4
        beq.s .go
.r:     rts
.go:    movem.l d0-d7/a0-a6,-(sp)
        movea.l ls_base(pc),a1
        lea G_SHAPE_BASE,a3
        lea G_COORD_POOL,a4
        lea tx_wc(pc),a2
        move.w ls_a(pc),d0
        bsr .end
        bne .x
        move.w ls_b(pc),d0
        bsr .end
        bne .x
        lea tx_wc(pc),a2                ; C: above A
        move.l (a2),12(a2)
        move.w #GR_H,16(a2)
        lea tw_given(pc),a0
        st (a0)
        bsr tw_plane
        lea tw_given(pc),a0
        sf (a0)
        tst.l d0
        bne .x
        lea tx_psurf(pc),a3
        move.w TS_P(a3),d2              ; footprint: 1 unit per texel, as
        subq.w #1,d2                    ; the walls
        bpl.s .fp
        moveq #0,d2
.fp:    move.w d2,TS_FP(a3)
        move.w tx_fn(pc),d0
        cmp.w #FENCE_MAX,d0
        bcc .x
        lea tx_fn(pc),a0
        addq.w #1,(a0)
        mulu.w #FL_SIZE,d0
        movea.l tx_flist(pc),a0
        adda.l d0,a0
        lea tx_wc(pc),a1
        movem.w (a1),d0-d2              ; key: depth of the middle
        movem.w 6(a1),d3-d5
        add.l d3,d0
        add.l d4,d1
        add.l d5,d2
        move.w G_CAM_POS,d3
        ext.l d3
        add.l d3,d3
        sub.l d3,d0
        move.w G_CAM_POS+2,d3
        ext.l d3
        add.l d3,d3
        sub.l d3,d1
        move.w G_CAM_POS+4,d3
        ext.l d3
        add.l d3,d3
        sub.l d3,d2
        asr.l #1,d0
        asr.l #1,d1
        asr.l #1,d2
        muls.w tx_m(pc),d0
        muls.w tx_m+6(pc),d1
        muls.w tx_m+12(pc),d2
        add.l d1,d0
        add.l d2,d0
        move.l d0,(a0)+                 ; FL_KEY
        move.l (a1)+,(a0)+              ; FL_FQ: A, B on the ground
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        lea tx_psurf(pc),a1             ; FL_SURF
        moveq #64/4-1,d0
.cs:    move.l (a1)+,(a0)+
        dbra d0,.cs
        move.w #GR_H,(a0)               ; FL_H
.x:     movem.l (sp)+,d0-d7/a0-a6
        rts
; End D0 (vertex_buf offset at A1) of the segment: a track vertex
; transformed this frame at z GR_Z, its x, y and z 0 to A2 (6 bytes on).
; Z set when so. D1-D3 lost.
.end:   moveq #0,d1
        move.w (a1,d0.w),d1             ; its source record
        move.l d1,d2
        sub.l #TRACK_VTX_REL,d2
        bcs.s .ne
        cmp.l #8*TRACK_VTX_N,d2
        bcc.s .ne
        andi.w #7,d2
        bne.s .ne
        cmp.w (a3,d1.l),d0              ; transformed this frame
        bne.s .ne
        move.w 6(a3,d1.l),d2            ; z
        move.w (a4,d2.w),d3
        add.w d3,d3
        asr.w #1,d3
        cmp.w #GR_Z,d3
        bne.s .ne
        move.w 2(a3,d1.l),d2
        move.w (a4,d2.w),d3
        add.w d3,d3
        asr.w #1,d3
        move.w d3,(a2)+
        move.w 4(a3,d1.l),d2
        move.w (a4,d2.w),d3
        add.w d3,d3
        asr.w #1,d3
        move.w d3,(a2)+
        clr.w (a2)+
        moveq #0,d1
        rts
.ne:    moveq #-1,d1
        rts

; Replaces "btst.b #0,$C093E3" in frame_loop after the 3D view (before the
; cars): the fences of the frame from the farthest to the nearest, so that
; the scenery drawn after a wall (grandstands) stays behind its fence.
fence_flush:
        movem.l d0-d2/a0-a2,-(sp)
        move.w tx_fn(pc),d2
        beq.s .x
        btst #0,chunky_on(pc)
        beq.s .clr
        btst #0,tx_ok(pc)
        beq.s .clr
        subq.w #1,d2
.pick:  movea.l tx_flist(pc),a0         ; the farthest left
        move.w tx_fn(pc),d1
        subq.w #1,d1
        move.l #$80000000,d0
        suba.l a1,a1
.f:     cmp.l (a0),d0
        bge.s .fn
        move.l (a0),d0
        movea.l a0,a1
.fn:    lea FL_SIZE(a0),a0
        dbra d1,.f
        move.l a1,d1
        beq.s .clr
        move.l #$80000000,(a1)+         ; drawn
        lea tx_fq(pc),a2
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        lea tx_psurf(pc),a2
        moveq #64/4-1,d1
.c:     move.l (a1)+,(a2)+
        dbra d1,.c
        lea fd_h(pc),a2
        move.w (a1),(a2)
        bsr fence_draw
        dbra d2,.pick
.clr:   lea tx_fn(pc),a0
        clr.w (a0)
.x:     movem.l (sp)+,d0-d2/a0-a2
        btst #0,G_VIEW_FLAGS            ; the replaced instruction
        rts

; fence_draw (from fence_flush): the catch fence, fd_h units above the
; top edge of a wall (tx_fq) on the wall's plane (tx_psurf), or a turn
; guardrail above its ground line (gr_seg), drawn as one
; quad (segments made short spans): camera space, clipped to the near
; plane and to a view cone twice as wide, projected as the game does and
; filled row by row with the mesh (holes keep what is behind).
fence_draw:
        movem.l d0-d7/a0-a6,-(sp)
        lea tx_psurf(pc),a3
        move.l tx_mtex(pc),TS_TEX(a3)
        st TS_MESH(a3)
        move.w fd_h(pc),d0              ; a guardrail: mode 5
        cmp.w #GR_H,d0
        bne.s .fm
        move.b #5,TS_MESH(a3)
.fm:
        lea tx_fq(pc),a0                ; corners: end 1, end 2,
        lea tx_fa(pc),a1                ; end 2 + h, end 1 + h
        bsr .cam
        bsr .cam
        lea tx_m+12(pc),a2              ; h = fd_h x world up
        lea tx_fc(pc),a0
        moveq #2,d6
.hv:    move.w (a2)+,d0
        muls.w fd_h(pc),d0
        moveq #10,d1
        asr.l d1,d0
        move.l d0,(a0)+
        dbra d6,.hv
        add.l d0,-4(a0)                 ; y' doubled
        lea tx_fa+12(pc),a0
        lea tx_fa+24(pc),a1
        bsr.s .up
        lea tx_fa(pc),a0
        bsr.s .up
        lea fc_zn(pc),a0
        moveq #FENCE_ZN*16,d7
        move.l d7,(a0)
        moveq #4,d6                     ; clip to 5 planes
        moveq #0,d7
        lea tx_fa(pc),a0
        lea tx_fbb(pc),a1
.cl:    bsr fclip
        exg a0,a1
        addq.w #1,d7
        cmp.w #5,d7
        bcs.s .cl
        cmp.w #3,d6
        bcs.s .x
        lea tx_fp(pc),a1                ; project
        move.w d6,d7
        subq.w #1,d7
.pr:    move.l 4(a0),d0
        muls.l #160,d0
        divs.l (a0),d0
        add.w #160,d0
        move.w d0,(a1)+
        move.l 8(a0),d0
        muls.l #62,d0
        divs.l (a0),d0
        neg.w d0
        add.w #62,d0
        move.w d0,(a1)+
        lea 12(a0),a0
        dbra d7,.pr
        bsr fscan
.x:     movem.l (sp)+,d0-d7/a0-a6
        rts
; A0 = corner -> A1 = corner + h.
.up:    lea tx_fc(pc),a2
        moveq #2,d6
.u:     move.l (a0)+,d0
        add.l (a2)+,d0
        move.l d0,(a1)+
        dbra d6,.u
        rts
; A0 = world x, y, z words -> A1 = camera depth, x', y' (longs in 1/16
; unit, y' as the game's, doubled), from the exact camera (cam_mt).
.cam:   move.w (a0)+,d0
        sub.w G_CAM_POS,d0
        move.w (a0)+,d1
        sub.w G_CAM_POS+2,d1
        move.w (a0)+,d2
        sub.w G_CAM_POS+4,d2
        move.l a3,-(sp)
        lea tx_m(pc),a2
        lea cam_mt(pc),a3
        moveq #2,d6
.cj:    move.w (a2),d3
        muls.w d0,d3
        move.w 6(a2),d7
        muls.w d1,d7
        add.l d7,d3
        move.w 12(a2),d7
        muls.w d2,d7
        add.l d7,d3
        sub.l (a3)+,d3
        moveq #10,d7
        asr.l d7,d3
        move.l d3,(a1)+
        addq.l #2,a2
        dbra d6,.cj
        movea.l (sp)+,a3
        add.l d3,-4(a1)
        rts

        machine 68000
