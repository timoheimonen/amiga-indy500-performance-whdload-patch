; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; End of the chunky view: the background tail as bytes (c_background_tail),
; the conversion to the four planes (c2p_view) and the tables of both
; (chunky_tables, bgtab, c2ptab).

; Background: planes 0 and 1 all ones and plane 3 = NOT plane 2, so each pixel
; is 7 where plane 2 (built in the fast plane buffer) is set, otherwise 11.
c_background_tail:
        ifd INTERP
        btst #0,aga_on(pc)
        bne c_sky_tail
        endif
        movem.l d5-d7/a0-a2,-(sp)
        movea.l G_DRAW_BACK,a0
        lea VIEW_TOP+2*FILL_PLANE(a0),a0
        movea.l chunky_base(pc),a1
        lea bgtab(pc),a2
        move.w #VIEW_H*40-1,d7
        moveq #0,d5
.byte:  move.b (a0)+,d5
        move.w d5,d6
        lsl.w #3,d6
        move.l (a2,d6.w),(a1)+
        move.l 4(a2,d6.w),(a1)+
        dbra d7,.byte
        lea $dff000,a2                  ; blitter state as the original leaves it
        move.w #$1ff,$40(a2)
        clr.w $42(a2)
        clr.w $64(a2)
        clr.w $66(a2)
        movem.l (sp)+,d5-d7/a0-a2
        rts

; Chunky view to the 4 planes of the view rows. A1 = back buffer.
c2p_view:
        movem.l d0-d4/a0-a2,-(sp)
        movea.l chunky_base(pc),a0
        lea VIEW_TOP(a1),a1
        lea c2ptab(pc),a2
        move.w #VIEW_H*40-1,d2          ; bytes per plane
.byte:  moveq #0,d4
pos     set 0
        rept 8
        moveq #15,d0
        and.b (a0)+,d0
        lsl.w #5,d0
        or.l pos(a2,d0.w),d4
pos     set pos+4
        endr
        move.b d4,3*FILL_PLANE(a1)
        lsr.l #8,d4
        move.b d4,2*FILL_PLANE(a1)
        lsr.l #8,d4
        move.b d4,FILL_PLANE(a1)
        lsr.w #8,d4
        move.b d4,(a1)+
        dbra d2,.byte
        movem.l (sp)+,d0-d4/a0-a2
        rts

; Builds bgtab (8 pixels of a plane 2 byte: 7 where set, 11 where clear) and
; c2ptab (for colour 0-15 and pixel position 0-7 of a byte: the bit in each
; plane's byte, plane 0 in the top byte).
chunky_tables:
        movea.l expmem(pc),a0           ; p2ctab: per byte 8 bytes, 1 where
        adda.l #P2C_OFF,a0              ; its bit is set (bit 7 first)
        lea p2c_base(pc),a1
        move.l a0,(a1)
        movea.l expmem(pc),a1           ; mask blit cache: all entries free
        adda.l #MB_OFF,a1
        lea mb_base(pc),a2
        move.l a1,(a2)
        moveq #MB_N-1,d0
.mbc:   clr.l MB_KEY(a1)
        adda.l #MB_SIZE,a1
        dbra d0,.mbc
        moveq #0,d0
.p2c:   moveq #7,d1
.p2b:   btst d1,d0
        sne d2
        neg.b d2
        move.b d2,(a0)+
        dbra d1,.p2b
        addq.w #1,d0
        cmp.w #256,d0
        bne.s .p2c
        lea bgtab(pc),a0
        moveq #0,d0
.bg:    moveq #7,d1
.bgb:   btst d1,d0
        sne d2
        andi.b #7-11,d2
        addi.b #11,d2
        move.b d2,(a0)+
        dbra d1,.bgb
        addq.w #1,d0
        cmp.w #256,d0
        bne.s .bg
        lea c2ptab(pc),a0
        moveq #0,d0                     ; colour
.col:   moveq #7,d1                     ; bit of the byte for position 0
.pos:   moveq #0,d2
        btst #0,d0
        beq.s .p1
        bset d1,d2
.p1:    swap d2                         ; plane 0 in bits 24-31
        lsl.l #8,d2
        btst #1,d0
        beq.s .p2
        moveq #0,d3
        bset d1,d3
        swap d3
        or.l d3,d2
.p2:    btst #2,d0
        beq.s .p3
        moveq #0,d3
        bset d1,d3
        lsl.w #8,d3
        or.l d3,d2
.p3:    btst #3,d0
        beq.s .p4
        moveq #0,d3
        bset d1,d3
        or.l d3,d2
.p4:    move.l d2,(a0)+
        dbra d1,.pos
        addq.w #1,d0
        cmp.w #16,d0
        bne.s .col
        rts

        cnop 0,4
bgtab:  ds.b 256*8
c2ptab: ds.l 8*16
