#ifndef PORT_H
#define PORT_H

#include "compat.h"

#define POST_PORT 0x80

STATIC_INLINE void port_write(uint16_t port, uint8_t value)
{
    __asm__ volatile("outb %0, %1" : : "a"(value), "Nd"(port));
}

STATIC_INLINE uint8_t port_read(uint16_t port)
{
    uint8_t value = 0;
    __asm__ volatile("inb %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

STATIC_INLINE void post_code_write(uint8_t code)
{
    port_write(POST_PORT, code);
}

#endif
