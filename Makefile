BUILD := build/gcc
CC := i686-elf-gcc
STD := c11
# WHY: -Wa,-march=i386 makes GNU as reject 486 instructions in inline assembly, which -march=i386 alone lets through; Clang's assembler ignores it
# WORKAROUND: the Nix GCC enables the stack protector by default, which needs __stack_chk_guard and __stack_chk_fail, and the kernel has neither
COMMON_FLAGS := -std=$(STD) -pedantic -ffreestanding -nostdlib -fno-stack-protector -march=i386 -Wa,-march=i386 -O2 -Werror
GCC_WARNINGS := -Wall -Wextra -Wconversion -Wsign-conversion -Wshadow -Wstrict-prototypes \
	-Wmissing-prototypes -Wmissing-declarations -Wold-style-definition -Wredundant-decls \
	-Wcast-qual -Wcast-align -Wpointer-arith -Wwrite-strings -Wundef -Wformat=2 \
	-Wnull-dereference -Wduplicated-cond -Wduplicated-branches -Wlogical-op \
	-Wswitch-default -Wswitch-enum -Wfloat-equal -Wvla -Wdouble-promotion \
	-Wjump-misses-init -Wbad-function-cast -Wnested-externs -fanalyzer
# WHY: -Wunsafe-buffer-usage is aimed at C++ (its fixes use std::span) and flags every pointer increment and subscript
CLANG_WARNINGS := -Weverything -Wno-unsafe-buffer-usage
WARNINGS := $(GCC_WARNINGS)
CFLAGS := $(COMMON_FLAGS) $(WARNINGS)
LOADER_SECTORS := 8
# WHY: a list of known post-386 instructions can miss one, unlike the assembler checks, which accept only 386 instructions
POST_386_INSTRUCTIONS := bswap|cmpxchg|cmpxchg8b|xadd|invlpg|invd|wbinvd|cpuid|rdtsc|rdtscp|rdmsr|wrmsr|rdpmc|rsm|sysenter|sysexit|syscall|sysret|cmov[a-z]+|fcmov[a-z]+|fcomip?|fucomip|emms|fxsave|fxrstor|lfence|sfence|mfence|prefetch[a-z0-9]*|movnti|popcnt|lzcnt|tzcnt|movbe|rdrand|rdseed|xgetbv
POST_386_REGISTERS := %(xmm|ymm|zmm|mm)[0-9]

.DELETE_ON_ERROR:

KERNEL_OBJECTS := $(BUILD)/boot.o $(BUILD)/kmain.o $(BUILD)/serial.o $(BUILD)/assertion.o $(BUILD)/gdt.o

$(BUILD)/kernel.elf: $(KERNEL_OBJECTS) linker.ld
	i686-elf-ld -m elf_i386 --no-warn-rwx-segments -z noexecstack -T linker.ld -o $@ $(KERNEL_OBJECTS)

$(BUILD)/boot.o: src/boot.asm src/kernel_header.inc | $(BUILD)
	nasm -f elf32 -Werror -I src/ $< -o $@

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(BUILD)/kmain.d $(BUILD)/serial.d $(BUILD)/assertion.d $(BUILD)/gdt.d

$(BUILD)/kernel.bin: $(BUILD)/kernel.elf
	i686-elf-objcopy -O binary $< $@
	test "$$(stat -c %s $@)" = "$$(od -A n -t u4 -j 8 -N 4 $@ | tr -d ' ')" \
		|| { echo "$@ differs in size from the file bytes in its header: a section outside .text, .rodata and .data?"; exit 1; }

$(BUILD)/stage1.bin: src/loader/stage1.asm | $(BUILD)
	nasm -f bin -Werror -d LOADER_SECTORS=$(LOADER_SECTORS) $< -o $@

$(BUILD)/stage2.bin: src/loader/stage2.asm src/kernel_header.inc | $(BUILD)
	nasm -f bin -Werror -I src/ -d LOADER_SECTORS=$(LOADER_SECTORS) $< -o $@

$(BUILD)/disk.img: $(BUILD)/stage1.bin $(BUILD)/stage2.bin $(BUILD)/kernel.bin
	cat $^ > $@
	truncate --size=%512 $@

$(BUILD):
	mkdir -p $@

clang:
	$(MAKE) BUILD=build/clang CC="clang --target=i386-none-elf" WARNINGS="$(CLANG_WARNINGS)"

c89:
	$(MAKE) BUILD=build/c89 STD=c89

disk: $(BUILD)/disk.img

check386: $(BUILD)/kernel.elf
	@if i686-elf-objdump -d --no-show-raw-insn --start-address=0x$$(i686-elf-nm $< | awk '$$3 == "_start" { print $$1 }') $< \
		| grep -E '^ *[0-9a-f]+:[[:space:]]+((lock|rep|repz|repnz|data16|addr16)[[:space:]]+)*(($(POST_386_INSTRUCTIONS))([[:space:]]|$$)|.*$(POST_386_REGISTERS))'; then \
		echo "$< contains instructions the plain 386 lacks"; exit 1; fi

test: $(BUILD)/kernel.elf $(BUILD)/disk.img
	tests/boot_test.sh -kernel $(BUILD)/kernel.elf
	tests/boot_test.sh -drive format=raw,file=$(BUILD)/disk.img

run: $(BUILD)/kernel.elf
	qemu-system-i386 -cpu 486 -kernel $(BUILD)/kernel.elf -nographic -no-reboot

run-disk: $(BUILD)/disk.img
	qemu-system-i386 -cpu 486 -drive format=raw,file=$(BUILD)/disk.img -nographic -no-reboot

clean:
	rm -rf build

.PHONY: clang c89 check386 disk test run run-disk clean
