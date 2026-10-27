BUILD := build/gcc
CC := i686-elf-gcc
STD := c11
COMMON_FLAGS := -std=$(STD) -pedantic -ffreestanding -nostdlib -march=i386 -O2 -Werror
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

$(BUILD)/kernel.elf: $(BUILD)/boot.o $(BUILD)/kmain.o linker.ld
	i686-elf-ld -m elf_i386 --no-warn-rwx-segments -z noexecstack -T linker.ld -o $@ $(BUILD)/boot.o $(BUILD)/kmain.o

$(BUILD)/boot.o: src/boot.asm | $(BUILD)
	nasm -f elf32 $< -o $@

$(BUILD)/kmain.o: src/kmain.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD):
	mkdir -p $@

clang:
	$(MAKE) BUILD=build/clang CC="clang --target=i386-none-elf" WARNINGS="$(CLANG_WARNINGS)"

c89:
	$(MAKE) BUILD=build/c89 STD=c89

run: $(BUILD)/kernel.elf
	qemu-system-i386 -cpu 486 -kernel $(BUILD)/kernel.elf -nographic -no-reboot

clean:
	rm -rf build

.PHONY: clang c89 run clean
