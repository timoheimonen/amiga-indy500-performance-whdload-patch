; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Frames between simulation steps: the frame loop hooks, the blend factor from
; the time since the last step and the blended camera and cars.

; Replaces the busy wait for a simulation step. Returns to the step handling
; when a step happened, otherwise renders an interpolated frame or waits.

interp_loop_top:
        tst.w G_STEP_COUNTER
        bne.s .step
        movem.l d0-d7/a0-a3,-(sp)
        lea valid(pc),a0
        btst #0,G_DEMO
        bne.s .invalid
        btst #1,G_MODE
        bne.s .invalid
        tst.b (a0)
        beq.s .wait
        jsr G_SIM_DISABLE
        bsr get_alpha
        bsr write_snapshot
        move.b #1,G_FRAME_FLAGS
        bsr cars_body
        jsr G_SIM_ENABLE
        movem.l (sp)+,d0-d7/a0-a3
        move.l #F_RENDER,(sp)
        rts
.invalid:
        clr.b (a0)
.wait:  movem.l (sp)+,d0-d7/a0-a3
        move.l #F_LOOP_TOP,(sp)
        rts
.step:  move.w G_STEP_COUNTER,d0        ; as the original for the code after it
        rts

;============================================================================
; Replaces the snapshot copy of a new step (SOFTINT masked): keep the previous
; and the new camera block and car positions, then write the blended snapshot.

interp_new_step:
        movem.l d0-d7/a0-a3,-(sp)
        lea prev_cam(pc),a0
        lea cur_cam(pc),a1
        moveq #CAM_BYTES/2-1,d0
.c1:    move.w (a1)+,(a0)+
        dbra d0,.c1
        lea G_STEP_COUNTER,a0
        lea cur_cam(pc),a1
        moveq #CAM_BYTES/2-1,d0
.c2:    move.w (a0)+,(a1)+
        dbra d0,.c2
        lea prev_cars(pc),a0
        lea cur_cars(pc),a1
        move.w #CARS*3-1,d0
.c3:    move.w (a1)+,(a0)+
        dbra d0,.c3
        lea G_CAR_OBJECTS+6,a0
        lea cur_cars(pc),a1
        moveq #CARS-1,d0
.c4:    move.w (a0),(a1)+
        move.l 2(a0),(a1)+
        lea CAR_SIZE(a0),a0
        dbra d0,.c4
        lea valid(pc),a0
        tst.b (a0)
        bne.s .ok
        st (a0)
        lea cur_cam(pc),a0              ; first step: no motion yet
        lea prev_cam(pc),a1
        moveq #CAM_BYTES/2-1,d0
.c5:    move.w (a0)+,(a1)+
        dbra d0,.c5
        lea cur_cars(pc),a0
        lea prev_cars(pc),a1
        move.w #CARS*3-1,d0
.c6:    move.w (a0)+,(a1)+
        dbra d0,.c6
.ok:    bsr get_alpha
        bsr write_snapshot
        movem.l (sp)+,d0-d7/a0-a3
        rts

;============================================================================
; Replaces "jsr build_car_list" of a new step (SOFTINT masked).

interp_cars:
        movem.l d0-d7/a0-a3,-(sp)
        bsr get_alpha
        bsr cars_body
        movem.l (sp)+,d0-d7/a0-a3
        rts

; D7: alpha. Writes blended positions into the car objects, builds the draw
; list, and puts the real values back. A car whose real values differ from the
; last captured state was moved outside the simulation step and is not blended.
; car_fr: the rest of each blended track position in 1/256 (0 when not
; blended), for the exact cars of the AGA view (car_proj).
cars_body:
        lea car_fr(pc),a0
        moveq #CARS-1,d6
.clr:   sf (a0)+
        dbra d6,.clr
        lea G_CAR_OBJECTS+6,a0
        lea saved_cars(pc),a1
        lea prev_cars(pc),a2
        lea cur_cars(pc),a3
        moveq #CARS-1,d6
.car:   move.w (a0),(a1)+
        move.l 2(a0),(a1)+
        move.w (a0),d0
        cmp.w (a3),d0
        bne.s .next
        move.l 2(a0),d0
        cmp.l 2(a3),d0
        bne.s .next
        move.w (a2),d0                  ; position along the track
        move.w (a3),d1
        bsr lerp_track
        bcs.s .next
        move.w d0,(a0)
        moveq #CARS-1,d5                ; its fraction
        sub.w d6,d5
        move.l a1,-(sp)
        lea car_fr(pc),a1
        move.b d4,(a1,d5.w)
        movea.l (sp)+,a1
        move.w 2(a2),d0                 ; lateral
        move.w 2(a3),d1
        bsr lerp
        move.w d0,2(a0)
        move.w 4(a2),d0                 ; heading
        move.w 4(a3),d1
        bsr lerp
        move.w d0,4(a0)
.next:  lea CAR_SIZE(a0),a0
        addq.l #6,a2
        addq.l #6,a3
        dbra d6,.car
        movem.l d6-d7/a0-a3,-(sp)
        jsr G_BUILD_CARS
        movem.l (sp)+,d6-d7/a0-a3
        lea G_CAR_OBJECTS+6,a0
        lea saved_cars(pc),a1
        moveq #CARS-1,d6
