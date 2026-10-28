cpu 386
bits 16
STAGE2_ADDRESS          equ 0x7E00
org STAGE2_ADDRESS

%include "kernel_header.inc"

SECTOR_BYTES            equ 512
STAGE2_BYTES            equ LOADER_SECTORS * SECTOR_BYTES
KERNEL_FIRST_SECTOR     equ 1 + LOADER_SECTORS
SECTOR_BUFFER           equ 0x9000
DISK_RETRIES            equ 3
MAXIMUM_CYLINDER        equ 1023

LOAD_ADDRESS_MINIMUM    equ 0x100000
MEMORY_LIMIT            equ 0x1000000

POST_PORT               equ 0x80
POST_CODE_STAGE2        equ 0xA2
POST_CODE_KERNEL_READ   equ 0xA3
POST_CODE_HANDOFF       equ 0xA4
POST_CODE_FAILED        equ 0xEE

COM1_BASE               equ 0x3F8
UART_DATA               equ 0
UART_INTERRUPT_ENABLE   equ 1
UART_DIVISOR_LOW        equ 0
UART_DIVISOR_HIGH       equ 1
UART_LINE_CONTROL       equ 3
UART_MODEM_CONTROL      equ 4
UART_LINE_STATUS        equ 5
BAUD_DIVISOR_115200     equ 1
LINE_CONTROL_DIVISOR_LATCH equ 0x80
LINE_CONTROL_8N1        equ 0x03
MODEM_CONTROL_DTR_RTS   equ 0x03
LINE_STATUS_TRANSMIT_EMPTY equ 0x20

BIOS_DISK_SERVICE       equ 0x13
BIOS_RESET_DISK         equ 0x00
BIOS_READ_SECTORS       equ 0x02
BIOS_GET_DRIVE_PARAMETERS equ 0x08
BIOS_SYSTEM_SERVICE     equ 0x15
BIOS_ENABLE_A20         equ 0x2401

KEYBOARD_DATA_PORT      equ 0x60
KEYBOARD_COMMAND_PORT   equ 0x64
KEYBOARD_STATUS_INPUT_FULL  equ 0x02
KEYBOARD_COMMAND_WRITE_OUTPUT_PORT equ 0xD1
KEYBOARD_OUTPUT_PORT_A20_ENABLED equ 0xDF
KEYBOARD_WAIT_ATTEMPTS  equ 0xFFFF

A20_PROBE_LOW_OFFSET    equ 0x0500
A20_PROBE_HIGH_SEGMENT  equ 0xFFFF
A20_PROBE_HIGH_OFFSET   equ 0x0510

CR0_PROTECTION_ENABLE   equ 0x01
CODE_SELECTOR           equ 0x08
DATA_SELECTOR           equ 0x10
FLAT_CODE_SEGMENT_4GB_RING0 equ 0x00CF9A000000FFFF
FLAT_DATA_SEGMENT_4GB_RING0 equ 0x00CF92000000FFFF

%define CRLF 13, 10

stage2_entry:
    mov [boot_drive], dl
    mov al, POST_CODE_STAGE2
    out POST_PORT, al
    call serial_init
    mov si, message_started
    call serial_put_string
    call read_drive_geometry
    call enable_a20
    call load_kernel
    mov al, POST_CODE_KERNEL_READ
    out POST_PORT, al
    call zero_kernel_bss
    mov si, message_starting_kernel
    call serial_put_string
    jmp start_kernel

fail:
    call serial_put_string
    mov al, POST_CODE_FAILED
    out POST_PORT, al
halt_forever:
    cli
    hlt
    jmp halt_forever

fail_disk:
    mov si, message_disk
    jmp fail

fail_a20:
    mov si, message_a20
    jmp fail

fail_header:
    mov si, message_header
    jmp fail

serial_init:
    mov dx, COM1_BASE + UART_INTERRUPT_ENABLE
    xor al, al
    out dx, al
    mov dx, COM1_BASE + UART_LINE_CONTROL
    mov al, LINE_CONTROL_DIVISOR_LATCH
    out dx, al
    mov dx, COM1_BASE + UART_DIVISOR_LOW
    mov al, BAUD_DIVISOR_115200
    out dx, al
    mov dx, COM1_BASE + UART_DIVISOR_HIGH
    xor al, al
    out dx, al
    mov dx, COM1_BASE + UART_LINE_CONTROL
    mov al, LINE_CONTROL_8N1
    out dx, al
    mov dx, COM1_BASE + UART_MODEM_CONTROL
    mov al, MODEM_CONTROL_DTR_RTS
    out dx, al
    ret

