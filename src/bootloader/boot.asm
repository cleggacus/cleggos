org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 headers
; useful reference: https://wiki.osdev.org/FAT
; 
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'CLEGG OS   '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

;
; Code goes here
;

start:
  jmp main

;
; print a string to the screen using bios tty mode
; ds:si point to string
;
puts:
  ; save registers we will modify
  push si
  push ax

.loop:
  lodsb                 ; loads byte from ds:si into al and increments si
  or al, al             ; if al is zero then result will be zero
  jz .done              ; jumps if acc is zero

  mov ah, 0x0e
  mov bh, 0
  int 0x10

  jmp .loop

.done:
  pop ax
  pop si
  ret


main:
  ; setup data segment
  mov ax, 0             ; cant write to ds / es directly
  mov ds, ax
  mov es, ax

  ; setup stack segment
  mov ss, ax
  mov sp, 0x7c00        ; start stack at end of segment

  mov [ebr_drive_number], dl
  mov ax, 1                     ; lba = 1, second sector from disk
  mov cl, 1                     ; 1 sector to read
  mov bx, 0x7E00                ; data sould be after the bootloader
  call disk_read

  mov si, msg_hello
  call puts

  cli
  hlt


floppy_error:
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

wait_key_and_reboot:
  mov ah, 0                           
  int 16h                             ; wait for keypress
  jmp 0FFFFh:0                        ; jump to start of bios (reboots system)


.halt:
  cli                                 ; disables interupts, this way the CPU cant get out of "halt" state
  hlt


;
; Disk routines
;

;
; Converts LBA (logical block address) to a CHS (Cylinder head sector) address
; params:
;   - ax: LBA address
; returns:
;   - cx [bits 0-5] sector number
;   - cx [bits 6-15] cylinder
;   - dh head
;
lba_to_chs:
  push ax
  push dx

  xor dx, dx                          ; dx = 0
  div word [bdb_sectors_per_track]    ; ax = LBA / sectors per track
                                      ; dx = LBA % sectors per track
  inc dx                              ; dx = (LBA % sectors per track) + 1 = sector
  mov cx, dx                          ; cx = sector

  xor dx, dx                          ; dx = 0
  div word [bdb_heads]                ; ax = (LBA / sectors per track) / heads = cylinder
                                      ; dx = (LBA / sectors per track) % heads = head
  mov dh, dl                          ; dl = head
  mov ch, al                          ; ch = cylinder (sets the end 8bits)
  shl ah, 6                           ; shift ah (cylinder) left 6
  or cl, ah                           ; puts upper 2 bits of cylinder in cl

  pop ax
  mov dl, al                          ; restore dl
  pop ax
  ret


;
; Reads sectors from disk
; Params:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx memory address where to store the data
;
disk_read:
  push ax
  push bx
  push cx
  push dx
  push di

  push cx                             ; temp save cl (num of sectors to read)
  call lba_to_chs                     ; computes CHS
  pop ax                              ; al = num of sectors

  mov ah, 02h
  mov di, 3                           ; retry count

.retry:
  pusha                               ; saves all registers
  stc                                 ; sets carry flag, some bioses forget to set it
  int 13h                             ; if carry flag cleared then success
  jnc .done                           ; jump if carry isnt set

  ; read failed
  popa
  call disk_reset

  dec di 
  test di, di
  jnz .retry

.fail:
  ; all attempts tried
  jmp floppy_error

.done:
  popa

  pop di
  pop dx
  pop cx
  pop bx
  pop ax
  ret

;
; Resets disk controller
; Params:
;   dl: drive number
;
disk_reset:
  pusha
  mov ah, 0
  stc
  int 13h
  jc floppy_error
  popa
  ret

  
  



msg_hello: db 'HELLO', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
