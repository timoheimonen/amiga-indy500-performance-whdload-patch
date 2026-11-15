; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Game addresses and constants of the interpolated rendering.

F_LOOP_TOP      equ G+$C08D5E       ; move.w sim_step_counter,d0; beq.b self
F_SNAPSHOT      equ G+$C08E50       ; move.w #5,d2 ... copy 6 longs
F_SNAPSHOT_END  equ G+$C08E66       ; clr.w sim_step_counter
F_CAR_LIST      equ G+$C08E76       ; jsr build_car_list
F_RENDER        equ G+$C08EA8       ; movem.w camera,d0-d5; jsr view_setup
G_SIM_DISABLE   equ G+$C093E6       ; mask SOFTINT
G_SIM_ENABLE    equ G+$C093F0
G_STEP_COUNTER  equ G+$C1243E       ; followed by the camera block
G_SNAPSHOT      equ G+$C093B2       ; render_camera_snapshot (24 bytes)
G_FRAME_FLAGS   equ G+$C093E3       ; bit 0: normal in-car frame
G_BUILD_CARS    equ G+$C28FAC       ; builds car_draw_list from the objects
G_CAR_OBJECTS   equ G+$C2B364       ; 33 objects of $56 bytes
G_DIVIDER       equ G+$C1AF8E       ; sim_tick_divider, 4..1
G_REQUEST       equ G+$C1AFA3       ; sim_request, bit 0
G_TICKS_SINCE   equ G+$C1AF94       ; ticks_since_frame
G_DEMO          equ G+$C2F4E6       ; demo_mode, bit 0
G_MODE          equ G+$C1273A       ; bit 1: replay frame path
F_FRAME_END     equ G+$C14180       ; btst.b #0,$C2F4E4.l
F_FRAME_END_RET equ G+$C091F8       ; return address from frame_loop
F_VBL_SWAP      equ G+$C13EB4       ; bclr.b #0,$C1AFA2.l; beq.b
F_TRANSITION    equ G+$C142D4       ; add.w d0,d0 x2; move.w #$10,$C1AF64.l
F_TRANSITION_CONT equ G+$C142E0
G_NO_SWAP       equ G+$C2F4E4       ; bit 0: frame_end does not swap
G_FE_TEXT       equ G+$C1320C       ; called by frame_end before the swap
G_FE_HUD        equ G+$C15648
G_SWAP          equ G+$C1AFA2       ; bit 0: swap at the next VBL
G_COCKPIT_SRC   equ G+$C1AF9E       ; cockpit picture to copy after the swap
G_FRONT         equ G+$C17414       ; draw_buffer_ptrs: front, back
G_BACK          equ G+$C17418
G_FRONT_COP     equ G+$C1741C       ; copper_list_ptrs: front, back
G_BACK_COP      equ G+$C17420
G_FADE_COUNT    equ G+$C1AF64
F_GAUGE_LOAD    equ G+$C32FC2       ; movea.l gauge_ptr,a0 (cockpit gauges)
F_GAUGE_INIT    equ G+$C32E88       ; move.l #gauges0,gauge_ptr
F_COCKPIT_DRAWN equ G+$C159A6       ; move.w #$100,$dff040: both cockpit loaders,
                                    ; after the picture went into the back buffer
G_GAUGE_PTR     equ G+$C330F0       ; the state drawn next, then the other
G_GAUGE_PTR2    equ G+$C330F4
G_GAUGES0       equ G+$C32FE8       ; two gauge states of 11 items: type,
G_GAUGES1       equ G+$C3306C       ; new value, value drawn, rectangle
F_HUD_BAND      equ G+$C31002       ; jsr band_copy (front to back)
G_BAND_COPY     equ G+$C141F0
CIAA_TBLO       equ $BFE601
CIAA_TBHI       equ $BFE701

PLANE           equ $1F40           ; one bit plane of a draw buffer
BAND_LEN        equ 24*40           ; status band rows 0-23 of a plane
BUF0            equ $400            ; the game's draw buffers
BUF1            equ $8100
COPPER1         equ $630C4          ; their copper lists (hunk 4)
COPPER2         equ $630FC          ; 4 planes, colours 1-3, end: 48 bytes
BUF3            equ $20000          ; third buffer in chip memory the game
COPPER3         equ BUF3+4*PLANE    ; leaves unused in the WHDLoad layout

CAM_BYTES       equ 24
CARS            equ 33
CAR_SIZE        equ $56
TRACK_LEN       equ 39600
TICK            equ $2E6B           ; timer B period
GAUGE_SIZE      equ 11*12
CAM_SNAP        equ 2000            ; larger moves are cuts, not motion
CAR_SNAP        equ 1000
