bits 32

MULTIBOOT_MAGIC     equ 0x1BADB002
MULTIBOOT_FLAGS     equ 0
POST_PORT           equ 0x80
POST_CODE_ENTERED   equ 0x01
STACK_BYTES         equ 16384

section .multiboot
align 4
    dd MULTIBOOT_MAGIC
    dd MULTIBOOT_FLAGS
    dd -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

section .bss
align 16
stack_bottom:
    resb STACK_BYTES
stack_top:

section .text
global _start
extern kmain

_start:
    mov esp, stack_top
    mov al, POST_CODE_ENTERED
    out POST_PORT, al
    call kmain

halt_forever:
    cli
    hlt
    jmp halt_forever
