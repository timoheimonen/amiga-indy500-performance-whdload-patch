; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Cars (aga_install): "jsr xform_sky_point" in draw_car goes through
; car_proj. The game's transform gives the record and the flags (C: behind,
; the mirrors; Z clear: outside, not drawn); a car in the view then gets
; its depth and screen x, y again from its exact position: the world point
; between its track position and the next one by the blended fraction
; (car_fr), relative to the camera with its fraction (cam_m), projected by
; hproj and rounded to the nearest pixel (the game rounds towards the
; centre). The game's values stay when the exact point is behind depth 1
; or outside the cone twice the view.

        machine 68020

CPSUM   macro                           ; D4 = exact sum, matrix words \1-\3
        HSUM \1,\2,\3
        move.w \1(a4),d0
        muls.w cp_d(pc),d0
        move.l d0,d5
        move.w \2(a4),d0
        muls.w cp_d+2(pc),d0
        add.l d0,d5
        move.w \3(a4),d0
        muls.w cp_d+4(pc),d0
        add.l d0,d5
        add.l #128,d5
        asr.l #8,d5
        add.l d5,d4
        sub.l cam_m+\4(pc),d4
        endm
car_proj:
        move.l a0,-(sp)
        lea c3_ok(pc),a0                ; no 3D car, no sparks (yet)
        sf (a0)
        sf sp_ok-c3_ok(a0)
        movea.l (sp)+,a0
        jsr F_XFORM_SKY
        bcs .x                          ; behind
        bne .x                          ; outside
        movem.l d0-d6/a0-a2/a4,-(sp)
        lea cp_w(pc),a1
        move.l G_T2W,(a1)               ; the game's point (track position)
        move.l G_T2W+4,4(a1)
        lea c3_obj(pc),a0
        st (a0)
        moveq #0,d5
        move.l -10(a2),d0               ; the car object -> its fraction
        sub.l #G_CAR_OBJECTS,d0
        cmp.l #CARS*CAR_SIZE,d0
        bcc.s .f
        divu.w #CAR_SIZE,d0
        move.b d0,(a0)
        lea car_fr(pc),a0
        move.b (a0,d0.w),d5
.f:     clr.l cp_d-cp_w(a1)
        clr.w cp_d+4-cp_w(a1)
        tst.w d5
        beq.s .nd
        move.w -6(a2),d0                ; the next track position
        addq.w #1,d0
        move.w -4(a2),d1
        movem.l d5/a1,-(sp)
        jsr F_TRACK_TO_WORLD
        movem.l (sp)+,d5/a1
        lea G_T2W,a0
        moveq #2,d4
.dl:    move.w (a0)+,d0                 ; (next - this) x fraction
        sub.w (a1)+,d0
        cmp.w #16,d0
        bgt.s .dz
        cmp.w #-16,d0
        blt.s .dz
        muls.w d5,d0
        move.w d0,cp_d-cp_w-2(a1)
.dz:    dbra d4,.dl
        lea cp_w(pc),a1
        move.l (a1),G_T2W               ; the game's point back
        move.l 4(a1),G_T2W+4
.nd:    move.w -6(a2),d0                ; the car along the lap (sparks)
        bsr sp_pos
        move.w -4(a2),d1                ; the bank of the road there
        bsr c3_shape
        lea c3_bank(pc),a0
        move.w d0,(a0)
        move.w (a1),d1                  ; relative to the camera
        sub.w G_CAM_POS,d1
        move.w 2(a1),d2
        sub.w G_CAM_POS+2,d2
        move.w 4(a1),d3
        sub.w G_CAM_POS+4,d3
        lea c3_rel(pc),a0
        movem.w d1-d3,(a0)
        lea G_VIEW_MATRIX,a4
        lea cp_c(pc),a0
        CPSUM 0,6,12,0                  ; depth
        asr.l #8,d4
        asr.l #2,d4
        move.l d4,(a0)
        CPSUM 2,8,14,4                  ; x'
        asr.l #8,d4
        asr.l #2,d4
        move.l d4,4(a0)
        CPSUM 4,10,16,8                 ; y' (2.13)
        asr.l #8,d4
        asr.l #1,d4
        move.l d4,8(a0)
        move.l (a0),d0                  ; depth from 1, x', y' within
        cmp.l #16,d0                    ; twice the depth
        blt .keep
        add.l d0,d0
        move.l 4(a0),d1
        bpl.s .ax
        neg.l d1
.ax:    cmp.l d0,d1
        bgt .keep
        move.l 8(a0),d1
        bpl.s .ay
        neg.l d1
.ay:    cmp.l d0,d1
        bgt .keep
        moveq #1,d6
        bsr hproj
        move.l 24(sp),d6                ; the record
        move.l hp_p(pc),d0
        addq.l #8,d0
        asr.l #4,d0
        sub.w #160,d0
        move.w d0,$a(a3,d6.l)           ; screen x - 160
        move.l hp_p+4(pc),d0
        add.l #128,d0
        asr.l #8,d0
        sub.w #62,d0
        move.w d0,$c(a3,d6.l)           ; screen y - 62
        move.l cp_c(pc),d0
        addq.l #8,d0
        asr.l #4,d0
        tst.b c3_obj(pc)
        bmi.s .hv
        cmp.l #SP_FAR,d0                ; its ground point and heading for
        bge.s .hv                       ; the sparks
        bsr c3_place
        lea c3_ok(pc),a0
        st sp_ok-c3_ok(a0)
        btst #2,tex_on2(pc)
        beq.s .hv
        cmp.l #C3_FAR,d0                ; near: the 3D car (the images
        bge.s .hv                       ; are about its size)
        st (a0)
.hv:    tst.w G_MATRIX_HALVED
        beq.s .h
        add.l d0,d0                     ; as the game: the true depth
.h:     move.w d0,2(a3,d6.l)
.keep:  movem.l (sp)+,d0-d6/a0-a2/a4
        moveq #0,d7
        move.w #4,ccr                   ; in the view
.x:     rts

        machine 68000
