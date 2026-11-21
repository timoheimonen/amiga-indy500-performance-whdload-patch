; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; WHDLoad slave for Indianapolis 500 (Papyrus / Electronic Arts, 1990).
;
; The slave replaces the bootblock: it loads the title picture and stage1
; (disk offsets $400-$1A1FF) to $400 and starts stage1 with the registers the
; boot loader leaves, reporting the expansion memory as the extra memory block.
; Stage1 then shows its intro and loads and relocates the main program itself:
; the two chip hunks downwards from $80000, the others upwards from the start
; of the expansion memory (hunk 1 at +0, hunk 0 at +$8C0C, up to +$6B51C).
; Its track reader is replaced with reads from the disk image.
;
; Before stage1 enters the main program the slave patches it:
;   - the sector reader and writer use the disk image and two save files,
;     "Settings" (sector 1172) and "Replay" (sectors 1628-1759); without
;     "Settings" the settings start with GRAPHICS DETAIL HIGH;
;   - the drive release does not touch the drive;
;   - the keyboard interrupt checks the quit key.
;
; Main program addresses are written as for the expansion memory at $C00000
; (G+address, main hunk 0 at G+$C08C0C). build.py finds every long that
; depends on GAME_BASE and appends their offsets to the slave (game_refs);
; the slave adds the real expansion memory address minus $C00000 to them
; before it uses any.

        include "whdload_api.i"

        ifnd GAME_BASE
GAME_BASE       equ $C00000
        endif
G               equ GAME_BASE-$C00000

BASEMEM         equ $80000          ; draw buffers, stage1, chip hunks 2 and 4
EXPMEM_SIZE     equ $70000          ; hunks 1, 0, 3, 5, 6 ($6B51C), then stack
        ifd CPUFILL
        ifd INTERP
OPTIONS         equ 1               ; the extras of the AGA view can be
                                    ; switched off (Custom2, keys)
EXPMEM_EXTRA    equ $265000         ; chunky view 320 x 128 bytes, p2c table,
                                    ; asphalt, wall, fence and grass textures, tables,
                                    ; fence list, ground colours, mask blit
                                    ; cache, c2p table, sky pairs, tree
                                    ; leaves, crowd, materials, seats (fill.s)
        else
EXPMEM_EXTRA    equ $36000          ; chunky view 320 x 128 bytes, p2c table,
                                    ; mask blit cache (fill.s)
        endif
        else
EXPMEM_EXTRA    equ 0
        endif
DISK_SIZE       equ 901120

; Stage1 (absolute, loaded at $400 from the same disk offset)
STAGE1_ENTRY    equ $A040
S1_TRACK        equ $AB7A           ; word: next track to read
S1_PRB          equ $AB7C           ; CIA-B PRB shadow (side bit 2)
S1_READ_TRACK   equ $B0BE           ; A0 = destination of 11 sectors
S1_ENTER_MAIN   equ $A28E           ; movea.l hunk0_ptr,a0 before jmp (a0)
S1_HUNK0_PTR    equ $AB84
S1_EXTRA_MASK   equ $A054           ; andi.l #$fff00000,d6
TRACK_BYTES     equ 11*512

; Main program
MAIN_HUNK0      equ G+$C08C0C
M_READ_SECTORS  equ G+$C36084       ; D0 sector, D1 count, A0 buffer
M_WRITE_SECTORS equ G+$C360C4
M_DISK_RELEASE  equ G+$C3611E       ; flush and motor off, carry on error
M_DISK_DIRTY    equ G+$C3690F       ; track buffer dirty flag
M_DISK_OK       equ G+$C36778       ; clear disk error, carry clear, rts
M_DISK_FAIL     equ G+$C36772       ; carry set, rts
M_DISK_ERROR    equ G+$C368DE       ; error code word
M_START_FADE    equ G+$C340F2       ; after the random seed is taken at the start
M_RNG_NEXT      equ G+$C131F4
M_FADE          equ G+$C142D4       ; screen transition, D0 = mode
M_KBD_CLEAR     equ G+$C1275E       ; clr.b $bfec01 in the level 2 handler
M_LOD_HIGH      equ G+$C0923A       ; select_lod_thresholds, detail HIGH: two move.w #40

