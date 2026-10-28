#ifndef GDT_H
#define GDT_H

#include "compat.h"

#define GDT_KERNEL_CODE_SELECTOR 0x08U
#define GDT_KERNEL_DATA_SELECTOR 0x10U

void gdt_load(void);

#endif
