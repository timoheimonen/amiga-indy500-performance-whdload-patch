; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; AGA display (68040/060 with AGA, --interp --cpufill). Each of the three
; draw buffers (BUF0, BUF1, BUF3 of the triple buffering) gets its own copper
; list and 4 extra planes for the 3D view rows in chip memory the game leaves
; unused ($28000-$630C3 stays zero in the WHDLoad layout). The list shows
; rows 0-23 and 148-199 as before (4 planes) and rows 24-147 with 8 planes:
; planes 0-3 from the draw buffer, planes 4-7 from the extra planes. A buffer
; is shown with its list only while its 3D view was drawn as bytes and
; written by c2p_view8 (aga_drawn); otherwise the game's list as before.
; Colours 0-15 stay the game's: the VBL handler and the fades write them,
; and colours 1-3 are copied from the game's list into the three lists at
; every VBL. Colours 16-255 repeat colours 0-15 (aga_palette).

AGA_CHIP        equ $28000          ; extra planes of BUF0, BUF1, BUF3
AGA_XPLANE      equ VIEW_H*40       ; one extra plane (the view rows)
AGA_XBUF        equ 4*AGA_XPLANE
AGA_LISTS       equ AGA_CHIP+3*AGA_XBUF
AGA_LIST        equ $60             ; bytes per copper list
AGA_ROW24       equ $44             ; beam line of row 24 (DIWSTRT $2C81)
AGA_ROW148      equ $C0
G_PALETTE       equ G+$C17222       ; colour count - 1, colours
F_VBL_COP1LC    equ G+$C13EEE       ; VBL handler: move.l d0,$dff080

aga_hw:         dc.b 0              ; AGA display possible
aga_on:         dc.b 0              ; lists built, in use
aga_drawn:      ds.b 3              ; per buffer: view rows drawn as bytes
        even

; Extra planes of draw buffer A1. Returns A1 = its planes, D1 = its index
; (0-2), or N set when A1 is not one of the three buffers.
aga_find:
        moveq #0,d1
        cmpa.l #BUF0,a1
        beq.s .ok
        moveq #1,d1
        cmpa.l #BUF1,a1
        beq.s .ok
        moveq #2,d1
        cmpa.l #BUF3,a1
        beq.s .ok
        moveq #-1,d1
        rts
.ok:    movea.w d1,a1
        mulu #AGA_XBUF,d1
        exg d1,a1
        adda.l #AGA_CHIP,a1
        tst.w d1
        rts

; From fast_view_begin: the back buffer's view is drawn anew.
aga_drawn_clear:
        movem.l d1/a1,-(sp)
        movea.l G_DRAW_BACK,a1
        bsr aga_find
        bmi.s .no
        lea aga_drawn(pc),a1
        sf (a1,d1.w)
.no:    movem.l (sp)+,d1/a1
        rts

; Writes COP1LC for the buffer in G_FRONT. D0: the game's copper list of
; that buffer. All registers kept.
aga_cop1lc:
        movem.l d0-d1/a1,-(sp)
        btst #0,aga_on(pc)
        beq.s .set
        movea.l G_FRONT,a1
        bsr aga_find
        bmi.s .set
        lea aga_drawn(pc),a1
        tst.b (a1,d1.w)
        beq.s .set
        mulu #AGA_LIST,d1
        add.l #AGA_LISTS,d1
        move.l d1,d0
.set:   move.l d0,$dff080
        movem.l (sp)+,d0-d1/a1
        rts

; From tb_vbl at every VBL: colours 1-3 of the game's lists into the three,
; colours 16-255 when the palette changed.
aga_colours:
        btst #0,aga_on(pc)
        beq.s .no
        bsr aga_palette
        movem.l d0/a0-a1,-(sp)
        lea COPPER2+$22,a0
        lea AGA_LISTS+$22,a1
        moveq #2,d0
.list:  move.w (a0),(a1)
        move.w 4(a0),4(a1)
        move.w 8(a0),8(a1)
        lea AGA_LIST(a1),a1
        dbra d0,.list
        movem.l (sp)+,d0/a0-a1
.no:    rts

; From tb_transition: no buffer holds a view drawn as bytes.
aga_reset:
        move.l a0,-(sp)
        lea aga_drawn(pc),a0
        sf (a0)+
        sf (a0)+
        sf (a0)
        movea.l (sp)+,a0
        rts

; From tb_activate: BUF3 is a copy without extra planes, and the palette
; banks get the current colours.
aga_activate:
        btst #0,aga_hw(pc)
        beq.s .no
        move.l a0,-(sp)
        btst #0,aga_on(pc)
        bne.s .built
        bsr aga_build
.built: lea aga_drawn+2(pc),a0
        sf (a0)
        movea.l (sp)+,a0
.no:    rts

