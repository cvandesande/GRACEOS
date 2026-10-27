#include "kmain.h"

#include "compat.h"

#define COM1_BASE 0x3F8
#define POST_PORT 0x80
#define POST_CODE_SERIAL_READY 0x02
#define BAUD_DIVISOR_115200 1

#define LINE_CONTROL_DIVISOR_LATCH 0x80U
#define LINE_CONTROL_8N1 0x03U
#define MODEM_CONTROL_DTR_RTS 0x03U
#define LINE_STATUS_TRANSMIT_EMPTY 0x20U

enum uart_register {
    UART_DATA = 0,
    UART_INTERRUPT_ENABLE = 1,
    UART_LINE_CONTROL = 3,
    UART_MODEM_CONTROL = 4,
    UART_LINE_STATUS = 5,
    UART_LATCHED_DIVISOR_LOW = 0,
    UART_LATCHED_DIVISOR_HIGH = 1
};

static const char BANNER[] = "GRACEOS 0.1 - dedicated to Andrew Tanenbaum and Linus Torvalds,\r\n"
                             "who argued about this in 1992. They were both right.\r\n";

static void port_write(uint16_t port, uint8_t value)
{
    __asm__ volatile("outb %0, %1" : : "a"(value), "Nd"(port));
}

static uint8_t port_read(uint16_t port)
{
    uint8_t value = 0;
    __asm__ volatile("inb %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

static void post_code_write(uint8_t code)
{
    port_write(POST_PORT, code);
}

static uint16_t com1_port(enum uart_register reg)
{
    return (uint16_t)(COM1_BASE + reg);
}

static void serial_write_register(enum uart_register reg, uint8_t value)
{
    port_write(com1_port(reg), value);
}

static uint8_t serial_read_register(enum uart_register reg)
{
    return port_read(com1_port(reg));
}

static void serial_init(void)
{
    serial_write_register(UART_INTERRUPT_ENABLE, 0);
    serial_write_register(UART_LINE_CONTROL, LINE_CONTROL_DIVISOR_LATCH);
    serial_write_register(UART_LATCHED_DIVISOR_LOW, BAUD_DIVISOR_115200);
    serial_write_register(UART_LATCHED_DIVISOR_HIGH, 0);
    serial_write_register(UART_LINE_CONTROL, LINE_CONTROL_8N1);
    serial_write_register(UART_MODEM_CONTROL, MODEM_CONTROL_DTR_RTS);
}

static void wait_until_transmitter_empty(void)
{
    while ((serial_read_register(UART_LINE_STATUS) & LINE_STATUS_TRANSMIT_EMPTY) == 0) {
    }
}

static void serial_put_char(char character)
{
    wait_until_transmitter_empty();
    serial_write_register(UART_DATA, (uint8_t)character);
}

static void serial_put_string(const char *text)
{
    for (; *text != '\0'; text++) {
        serial_put_char(*text);
    }
}

void kmain(void)
{
    serial_init();
    post_code_write(POST_CODE_SERIAL_READY);
    serial_put_string(BANNER);
}
