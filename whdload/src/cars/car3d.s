; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; 3D cars (tex_on2 bit 2): a car nearer than C3_FAR is drawn from the
; model car3d.i (generated data) instead of its image: car_proj keeps
; its ground point, heading and the bank of the road (c3_place) and sets
; c3_ok, and the image call that follows (c_car_sprite) draws it with
; c3_car. Cars farther away keep the images at 2/3 of their size, which
; matches the model (1 unit = 2 inches, the images are about 1.5 times
; the size of a real car).
;
; Also the team liveries of the computer cars (liv_set, tex_on2 bit 3).

        machine 68020

; D0 = track position of a car (as object +6), D1 = lateral x 16 -> D0 =
; bank (65536 per turn), D1 = height of the road there (units); as
; track_shape_at, without its globals (track_to_world already puts the
; cars on the banking). Uses D2-D4, A0.
c3_shape:
        asr.w #4,d1                     ; lateral
        sub.w #$1b12,d0                 ; track_pos
        neg.w d0
        bpl.s .p
        add.w #-$6550,d0
.p:     moveq #0,d2
        moveq #0,d3
        cmp.w #$4d58,d0
        bcc.s .h2
        sub.w #$26ac,d0
        ble.s .out
        sub.w #$f78,d0
        blt.s .t1
        sub.w #$7bc,d0
        bgt.s .turn
        bra.s .out
.h2:    sub.w #$7404,d0
        bls.s .out
        sub.w #$f78,d0
        blt.s .t1
        sub.w #$7bc,d0
        bgt.s .turn
        bra.s .out
.t1:    add.w #$f78,d0
.turn:  sub.w #$d0,d1                   ; the banking from lateral $D0
        bmi.s .out
        sub.w #$7bc,d0                  ; from the middle of the turn
        bpl.s .a
        neg.w d0
.a:     move.w #$28d7,d4
        sub.w #$528,d0
        bgt.s .ends
        move.w #$680,d2                 ; 9.1 degrees
        bra.s .bk
.ends:  neg.w d0                        ; less towards the ends
        add.w #$294,d0
        lsr.w #3,d0
        and.w #-2,d0
        lea G_BANK_TAB,a0
        move.w (a0,d0.w),d4
        move.w #$28be,d2
        mulu.w d4,d2
        swap d2
.bk:    cmp.w #$40,d1                   ; rising over 64 units
        bgt.s .r
        mulu.w d1,d2
        lsr.l #6,d2
.r:     sub.w #$2c,d1
        bmi.s .out
        mulu.w d4,d1
        swap d1
        move.w d1,d3
.out:   move.w d2,d0
        move.w d3,d1
        rts

; car_proj, a car for the 3D model or the sparks: its ground point (cp_c,
; 15 units lower) in camera space, its heading. Uses A0, A1, A4.
c3_place:
        movem.l d2-d3,-(sp)
        lea G_VIEW_MATRIX,a4
        lea cp_c(pc),a0
        lea c3_org(pc),a1
        moveq #-15,d3
        move.w 12(a4),d2                ; world z . -15 units
        muls.w d3,d2
        asr.l #8,d2
        asr.l #2,d2
        add.l (a0)+,d2
        move.l d2,(a1)+
        move.w 14(a4),d2
        muls.w d3,d2
        asr.l #8,d2
        asr.l #2,d2
        add.l (a0)+,d2
        move.l d2,(a1)+
        move.w 16(a4),d2
        muls.w d3,d2
        asr.l #8,d2
        asr.l #1,d2
        add.l (a0)+,d2
        move.l d2,(a1)+
        lea c3_head(pc),a0
        move.w G_CAR_HEAD,(a0)
        movem.l (sp)+,d2-d3
        rts

; c_car_sprite with c3_ok: the 3D car (D3 = its two body colours) in place
; of the image at A0, which is skipped as the original does. All
; registers kept except A0.
c3_car:
        movem.l d0-d7/a1-a6,-(sp)
        move.l a0,-(sp)
        lea c3_ok(pc),a0
        sf (a0)
        sf sp_ok-c3_ok(a0)
        bsr c3_colours
        bsr c3_matrix
        bsr sp_check                    ; sparks: before the car when the
        move.w c3_cm(pc),d0             ; camera is ahead of them
        cmp.w #SP_F0,d0
        ble.s .sb
        tst.b sp_act(pc)
        beq.s .sb
        bsr sp_draw
