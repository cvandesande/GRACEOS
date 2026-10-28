ENTRY(_start)

SECTIONS
{
    . = 1M;
    image_start = .;

    .text : {
        *(.loader_header)
        *(.multiboot)
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    /* WHY: ld adds an empty 12-byte .got.plt on i386 and would place it after image_file_bytes is taken */
    .data : {
        *(.data*)
        *(.got.plt)
    }

    image_file_bytes = . - image_start;

    .bss : {
        *(.bss*)
        *(COMMON)
    }

    image_end = .;
}
