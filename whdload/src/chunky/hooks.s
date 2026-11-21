; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Chunky view hooks (68040/060 only). In the cockpit view the sky, track,
; scenery and cars are drawn as bytes (chunky/view.s) and then
; written into the view rows of the chip back buffer, before the instruments,
; front wheels and cockpit lines. Every drawing routine between the two hooks
; is a CPU version of fill/ (the mirror blits write their own chip buffer at
; $78514).

; Replaces "jsr view_setup" in frame_loop: the view is drawn as bytes.
fast_view_begin:
        ifd INTERP
        bsr aga_drawn_clear
        endif
        move.l a0,-(sp)
        lea chunky_on(pc),a0
        btst #0,chunky_enable(pc)
        sne (a0)
        sne chunky_frame-chunky_on(a0)
        ifd INTERP
        lea xl_ck(pc),a0                ; a new view: no corner kept
        move.l #-1,(a0)
        endif
        movea.l (sp)+,a0
        ifd INTERP
        jsr F_VIEW_SETUP
        bsr cam_view
        bsr pe_drop
        move.l d0,-(sp)
        move.w opt_off(pc),d0           ; the groups switched off
        bsr opt_apply
        move.l (sp)+,d0
        bra tex_frame
        else
        jmp F_VIEW_SETUP
        endif

; Cockpit view: after the cars the game draws the instruments (planar, into
; the cockpit rows), the wall hit debris, the HUD and the front wheels. The
; debris and the wheels go into the bytes as well; the bytes are written
; into the planes after the wheels.

; Replaces "jsr draw_cars" in the cockpit view branch of frame_loop.
fast_view_cars:
        ifd INTERP
        movem.l d0/a0-a1,-(sp)          ; the track in the mirrors, under
        lea G_VIEW_MATRIX,a0            ; the cars
        lea G_CAM_POS,a1
        move.w G_MATRIX_HALVED,d0
        machine 68020
        bsr.l mir_draw
        machine 68000
        movem.l (sp)+,d0/a0-a1
        endif
        jsr F_DRAW_CARS
chunky_pause:
        move.l a0,-(sp)
        lea chunky_on(pc),a0
        sf (a0)
        movea.l (sp)+,a0
        rts

chunky_resume:
        move.l a0,-(sp)
        lea chunky_on(pc),a0
        move.b chunky_frame-chunky_on(a0),(a0)
        movea.l (sp)+,a0
        ifd INTERP
        bra pe_drop                     ; polygons drawn planar meanwhile
        else
        rts
        endif

; Replaces "jsr $C35104" in the cockpit view branch.
fast_view_debris:
        bsr.s chunky_resume
        jsr F_DEBRIS
        bra.s chunky_pause

; Replaces "jsr $C15AC2" in the cockpit view branch. D0-D2: its arguments.
fast_view_wheels:
        bsr.s chunky_resume
        jsr F_WHEELS
        bra.s view_flush

; Replaces "jsr $C35104" in the outside view branch (after the cars).
fast_view_outside:
        jsr F_DEBRIS

; The bytes into the view rows of the back buffer, if this frame has them.
view_flush:
        movem.l a0-a1,-(sp)
        lea chunky_on(pc),a0
        sf (a0)
        btst #0,chunky_frame-chunky_on(a0)
        beq.s .done
        sf chunky_frame-chunky_on(a0)
        movea.l G_DRAW_BACK,a1
        ifd INTERP
        bsr gnd_flush                   ; the ground under the view's rest
        btst #0,aga_on(pc)
        bne.s .aga
        btst #0,aga_hw(pc)
        beq.s .planar
        bsr aga_build                   ; the first frame drawn as bytes
.aga:   bsr c2p_view8
        bra.s .done
        endif
.planar:
        bsr c2p_view
.done:  movem.l (sp)+,a0-a1
        rts

; Entry of the masked blit $C15BE2 (front wheels and the steering wheel top
; in $C15AC2). D0: mask, then 4 image planes each D1 bytes on; D2: BLTSIZE;
; D3: destination modulo; D4: destination in the back buffer.
mask_blit:
        btst #0,chunky_on(pc)
        bne.s c_mask_blit
        move.w #$0fca,$dff040           ; the replaced instruction
        jmp F_MASK_BLIT+8

; As bytes: where the mask is set, the pixel becomes the image's colour.
; The game blits the same few images every frame (the front wheels, the
; steering wheel top), so each source (mask address, plane distance, words
; per row) gets a cache entry: a copy of the source, each pixel's colour
; where the mask is set and $ff where it is clear. The copy is compared
; with the source at every blit and the entry converted again when they
; differ or more rows are needed; drawing then merges longs.
c_mask_blit:
        movem.l d0-d7/a0-a6,-(sp)
        move.w d2,d5
        andi.w #63,d5                   ; words
        move.w d2,d6
        lsr.w #6,d6                     ; rows
        move.w d5,d7
        mulu.w d6,d7
        beq .slow                       ; 64 words or 1024 rows
        cmp.w #MB_MAXW,d7
        bhi .slow
        btst #0,d7
        bne .slow
        sub.l G_DRAW_BACK,d4            ; first row as below
        divu #40,d4
        move.w d4,d3
        subi.w #VIEW_TOP/40,d3
        mulu #VIEW_W,d3
        swap d4
        lsl.w #3,d4
        movea.l chunky_base(pc),a5
        adda.l d3,a5
        adda.w d4,a5
        move.l a5,-(sp)
        movea.l mb_base(pc),a3
        moveq #MB_N-1,d3
.find:  cmp.l MB_KEY(a3),d0
        bne.s .fn
        cmp.l MB_STRIDE(a3),d1
        bne.s .fn
        cmp.w MB_WORDS(a3),d5
        beq.s .found