.sb:    lea c3_stamp(pc),a0             ; a new car: no vertex done
        addq.w #1,(a0)
        bne.s .st
        addq.w #1,(a0)
.st:    lea c3_mb(pc),a0                ; the level of detail
        lea c3_model0(pc),a1
        move.l a1,(a0)+
        lea c3_ptab0(pc),a1
        move.l a1,(a0)+
        move.w #C3_NP0,(a0)
        cmp.l #C3_LOD*16,c3_org(pc)
        blt.s .lod
        lea c3_mb(pc),a0
        lea c3_model1(pc),a1
        move.l a1,(a0)+
        lea c3_ptab1(pc),a1
        move.l a1,(a0)+
        move.w #C3_NP1,(a0)
.lod:   bsr c3_draw
        tst.b sp_act(pc)
        beq.s .ns
        bsr sp_draw
.ns:
        lea $dff000,a2                  ; blitter state as the original leaves it
        move.w #$5ac,$40(a2)
        clr.w $42(a2)
        move.w #$ffff,$74(a2)
        move.l #$ffffffff,$44(a2)
        movea.l (sp)+,a0                ; the image: count, then groups of
        moveq #0,d1                     ; colour, row, height, height pairs
        move.b (a0)+,d1
        bra.s .gi
.g:     moveq #0,d0
        move.b 2(a0),d0
        add.w d0,d0
        lea 3(a0,d0.w),a0
.gi:    dbra d1,.g
        movem.l (sp)+,d0-d7/a1-a6
        rts

; c_car_sprite, after the image of a car farther than the 3D cars (or
; with them off): its sparks. All registers kept.
sp_far: movem.l d0-d7/a0-a6,-(sp)
        lea sp_ok(pc),a0
        sf (a0)
        bsr sp_check
        tst.b sp_act(pc)
        beq.s .x
        bsr c3_matrix
        bsr sp_draw
.x:     movem.l (sp)+,d0-d7/a0-a6
        rts

; The car's livery (liv_ok) or D3 = its two body colours (for the images'
; 12 and 9) -> c3_cols (the slots of car3d.i).
c3_colours:
        lea c3_cols(pc),a0
        btst #0,liv_ok(pc)
        beq.s .g
        move.l liv_cols(pc),d0          ; primary, secondary, accent, helmet
        move.b d0,7(a0)
        lsr.l #8,d0
        move.b d0,2(a0)
        lsr.w #8,d0
        move.b d0,1(a0)
        swap d0
        move.b d0,(a0)
        bra.s .f
.g:     move.w d3,d0
        lsr.w #8,d0
        move.b d0,(a0)                  ; primary
        move.b d3,1(a0)                 ; secondary
        move.b d3,2(a0)                 ; accent
        move.b #$0f,7(a0)               ; helmet: colour 15
.f:     move.b #$00,3(a0)               ; tyres: colour 0
        move.b #$ef,4(a0)               ; rims: colour 15, level 7
        move.b #$08,5(a0)               ; dark parts: colour 8
        move.b #$00,6(a0)               ; cockpit: colour 0
        rts

; draw_car, draw_car_aerial: G_CAR_COLS = the two body colours of the car
; object A0 (the replaced move.w). With tex_on2 bit 3 a computer car
; (objects 1-32) also gets its team livery (liv_tab) for the images and
; the 3D car: liv_cols and liv_ok. The mirrors keep the game's colours.
liv_set:
        move.w $1a(a0),G_CAR_COLS
        movem.l d0/a1,-(sp)
        lea liv_ok(pc),a1
        sf (a1)
        btst #3,tex_on2(pc)
        beq.s .x
        move.l a0,d0
        sub.l #G_CAR_OBJECTS,d0
        cmp.l #CARS*CAR_SIZE,d0
        bcc.s .x
        divu.w #CAR_SIZE,d0
        subq.w #1,d0                    ; object 0, the player: its own
        bmi.s .x
        st (a1)
        lsl.w #2,d0
        lea liv_tab(pc),a1
        move.l (a1,d0.w),-(sp)
        lsr.w #1,d0                     ; the game's pair, which the mirror
        lea liv_game(pc),a1             ; cars are drawn with: the game
        move.w (a1,d0.w),G_CAR_COLS     ; colours nearest to the livery
        lea liv_cols(pc),a1
        move.l (sp)+,(a1)