.back:  move.w (a1)+,(a0)
        move.l (a1)+,2(a0)
        lea CAR_SIZE(a0),a0
        dbra d6,.back
        rts

;============================================================================
; D7 = alpha, 0-256: the time since the last step request in 1/256 of a step,
; or 256 while the requested step has not run yet. When frames take less than
; 4 ticks, irq2 runs every step itself at the 4th tick (the request stays set
; and ticks_since_frame restarts at 0); frame_end starts a step only when
; ticks_since_frame has reached 4.

get_alpha:
        move.w #256,d7
        btst #0,G_REQUEST               ; a request that frame_end will turn
        beq.s .read                     ; into a step: the step has not run
        cmpi.w #4,G_TICKS_SINCE
        bhs.s .done
.read:  move.w G_DIVIDER,d1
        move.b CIAA_TBHI,d3
        move.b CIAA_TBLO,d2
        cmp.b CIAA_TBHI,d3
        bne.s .read                     ; high byte changed: read again
        cmp.w G_DIVIDER,d1
        bne.s .read                     ; a tick came in between
        lsl.w #8,d3
        move.b d2,d3
        moveq #0,d2
        move.w d3,d2                    ; timer B count
        moveq #4,d3
        sub.w d1,d3
        bmi.s .done
        mulu.w #TICK,d3                 ; whole ticks
        move.l #TICK,d4
        sub.l d2,d4                     ; part of the current tick
        bmi.s .whole
        add.l d4,d3
.whole: divu.w #(4*TICK+255)/256,d3
        bvs.s .done
        cmp.w d7,d3
        bhi.s .done
        move.w d3,d7
.done:  rts

; Write the blended camera block to render_camera_snapshot. D7: alpha.
; The fractions of the blended x, y and height go to cam_fr (1/256 unit,
; 0 when not blended) with the whole values they belong to (cam_fi).
write_snapshot:
        lea cur_cam(pc),a0
        lea G_SNAPSHOT,a1
        moveq #CAM_BYTES/2-1,d0
.copy:  move.w (a0)+,(a1)+
        dbra d0,.copy
        lea cam_fr(pc),a0
        clr.l (a0)+
        clr.w (a0)
        lea prev_cam(pc),a2
        lea cur_cam(pc),a3
        lea G_SNAPSHOT,a1
        move.w $e(a2),d0                ; track position: a cut when it jumps
        move.w $e(a3),d1
        bsr lerp_track
        bcs.s .done
        move.w d0,$e(a1)
        move.w 2(a3),d0                 ; x and y: a cut when they jump
        sub.w 2(a2),d0
        bsr.s abs_d0
        cmp.w #CAM_SNAP,d0
        bhi.s .cut
        move.w 4(a3),d0
        sub.w 4(a2),d0
        bsr.s abs_d0
        cmp.w #CAM_SNAP,d0
        bhi.s .cut
        lea cam_fr-2(pc),a0
        moveq #2,d5                     ; x, y, height, yaw, pitch, roll,
.word:  cmp.w #$e,d5                    ; lateral, track direction, steering
        beq.s .skip
        move.w (a2,d5.w),d0
        move.w (a3,d5.w),d1
        bsr.s lerp
        move.w d0,(a1,d5.w)
        cmp.w #8,d5
        bcc.s .skip
        move.w d2,(a0,d5.w)             ; x, y, height: the fraction
        move.w d0,6(a0,d5.w)
.skip:  addq.w #2,d5
        cmp.w #$16,d5
        bne.s .word
.done:  rts
.cut:   move.w $e(a3),$e(a1)
        rts

abs_d0: tst.w d0
        bpl.s .p
        neg.w d0
.p:     rts

; D0 = prev, D1 = cur, D7 = alpha: D0 = prev + (cur - prev) * alpha / 256
; rounded down, D2 = the rest in 1/256. Angles wrap correctly through the
; 16 bit difference.
lerp:   sub.w d0,d1
        muls.w d7,d1
        moveq #0,d2
        move.b d1,d2
        asr.l #8,d1
        add.w d1,d0
        rts

; As lerp for positions along the track (0..TRACK_LEN-1, wrapping), D4 = the
; rest in 1/256. Carry set when the move is too large to be motion (D0
; unchanged then).
lerp_track:
        moveq #0,d2
        move.w d1,d2
        moveq #0,d3
        move.w d0,d3
        sub.l d3,d2                     ; cur - prev
        cmp.l #TRACK_LEN/2,d2
        ble.s .lo
        sub.l #TRACK_LEN,d2
.lo:    cmp.l #-TRACK_LEN/2,d2
        bge.s .ok
        add.l #TRACK_LEN,d2
.ok:    move.l d2,d4
        bpl.s .pos
        neg.l d4
.pos:   cmp.l #CAR_SNAP,d4
        bhi.s .cut
        muls.w d7,d2
        moveq #0,d4
        move.b d2,d4
        asr.l #8,d2
        add.l d3,d2
        bpl.s .nn
        add.l #TRACK_LEN,d2
.nn:    cmp.l #TRACK_LEN,d2
        blt.s .in
        sub.l #TRACK_LEN,d2
.in:    move.w d2,d0
        andi.b #$fe,ccr
        rts
.cut:   move.w d1,d0
        ori.b #1,ccr
        rts