serial_put_char:
    push ax
    push dx
    mov dx, COM1_BASE + UART_LINE_STATUS
.wait_until_transmitter_empty:
    in al, dx
    test al, LINE_STATUS_TRANSMIT_EMPTY
    jz .wait_until_transmitter_empty
    pop dx
    pop ax
    mov dx, COM1_BASE + UART_DATA
    out dx, al
    ret

serial_put_string:
    cld
.next_character:
    lodsb
    test al, al
    jz .done
    call serial_put_char
    jmp .next_character
.done:
    ret

read_drive_geometry:
    mov ah, BIOS_GET_DRIVE_PARAMETERS
    mov dl, [boot_drive]
    push es
    xor di, di
    int BIOS_DISK_SERVICE
    pop es
    jc fail_disk
    movzx ax, dh
    inc ax
    and cl, 0x3F
    movzx cx, cl
    test cx, cx
    jz fail_disk
    mov [sectors_per_track], cx
    mul cx
    mov [sectors_per_cylinder], ax
    ret

read_sector_at_ax_into_buffer:
    xor dx, dx
    div word [sectors_per_cylinder]
    cmp ax, MAXIMUM_CYLINDER
    ja fail_disk
    mov si, ax
    mov ax, dx
    xor dx, dx
    div word [sectors_per_track]
    mov dh, al
    inc dl
    mov ax, si
    mov ch, al
    mov cl, ah
    shl cl, 6
    or cl, dl
    mov dl, [boot_drive]
    mov si, DISK_RETRIES
.try:
    push cx
    push dx
    mov bx, SECTOR_BUFFER
    mov ax, (BIOS_READ_SECTORS << 8) | 1
    int BIOS_DISK_SERVICE
    pop dx
    pop cx
    jnc .done
    xor ax, ax
    int BIOS_DISK_SERVICE
    dec si
    jnz .try
    jmp fail_disk
.done:
    ret

enable_a20:
    call is_a20_enabled_zero_flag_clear
    jne .done
    mov ax, BIOS_ENABLE_A20
    int BIOS_SYSTEM_SERVICE
    call is_a20_enabled_zero_flag_clear
    jne .done
    call enable_a20_through_keyboard_controller
    call is_a20_enabled_zero_flag_clear
    je fail_a20
.done:
    ret

; WHY: with the A20 gate closed, address FFFF:0510 wraps to 0000:0500, so a write through one shows up in the other
is_a20_enabled_zero_flag_clear:
    push ds
    push es
    xor ax, ax
    mov ds, ax
    mov ax, A20_PROBE_HIGH_SEGMENT
    mov es, ax
    mov si, A20_PROBE_LOW_OFFSET
    mov di, A20_PROBE_HIGH_OFFSET
    mov al, [ds:si]
    mov ah, [es:di]
    push ax
    mov byte [ds:si], 0x00
    mov byte [es:di], 0xFF
    cmp byte [ds:si], 0xFF
    pop ax
    mov [ds:si], al
    mov [es:di], ah
    pop es
    pop ds
    ret

; WHY: interrupts stay off so the BIOS keyboard handler cannot use the controller between our command and its data byte
enable_a20_through_keyboard_controller:
    cli
    call wait_keyboard_input_empty
    mov al, KEYBOARD_COMMAND_WRITE_OUTPUT_PORT
    out KEYBOARD_COMMAND_PORT, al
    call wait_keyboard_input_empty
    mov al, KEYBOARD_OUTPUT_PORT_A20_ENABLED
    out KEYBOARD_DATA_PORT, al
    call wait_keyboard_input_empty
    sti
    ret

wait_keyboard_input_empty:
    mov cx, KEYBOARD_WAIT_ATTEMPTS
.poll:
    in al, KEYBOARD_COMMAND_PORT
    test al, KEYBOARD_STATUS_INPUT_FULL
    jz .ready
    loop .poll
    jmp fail_a20
.ready:
    ret

; WHY: loading a segment register in real mode keeps the limit already cached, so ES stays 4GB after protected mode is left
enter_unreal_mode:
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or al, CR0_PROTECTION_ENABLE
    mov cr0, eax
    jmp short .protection_enabled
