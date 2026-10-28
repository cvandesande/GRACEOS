#ifndef SERIAL_H
#define SERIAL_H

#include "compat.h"

void serial_init(void);
void serial_put_char(char character);
void serial_put_string(const char *text);
void serial_put_unsigned(uint32_t value);

#endif