SETTINGS_SECTOR equ 1172
SETTINGS_DETAIL equ $A8             ; detail level in it: 0 LOW, 1 MEDIUM, 2 HIGH
REPLAY_SECTOR   equ 1628
REPLAY_SECTORS  equ 132
ERR_PROTECTED   equ 8

;============================================================================

base:
        moveq #-1,d0                    ; ws_Security
        rts
        dc.b "WHDLOADS"                 ; ws_ID
        dc.w 17                         ; ws_Version
        dc.w WHDLF_NoError|WHDLF_ClearMem
        dc.l BASEMEM                    ; ws_BaseMemSize
        dc.l 0                          ; ws_ExecInstall
        dc.w start-base                 ; ws_GameLoader
        dc.w 0                          ; ws_CurrentDir
        dc.w 0                          ; ws_DontCache
        dc.b 0                          ; ws_keydebug
keyexit:
        dc.b $59                        ; ws_keyexit: F10
expmem:
        dc.l EXPMEM_SIZE+EXPMEM_EXTRA   ; ws_ExpMem, replaced by its address
        dc.w name-base                  ; ws_name
        dc.w copy-base                  ; ws_copy
        dc.w info-base                  ; ws_info
        dc.w 0                          ; ws_kickname
        dc.l 0                          ; ws_kicksize
        dc.w 0                          ; ws_kickcrc
        ifd OPTIONS
        dc.w config-base                ; ws_config
        else
        dc.w 0                          ; ws_config
        endif

        ifd OPTIONS
; Custom2: bit n set switches group n of the extras of the AGA view off
; (opt_off, OPT_N groups; applied by opt_apply).
config: dc.b "C2:X:Original road and grass:0;"
        dc.b "C2:X:Original walls without fences:1;"
        dc.b "C2:X:Original trees:2;"
        dc.b "C2:X:Original grandstands:3;"
        dc.b "C2:X:Original buildings:4;"
        dc.b "C2:X:No guardrails and thin posts:5;"
        dc.b "C2:X:Original 2D cars:6;"
        dc.b "C2:X:Original car colours:7;"
        dc.b "C2:X:Original flat sky:8;"
        dc.b "C2:X:No sparks under the cars:9;"
        dc.b "C2:X:Original empty mirrors:10",0
        endif
name:   dc.b "Indianapolis 500",0
copy:   dc.b "1990 Papyrus / Electronic Arts",0
info:   dc.b "Performance V1.1",10
        dc.b "by Timo Heimonen",0
disk_name:      dc.b "Disk.1",0
settings_name:  dc.b "Settings",0
replay_name:    dc.b "Replay",0
        even

resload:
        dc.l 0

;============================================================================
; Entry from WHDLoad. A0: resload base.

start:
        lea resload(pc),a1
        move.l a0,(a1)
        movea.l a0,a2
        move.l expmem(pc),d0
        movea.l d0,sp
        adda.l #EXPMEM_SIZE,sp

        ; Game addresses: add the expansion memory address minus $C00000.
        sub.l #$C00000,d0                ; the layout the sources are written for
        lea base(pc),a1
        lea (a1),a0
        adda.l #game_refs-base,a0       ; beyond a 16 bit displacement
        ifd CPUFILL
.fix:   moveq #0,d1                     ; offsets up to 64 KB
        move.w (a0)+,d1
        beq.s .fixed
        add.l d0,(a1,d1.l)
        else
.fix:   move.w (a0)+,d1
        beq.s .fixed
        add.l d0,(a1,d1.w)
        endif
        bra.s .fix