; From aga_colours at every VBL: when the game's palette table changed (a
; fade step) or after tb_activate, colours 16-255 are written again (24 bit,
; level_colours). Nothing is written while the table holds 32 colours
; (pictures use colours 16-31). Only the VBL writes BPLCON3, so the bank
; selection cannot be interrupted.
aga_palette:
        movem.l d0-d6/a0-a3,-(sp)
        lea G_PALETTE,a0
        cmpi.w #15,(a0)+
        beq.s .c16
        lea aga_dirty(pc),a1            ; 32 colours (a picture): its colours
        st (a1)                         ; 16-31 stay, written again later
        bra .done
.c16:
        lea aga_pal(pc),a1
        moveq #15,d1
        moveq #0,d2
.cmp:   move.w (a0)+,d0
        cmp.w (a1),d0
        beq.s .same
        move.w d0,(a1)
        moveq #1,d2
.same:  addq.l #2,a1
        dbra d1,.cmp
        lea aga_dirty(pc),a1
        or.b (a1),d2
        beq .done
        sf (a1)
        lea aga_pal(pc),a0
        bsr sky_colours
        bsr level_colours
        lea $dff000,a2
        lea pal_hi(pc),a0
        lea pal_lo(pc),a1
        moveq #0,d0                     ; bank
.bank:  move.w d0,d1
        ror.w #3,d1                     ; bank in bits 15-13
        ori.w #$0c00,d1
        moveq #0,d2                     ; first register
        tst.w d0
        bne.s .all
        moveq #16,d2                    ; colours 0-15 are the game's
.all:   move.w d1,$106(a2)
        bsr.s .regs                     ; high nibbles (low ones copied)
        exg a0,a1
        ori.w #$0200,d1                 ; LOCT: low nibbles
        move.w d1,$106(a2)
        bsr.s .regs
        exg a0,a1
        lea 64(a0),a0
        lea 64(a1),a1
        addq.w #1,d0
        cmp.w #8,d0
        bne.s .bank
        move.w #$0c00,$106(a2)
.done:  movem.l (sp)+,d0-d6/a0-a3
        rts
; Registers D2-31 of the bank from the 32 words at A0.
.regs:  move.w d2,d3
        add.w d3,d3
        lea $180(a2),a3
        adda.w d3,a3
.reg:   move.w (a0,d3.w),(a3)+
        addq.w #2,d3
        cmp.w #64,d3
        bne.s .reg
        rts

; Colours 16-255 into pal_hi and pal_lo (high and low nibbles of 8 bit
; guns) from the palette at A0: 16 r + 11 the sky levels (sky_colours),
; 16 r + 1-3 copies of colours 1-3 (they rotate), the others colour c at
; the brightness of texture level (r + 9) & 15 (level_tab).
level_colours:
        movem.l d0-d7/a1-a4,-(sp)
        lea pal_hi+32(pc),a1
        lea pal_lo+32(pc),a2
        lea level_tab+16(pc),a3
        moveq #1,d7                     ; r
.r:     moveq #0,d6                     ; c
.c:     move.w d6,d0
        add.w d0,d0
        move.w (a0,d0.w),d0             ; colour c
        cmp.w #11,d6
        beq.s .sky
        cmp.w #4,d6
        bcc.s .lev
        tst.w d6
        beq.s .lev
        move.w d0,(a1)+
        move.w d0,(a2)+
        bra.s .next
.sky:   move.w d7,d0
        add.w d0,d0
        lea sky_high(pc),a4
        move.w (a4,d0.w),(a1)+
        lea sky_low(pc),a4
        move.w (a4,d0.w),(a2)+
        bra.s .next
.lev:   moveq #0,d1                     ; high nibbles
        moveq #0,d2                     ; low nibbles
        moveq #8,d5                     ; R, G, B
.gun:   move.w d0,d4
        lsr.w d5,d4
        andi.w #15,d4
        moveq #0,d3
        move.b (a3,d4.w),d3             ; 8 bit gun
        lsl.w #4,d1
        lsl.w #4,d2
        move.w d3,d4
        lsr.w #4,d4
        or.w d4,d1
        andi.w #15,d3
        or.w d3,d2
        subq.w #4,d5
        bpl.s .gun
        move.w d1,(a1)+
        move.w d2,(a2)+
.next:  addq.w #1,d6
        cmp.w #16,d6
        bne.s .c
        lea 16(a3),a3
        addq.w #1,d7
        cmp.w #16,d7
        bne.s .r
        movem.l (sp)+,d0-d7/a1-a4
        rts

; Sky gradient from the palette at A0 (16 words): level k = 0 (horizon) to
; 15 (top). Level 0 is half way from colour 11 to colour 15, level 4 is
; colour 11 itself, level 15 half way to colour 9; linear in 8 bits per gun
; between them. Built from the current palette, so it follows the fades.
; Writes sky_high and sky_low per r = 1-15 (the register 16 r + 11).
sky_colours:
        lea sky_rgb(pc),a1
        moveq #8,d6                     ; shift of the gun: R, G, B
