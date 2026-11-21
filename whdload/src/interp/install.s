; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; interp_checks: the game code the interpolated rendering patches, checked
; before any patch. interp_install (from enter_main, slave.s) sets the hooks.

interp_checks:
        CHECKW F_LOOP_TOP,$3039
        CHECKL F_LOOP_TOP+2,G_STEP_COUNTER
        CHECKW F_LOOP_TOP+6,$67f8
        CHECKL F_SNAPSHOT,$343c0005
        CHECKW F_CAR_LIST,$4eb9
        CHECKL F_CAR_LIST+2,G_BUILD_CARS
        CHECKL F_RENDER,$4cb9003f
        CHECKW F_FRAME_END_RET-6,$4eb9
        CHECKL F_FRAME_END_RET-4,F_FRAME_END
        CHECKL F_FRAME_END,$08390000
        CHECKL F_FRAME_END+4,G_NO_SWAP
        CHECKL F_VBL_SWAP,$08b90000
        CHECKL F_VBL_SWAP+4,G_SWAP
        CHECKW F_VBL_SWAP+8,$673c
        CHECKL F_TRANSITION,$d040d040
        CHECKW F_TRANSITION+4,$33fc
        CHECKL F_TRANSITION+8,G_FADE_COUNT
        CHECKW F_GAUGE_LOAD,$2079
        CHECKL F_GAUGE_LOAD+2,G_GAUGE_PTR
        CHECKW F_GAUGE_INIT,$23fc
        CHECKL F_GAUGE_INIT+2,G_GAUGES0
        CHECKL F_GAUGE_INIT+6,G_GAUGE_PTR
        CHECKL F_COCKPIT_DRAWN,$33fc0100
        CHECKL F_COCKPIT_DRAWN+4,$00dff040
        CHECKW F_HUD_BAND,$4eb9
        CHECKL F_HUD_BAND+2,G_BAND_COPY
        dc.l 0

interp_install:
        lea interp_checks(pc),a0
        bsr check_sites
        bne wrong_version
        lea interp_loop_top(pc),a0
        move.w #$4eb9,F_LOOP_TOP
        move.l a0,F_LOOP_TOP+2
        move.w #$4e71,F_LOOP_TOP+6
        lea interp_new_step(pc),a0
        move.w #$4eb9,F_SNAPSHOT
        move.l a0,F_SNAPSHOT+2
        move.w #$6000|(F_SNAPSHOT_END-F_SNAPSHOT-8),F_SNAPSHOT+6  ; bra.b
        lea interp_cars(pc),a0
        move.l a0,F_CAR_LIST+2
        lea tb_frame_end(pc),a0
        move.w #$4ef9,F_FRAME_END
        move.l a0,F_FRAME_END+2
        move.w #$4e71,F_FRAME_END+6
        lea tb_vbl(pc),a0
        move.w #$4eb9,F_VBL_SWAP
        move.l a0,F_VBL_SWAP+2
        move.w #$4e71,F_VBL_SWAP+6
        lea tb_transition(pc),a0
        move.w #$4ef9,F_TRANSITION
        move.l a0,F_TRANSITION+2
        lea tb_gauges(pc),a0
        move.w #$4eb9,F_GAUGE_LOAD
        move.l a0,F_GAUGE_LOAD+2
        lea tb_gauge_init(pc),a0
        move.w #$4eb9,F_GAUGE_INIT
        move.l a0,F_GAUGE_INIT+2
        move.l #$4e714e71,F_GAUGE_INIT+6
        lea tb_cockpit_drawn(pc),a0
        move.w #$4eb9,F_COCKPIT_DRAWN
        move.l a0,F_COCKPIT_DRAWN+2
        move.w #$4e71,F_COCKPIT_DRAWN+6
        lea tb_band(pc),a0
        move.l a0,F_HUD_BAND+2
        rts
