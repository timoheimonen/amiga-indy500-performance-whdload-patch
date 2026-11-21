; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; fill_checks: the game code the CPU drawing patches, checked before any
; patch. fill_install (from enter_main, slave.s): the hooks by CPU type, the
; background tail on every CPU, the CPU drawing and the chunky view on a
; 68040/060, the deferred line wait on the others.

fill_checks:
        CHECKW F_POLY_FILL,$3c39
        CHECKL F_POLY_FILL+2,G_SPAN_YMAX
        CHECKW F_POLY_FILL+6,$3a39
        CHECKL F_POLY_FILL+8,G_SPAN_YMIN
        CHECKL F_BG_TAIL,$08390006
        CHECKL F_BG_TAIL+4,$00dff002
        CHECKL F_BG_TAIL+18,$23c100df       ; move.l d1,BLTAPT
        CHECKL F_BG_TAIL+42,$33fc090f       ; BLTCON0 = NOT A
        CHECKL F_LINE_DRAW,$2f0233c0
        CHECKL F_LINE_DRAW+4,G_LINE_X1
        CHECKW F_LINE_TAIL,$3039
        CHECKL F_LINE_TAIL+2,G_LINE_X1
        CHECKW F_FILL_PATTERN,$3c39
        CHECKL F_FILL_PATTERN+2,G_SPAN_YMAX
        CHECKW F_FILL_PATTERN+$AA,$d079     ; add.w pattern_x,d0
        CHECKL F_FILL_PATTERN+$AC,G_PATTERN_X
        CHECKW F_FILL_PATTERN+$B2,$d0b9     ; add.l pattern_base,d0
        CHECKL F_FILL_PATTERN+$B4,G_PATTERN_BASE
        CHECKW G_SETPAT_MID-2,$23fc         ; move.l #pattern,pattern_base
        CHECKL G_SETPAT_MID+4,G_PATTERN_BASE
        CHECKW G_SETPAT_LIGHT-2,$23fc
        CHECKL G_SETPAT_LIGHT+4,G_PATTERN_BASE
        CHECKL F_BACKGROUND,$d040d241
        CHECKW F_BACKGROUND+4,$6b00
        CHECKL F_BACKGROUND+8,$343b0080     ; move.w horizon(pc,d0.w),d2
        CHECKL F_BACKGROUND+12,$363b10ba    ; move.w band(pc,d1.w),d3
        CHECKL F_CAR_SPRITE,$48e7003e
        CHECKW F_CAR_SPRITE+4,$33c1
        CHECKL F_CAR_SPRITE+6,G_SPR_Y
        CHECKW F_CAR_SPRITE+$26,$267c
        CHECKL F_CAR_SPRITE+$28,G_SPR_FIRST
        CHECKW F_CAR_SPRITE+$32,$2a7c
        CHECKL F_CAR_SPRITE+$34,G_SPR_OFFSET
        CHECKW F_CAR_SPRITE+$80,$6100       ; bsr set_colour
        CHECKW F_FILL_DITHER,$3c39
        CHECKL F_FILL_DITHER+2,G_SPAN_YMAX
        CHECKW F_FILL_DITHER+$12,$3039      ; move.w dither,d0
        CHECKL F_FILL_DITHER+$14,G_DITHER
        CHECKW F_FILL_DITHER+$2E,$33c0      ; move.w d0,dither_row
        CHECKL F_FILL_DITHER+$30,G_DITHER_ROW
        CHECKW F_VIEW_CALL,$4eb9
        CHECKL F_VIEW_CALL+2,F_VIEW_SETUP
        CHECKW F_CARS_CALL,$4eb9
        CHECKL F_CARS_CALL+2,F_DRAW_CARS
        CHECKW F_DEBRIS_CALL,$4eb9
        CHECKL F_DEBRIS_CALL+2,F_DEBRIS
        CHECKW F_DEBRIS_CALL2,$4eb9
        CHECKL F_DEBRIS_CALL2+2,F_DEBRIS
        CHECKW F_WHEELS_CALL,$4eb9
        CHECKL F_WHEELS_CALL+2,F_WHEELS
        CHECKL F_MASK_BLIT,$33fc0fca
        CHECKL F_MASK_BLIT+4,$00dff040
        CHECKL F_VIEW_DONE,$08390000
        CHECKL F_VIEW_DONE+4,G_VIEW_FLAGS
        CHECKL F_LINE_REGS,$33c100df
        CHECKW F_LINE_REGS+4,$f062
        CHECKL F_LINE_WAIT,$08390006
        CHECKL F_LINE_WAIT+4,$00dff002
        CHECKW F_LINE_WAIT+18,$241f         ; move.l (sp)+,d2
        CHECKL F_FILL_REGS,$317c05ac
        CHECKW F_FILL_REGS+4,$0040
        CHECKL F_PATTERN_REGS,$317c07ac
        CHECKW F_PATTERN_REGS+4,$0040
        CHECKL F_DITHER_REGS,$317c05ac
        CHECKW F_DITHER_REGS+4,$0040
        CHECKL F_POLY_EDGE,$30337808
        CHECKW F_POLY_EDGE+4,$d040
        CHECKL F_POLY_BEGIN,$33fc0400
        CHECKL F_POLY_BEGIN+4,G_SPAN_YMIN
        CHECKW F_REL_BEGIN,$4eb9
        CHECKL F_REL_BEGIN+2,F_POLY_BEGIN
        ifd INTERP
        CHECKL F_XT_X,$d040e240         ; add.w d0,d0; asr.w #1,d0
        CHECKW F_XT_X+4,$9079           ; sub.w view_cam_pos,d0
        CHECKL F_XT_X+6,G_CAM_POS
        CHECKW F_XT_X+$3E,$3819         ; move.w (a1)+,d4
        CHECKL F_XT_Y,$d040e240
        CHECKW F_XT_Y+4,$9079
        CHECKL F_XT_Y+6,G_CAM_POS+2
        CHECKW F_XT_Y+$3E,$d859         ; add.w (a1)+,d4
        CHECKL F_XT_Z,$d040e240
        CHECKW F_XT_Z+4,$9079
        CHECKL F_XT_Z+6,G_CAM_POS+4
        CHECKW F_XT_Z+$3E,$d859
        CHECKW F_XW_SUM,$3039           ; move.w view_matrix+2,d0
        CHECKL F_XW_SUM+2,G_VIEW_MATRIX+2
        CHECKL F_XW_SUM+$6A,$e5844844   ; asl.l #2,d4; swap d4
        CHECKL F_XW_SUM+$72,$70004444   ; moveq #0,d0; neg.w d4
        CHECKL F_SINCOS,$0640001f       ; addi.w #$1f,d0
        CHECKW F_VS_YAW,$4eb9
        CHECKL F_VS_YAW+2,F_SINCOS
        CHECKW F_VS_ROLL,$4eb9
        CHECKL F_VS_ROLL+2,F_SINCOS
        CHECKW F_VS_PITCH,$4eb9
        CHECKL F_VS_PITCH+2,F_SINCOS
        CHECKW F_BG_CHOICE,$3039        ; move.w pitch,d0
        CHECKL F_BG_CHOICE+2,G_SNAPSHOT+$A
        CHECKW F_BG_CHOICE+$30,$4eb9    ; jsr background
        CHECKL F_BG_CHOICE+$32,F_BACKGROUND
        CHECKW F_BG_CHOICE+$38,$247c    ; movea.l #streams,a2
        CHECKW F_BG_CHOICE+$50,$13fc    ; the code after the background
        CHECKW F_LINES_TRACK+$42,$33c6  ; move.w d6,G_LINE_PREV
        CHECKL F_PAT_A,$0c790000        ; cmpi.w #0,race_mode
        CHECKL F_PAT_A+4,G_RACE_MODE
        CHECKL F_PAT_A+8,$6700fe8e      ; beq.w shape_polys_track
        CHECKW F_PAT_A+12,$600c         ; bra.s the pattern polygons
        CHECKL F_PAT_B,$0c790002        ; cmpi.w #2,race_mode
        CHECKL F_PAT_B+4,G_RACE_MODE
        CHECKL F_PAT_B+8,$6600fe80      ; bne.w shape_polys_track
        CHECKL F_PAT_BODY,$70007400     ; moveq #0,d0; moveq #0,d2
        CHECKL F_POLYS_TRACK,$70007400
        CHECKL F_LINES_TRACK+$44,G_LINE_PREV
        CHECKW F_LINE_PAIRS+$12,$33c6
        CHECKL F_LINE_PAIRS+$14,G_LINE_PREV
        CHECKL F_DRAW_CAR,$205a301a     ; draw_car: car, track position,
        CHECKW F_DRAW_CAR+4,$321a       ; lateral from the list entry
        LSJSR F_CAR_PROJ,F_XFORM_SKY
        CHECKL F_CAR_COLS,$33e8001a     ; move.w $1a(a0),G_CAR_COLS
        CHECKL F_CAR_COLS+4,G_CAR_COLS
        CHECKL F_AERIAL_COLS,$33e8001a
        CHECKL F_AERIAL_COLS+4,G_CAR_COLS
        CHECKW F_SHAPE_TAB,$227c        ; track_shape_at: the bank table
        CHECKL F_SHAPE_TAB+2,G_BANK_TAB
        CHECKW F_TRACK_TO_WORLD,$e841   ; asr.w #4,d1
        CHECKW F_TRACK_TO_WORLD+$44,$33c1
        CHECKL F_TRACK_TO_WORLD+$46,G_T2W
        CHECKW F_XFORM_SKY+$12,$3239
        CHECKL F_XFORM_SKY+$14,G_T2W
        LSJSR F_LINES_TRACK+$3A,F_XFORM_TRACK ; second and later vertices
        LSJSR F_LINES_TRACK+$98,F_XFORM_TRACK
        LSJSR F_LINES_WORLD+$3A,F_XFORM_WORLD
        LSJSR F_LINES_WORLD+$98,F_XFORM_WORLD
        LSJSR F_LINES_REL+$3A,F_XFORM_REL
        LSJSR F_LINES_REL+$98,F_XFORM_REL
        LSJSR F_LINE_PAIRS+$28,F_XFORM_TRACK
        LSJSR F_LINE_PAIRS+$4E,F_XFORM_TRACK
        LSJSR F_LINES_TRACK+$50,F_LINE_DRAW ; line_draw_to
        LSJSR F_LINES_TRACK+$80,F_LINE_DRAW
        LSJSR F_LINES_TRACK+$C8,F_LINE_DRAW
        LSJSR F_LINES_TRACK+$11E,F_LINE_DRAW
        LSJSR F_LINES_WORLD+$50,F_LINE_DRAW
        LSJSR F_LINES_WORLD+$80,F_LINE_DRAW
        LSJSR F_LINES_WORLD+$C8,F_LINE_DRAW
        LSJSR F_LINES_WORLD+$11E,F_LINE_DRAW
        LSJSR F_LINES_REL+$50,F_LINE_DRAW
        LSJSR F_LINES_REL+$80,F_LINE_DRAW
        LSJSR F_LINES_REL+$C8,F_LINE_DRAW
        LSJSR F_LINES_REL+$11E,F_LINE_DRAW
        LSJSR F_LINE_PAIRS+$38,F_LINE_DRAW
        LSJSR F_LINE_PAIRS+$82,F_LINE_DRAW
        LSJSR F_LINE_PAIRS+$C4,F_LINE_DRAW
        endif
        dc.l 0

