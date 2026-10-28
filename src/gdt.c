#include "gdt.h"

#include "compat.h"

#define GDT_ENTRY_COUNT 3

#define ACCESS_PRESENT 0x80U
#define ACCESS_CODE_OR_DATA_SEGMENT 0x10U
#define ACCESS_EXECUTABLE 0x08U
#define ACCESS_CODE_READABLE 0x02U
#define ACCESS_DATA_WRITABLE 0x02U

#define FLAGS_GRANULARITY_4_KIB 0x80U
#define FLAGS_DEFAULT_32_BIT 0x40U
#define LIMIT_HIGH_BITS_ALL_SET 0x0FU
#define LIMIT_LOW_BITS_ALL_SET 0xFFFFU

#define LOW_HALF_MASK 0xFFFFU
#define HALF_WORD_BITS 16U

struct segment_descriptor {
    uint16_t limit_low;
    uint16_t base_low;
    uint8_t base_middle;
    uint8_t access;
    uint8_t flags_and_limit_high;
    uint8_t base_high;
};

/* WHY: lgdt reads a 16-bit limit then a 32-bit base with no padding between them. Splitting the
 * base in two 16-bit halves gives that layout without a packed attribute. */
struct gdt_pointer {
    uint16_t limit;
    uint16_t base_low;
    uint16_t base_high;
};

STATIC_ASSERT(sizeof(struct segment_descriptor) == 8, segment_descriptor_is_eight_bytes_t);
STATIC_ASSERT(sizeof(struct gdt_pointer) == 6, gdt_pointer_is_six_bytes_t);
STATIC_ASSERT(sizeof(struct segment_descriptor) * 1 == GDT_KERNEL_CODE_SELECTOR,
              kernel_code_selector_is_entry_one_t);
STATIC_ASSERT(sizeof(struct segment_descriptor) * 2 == GDT_KERNEL_DATA_SELECTOR,
              kernel_data_selector_is_entry_two_t);

/* WHY: every segment starts at 0 and spans 4 GiB, so segmentation does nothing and paging will
 * do the protecting. The CPU writes the accessed bit into a descriptor when a selector loads it,
 * so the table stays writable. */
static struct segment_descriptor gdt[GDT_ENTRY_COUNT] ALIGNED(8) = {
    {0, 0, 0, 0, 0, 0},
    {LIMIT_LOW_BITS_ALL_SET, 0, 0,
     ACCESS_PRESENT | ACCESS_CODE_OR_DATA_SEGMENT | ACCESS_EXECUTABLE | ACCESS_CODE_READABLE,
     FLAGS_GRANULARITY_4_KIB | FLAGS_DEFAULT_32_BIT | LIMIT_HIGH_BITS_ALL_SET, 0},
    {LIMIT_LOW_BITS_ALL_SET, 0, 0,
     ACCESS_PRESENT | ACCESS_CODE_OR_DATA_SEGMENT | ACCESS_DATA_WRITABLE,
     FLAGS_GRANULARITY_4_KIB | FLAGS_DEFAULT_32_BIT | LIMIT_HIGH_BITS_ALL_SET, 0}};

void gdt_load(void)
{
    struct gdt_pointer pointer;
    uint32_t base = (uint32_t)gdt;
    uint16_t data_selector = GDT_KERNEL_DATA_SELECTOR;

    pointer.limit = sizeof(gdt) - 1U;
    pointer.base_low = (uint16_t)(base & LOW_HALF_MASK);
    pointer.base_high = (uint16_t)(base >> HALF_WORD_BITS);

    /* WHY: lgdt alone changes nothing the CPU uses; each segment register keeps its cached
     * descriptor until a selector is loaded into it, and the far jump reloads CS. */
    __asm__ volatile("lgdt %0\n\t"
                     "ljmp %1, $1f\n"
                     "1:\n\t"
                     "movw %2, %%ds\n\t"
                     "movw %2, %%es\n\t"
                     "movw %2, %%fs\n\t"
                     "movw %2, %%gs\n\t"
                     "movw %2, %%ss"
                     :
                     : "m"(pointer), "i"(GDT_KERNEL_CODE_SELECTOR), "r"(data_selector)
                     : "memory");
}