.fixed:

        lea disk_name(pc),a0
        jsr resload_GetFileSize(a2)
        cmp.l #DISK_SIZE,d0
        bne wrong_version

        ; Title picture and stage1, as the boot loader reads them.
        move.l #$400,d0
        move.l #$1A200-$400,d1
        moveq #1,d2
        lea $400,a0
        jsr resload_DiskLoad(a2)

        lea stage1_checks(pc),a0
        bsr check_sites
        bne wrong_version
        move.l #$4e714e71,S1_EXTRA_MASK         ; keep D6 as it is
        move.w #$4e71,S1_EXTRA_MASK+4

        lea read_track(pc),a0
        move.w #$4ef9,S1_READ_TRACK
        move.l a0,S1_READ_TRACK+2
        lea enter_main(pc),a0
        move.w #$4eb9,S1_ENTER_MAIN
        move.l a0,S1_ENTER_MAIN+2
        jsr resload_FlushCache(a2)

        ; Boot loader results: next track 19, drive select on side 1.
        move.b #19,$0
        move.b #$73,$1
        move.l expmem(pc),d6            ; extra memory block
        move.l #BASEMEM,d7              ; AvailMem(MEMF_CHIP)
        move.l #$55555555,d4
        lea $dff000,a4
        lea $bfe001,a5
        lea $bfd000,a6
        jmp STAGE1_ENTRY

wrong_version:
        pea TDREASON_WRONGVER
        move.l resload(pc),-(sp)
        addq.l #resload_Abort,(sp)
        rts

; A0: list of (address, size, expected value), size 2 or 4, ending with
; address 0. Z set when all match.
check_sites:
.loop:  move.l (a0)+,d0
        beq.s .done
        movea.l d0,a1
        move.w (a0)+,d1
        move.l (a0)+,d0
        cmp.w #2,d1
        beq.s .word
        cmp.l (a1),d0
        beq.s .loop
.done:  rts
.word:  cmp.w (a1),d0
        beq.s .loop
        rts

CHECKW  macro
        dc.l \1
        dc.w 2
        dc.l \2
        endm
CHECKL  macro
        dc.l \1
        dc.w 4
        dc.l \2
        endm

stage1_checks:
        CHECKL S1_READ_TRACK,$264833fc
        CHECKL S1_ENTER_MAIN,$20790000
        CHECKL S1_ENTER_MAIN+2,$0000ab84
        CHECKL S1_EXTRA_MASK,$0286fff0
        CHECKW S1_EXTRA_MASK+4,$0000
        dc.l 0

main_checks:
        CHECKL M_READ_SECTORS,$48e7fffe
        CHECKL M_WRITE_SECTORS,$48e7fffe
        CHECKW M_DISK_RELEASE,$4a39     ; tst.b disk dirty flag
        CHECKL M_DISK_RELEASE+2,M_DISK_DIRTY
        CHECKW M_DISK_OK,$4279          ; clr.w disk error
        CHECKL M_DISK_OK+2,M_DISK_ERROR
        CHECKW M_START_FADE,$4eb9       ; jsr rng_next
        CHECKL M_START_FADE+2,M_RNG_NEXT
        CHECKW M_KBD_CLEAR,$4239
        CHECKL M_KBD_CLEAR+2,$00bfec01
        CHECKL M_LOD_HIGH,$33fc0028
        CHECKL M_LOD_HIGH+8,$33fc0028
        dc.l 0

;============================================================================
; Replaces stage1 read_track. A0: destination; reads the track in S1_TRACK,
; then advances the track and the side bit like the original.

read_track:
        movem.l d0-d2/a0-a2,-(sp)
        moveq #0,d0
        move.w S1_TRACK,d0
        mulu.w #TRACK_BYTES,d0
        move.l #TRACK_BYTES,d1
        moveq #1,d2
        movea.l resload(pc),a2
        jsr resload_DiskLoad(a2)
        addq.w #1,S1_TRACK
        bchg #2,S1_PRB
        movem.l (sp)+,d0-d2/a0-a2
        rts

;============================================================================
; Called by stage1 instead of "movea.l S1_HUNK0_PTR,a0" just before it jumps
; to the main program. Patches the main program in place.