fill_install:
        lea fill_checks(pc),a0
        bsr check_sites
        bne wrong_version
        lea cpu_background_tail(pc),a0
        move.w #$4ef9,F_BG_TAIL
        move.l a0,F_BG_TAIL+2
        move.w #$4e71,F_BG_TAIL+6
        ; The polygon fill and the lines are faster than the blits only on a
        ; 68040 or 68060 (on the 68020 the lines are slower, the fill equal).
        move.l attn_flags(pc),d0
        btst #AFB_68040,d0
        bne.s .fast
        btst #AFB_68060,d0
        beq .blits
.fast:  lea cpu_poly_fill(pc),a0
        move.w #$4ef9,F_POLY_FILL
        move.l a0,F_POLY_FILL+2
        lea cpu_line_draw(pc),a0
        move.w #$4ef9,F_LINE_DRAW
        move.l a0,F_LINE_DRAW+2
        lea cpu_pattern_fill(pc),a0
        move.w #$4ef9,F_FILL_PATTERN
        move.l a0,F_FILL_PATTERN+2
        lea cpu_dither_fill(pc),a0
        move.w #$4ef9,F_FILL_DITHER
        move.l a0,F_FILL_DITHER+2
        lea cpu_car_sprite(pc),a0
        move.w #$4ef9,F_CAR_SPRITE
        move.l a0,F_CAR_SPRITE+2
        lea cpu_background(pc),a0
        move.w #$4ef9,F_BACKGROUND
        move.l a0,F_BACKGROUND+2
        lea fast_view_begin(pc),a0
        move.l a0,F_VIEW_CALL+2
        lea fast_view_cars(pc),a0
        move.l a0,F_CARS_CALL+2
        lea fast_view_debris(pc),a0
        move.l a0,F_DEBRIS_CALL+2
        lea fast_view_wheels(pc),a0
        move.l a0,F_WHEELS_CALL+2
        lea fast_view_outside(pc),a0
        move.l a0,F_DEBRIS_CALL2+2
        lea mask_blit(pc),a0
        move.w #$4ef9,F_MASK_BLIT
        move.l a0,F_MASK_BLIT+2
        move.w #$4e71,F_MASK_BLIT+6
        move.l expmem(pc),d0
        add.l #CHUNKY_OFF,d0
        lea chunky_base(pc),a0
        move.l d0,(a0)
        ifd INTERP
        bsr aga_install
        endif
        bra chunky_tables
        ; Other CPUs keep the blits; in the 3D view the last line blit runs
        ; while the CPU goes on (blit_defer).
.blits: lea defer_begin(pc),a0
        move.l a0,F_VIEW_CALL+2
        lea defer_end(pc),a0
        move.w #$4eb9,F_VIEW_DONE
        move.l a0,F_VIEW_DONE+2
        move.w #$4e71,F_VIEW_DONE+6
        lea sync_line(pc),a0
        move.w #$4eb9,F_LINE_REGS
        move.l a0,F_LINE_REGS+2
        lea line_end(pc),a0
        move.w #$4eb9,F_LINE_WAIT
        move.l a0,F_LINE_WAIT+2
        move.w #$600a,F_LINE_WAIT+6     ; bra.b to move.l (sp)+,d2
        lea sync_fill(pc),a0
        move.w #$4eb9,F_FILL_REGS
        move.l a0,F_FILL_REGS+2
        move.w #$4eb9,F_DITHER_REGS
        move.l a0,F_DITHER_REGS+2
        lea sync_pattern(pc),a0
        move.w #$4eb9,F_PATTERN_REGS
        move.l a0,F_PATTERN_REGS+2
        rts
