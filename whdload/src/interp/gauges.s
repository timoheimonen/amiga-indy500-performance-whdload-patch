; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Cockpit instruments (11 items: needles, warning lights, the levers). The
; game keeps a state per draw buffer (per item the value drawn into it and,
; for the needles, the rectangle restored from the clean cockpit before
; another value is drawn), draws an item only when its value differs from
; the value drawn, and exchanges the two states after each draw, so with
; three buffers the states and the buffers would drift apart. Here each buffer has a fixed state: $400
; gauges0, $8100 gauges1, the third buffer tb_gauges3. The game writes the
; new values into gauges0 and gauges1 only.
;
; Last in the module: the status band of the HUD with three buffers (tb_band).

; Replaces "movea.l gauge_ptr,a0" before the draw: A0 = the state of the
; back buffer.
tb_gauges:
        movea.l G_GAUGE_PTR,a0
        move.l a1,-(sp)
        lea tb_vars(pc),a1
        tst.b TB_ON(a1)
        beq.s .x
        lea G_GAUGES0,a0
        cmpi.l #BUF0,G_BACK
        beq.s .x
        lea G_GAUGES1,a0
        cmpi.l #BUF1,G_BACK
        beq.s .x
        move.l d0,-(sp)
        lea G_GAUGES0,a0
        lea tb_gauges3(pc),a1
        moveq #10,d0
.new:   move.l (a0),(a1)                ; type and new value
        lea 12(a0),a0
        lea 12(a1),a1
        dbra d0,.new
        move.l (sp)+,d0
        lea tb_gauges3(pc),a0
.x:     movea.l (sp)+,a1
        rts

; Replaces "move.l #gauges0,gauge_ptr" at the end of the game's reset of
; both states (nothing drawn): resets the third one as well.
tb_gauge_init:
        move.l #G_GAUGES0,G_GAUGE_PTR
        movem.l d0/a0-a1,-(sp)
        lea G_GAUGES0,a0
        lea tb_gauges3(pc),a1
        bsr tb_gauges_copy
        movem.l (sp)+,d0/a0-a1
        rts

; Replaces "move.w #$100,$dff040" where both of the game's cockpit loaders
; ($C15A54 and the car type's one that ends at $C1599C) go on after they
; drew the clean picture into the back buffer. The game relies on its
; exchange of the two states here (the state of this buffer is still
; nothing drawn after the reset a frame earlier); with three buffers the
; buffer may be another one, whose state says drawn, so it is reset.
tb_cockpit_drawn:
        move.w #$100,$dff040
        move.l a0,-(sp)
        lea tb_vars(pc),a0
        tst.b TB_ON(a0)
        movea.l (sp)+,a0
        beq.s .x
        bsr.s tb_gauges_clear
.x:     rts

; The back buffer got the clean cockpit picture: its state is set to
; nothing drawn, as the game's reset does, so every item is drawn again.
tb_gauges_clear:
        movem.l d0/a0,-(sp)
        move.l G_BACK,d0
        bsr.s tb_gauges_of
        moveq #10,d0
.item:  move.w #$ffff,4(a0)
        lea 12(a0),a0
        dbra d0,.item
        movem.l (sp)+,d0/a0
        rts

; Copies the state at A0 to A1. D0, A0, A1 changed.
tb_gauges_copy:
        moveq #GAUGE_SIZE/4-1,d0
.c:     move.l (a0)+,(a1)+
        dbra d0,.c
        rts

; The fixed state of the buffer in D0 to A0.
tb_gauges_of:
        lea G_GAUGES0,a0
        cmp.l #BUF0,d0
        beq.s .x
        lea G_GAUGES1,a0
        cmp.l #BUF1,d0
        beq.s .x
        lea tb_gauges3(pc),a0
.x:     rts

; From tb_activate, at frame_end after the back buffer's gauges were drawn
; (gauge_ptr2 holds its state) and the back buffer was copied to the third
; one: the two states go to their fixed buffers, the third gets a copy of
; the back buffer's state.
tb_gauges_on:
        movem.l d0-d1/a0-a1,-(sp)
        move.l G_BACK,d0
        bsr.s tb_gauges_of
        cmpa.l G_GAUGE_PTR2,a0
        beq.s .same
        lea G_GAUGES0,a0                ; exchange gauges0 and gauges1
        lea G_GAUGES1,a1
        moveq #GAUGE_SIZE/4-1,d0
.ex:    move.l (a0),d1
        move.l (a1),(a0)+
        move.l d1,(a1)+
        dbra d0,.ex
        move.l G_BACK,d0
        bsr.s tb_gauges_of
.same:  lea tb_gauges3(pc),a1
        bsr tb_gauges_copy
        movem.l (sp)+,d0-d1/a0-a1
        rts

; From tb_deactivate, after the third buffer was copied into a game buffer
; (TB_FREE(a2), unless it is the third buffer itself): that buffer gets the
; third state, and gauge_ptr the state of the buffer drawn next (the front
; one after the game's swap, the back one when frame_end does not swap).
tb_gauges_off:
        movem.l d0-d1/a0-a1,-(sp)
        move.l TB_FREE(a2),d0
        cmp.l #BUF3,d0
        beq.s .ptr
        bsr tb_gauges_of
        movea.l a0,a1
        lea tb_gauges3(pc),a0
        bsr tb_gauges_copy
.ptr:   move.l G_FRONT,d0
        move.l G_BACK,d1
        btst #0,G_NO_SWAP
        beq.s .set
        exg d0,d1
.set:   bsr tb_gauges_of
        move.l a0,G_GAUGE_PTR
        move.l d1,d0
        bsr tb_gauges_of
        move.l a0,G_GAUGE_PTR2
        movem.l (sp)+,d0-d1/a0-a1
        rts

; Replaces "jsr band_copy" in the HUD (status band rows from the front
; buffer into the back one, a frame after the text changed). With three
; buffers frame_end copies the band from the finished frame every frame,
; and the front buffer may be a frame older.
tb_band:
        move.l a0,-(sp)
        lea tb_vars(pc),a0
        tst.b TB_ON(a0)
        movea.l (sp)+,a0
        bne.s .x
        jmp G_BAND_COPY
.x:     rts