.x:     movem.l (sp)+,d0/a1
        rts

; c3_head, c3_bank -> c3_ax: the car's axes (forward, right, up) in world;
; c3_m: in camera space (view_matrix . axes, 2.14) per camera axis
; (depth, x', y'); c3_cm: the camera in the model's axes (1/16 unit).
c3_matrix:
        lea c3_ax(pc),a1
        move.w c3_head(pc),d0
        bsr view_sincos
        move.w d2,d4                    ; cA = cos heading
        move.w d1,d5
        neg.w d5                        ; sA = -sin heading
        move.w c3_bank(pc),d0
        bsr view_sincos                 ; cB = D2, sB = D1
        move.w d4,(a1)+                 ; forward: cA, sA, 0
        move.w d5,(a1)+
        clr.w (a1)+
        move.w d5,d0                    ; right: -sA cB, cA cB, sB
        muls.w d2,d0
        asl.l #2,d0
        swap d0
        neg.w d0
        move.w d0,(a1)+
        move.w d4,d0
        muls.w d2,d0
        asl.l #2,d0
        swap d0
        move.w d0,(a1)+
        move.w d1,(a1)+
        move.w d5,d0                    ; up: sA sB, -cA sB, cB
        muls.w d1,d0
        asl.l #2,d0
        swap d0
        move.w d0,(a1)+
        move.w d4,d0
        muls.w d1,d0
        asl.l #2,d0
        swap d0
        neg.w d0
        move.w d0,(a1)+
        move.w d2,(a1)+
        lea c3_ax(pc),a0                ; c3_m[3 c + j] = W[.][c] . axis j
        lea c3_m(pc),a1
        lea G_VIEW_MATRIX,a4
        moveq #0,d6                     ; camera axis c (byte offset)
