; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Triple buffering. Buffers and copper lists move in pairs between front
; (G_FRONT, shown), back (G_BACK, drawn), and pending (finished, shown at the
; next VBL) or free. The game's own swap flag is not used while it is on.

; COP1LC = D0 (the copper list of the buffer in G_FRONT); the slave's AGA
; list of that buffer instead when it has one (aga_cop1lc, aga/display.s).
COP1LC  macro
        ifd CPUFILL
        bsr aga_cop1lc
        else
        move.l d0,$dff080
        endif
        endm

TB_PEND         equ 0
TB_PEND_COP     equ 4
TB_FREE         equ 8
TB_FREE_COP     equ 12
TB_ON           equ 16              ; byte
TB_COCKPIT      equ 20              ; cockpit picture for the third buffer

; Entry of frame_end (jmp). Triple buffering in the frame loop's in-car mode,
; the game's frame_end everywhere else.
tb_frame_end:
        movem.l d0-d3/a0-a2,-(sp)
        lea tb_vars(pc),a2
        cmpi.l #F_FRAME_END_RET,7*4(sp)
        bne.s .classic
        btst #0,G_NO_SWAP
        bne.s .classic
        btst #0,G_DEMO
        bne.s .classic
        btst #1,G_MODE
        bne.s .classic
        lea valid(pc),a0
        tst.b (a0)
        beq.s .classic
        tst.b TB_ON(a2)
        bne.s .on
        bsr tb_activate
        tst.b TB_ON(a2)
        beq.s .orig
.on:    movem.l (sp)+,d0-d3/a0-a2
        bra.s tb_end_frame
.classic:
        bsr tb_deactivate
.orig:  movem.l (sp)+,d0-d3/a0-a2
        btst #0,G_NO_SWAP               ; the replaced instruction
        jmp F_FRAME_END+8

; frame_end with triple buffering: as the game's, but the finished frame
; becomes pending and drawing goes on in the free buffer at once.
tb_end_frame:
        movem.l d2-d3/a2,-(sp)
        jsr G_FE_TEXT
        jsr G_FE_HUD
        cmpi.w #4,G_TICKS_SINCE
        bcs.s .wait
        bclr #0,G_REQUEST
        beq.s .wait
        move.w #$8004,$dff09c           ; start the step (SOFTINT)
.wait:  lea tb_vars(pc),a2
.busy:  tst.l TB_PEND(a2)               ; the frame before is not shown yet
        bne.s .busy
        move.w sr,-(sp)
        move.w #$2700,sr
        move.l G_BACK,d2
        move.l d2,TB_PEND(a2)
        move.l G_BACK_COP,TB_PEND_COP(a2)
        move.l TB_FREE(a2),G_BACK
        move.l TB_FREE_COP(a2),G_BACK_COP
        clr.l TB_FREE(a2)
        move.w (sp)+,sr
        move.l G_COCKPIT_SRC,d1         ; as the game after its swap; the
        beq.s .again                    ; game has drawn it into two buffers,
        clr.l G_COCKPIT_SRC             ; so the next frame gets it as well
        move.l d1,TB_COCKPIT(a2)
        bra.s .pic
.again: move.l TB_COCKPIT(a2),d1
        beq.s .band
        clr.l TB_COCKPIT(a2)
.pic:   movea.l d1,a0
        movea.l G_BACK,a1
        moveq #3,d0
.plane: adda.w #$1720,a1
        move.w #$207,d1
.copy:  move.l (a0)+,(a1)+
        dbra d1,.copy
        dbra d0,.plane
        bsr tb_gauges_clear             ; no gauge drawn in it now
