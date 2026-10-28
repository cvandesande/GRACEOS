#include "assertion.h"

#include "compat.h"
#include "port.h"
#include "serial.h"

#define POST_CODE_ASSERTION_FAILED 0xEE

void assertion_failed(const char *file, uint32_t line, const char *condition)
{
    __asm__ volatile("cli");
    post_code_write(POST_CODE_ASSERTION_FAILED);
    serial_put_string("ASSERT failed: ");
    serial_put_string(file);
    serial_put_char(':');
    serial_put_unsigned(line);
    serial_put_string(": ");
    serial_put_string(condition);
    serial_put_string("\r\n");
    for (;;) {
        __asm__ volatile("hlt");
    }
}