enter_main:
        movem.l d0-d1/a0-a2,-(sp)
        cmpi.l #MAIN_HUNK0,S1_HUNK0_PTR
        bne wrong_version
        lea main_checks(pc),a0
        bsr check_sites
        bne wrong_version

        lea read_sectors(pc),a0
        move.w #$4ef9,M_READ_SECTORS
        move.l a0,M_READ_SECTORS+2
        lea write_sectors(pc),a0
        move.w #$4ef9,M_WRITE_SECTORS
        move.l a0,M_WRITE_SECTORS+2
        move.l #$023c00fe,M_DISK_RELEASE        ; andi.b #$fe,ccr
        move.w #$4e75,M_DISK_RELEASE+4          ; rts
        ; Straight on to the menu: fade with modes 0 (already done at the
        ; start of the routine) and 1.
        move.w #$7001,M_START_FADE              ; moveq #1,d0
        move.w #$4ef9,M_START_FADE+2
        move.l #M_FADE,M_START_FADE+4
        lea keyboard(pc),a0
        move.w #$4eb9,M_KBD_CLEAR
        move.l a0,M_KBD_CLEAR+2

        lea attn_tags(pc),a0
        movea.l resload(pc),a2
        jsr resload_Control(a2)
        ; Custom1 = 1-39: LOD threshold of the HIGH graphics detail (the game
        ; uses 40, which draws every LOD list).
        move.l custom1(pc),d0
        beq.s .lod
        cmp.l #40,d0
        bcc.s .lod
        move.w d0,M_LOD_HIGH+2
        move.w d0,M_LOD_HIGH+10
.lod:
        ifd OPTIONS
        move.l custom2(pc),d0
        andi.w #(1<<OPT_N)-1,d0
        lea opt_off(pc),a0
        move.w d0,(a0)
        endif
        ifd INTERP
        bsr interp_install
        endif
        ifd CPUFILL
        bsr fill_install
        endif
        bsr cache_setup
        movem.l (sp)+,d0-d1/a0-a2
        movea.l S1_HUNK0_PTR,a0
        rts

;============================================================================
; Instruction cache on a 68020 or 68030. Without the MMU WHDLoad turns all
; caches off while BaseMem is non cacheable (its default), so BaseMem is made
; cacheable write through for the instruction cache only; the data cache stays
; off (the blitter writes chip memory behind it). With the MMU (68040/060) the
; instruction cache is already on and the setup is left alone. The game
; patches its own code only on a 512K machine, which this layout is not
; (main_entry skips $C30692 and $C12BEE). resload_SetCPU flushes the caches.

cache_setup:
        move.l attn_flags(pc),d0
        btst #AFB_68040,d0
        bne.s .done
        btst #AFB_68060,d0
        bne.s .done
        move.l #WCPUF_Base_WT|WCPUF_IC,d0
        move.l #WCPUF_Base|WCPUF_IC|WCPUF_DC,d1
        movea.l resload(pc),a2
        jsr resload_SetCPU(a2)
.done:  rts

attn_tags:  dc.l WHDLTAG_ATTNFLAGS_GET
attn_flags: dc.l 0
            dc.l WHDLTAG_CUSTOM1_GET
custom1:    dc.l 0
        ifd OPTIONS
            dc.l WHDLTAG_CUSTOM2_GET
custom2:    dc.l 0
        endif
            dc.l TAG_DONE
        ifd OPTIONS
OPT_N       equ 11
opt_off:    dc.w 0                      ; groups switched off: bit 0 road,
                                        ; ground and grass textures, 1 wall
                                        ; textures and fences, 2 trees, 3 crowd,
                                        ; seats and grandstand roofs, 4 buildings,
                                        ; 5 guardrails and posts, 6 3D cars,
                                        ; 7 team liveries, 8 sky gradient,
                                        ; 9 sparks, 10 track in the mirrors
opt_keys:   dc.b $10,$11,$12,$14,$15,$16,$17,$18,$20,$27,$37 ; Q W E T Y U I O A K M:
            even                        ; raw keys the game does not use
        endif

;============================================================================
; Level 2 keyboard handler hook, replaces "clr.b $bfec01". D0.b: raw key byte.

