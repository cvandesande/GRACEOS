#ifndef COMPAT_H
#define COMPAT_H

#include <limits.h>
#include <stddef.h>

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;

/* WORKAROUND: name is a declarator, so it cannot be parenthesised.
 * NOLINTNEXTLINE(bugprone-macro-parentheses) */
#define STATIC_ASSERT(condition, name) typedef char name[(condition) ? 1 : -1]

STATIC_ASSERT(CHAR_BIT == 8, char_has_eight_bits_t);
STATIC_ASSERT(sizeof(uint8_t) == 1, uint8_is_one_byte_t);
STATIC_ASSERT(sizeof(uint16_t) == 2, uint16_is_two_bytes_t);
STATIC_ASSERT(sizeof(uint32_t) == 4, uint32_is_four_bytes_t);

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#define STATIC_INLINE static inline
#define RESTRICT restrict
#elif defined(__GNUC__)
#define STATIC_INLINE static __inline__
#define RESTRICT __restrict__
#else
#define STATIC_INLINE static
#define RESTRICT
#endif

#ifdef __GNUC__
#define NORETURN __attribute__((noreturn))
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define NORETURN _Noreturn
#else
#define NORETURN
#endif

#ifdef __GNUC__
#define ALIGNED(bytes) __attribute__((aligned(bytes)))
#endif

#endif