.protection_enabled:
    mov ax, DATA_SELECTOR
    mov es, ax
    mov eax, cr0
    and al, ~CR0_PROTECTION_ENABLE
    mov cr0, eax
    xor ax, ax
    mov es, ax
    sti
    ret

load_kernel:
    mov ax, KERNEL_FIRST_SECTOR
    call read_sector_at_ax_into_buffer
    cmp dword [SECTOR_BUFFER + KERNEL_HEADER_MAGIC_OFFSET], KERNEL_IMAGE_MAGIC
    jne fail_header
    mov eax, [SECTOR_BUFFER + KERNEL_HEADER_LOAD_ADDRESS_OFFSET]
    mov [kernel_load_address], eax
    mov ebx, [SECTOR_BUFFER + KERNEL_HEADER_MEMORY_END_OFFSET]
    mov ecx, [SECTOR_BUFFER + KERNEL_HEADER_FILE_BYTES_OFFSET]
    mov [kernel_file_bytes], ecx
    mov edx, [SECTOR_BUFFER + KERNEL_HEADER_ENTRY_OFFSET]
    mov [kernel_entry], edx
    mov [kernel_memory_end], ebx
    cmp eax, LOAD_ADDRESS_MINIMUM
    jb fail_header
    cmp ebx, MEMORY_LIMIT
    ja fail_header
    cmp eax, ebx
    ja fail_header
    cmp ecx, KERNEL_HEADER_BYTES
    jb fail_header
    cmp ecx, MEMORY_LIMIT
    ja fail_header
    sub ebx, eax
    sub edx, eax
    cmp edx, ebx
    jae fail_header
    add ecx, SECTOR_BYTES - 1
    and ecx, -SECTOR_BYTES
    cmp ecx, ebx
    ja fail_header
    shr ecx, 9
    mov [sectors_remaining], ecx
    mov [copy_destination], eax
    mov word [next_sector], KERNEL_FIRST_SECTOR
.copy_next_sector:
    cmp dword [sectors_remaining], 0
    je .done
    mov ax, [next_sector]
    call read_sector_at_ax_into_buffer
    call copy_sector_to_high_memory
    inc word [next_sector]
    dec dword [sectors_remaining]
    jmp .copy_next_sector
.done:
    ret

copy_sector_to_high_memory:
    call enter_unreal_mode
    mov esi, SECTOR_BUFFER
    mov edi, [copy_destination]
    mov ecx, SECTOR_BYTES / 4
    a32 rep movsd
    mov [copy_destination], edi
    ret

zero_kernel_bss:
    call enter_unreal_mode
    mov edi, [kernel_load_address]
    add edi, [kernel_file_bytes]
    mov ecx, [kernel_memory_end]
    sub ecx, edi
    xor al, al
    a32 rep stosb
    ret

start_kernel:
    mov al, POST_CODE_HANDOFF
    out POST_PORT, al
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or al, CR0_PROTECTION_ENABLE
    mov cr0, eax
    jmp dword CODE_SELECTOR:protected_mode_entry

bits 32
protected_mode_entry:
    mov ax, DATA_SELECTOR
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp dword [kernel_entry]

bits 16
align 8
gdt:
    dq 0
    dq FLAT_CODE_SEGMENT_4GB_RING0
    dq FLAT_DATA_SEGMENT_4GB_RING0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt - 1
    dd gdt

message_started:        db 'GRACEOS loader', CRLF, 0
message_starting_kernel: db 'loader: starting kernel', CRLF, 0
message_disk:           db 'loader: disk read failed', CRLF, 0
message_a20:            db 'loader: cannot enable A20', CRLF, 0
message_header:         db 'loader: kernel header is missing or wrong', CRLF, 0

boot_drive:             db 0
sectors_per_track:      dw 0
sectors_per_cylinder:   dw 0
next_sector:            dw 0
sectors_remaining:      dd 0
copy_destination:       dd 0
kernel_load_address:    dd 0
kernel_file_bytes:      dd 0
kernel_memory_end:      dd 0
kernel_entry:           dd 0

%if ($ - $$) > SECTOR_BUFFER - STAGE2_ADDRESS
%error stage 2 reaches into SECTOR_BUFFER
%endif

    times STAGE2_BYTES - ($ - $$) db 0
