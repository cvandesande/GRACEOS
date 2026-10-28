#ifndef ASSERTION_H
#define ASSERTION_H

#include "compat.h"

NORETURN void assertion_failed(const char *file, uint32_t line, const char *condition);

#define ASSERT(condition) ((condition) ? (void)0 : assertion_failed(__FILE__, __LINE__, #condition))

#ifdef NDEBUG
#define DEBUG_ASSERT(condition) ((void)0)
#else
#define DEBUG_ASSERT(condition) ASSERT(condition)
#endif

#endif