.gun:   move.w 11*2(a0),d0
        lsr.w d6,d0
        andi.w #15,d0
        mulu #17,d0                     ; C: colour 11
        move.w 15*2(a0),d1
        lsr.w d6,d1
        andi.w #15,d1
        mulu #17,d1
        add.w d0,d1
        lsr.w #1,d1                     ; H: horizon
        move.w 9*2(a0),d2
        lsr.w d6,d2
        andi.w #15,d2
        mulu #17,d2
        add.w d0,d2
        lsr.w #1,d2                     ; Z: top
        move.b sky_flat(pc),d3
        beq.s .grad
        move.w d0,d1                    ; flat: all levels colour 11
        move.w d0,d2
.grad:
        moveq #0,d3                     ; level
.lo:    move.w d0,d4                    ; H + (C - H) k / 4
        sub.w d1,d4
        muls.w d3,d4
        asr.w #2,d4
        add.w d1,d4
        move.b d4,(a1,d3.w)
        addq.w #1,d3
        cmp.w #5,d3
        bne.s .lo
.hi:    move.w d3,d5                    ; C + (Z - C) (k - 4) / 11
        subq.w #4,d5
        move.w d2,d4
        sub.w d0,d4
        muls.w d5,d4
        divs.w #11,d4
        add.w d0,d4
        move.b d4,(a1,d3.w)
        addq.w #1,d3
        cmp.w #16,d3
        bne.s .hi
        lea 16(a1),a1
        subq.w #4,d6
        bpl.s .gun
        ; words for the registers: r = 1-4 levels 0-3, r = 5-15 levels 5-15
        lea sky_rgb(pc),a1
        lea sky_high+2(pc),a2
        lea sky_low+2(pc),a3
        moveq #1,d3                     ; r
.word:  move.w d3,d5                    ; level
        cmp.w #5,d5
        bcc.s .k
        subq.w #1,d5
.k:     moveq #0,d0                     ; high nibbles
        moveq #0,d1                     ; low nibbles
        moveq #2,d6
.g:     lsl.w #4,d0
        lsl.w #4,d1
        moveq #0,d2
        move.b (a1,d5.w),d2
        moveq #15,d4
        and.w d2,d4
        or.w d4,d1
        lsr.w #4,d2
        or.w d2,d0
        lea 16(a1),a1
        dbra d6,.g
        lea -48(a1),a1
        move.w d0,(a2)+
        move.w d1,(a3)+
        addq.w #1,d3
        cmp.w #16,d3
        bne.s .word
        rts

; At install on a 68040/060: AGA (LISAID $F8) and chunky view enabled.
; Takes over the VBL handler's COP1LC write; the lists come later
; (aga_build), as the chip memory they use may still hold the loader's data.
aga_install:
        movem.l d0-d1/a0,-(sp)
        btst #0,chunky_enable(pc)
        beq .no
        moveq #15,d1