.fn:    adda.l #MB_SIZE,a3
        dbra d3,.find
        lea mb_next(pc),a0              ; a new entry, in turn
        move.w (a0),d3
        addq.w #1,d3
        andi.w #MB_N-1,d3
        move.w d3,(a0)
        mulu.w #MB_SIZE,d3
        movea.l mb_base(pc),a3
        adda.l d3,a3
        move.l d0,MB_KEY(a3)
        move.l d1,MB_STRIDE(a3)
        move.w d5,MB_WORDS(a3)
        clr.w MB_ROWS(a3)
.found: cmp.w MB_ROWS(a3),d6
        bhi.s .conv
        movea.l d0,a0                   ; the source as the copy?
        lea MB_PL(a3),a1
        moveq #4,d3
.vp:    movea.l a0,a2
        movea.l a1,a4
        move.w d7,d4
        lsr.w #1,d4
        subq.w #1,d4
.vl:    cmpm.l (a2)+,(a4)+
        dbne d4,.vl
        bne.s .conv
        adda.l d1,a0
        lea 2*MB_MAXW(a1),a1
        dbra d3,.vp
        bra .draw
.conv:  move.w d6,MB_ROWS(a3)
        movea.l d0,a0                   ; copy the source
        lea MB_PL(a3),a1
        moveq #4,d3
.cp:    movea.l a0,a2
        movea.l a1,a4
        move.w d7,d4
        subq.w #1,d4
.cw:    move.w (a2)+,(a4)+
        dbra d4,.cw
        adda.l d1,a0
        lea 2*MB_MAXW(a1),a1
        dbra d3,.cp
        lea MB_PL(a3),a4                ; then each word's pixels
        lea MB_C(a3),a5
        lea MB_NM(a3),a6
        move.w d7,d5
        subq.w #1,d5
.cvw:   move.w 2*MB_MAXW(a4),d0
        move.w 4*MB_MAXW(a4),d1
        move.w 6*MB_MAXW(a4),d2
        move.w 8*MB_MAXW(a4),d3
        lea mtab(pc),a0
        bsr ctable
        move.w (a4)+,d4
        lea mtab(pc),a1
        moveq #15,d3
.cvp:   move.b (a1)+,d0
        add.w d4,d4
        bcs.s .cvs
        moveq #0,d0
        st (a6)+
        bra.s .cvn
.cvs:   sf (a6)+
.cvn:   move.b d0,(a5)+
        dbra d3,.cvp
        dbra d5,.cvw
.draw:  movea.l (sp)+,a5
        move.w MB_WORDS(a3),d5
        lea MB_PL(a3),a4
        lea MB_C(a3),a1
        lea MB_NM(a3),a2
        subq.w #1,d6
.drow:  movea.l a5,a6
        move.w d5,d7
        subq.w #1,d7
.dw:    move.w (a4)+,d4
        beq.s .dz
        cmp.w #$ffff,d4
        bne.s .dp
        move.l (a1)+,(a6)+              ; whole word
        move.l (a1)+,(a6)+
        move.l (a1)+,(a6)+
        move.l (a1)+,(a6)+
        lea 16(a2),a2
        dbra d7,.dw
        bra.s .dn
.dp:    move.l (a6),d0                  ; mask partly set
        and.l (a2)+,d0
        or.l (a1)+,d0
        move.l d0,(a6)+
        move.l (a6),d0
        and.l (a2)+,d0
        or.l (a1)+,d0
        move.l d0,(a6)+
        move.l (a6),d0
        and.l (a2)+,d0
        or.l (a1)+,d0
        move.l d0,(a6)+
        move.l (a6),d0
        and.l (a2)+,d0
        or.l (a1)+,d0
        move.l d0,(a6)+
        dbra d7,.dw
        bra.s .dn
.dz:    lea 16(a1),a1                   ; mask clear
        lea 16(a2),a2
        lea 16(a6),a6
        dbra d7,.dw
.dn:    lea VIEW_W(a5),a5
        dbra d6,.drow
        movem.l (sp)+,d0-d7/a0-a6
        rts
        ; Larger or odd sizes: each word converted and written.
.slow:  movea.l d0,a0                   ; mask
        lea (a0,d1.l),a1                ; planes 0-3
        lea (a1,d1.l),a2
        lea (a2,d1.l),a3
        lea (a3,d1.l),a4
        sub.l G_DRAW_BACK,d4
        divu #40,d4                     ; row, byte column in the high word
        move.w d4,d0
        subi.w #VIEW_TOP/40,d0
        mulu #VIEW_W,d0
        swap d4
        lsl.w #3,d4
        movea.l chunky_base(pc),a5
        adda.l d0,a5
        adda.w d4,a5
        move.w d2,d0
        lsr.w #6,d0
        move.w d0,-(sp)                 ; rows
        andi.w #63,d2
        move.w d2,-(sp)                 ; words
.row:   movea.l a5,a6
        move.w (sp),d7
        subq.w #1,d7
.word:  move.w (a0)+,d4
        bne.s .bits
        addq.l #2,a1
        addq.l #2,a2
        addq.l #2,a3
        addq.l #2,a4
        bra.s .next
.bits:  move.w (a1)+,d0
        move.w (a2)+,d1
        move.w (a3)+,d2
        move.w (a4)+,d3
        move.l a0,d5
        lea mtab(pc),a0
        bsr ctable
        movea.l a6,a0
        move.l a2,d6
        lea mtab(pc),a2
        bsr cword
        movea.l d6,a2
        movea.l d5,a0
.next:  lea 16(a6),a6
        dbra d7,.word
        lea VIEW_W(a5),a5
        subq.w #1,2(sp)
        bne.s .row
        addq.l #4,sp
        movem.l (sp)+,d0-d7/a0-a6
        rts
