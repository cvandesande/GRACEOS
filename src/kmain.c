#include "kmain.h"

#include "gdt.h"
#include "port.h"
#include "serial.h"

#define POST_CODE_SERIAL_READY 0x02
#define POST_CODE_GDT_LOADED 0x03

static const char BANNER[] = "GRACEOS 0.1 - dedicated to Andrew Tanenbaum and Linus Torvalds,\r\n"
                             "who argued about this in 1992. They were both right.\r\n";

void kmain(void)
{
    serial_init();
    post_code_write(POST_CODE_SERIAL_READY);
    gdt_load();
    post_code_write(POST_CODE_GDT_LOADED);
    serial_put_string(BANNER);
}
