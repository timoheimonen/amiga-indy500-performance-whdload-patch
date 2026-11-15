; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; c2p for 8 planes. A block of 32 pixels is 8 longs of 4 pixels. A table
; (c2p_t2, 65536 entries of 2 longs, signed word index) gives for 2 pixels
; a, b the bit k of a in bit 29 - 4k and of b in bit 28 - 4k (second long;
; the first long the same shifted left by 2); two lookups give each long
; Y as 8 nibbles, nibble k = plane k of its 4 pixels (C2PY). The 8 x 8
; nibbles are then transposed with three merge stages: C2PM y,x swaps the
; low parts of x with the high parts of y (t = ((y >> s) ^ x) & m, x ^= t,
; y ^= t << s) for nibbles (s 4) and bytes (s 8) within each group of 4
; longs, C2P16 for words between the groups. The registers end as planes
; d4-d7 = 0-3, d0-d3 = 4-7 (bit 31 = the first pixel).

C2PY    macro                           ; \1 = Y of the next 4 pixels, \2 temp
        move.w (a0)+,\2
        move.l (a2,\2.w*8),\1
        move.w (a0)+,\2
        or.l 4(a2,\2.w*8),\1
        endm
C2PM    macro                           ; \1 = y, \2 = x, \3 = s, \4 = m, \5 temp
        move.l \1,\5
        lsr.l #\3,\5
        eor.l \2,\5
        and.l #\4,\5
        eor.l \5,\2
        lsl.l #\3,\5
        eor.l \5,\1
        endm
C2P16   macro                           ; \1 = \2.lo:\1.lo, \2 = \2.hi:\1.hi
        swap \1
        eor.w \1,\2
        eor.w \2,\1
        eor.w \1,\2
        swap \1
        endm

; c2p_view for 8 planes: bits 0-3 of each byte into planes 0-3 of the
; view rows of A1, bits 4-7 into its extra planes; marks the buffer. A
; block of 32 pixels equal to the one before it (sky rows, flat areas)
; stores the planes still in D0-D7 again.
C2PST   macro                           ; planes of a block, A1/A3 to the next
        move.l d5,FILL_PLANE(a1)
        move.l d6,2*FILL_PLANE(a1)
        move.l d7,3*FILL_PLANE(a1)
        move.l d4,(a1)+
        move.l d1,AGA_XPLANE(a3)
        move.l d2,2*AGA_XPLANE(a3)
        move.l d3,3*AGA_XPLANE(a3)
        move.l d0,(a3)+
        endm
        machine 68020
c2p_view8:
        movem.l d0-d7/a0-a6,-(sp)
        movea.l a1,a3
        bsr aga_find
        exg a1,a3                       ; A3: extra planes
        bmi .other
        lea aga_drawn(pc),a0
        st (a0,d1.w)
        movea.l chunky_base(pc),a0
        lea VIEW_TOP(a1),a1
        movea.l a0,a4
        adda.l #VIEW_H*VIEW_W,a4
        movea.l c2p_t2(pc),a2
        bra.s .full                     ; the first block has no planes yet
.blk:   movea.l a0,a6                   ; A5: the block before
        rept 8
        cmpm.l (a5)+,(a6)+
        bne.s .full
        endr
        movea.l a6,a0
        C2PST
        cmpa.l a4,a0
        bne.s .blk
        bra .done
.full:  movea.l a0,a5
        C2PY d4,d0
        C2PY d5,d0
        C2PY d6,d0
        C2PY d7,d0
        C2PM d5,d4,4,$0f0f0f0f,d0
        C2PM d7,d6,4,$0f0f0f0f,d0
        C2PM d6,d4,8,$00ff00ff,d0
        C2PM d7,d5,8,$00ff00ff,d0
        movea.l d7,a6
        C2PY d0,d7
        C2PY d1,d7
        C2PY d2,d7
        C2PY d3,d7
        C2PM d1,d0,4,$0f0f0f0f,d7
        C2PM d3,d2,4,$0f0f0f0f,d7
        C2PM d2,d0,8,$00ff00ff,d7
        C2PM d3,d1,8,$00ff00ff,d7
        move.l a6,d7
        C2P16 d0,d4
        C2P16 d1,d5
        C2P16 d2,d6
        C2P16 d3,d7
        C2PST
        cmpa.l a4,a0
        bne .blk
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts
.other: movem.l (sp)+,d0-d7/a0-a6
        bra c2p_view
        machine 68000

; The c2p table at E + C2PT_OFF, in the order of the signed index (pixel a
; from $80): first the second long of each entry gets the bits of a, then
; the bits of b, which are those of column 0 of the row of b shifted right
; by 1; then the first long is the second shifted left by 2.
c2p_t2_build:
        movem.l d0-d4/a0-a2,-(sp)
        movea.l expmem(pc),a2
        adda.l #C2PT_OFF,a2
        movea.l a2,a0
        adda.l #$40000,a0
        lea c2p_t2(pc),a1
        move.l a0,(a1)
        lea 4(a2),a0
        moveq #0,d4                     ; row
.row:   move.w d4,d0
        eori.w #$80,d0                  ; a
        moveq #0,d1
        moveq #29,d3
        moveq #0,d2                     ; plane
.bit:   btst d2,d0
        beq.s .nb
        bset d3,d1
.nb:    subq.w #4,d3
        addq.w #1,d2
        cmp.w #8,d2
        bne.s .bit
        move.w #255,d2
.fill:  move.l d1,(a0)
        addq.l #8,a0
        dbra d2,.fill
        addq.w #1,d4
        cmp.w #256,d4
        bne.s .row
        lea 4(a2),a0
        move.w #255,d4
.row2:  lea 4(a2),a1                    ; b 0-127: rows $80-$ff
        adda.l #$40000,a1
        bsr.s .cols
        lea 4(a2),a1                    ; b 128-255: rows 0-127
        bsr.s .cols
        dbra d4,.row2
        movea.l a2,a0
        moveq #-1,d2                    ; 65536 entries
.sh:    move.l 4(a0),d1
        lsl.l #2,d1
        move.l d1,(a0)
        addq.l #8,a0
        dbra d2,.sh
        movem.l (sp)+,d0-d4/a0-a2
        rts
.cols:  moveq #127,d2
.col:   move.l (a1),d1
        lsr.l #1,d1
        or.l d1,(a0)
        addq.l #8,a0
        lea 2048(a1),a1
        dbra d2,.col
        rts