.id:    move.w $dff07c,d0
        cmp.b #$f8,d0
        bne .no
        dbra d1,.id
        lea aga_cop1lc(pc),a0           ; replaces move.l d0,$dff080
        move.w #$4eb9,F_VBL_COP1LC
        move.l a0,F_VBL_COP1LC+2
        lea aga_hw(pc),a0
        st (a0)
        lea pe_edge(pc),a0              ; corners of each polygon
        move.w #$4ef9,F_POLY_EDGE
        move.l a0,F_POLY_EDGE+2
        lea pe_begin(pc),a0
        move.w #$4ef9,F_POLY_BEGIN
        move.l a0,F_POLY_BEGIN+2
        lea pe_begin_rel(pc),a0
        move.l a0,F_REL_BEGIN+2
        lea xt_x(pc),a0                 ; the transforms round to nearest
        move.w #$4eb9,F_XT_X
        move.l a0,F_XT_X+2
        move.w #$6036,F_XT_X+6          ; bra.s to the block's end
        lea xt_y(pc),a0
        move.w #$4eb9,F_XT_Y
        move.l a0,F_XT_Y+2
        move.w #$6036,F_XT_Y+6
        lea xt_z(pc),a0
        move.w #$4eb9,F_XT_Z
        move.l a0,F_XT_Z+2
        move.w #$6036,F_XT_Z+6
        lea xw_sum(pc),a0
        move.w #$4ef9,F_XW_SUM
        move.l a0,F_XW_SUM+2
        lea view_sincos(pc),a0          ; the view from the full angles
        move.l a0,F_VS_YAW+2
        move.l a0,F_VS_ROLL+2
        move.l a0,F_VS_PITCH+2
        lea bg_choose(pc),a0            ; the background at any angle
        move.w #$4eb9,F_BG_CHOICE
        move.l a0,F_BG_CHOICE+2
        move.l #$6748602e,F_BG_CHOICE+6 ; beq.s after it, bra.s streams
        lea lx_track(pc),a0             ; lines from the exact ends
        move.l a0,F_LINES_TRACK+$3A+2
        move.l a0,F_LINES_TRACK+$98+2
        move.l a0,F_LINE_PAIRS+$28+2
        move.l a0,F_LINE_PAIRS+$4E+2
        lea lx_world(pc),a0
        move.l a0,F_LINES_WORLD+$3A+2
        move.l a0,F_LINES_WORLD+$98+2
        lea lx_rel(pc),a0
        move.l a0,F_LINES_REL+$3A+2
        move.l a0,F_LINES_REL+$98+2
        lea car_proj(pc),a0             ; cars from their exact positions
        move.l a0,F_CAR_PROJ+2
        lea liv_set(pc),a0              ; the cars' team liveries
        move.w #$4eb9,F_CAR_COLS
        move.l a0,F_CAR_COLS+2
        move.w #$4e71,F_CAR_COLS+6
        move.w #$4eb9,F_AERIAL_COLS
        move.l a0,F_AERIAL_COLS+2
        move.w #$4e71,F_AERIAL_COLS+6
        lea ls_draw(pc),a0
        move.l a0,F_LINES_TRACK+$50+2
        move.l a0,F_LINES_TRACK+$80+2
        move.l a0,F_LINES_TRACK+$C8+2
        move.l a0,F_LINES_TRACK+$11E+2
        move.l a0,F_LINES_WORLD+$50+2
        move.l a0,F_LINES_WORLD+$80+2
        move.l a0,F_LINES_WORLD+$C8+2
        move.l a0,F_LINES_WORLD+$11E+2
        move.l a0,F_LINES_REL+$50+2
        move.l a0,F_LINES_REL+$80+2
        move.l a0,F_LINES_REL+$C8+2
        move.l a0,F_LINES_REL+$11E+2
        move.l a0,F_LINE_PAIRS+$38+2
        move.l a0,F_LINE_PAIRS+$82+2
        move.l a0,F_LINE_PAIRS+$C4+2
        bsr tex_build
        bsr c2p_t2_build
        bsr sky_pt_build
        lea fence_flush(pc),a0          ; fences before the cars
        move.w #$4eb9,F_VIEW_DONE
        move.l a0,F_VIEW_DONE+2
        move.w #$4e71,F_VIEW_DONE+6
.no:    movem.l (sp)+,d0-d1/a0
        rts

; At the first view drawn as bytes (or the first tb_activate): clears the
; extra planes, builds the three lists and turns the AGA display on; the
; next VBL writes colours 16-255.
aga_build:
        movem.l d0-d4/a0-a2,-(sp)
        lea AGA_CHIP,a0
        move.w #3*AGA_XBUF/4-1,d0
.clr:   clr.l (a0)+
        dbra d0,.clr
        lea aga_bufs(pc),a2
        lea AGA_LISTS,a0
        moveq #2,d3
.list:  move.l (a2)+,d0                 ; draw buffer
        move.w #$e0,d1
        bsr.s .ptrs
        move.l #$01820000,(a0)+
        move.l #$01840000,(a0)+
        move.l #$01860000,(a0)+
        move.l #AGA_ROW24<<24|$01fffe,(a0)+
        move.l #$01000210,(a0)+         ; 8 planes
        move.l (a2)+,d0                 ; extra planes
        move.w #$f0,d1
        bsr.s .ptrs
        move.l #AGA_ROW148<<24|$01fffe,(a0)+
        move.l #$01004200,(a0)+         ; 4 planes
        move.l #$fffffffe,(a0)+
        dbra d3,.list
        lea aga_dirty(pc),a0
        st (a0)
        lea aga_on(pc),a0
        st (a0)
        movem.l (sp)+,d0-d4/a0-a2
        rts
; D0: first plane, D1: register of its high word; 4 planes in steps of
; the plane size of D0's kind (a draw buffer or the extra planes).
.ptrs:  move.l #PLANE,d2
        cmp.w #$e0,d1
        beq.s .p
        move.l #AGA_XPLANE,d2
.p:     moveq #3,d4
        bra.s .first
.ptr:   add.l d2,d0
.first: swap d0
        move.w d1,(a0)+
        move.w d0,(a0)+
        swap d0
        addq.w #2,d1
        move.w d1,(a0)+
        move.w d0,(a0)+
        addq.w #2,d1
        dbra d4,.ptr
        rts

aga_bufs:
        dc.l BUF0,AGA_CHIP
        dc.l BUF1,AGA_CHIP+AGA_XBUF
        dc.l BUF3,AGA_CHIP+2*AGA_XBUF