.c:     moveq #0,d7                     ; car axis j
.j:     lea (a0,d7.w),a2
        move.w (a4,d6.w),d0
        muls.w (a2)+,d0
        move.w 6(a4,d6.w),d1
        muls.w (a2)+,d1
        add.l d1,d0
        move.w 12(a4,d6.w),d1
        muls.w (a2)+,d1
        add.l d1,d0
        asl.l #2,d0
        swap d0
        move.w d0,(a1)+
        addq.w #6,d7
        cmp.w #18,d7
        bne.s .j
        addq.w #2,d6
        cmp.w #6,d6
        bne.s .c
        movem.w c3_rel(pc),d3-d5        ; the camera: -(axis . (ground
        sub.w #15,d5                    ; point - camera)) in world units
        lea c3_ax(pc),a0
        lea c3_cm(pc),a1
        moveq #2,d7
.cm:    move.w (a0)+,d0
        muls.w d3,d0
        move.w (a0)+,d1
        muls.w d4,d1
        add.l d1,d0
        move.w (a0)+,d1
        muls.w d5,d1
        add.l d1,d0
        asr.l #8,d0
        asr.l #2,d0
        neg.l d0
        move.w d0,(a1)+
        dbra d7,.cm
        rts

; D0 = offset of a vertex in c3_v -> A0 = its record: depth, x', y'
; (1/16 unit, y' doubled as hcorner's) from c3_org, the outcode (word:
; bit 0 nearer than depth 1, bits 1-4 outside the right, left, top,
; bottom of the cone twice the view, the planes of fclip), the car stamp
; (word) and, with outcode 0, x x 16 and y x 256 (as hproj). Done once
; per car (c3_stamp). Keeps all other registers.
c3_vert:
        lea c3_v(pc),a0
        adda.w d0,a0
        move.l d1,-(sp)
        move.w c3_stamp(pc),d1
        cmp.w 14(a0),d1
        beq .x
        move.w d1,14(a0)
        movem.l d2-d6/a1-a2,-(sp)
        movea.l c3_mb(pc),a1            ; the model vertex: offset / 4
        lsr.w #2,d0
        adda.w d0,a1
        movem.w (a1),d3-d5              ; f, r, u
        lea c3_m(pc),a2
        move.w (a2)+,d0                 ; depth
        muls.w d3,d0
        move.w (a2)+,d1
        muls.w d4,d1
        add.l d1,d0
        move.w (a2)+,d1
        muls.w d5,d1
        add.l d1,d0
        asr.l #8,d0
        asr.l #6,d0
        add.l c3_org(pc),d0
        move.l d0,(a0)
        move.w (a2)+,d1                 ; x'
        muls.w d3,d1
        move.w (a2)+,d2
        muls.w d4,d2
        add.l d2,d1
        move.w (a2)+,d2
        muls.w d5,d2
        add.l d2,d1
        asr.l #8,d1
        asr.l #6,d1
        add.l c3_org+4(pc),d1
        move.l d1,4(a0)
        move.w (a2)+,d2                 ; y' (doubled)
        muls.w d3,d2
        move.w (a2)+,d6
        muls.w d4,d6
        add.l d6,d2
        move.w (a2),d6
        muls.w d5,d6
        add.l d6,d2
        asr.l #8,d2
        asr.l #5,d2
        add.l c3_org+8(pc),d2
        move.l d2,8(a0)
        moveq #0,d6                     ; outcode
        moveq #16,d5
        cmp.l d5,d0
        bge.s .o0
        moveq #1,d6
.o0:    move.l d0,d5                    ; twice the depth
        add.l d5,d5
        cmp.l d5,d1
        ble.s .o1
        addq.w #2,d6
.o1:    move.l d1,d3
        neg.l d3
        cmp.l d5,d3
        ble.s .o2
        addq.w #4,d6
.o2:    cmp.l d5,d2
        ble.s .o3
        addq.w #8,d6
.o3:    move.l d2,d3
        neg.l d3
        cmp.l d5,d3
        ble.s .o4
        add.w #16,d6
.o4:    move.w d6,12(a0)
        bne.s .np
        muls.l #VIEW_W*8,d1             ; projected: x x 16, y x 256
        divs.l d0,d1
        add.l #VIEW_W*8,d1
        move.l d1,16(a0)
        muls.l #62*256,d2
        divs.l d0,d2
        neg.l d2
        add.l #62*256,d2
        move.l d2,20(a0)
.np:    movem.l (sp)+,d2-d6/a1-a2
.x:     move.l (sp)+,d1
        rts

; The parts far to near (depth of their centres), each face that faces
; the camera clipped, projected and filled in its colour.
c3_draw:
        movea.l c3_pt(pc),a2            ; sort keys: depth, part address
        lea c3_ord(pc),a1
        move.w c3_np(pc),d7
        subq.w #1,d7
        moveq #0,d6                     ; parts in c3_ord
        moveq #0,d5
.k:     move.w (a2,d5.w),d0             ; the part
        lea (a2,d0.w),a3
        move.w (a3),d0                  ; its centre
        bsr c3_vert
        move.l (a0),d1                  ; depth
        move.w d6,d2                    ; insert, deepest first
        bra.s .ii
.is:    move.l -8(a1,d2.w*8),d3
        cmp.l d1,d3
        bge.s .ip
        move.l d3,(a1,d2.w*8)
        move.l -4(a1,d2.w*8),4(a1,d2.w*8)
        subq.w #1,d2
.ii:    tst.w d2
        bne.s .is
.ip:    move.l d1,(a1,d2.w*8)
        move.l a3,4(a1,d2.w*8)
        addq.w #1,d6
        addq.w #2,d5
        dbra d7,.k
        subq.w #1,d6
.part:  movea.l 4(a1),a3
        addq.l #8,a1
        movem.l d6/a1,-(sp)
        addq.l #2,a3                    ; skip the centre
        move.w (a3)+,d7                 ; faces - 1
.face:  bsr.s c3_face
        dbra d7,.face
        movem.l (sp)+,d6/a1
        dbra d6,.part
        rts

; One face at A3 (slot, corners - 1, outward normal, normal . corner 0,
; corners) -> A3 after it: drawn when the camera is in front of its plane
; (c3_cm, model space) and the face is not outside one plane of the view;
; the corners transformed when first used (c3_vert), clipped when one is
; outside, scanned (hscan) and filled in the slot's colour. Keeps D7.
c3_face:
        move.l d7,-(sp)
        moveq #0,d0
        move.b (a3)+,d0                 ; slot -> colour byte
        lea c3_cols(pc),a0
        move.b (a0,d0.w),d0
        lea c3_fcol(pc),a0
        move.b d0,(a0)
        moveq #0,d7
        move.b (a3)+,d7                 ; corners - 1
        movem.w (a3)+,d0-d2             ; facing: normal . camera > n . v0
        muls.w c3_cm(pc),d0
        muls.w c3_cm+2(pc),d1
        muls.w c3_cm+4(pc),d2
        add.l d1,d0
        add.l d2,d0
        sub.l (a3)+,d0
        movea.l a3,a4                   ; the corners
        lea 2(a3,d7.w*2),a3             ; the next face
        tst.l d0
        ble .x
        moveq #0,d4                     ; outcodes: OR
        moveq #-1,d5                    ; AND
        move.w d7,d6
        movea.l a4,a5
.oc:    move.w (a5)+,d0
        bsr c3_vert
        move.w 12(a0),d0
        or.w d0,d4
        and.w d0,d5
        dbra d6,.oc
        tst.w d5
        bne .x                          ; outside one plane
        move.w d7,d6
        addq.w #1,d6                    ; corners
        tst.w d4
        bne.s .clip
        lea hp_p(pc),a1                 ; all inside: projected already
        move.w d7,d5
.pp:    move.w (a4)+,d0
        lea c3_v(pc),a0
        adda.w d0,a0
        move.l 16(a0),(a1)+
        move.l 20(a0),(a1)+
        dbra d5,.pp
        bra.s .scan
.clip:  lea hp_a(pc),a1                 ; else clipped as hspans
        move.w d7,d5
.cc:    move.w (a4)+,d0
        lea c3_v(pc),a0
        adda.w d0,a0
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0),(a1)+
        dbra d5,.cc
        lea hp_a(pc),a0
        lea fc_zn(pc),a1
        moveq #16,d0
        move.l d0,(a1)
        lea hp_b(pc),a1
        btst #0,d4
        beq.s .sd
        moveq #0,d7                     ; the near plane
        bsr fclip
        exg a0,a1
        moveq #%11110,d4                ; a corner behind: all planes
.sd:    moveq #1,d7
.pl:    btst d7,d4
        beq.s .pn
        bsr fclip
        exg a0,a1
.pn:    addq.w #1,d7
        cmp.w #5,d7
        bne.s .pl
        cmp.w #3,d6
        bcs .x
        bsr hproj
.scan:  bsr hscan
        moveq #0,d5                     ; the colour in 4 bytes
        move.b c3_fcol(pc),d5
        move.l d5,d0
        lsl.l #8,d0
        or.l d0,d5
        move.l d5,d0
        swap d0
        or.l d0,d5
        lea hs_y0(pc),a4
        move.w (a4)+,d2
        move.w (a4),d3
        cmp.w d3,d2
        bgt.s .x
        lea hs_l(pc),a4
        lea hs_r(pc),a5
        move.w d2,d0
        bsr crow
.row:   move.w (a4,d2.w*2),d0
        bpl.s .l0
        moveq #0,d0
.l0:    move.w (a5,d2.w*2),d1
        cmp.w #VIEW_W-1,d1
        ble.s .l1
        move.w #VIEW_W-1,d1
.l1:    cmp.w d1,d0
        bgt.s .nr
        movea.l a6,a0
        bsr hrow_solid
.nr:    lea VIEW_W(a6),a6
        addq.w #1,d2
        cmp.w d3,d2
        ble.s .row
.x:     move.l (sp)+,d7
        rts

        machine 68000
