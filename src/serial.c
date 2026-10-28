#include "serial.h"

#include "compat.h"
#include "port.h"

#define COM1_BASE 0x3F8
#define BAUD_DIVISOR_115200 1

#define DECIMAL_BASE 10U
#define MAX_DECIMAL_DIGITS 10

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

void serial_init(void)
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

void serial_put_char(char character)
{
    wait_until_transmitter_empty();
    serial_write_register(UART_DATA, (uint8_t)character);
}

void serial_put_string(const char *text)
{
    for (; *text != '\0'; text++) {
        serial_put_char(*text);
    }
}

void serial_put_unsigned(uint32_t value)
{
    char digits[MAX_DECIMAL_DIGITS];
    uint32_t digit_count = 0;

    do {
        digits[digit_count] = (char)('0' + (value % DECIMAL_BASE));
        digit_count++;
        value /= DECIMAL_BASE;
    } while (value != 0);

    while (digit_count > 0) {
        digit_count--;
        serial_put_char(digits[digit_count]);
    }
}
