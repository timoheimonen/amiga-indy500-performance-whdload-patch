; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Sparks under the computer cars (sp_off clear): a car that enters one of
; the four zones at the turn entries at racing speed bottoms out there
; with the chance sp_prob / 256 (decided once per pass, sp_st per car
; object) and trails a burst of SP_N sparks. Nothing is stored per spark: its age is the car's
; distance into the zone (track position with the blended fraction) minus
; its birth distance, and its place in the car's axes follows from the
; age, so a burst moves evenly in the interpolated views, stands still in
; the pause and needs no step hook. Each spark is two pixels, the head and
; a dimmer tail 10 units behind it, in the game's white, yellow and orange
; at the levels of the AGA palette.

        machine 68020

SP_N    equ 12                          ; sparks of a burst
SP_PRE  equ 128                         ; a zone starts this far before its
SP_LEN  equ 512                         ; turn and is this long (track units)
SP_VMIN equ $3000                       ; no sparks below this speed (object
                                        ; +$0C; racing about 15 000, the
                                        ; caution limit $1A68)
SP_F0   equ -704                        ; where the sparks start: 44 units
                                        ; behind the car's middle, under its
                                        ; rear end (1/16 unit)
SP_NEAR equ 150*16                      ; nearer: two pixels wide

; car_proj: D0 = the car's track position, D5 = its fraction, -10(A2) =
; the car object c3_obj -> sp_p, the distance along the lap in 1/256 track
; unit, growing as the car drives (as c3_shape counts), and sp_v, its
; speed (0 for the player's car and without an object). No game address
; here: this module lies beyond the reach of the game_refs table. All
; registers kept.
sp_pos: movem.l d1/a0,-(sp)
        moveq #0,d1
        move.w d0,d1
        lsl.l #8,d1
        move.b d5,d1
        neg.l d1
        add.l #$1b12<<8,d1
        bpl.s .p
        add.l #$9ab0<<8,d1
.p:     lea sp_p(pc),a0
        move.l d1,(a0)
        moveq #0,d1
        tst.b c3_obj(pc)
        ble.s .v
        movea.l -10(a2),a0
        move.w $c(a0),d1
.v:     lea sp_v(pc),a0
        move.w d1,(a0)
        movem.l (sp)+,d1/a0
        rts

; c3_car: the car c3_obj at sp_p -> sp_act = its burst (seed with bit 7
; set, 0 none) and sp_s = its distance into the zone. All registers kept.
sp_check:
        movem.l d0-d3/a0-a1,-(sp)
        lea sp_act(pc),a1
        sf (a1)
        tst.b sp_off(pc)
        bne.s .x
        moveq #0,d3
        move.b c3_obj(pc),d3
        ble.s .x                        ; no object, or the player's car
        lea sp_st(pc),a0
        adda.w d3,a0
        move.w sp_v(pc),d0
        cmp.w #SP_VMIN,d0
        bcs.s .slow
        move.l sp_p(pc),d0
        lea sp_zone(pc),a1
        moveq #3,d1
.z:     move.l d0,d2
        sub.l (a1)+,d2
        cmp.l #SP_LEN<<8,d2
        bcs.s .in
        dbra d1,.z
.slow:  sf (a0)                         ; outside the zones, or slow
        bra.s .x
.in:    tst.b (a0)
        bne.s .have
        lea sp_rnd(pc),a1               ; a new pass: sparks or not
        move.w (a1),d1
        mulu.w #$4e6d,d1
        add.w $dff006,d1
        add.w d3,d1
        move.w d1,(a1)
        moveq #1,d0                     ; 1: in the zone without sparks
        lsr.w #8,d1
        cmp.b sp_prob(pc),d1
        bcc.s .set
        move.w (a1),d0
        or.b #$80,d0
.set:   move.b d0,(a0)
.have:  move.b (a0),d0
        bpl.s .x
        lea sp_act(pc),a1
        move.b d0,(a1)
        move.l d2,sp_s-sp_act(a1)
.x:     movem.l (sp)+,d0-d3/a0-a1
        rts
sp_zone:                                ; the turn entries (c3_shape)
        dc.l ($26ac-SP_PRE)<<8
        dc.l ($3de0-SP_PRE)<<8
        dc.l ($7404-SP_PRE)<<8
        dc.l ($8b38-SP_PRE)<<8

; The burst sp_act of the car of c3_m and c3_org into the view bytes.
; All registers kept.
sp_draw:
        movem.l d0-d7/a0/a3-a4,-(sp)
        lea sp_act(pc),a0
        moveq #0,d7
        move.b (a0),d7                  ; the seed
        sf (a0)
        movea.l chunky_base(pc),a3
        lea sp_born(pc),a4
        moveq #SP_N-1,d6
.p:     moveq #0,d0
        move.b (a4)+,d0                 ; born at this distance
        lsl.l #8,d0
        move.l sp_s(pc),d1
        sub.l d0,d1
        bmi.s .next
        lsr.l #8,d1                     ; age: 256 in 256 track units
        cmp.w #256,d1
        bcc.s .next
        move.w d6,d0
        add.w d7,d0
        and.w #31,d0
        lea sp_lat(pc),a0
        move.b (a0,d0.w),d2             ; lateral
        ext.w d2
        moveq #0,d3
        move.b 32(a0,d0.w),d3           ; height of its bounce
        move.w d1,d0
        lsr.w #5,d0
        lea sp_col(pc),a0
        adda.w d0,a0
        move.b 1(a0),d4                 ; the tail
        add.w #16,d1
        bsr.s sp_pt
        sub.w #16,d1
        move.b (a0),d4                  ; the head
        bsr.s sp_pt
.next:  dbra d6,.p
        movem.l (sp)+,d0-d7/a0/a3-a4
        rts

; D1 = age (0-271), D2 = lateral (units), D3 = bounce (units), D4 = colour
; byte, A3 = the view bytes: the spark's point in the car's axes (it falls
; behind by 10/16 unit and spreads by 1/256 per age, and rises and falls
; once), through c3_m to the view, one byte or two side by side. All
; registers kept.
sp_pt:  movem.l d0-d7/a2,-(sp)
        move.b d4,d7
        move.w d2,d4                    ; r = lateral x (256 + age) / 16
        move.w #256,d0
        add.w d1,d0
        muls.w d0,d4
        asr.l #4,d4
        move.w #256,d5                  ; u = 1 + bounce x 4 t (1 - t)
        sub.w d1,d5
        bpl.s .h
        moveq #0,d5
.h:     mulu.w d1,d5
        mulu.w d3,d5
        lsr.l #8,d5
        lsr.l #2,d5
        add.w #16,d5
        move.w d1,d3                    ; f
        mulu.w #10,d3
        neg.w d3
        add.w #SP_F0,d3
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
        moveq #16,d1
        cmp.l d1,d0
        blt .out
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
        move.l d0,d6                    ; inside twice the view
        add.l d6,d6
        move.l d1,d3
        bpl.s .ax
        neg.l d3
.ax:    cmp.l d6,d3
        bgt .out
        move.l d2,d3
        bpl.s .ay
        neg.l d3
.ay:    cmp.l d6,d3
        bgt .out
        muls.l #VIEW_W*8,d1
        divs.l d0,d1
        add.l #VIEW_W*8+8,d1
        asr.l #4,d1                     ; x
        muls.l #62*256,d2
        divs.l d0,d2
        neg.l d2
        add.l #62*256+128,d2
        asr.l #8,d2                     ; y
        cmp.l #VIEW_W-1,d1
        bcc .out
        cmp.l #VIEW_H,d2
        bcc .out
        mulu.w #VIEW_W,d2
        add.l d1,d2
        move.b d7,(a3,d2.l)
        cmp.l #SP_NEAR,d0
        bge .out
        move.b d7,1(a3,d2.l)
.out:   movem.l (sp)+,d0-d7/a2
        rts

sp_born:                                ; SP_N birth distances (track units)
        dc.b 0,21,44,67,88,111,133,158,170,201,219,244
sp_lat: dc.b -7,4,-2,8,1,-9,6,-4,3,-6,9,0,-3,7,-8,2      ; 32 laterals
        dc.b 5,-1,-5,8,-7,3,0,6,-9,2,-4,7,1,-6,4,-2
        dc.b 3,6,2,7,4,1,5,8,2,6,3,7,1,4,8,5              ; 32 bounces
        dc.b 6,2,5,3,7,4,1,8,3,5,2,6,4,7,1,5
sp_col: dc.b $6f,$6e,$6e,$3e,$0e,$06,$06,$c6,$c6,$c6    ; by age / 32: white
        even                            ; and yellow at level 15, yellow at
                                        ; 12 and 9, orange at 9 and 5

        machine 68000