keyboard:
        clr.b $bfec01
        move.l d0,-(sp)
        not.b d0
        ror.b #1,d0
        cmp.b keyexit(pc),d0
        beq.s .quit
        ifd OPTIONS
        move.l a0,-(sp)                 ; a key of opt_keys pressed: its
        lea opt_keys+OPT_N(pc),a0       ; group on or off (from the next
        move.l d1,-(sp)                 ; view on). The game gets the key as
        moveq #OPT_N-1,d1               ; released (bit 0 of the raw byte
.opt:   cmp.b -(a0),d0                  ; clear) and never sees it pressed
        dbeq d1,.opt
        bne.s .nopt
        lea opt_off(pc),a0
        move.w (a0),d0
        bchg d1,d0
        move.w d0,(a0)
        bclr #0,11(sp)
.nopt:  move.l (sp)+,d1
        movea.l (sp)+,a0
        endif
        move.l (sp)+,d0
        rts
.quit:  pea TDREASON_OK
        move.l resload(pc),-(sp)
        addq.l #resload_Abort,(sp)
        rts

;============================================================================
; Save file for a sector range. D0: sector, D1: count.
; Returns A1 = file name, or 0 when the range is not a save area.

save_file:
        cmp.w #SETTINGS_SECTOR,d0
        bne.s .replay
        cmp.w #1,d1
        bne.s .none
        lea settings_name(pc),a1
        rts
.replay:
        cmp.w #REPLAY_SECTOR,d0
        bne.s .none
        cmp.w #REPLAY_SECTORS,d1
        bne.s .none
        lea replay_name(pc),a1
        rts
.none:  suba.l a1,a1
        rts

; Replaces disk_read_sectors. D0.w: first sector, D1.w: count, A0: buffer.
; All registers preserved, carry set on error.
read_sectors:
        movem.l d0-d7/a0-a6,-(sp)
        moveq #0,d5
        move.w d0,d5                    ; sector
        moveq #0,d6
        move.w d1,d6                    ; count
        movea.l a0,a3
        movea.l resload(pc),a2
        bsr save_file
        move.l a1,d7
        beq.s .disk
        movea.l a1,a0
        jsr resload_GetFileSize(a2)
        move.l d6,d1
        mulu.w #512,d1
        cmp.l d1,d0
        bne.s .disk
        movea.l d7,a0
        movea.l a3,a1
        jsr resload_LoadFile(a2)
        bra.s .ok
.disk:  move.l d5,d0
        mulu.w #512,d0
        move.l d6,d1
        mulu.w #512,d1
        moveq #1,d2
        movea.l a3,a0
        jsr resload_DiskLoad(a2)
        cmp.w #SETTINGS_SECTOR,d5       ; no Settings file yet: GRAPHICS
        bne.s .ok                       ; DETAIL HIGH, the disk has MEDIUM
        move.w #2,SETTINGS_DETAIL(a3)
.ok:    movem.l (sp)+,d0-d7/a0-a6
        jmp M_DISK_OK

; Replaces disk_write_sectors. Only the save areas can be written; anything
; else reports a write protected disk.
write_sectors:
        movem.l d0-d7/a0-a6,-(sp)
        moveq #0,d6
        move.w d1,d6
        movea.l a0,a3
        bsr save_file
        move.l a1,d7
        beq.s .protected
        move.l d6,d0
        mulu.w #512,d0
        movea.l d7,a0
        movea.l a3,a1
        movea.l resload(pc),a2
        jsr resload_SaveFile(a2)
        movem.l (sp)+,d0-d7/a0-a6
        jmp M_DISK_OK
.protected:
        move.w #ERR_PROTECTED,M_DISK_ERROR
        movem.l (sp)+,d0-d7/a0-a6
        jmp M_DISK_FAIL

        ifd INTERP
        include "interp.s"
        endif
        ifd CPUFILL
        include "fill.s"
        endif

; Offsets (from base) of the longs that hold game addresses, ending with 0.
; Appended by build.py; nothing may follow this label.
        cnop 0,4
game_refs:
