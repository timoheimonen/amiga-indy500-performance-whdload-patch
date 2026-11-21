; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Colour tables of the AGA view: the nibbles of colours 16-255 (pal_hi and
; pal_lo, level_colours in aga/display.s) and the brightness levels of the
; textures (level_tab).

pal_hi:         ds.w 256                ; colours 16-255: high nibbles
pal_lo:         ds.w 256                ; and low nibbles
; Brightness levels of the textures: level_tab + 16 r + n = 8 bit value of
; gun n (0-15) at level L = (r + 9) & 15, factor (55 + 5 L) / 100 (r = 0:
; n x 17).
level_tab:
lv_r    set 0
        rept 16
lv_l    set (lv_r+9)&15
lv_g    set 0
        rept 16
lv_v    set (lv_g*17*(55+5*lv_l)+50)/100
        ifgt lv_v-255
lv_v    set 255
        endif
        dc.b lv_v
lv_g    set lv_g+1
        endr
lv_r    set lv_r+1
        endr
