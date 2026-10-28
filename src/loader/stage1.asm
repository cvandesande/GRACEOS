cpu 386
bits 16
org 0x7C00

BOOT_SECTOR_BYTES   equ 512
BOOT_SIGNATURE      equ 0xAA55
STACK_TOP           equ 0x7C00
STAGE2_ADDRESS      equ 0x7E00
STAGE2_FIRST_SECTOR equ 2
DISK_RETRIES        equ 3

POST_PORT           equ 0x80
POST_CODE_STAGE1    equ 0xA1
POST_CODE_FAILED    equ 0xEE

BIOS_DISK_SERVICE   equ 0x13
BIOS_RESET_DISK     equ 0x00
BIOS_READ_SECTORS   equ 0x02

; WHY: some BIOSes enter at 07C0:0000 instead of 0000:7C00, and the addresses below assume CS is 0
    jmp 0x0000:start

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, STACK_TOP
    sti
    mov [boot_drive], dl
    mov al, POST_CODE_STAGE1
    out POST_PORT, al
    mov si, DISK_RETRIES

read_stage2:
    mov ah, BIOS_READ_SECTORS
    mov al, LOADER_SECTORS
    mov bx, STAGE2_ADDRESS
    xor ch, ch
    mov cl, STAGE2_FIRST_SECTOR
    xor dh, dh
    mov dl, [boot_drive]
    int BIOS_DISK_SERVICE
    jnc run_stage2
    mov ah, BIOS_RESET_DISK
    mov dl, [boot_drive]
    int BIOS_DISK_SERVICE
    dec si
    jnz read_stage2

fail:
    mov al, POST_CODE_FAILED
    out POST_PORT, al
halt_forever:
    cli
    hlt
    jmp halt_forever

run_stage2:
    mov dl, [boot_drive]
    jmp STAGE2_ADDRESS

boot_drive: db 0

    times BOOT_SECTOR_BYTES - 2 - ($ - $$) db 0
    dw BOOT_SIGNATURE
