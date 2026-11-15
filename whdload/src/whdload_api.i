; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The parts of the WHDLoad slave interface this slave uses, as described in the
; WHDLoad autodoc: slave flags, termination reasons and the offsets of the
; resload functions from the resload base passed to the slave in A0.

WHDLF_NoError           equ 1<<1        ; resload errors quit with a requester
WHDLF_ClearMem          equ 1<<12       ; clear BaseMem and ExpMem instead of filling

TDREASON_OK             equ -1
TDREASON_WRONGVER       equ 9

resload_Abort           equ $04
resload_LoadFile        equ $08
resload_SaveFile        equ $0c
resload_FlushCache      equ $20
resload_GetFileSize     equ $24
resload_DiskLoad        equ $28
resload_Control         equ $34         ; A0 tag list, filled in
resload_SetCPU          equ $60         ; D0 new setup, D1 mask; flushes the caches

WCPUF_Base              equ 3           ; BaseMem cacheability mask
WCPUF_Base_WT           equ 2           ; BaseMem cacheable write through
WCPUF_IC                equ 1<<8        ; instruction cache (68020-68060)
WCPUF_DC                equ 1<<9        ; data cache (68030-68060)

WHDLTAG_ATTNFLAGS_GET   equ $88000000   ; exec AttnFlags of the machine
WHDLTAG_CUSTOM1_GET     equ $88000007   ; value of the Custom1/N option
WHDLTAG_CUSTOM2_GET     equ $88000008   ; value of the Custom2/N option
TAG_DONE                equ 0
AFB_68040               equ 3
AFB_68060               equ 7