.band:  move.l attn_flags(pc),d0        ; status band rows 0-23 from the
        btst #AFB_68040,d0              ; finished frame (the game copies
        bne.s .bcpu                     ; from the front after its swap).
        btst #AFB_68060,d0              ; On a 68040/060 the CPU copies it
        beq.s .bblt                     ; (the four blits are 1.1 ms of
.bcpu:  btst #6,$dff002                 ; waiting) and leaves the blitter
.bw0:   btst #6,$dff002                 ; registers as the blits do
        bne.s .bw0
        movea.l d2,a0
        movea.l G_BACK,a1
        moveq #3,d3
.bpl:   moveq #BAND_LEN/32-1,d0
.bcp:   move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        dbra d0,.bcp
        lea PLANE-BAND_LEN(a0),a0
        lea PLANE-BAND_LEN(a1),a1
        dbra d3,.bpl
        lea -(PLANE-BAND_LEN)(a0),a0
        lea -(PLANE-BAND_LEN)(a1),a1
        move.w #$9f0,$dff040
        clr.w $dff042
        clr.w $dff064
        clr.w $dff066
        move.l a0,$dff050
        move.l a1,$dff054
        movem.l (sp)+,d2-d3/a2
        rts
.bblt:  move.l G_BACK,d0
        moveq #3,d3
.blit:  btst #6,$dff002
.bw:    btst #6,$dff002
        bne.s .bw
        move.w #$9f0,$dff040
        clr.w $dff042
        clr.w $dff064
        clr.w $dff066
        move.l d2,$dff050
        move.l d0,$dff054
        move.w #$614,$dff058
        add.l #PLANE,d2
        add.l #PLANE,d0
        dbra d3,.blit
        btst #6,$dff002
.bw2:   btst #6,$dff002
        bne.s .bw2
        movem.l (sp)+,d2-d3/a2
        rts

; From the game's two buffers to three, after the frame in the back buffer
; is finished. A2: tb_vars. Only from the normal two buffer state.
tb_activate:
        btst #0,G_SWAP
        bne .no
        move.l G_FRONT,d0
        move.l G_BACK,d1
        add.l d0,d1
        cmp.l #BUF0+BUF1,d1
        bne .no
        cmp.l #BUF0,d0
        beq.s .buf
        cmp.l #BUF1,d0
        bne .no
.buf:   move.l G_FRONT_COP,d0
        add.l G_BACK_COP,d0
        cmp.l #COPPER1+COPPER2,d0
        bne .no
        cmpi.w #$e0,COPPER2
        bne .no
        cmpi.w #$186,COPPER2+$28
        bne .no
        cmpi.w #$ffff,COPPER2+$2c
        bne .no
        movea.l G_BACK,a0
        lea BUF3,a1
        move.w #PLANE-1,d0              ; 4 planes in longs
.copy:  move.l (a0)+,(a1)+
        dbra d0,.copy
        lea COPPER2,a0
        lea COPPER3,a1
        moveq #48/4-1,d0
.list:  move.l (a0)+,(a1)+
        dbra d0,.list
        lea COPPER3+2,a1
        move.l #BUF3,d0
        moveq #3,d1
.ptr:   swap d0
        move.w d0,(a1)
        swap d0
        move.w d0,4(a1)
        addq.l #8,a1
        add.l #PLANE,d0
        dbra d1,.ptr
        clr.l TB_PEND(a2)
        clr.l TB_COCKPIT(a2)
        move.l #BUF3,TB_FREE(a2)
        move.l #COPPER3,TB_FREE_COP(a2)
        st TB_ON(a2)
        bsr tb_gauges_on
        ifd CPUFILL
        bsr aga_activate
        endif
.no:    rts

; Back to the game's two buffers: show a pending frame, then copy the third
; buffer into the free one of the game's buffers if it is in use.
tb_deactivate:
        movem.l d0-d1/a0-a2,-(sp)
        lea tb_vars(pc),a2
        tst.b TB_ON(a2)
        beq .done
        move.w sr,-(sp)
        move.w #$2700,sr
        move.l TB_PEND(a2),d0
        beq.s .shown
        move.l G_FRONT,TB_FREE(a2)
        move.l G_FRONT_COP,TB_FREE_COP(a2)
        move.l d0,G_FRONT
        move.l TB_PEND_COP(a2),d0
        move.l d0,G_FRONT_COP
        COP1LC                          ; from the next field on
        clr.l TB_PEND(a2)
.shown: move.w (sp)+,sr
        cmpi.l #BUF3,TB_FREE(a2)
        beq .off
        lea BUF3,a0
        movea.l TB_FREE(a2),a1
        move.w #PLANE-1,d0
.copy:  move.l (a0)+,(a1)+
        dbra d0,.copy
        move.w sr,-(sp)
        move.w #$2700,sr
        cmpi.l #BUF3,G_BACK
        bne.s .front
        move.l TB_FREE(a2),G_BACK
        move.l TB_FREE_COP(a2),G_BACK_COP
        bra.s .set
.front: move.l TB_FREE(a2),G_FRONT
        move.l TB_FREE_COP(a2),d0
        move.l d0,G_FRONT_COP
        COP1LC
.set:   move.w (sp)+,sr
.off:   clr.b TB_ON(a2)
        bsr tb_gauges_off
.done:  movem.l (sp)+,d0-d1/a0-a2
        rts

; Replaces bclr.b #0,G_SWAP in the VBL handler (D0-D2/A0 saved there). Z set
; skips the game's swap.
tb_vbl:
        ifd CPUFILL
        bsr aga_colours
        endif
        move.l a1,-(sp)
        lea tb_vars(pc),a1
        tst.b TB_ON(a1)
        beq.s .game
        move.l TB_PEND(a1),d0
        beq.s .colours
        move.l G_FRONT,TB_FREE(a1)
        move.l G_FRONT_COP,TB_FREE_COP(a1)
        move.l d0,G_FRONT
        move.l TB_PEND_COP(a1),d0
        move.l d0,G_FRONT_COP
        COP1LC
        move.w d0,$dff088
        clr.l TB_PEND(a1)
.colours:
        lea COPPER2+$22,a0              ; palette changes reach lists 1 and 2
        lea COPPER3+$22,a1
        move.w (a0),(a1)
        move.w 4(a0),4(a1)
        move.w 8(a0),8(a1)
        movea.l (sp)+,a1
        cmp.b d0,d0
        rts
.game:  movea.l (sp)+,a1
        bclr #0,G_SWAP
        rts

; Entry of the screen transition dispatcher: back to two buffers first.
tb_transition:
        bsr tb_deactivate
        ifd CPUFILL
        bsr aga_reset
        endif
        add.w d0,d0
        add.w d0,d0
        move.w #$10,G_FADE_COUNT
        jmp F_TRANSITION_CONT
