# GRACEOS: notes for agents and contributors

GRACEOS is a hybrid kernel for a 386 PC that runs POSIX (Unix) programs, DOS and Windows 3.1 (386 Enhanced mode) programs side by side. It is a learning project and a test bench for architecture ideas. The name is written in capitals.

## Where to look

- `docs/design.md`: the source of truth. Decisions, proposals, hypotheses, build plan and decision log. Read all of it with the Read tool before proposing anything; do not search it with `grep`, which skips the Decided and Proposed labels around a match.
- `README.md`: short summary of the project.
- `flake.nix`: the dev shell. Run `nix develop` to get the toolchain and activate the pre-commit hook.
- GitHub milestones: one per build-plan phase, with the phase gate as the description. Check the current phase there.

## The design doc

- Every item is **Decided**, **Proposed** or **To measure**. Do not treat Proposed items as settled.
- Changing a Decided item means a new entry in the decision log, not a silent edit.
- Results of a measurement go into the doc and its decision log. Issues only point to them.

## Licence

- Our own code is MIT. Third-party code is allowed only under a permissive licence (MIT, BSD, ISC or 0BSD), in a separate directory with its licence intact. Check the header of every imported file. Do not add, vendor or ship anything under an incompatible licence, GPL included. If a component needs one, say so and propose writing our own.
- Never use leaked or disassembled Microsoft code. GPL and Microsoft code are behaviour references only.

## Code conventions

- Assembly (NASM) for boot, mode switches, interrupt entry, context switching and fast paths; strict C11 for everything else (`-std=c11 -pedantic -ffreestanding -nostdlib -Werror`, with the strictest warning set for each compiler as defined in the `Makefile`: an explicit list for GCC, `-Weverything` for Clang minus the exclusions listed there). All warnings are errors.
- Our C must also compile as C89 (`make c89`), so old compilers can build it: `/* */` comments only, declarations at the top of a block, no trailing comma after the last enumerator, and no `inline`, `restrict`, `long long`, `bool` or designated initialisers. Use `src/compat.h` instead: its `uint8_t`, `uint16_t` and `uint32_t` replace `<stdint.h>` (no 64-bit type), and `STATIC_ASSERT`, `STATIC_INLINE`, `RESTRICT`, `NORETURN` and `ALIGNED` replace the C99 and C11 features. `bool`, designated initialisers, mixed declarations and compound literals have no workaround.
- Keep C compiler-neutral: it must build with both GCC and Clang, with no extensions beyond inline assembly, attributes and the keyword spellings in `src/compat.h` that both accept. GCC is the primary compiler. Build with Clang too (`make clang`) and compare the generated assembly and speed.
- One kernel image for every CPU configuration, built for the plain 386. Do not use 486-only instructions (cmpxchg, xadd, invlpg, bswap and so on) outside paths guarded by boot-time CPU detection. Every `.asm` file starts with `cpu 386` (`cpu 486` only in a file holding a guarded 486 path) and GCC builds with `-Wa,-march=i386`, so the assemblers reject them; `make check386` scans the linked kernel, which also covers Clang.
- CPU differences are selected at run time, never at build time: no `#ifdef` and no per-CPU git branches. Each operation that differs between CPUs (such as flushing one TLB entry or an atomic add) sits behind one self-explanatory function name, with a plain 386 version and a version for each newer CPU that needs one. Boot-time CPU detection fills a table of function pointers (`cpu_operations`) with the right versions, and callers only use the names. The 386SX runs the same instructions as the 386DX, so it needs no versions of its own; its differences (16-bit bus, no VLB) belong in drivers. Boot-time patching of the call sites, as NetBSD does in `sys/arch/x86/x86/patch.c`, is a **To measure** option: switch only when a measurement shows the pointer calls cost too much, and change only the mechanism, not the callers.
- Nothing may rule out the 386SX: work within 16MB and 24-bit addresses, with no reliance on an FPU.
- Atomics on the 386 briefly disable interrupts, or use `lock inc` and `lock dec` with the CPU flags. There is no `cmpxchg` or `xadd` before the 486.
- No floating point in the kernel or services; the 386 may have no FPU. Build with `-mgeneral-regs-only`.
- The 386 has no cycle counter. Benchmarks use the 8254 timer.
- Never use port 80h as an I/O delay: it carries the POST card's progress codes.
- Emit port 80h progress codes and serial output on COM1 at each boot stage.
- Code need not be perfect, but it must be simple and easy to read. Prefer small designs with few options. Do not add configurability, abstraction layers or negotiation until a measurement or a concrete need justifies it. The in-kernel or IPC experiment harness is the deliberate exception.
- Names must be self-explanatory: functions, variables, constants, enums and types. If code seems to need a comment, rename or restructure it first. A comment is the exception, and it starts with a tag (`/* ` in C, since `//` is not C89; `; ` in assembly): `WORKAROUND:` for an unexpected workaround, saying why it is needed, or `WHY:` for a fact a name cannot carry, such as a hardware behaviour, an ordering constraint or a datasheet reference.

## Robust C

Flight-software style: the code should fail loudly and early, and never silently. These rules sit on top of the code conventions above, and the same hook and builds enforce what they can.

- **Errors**: a function that can fail returns `int`, 0 for success and a negative error code on failure (`-E_NOMEM`, `-E_IO`). Mark it `MUST_CHECK`. Results come back through pointer parameters, not through the status code. A function returns `void` only when failure is impossible or meaningless, such as writing a character to the serial port.
- **Check every return value.** To ignore one on purpose, use `IGNORE_RESULT(...)` with a `WHY:` comment. A plain `(void)` cast does not silence `warn_unused_result` in GCC. Both macros belong in `src/compat.h`, with an empty fallback for compilers that lack the attribute (GCC before 3.4):

```c
#if defined(__GNUC__) && (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 4))
#define MUST_CHECK __attribute__((warn_unused_result))
#else
#define MUST_CHECK
#endif
#define IGNORE_RESULT(expression) ((void)((expression) != 0))
```

- **One exit point**: a function that acquires something releases it at a single cleanup label at the end. Forward `goto` to that label is the only `goto` allowed. This is a deliberate exception to the NASA JPL "Power of 10" rule against `goto`, and it is how C gets the effect of Rust's `Drop`.

```c
MUST_CHECK static int work_with_buffer(void)
{
    int result;
    struct buffer *buffer = 0;

    result = buffer_get(&buffer);
    if (result != 0) {
        goto out;
    }
    result = buffer_fill(buffer);
out:
    if (buffer != 0) {
        buffer_put(buffer);
    }
    return result;
}
```

- **Distinct types for distinct things.** `typedef` alone does not create a new type in C, so wrap addresses in one-field structs (`struct physical_address { uint32_t value; }`, `struct virtual_address { uint32_t value; }`). Never pass one where the other is expected.
- **Buffers travel as a pointer and a length** in one struct, accessed through functions that check bounds in one place.
- **Every object has one owner**, documented where it is declared. Function names say who frees (`buffer_get` and `buffer_put`, `x_take` and `x_give`).
- **Validate once, where data enters**: system calls, IPC messages, hardware registers, disk blocks. Code behind that boundary may rely on what was checked.
- **No dynamic allocation outside the memory manager.** Use fixed-size tables and pools.
- **Assertions**: `ASSERT(condition)` is always on. On failure it prints file, line and condition to COM1, writes `0xEE` to port 80h, disables interrupts and halts. Use it on cold paths and for conditions that mean the kernel's own state is corrupt. `DEBUG_ASSERT(condition)` is compiled out of release builds; use it on hot paths. A stopped machine with a clear message beats silent corruption.

### Strictness by tier

| Tier | Code | Rules |
| --- | --- | --- |
| 1 | Kernel core: IPC, scheduler, memory manager, interrupt and V86 paths | All of the above, plus: no recursion, every loop has a fixed upper bound, no allocation after boot, functions under about 60 lines, and assertions on the invariants of each non-trivial function |
| 2 | Services: disk, filesystem, block cache, device virtualisation | All of the above; bounded loops where practical; fixed pools |
| 3 | Personalities: POSIX, DOS, Windows | All of the above, except that they may allocate from the memory manager, always with a checked result |

Strictness is for correctness. If a rule here makes a tier 1 function harder to read, say so rather than working around it.

### Performance

- Measure before tuning. Hot paths (IPC fast path, context switch, interrupt entry, V86 traps) are hand-written NASM, and each has a plain C version with the same behaviour. A host test runs both on random inputs and compares the results.
- Compare `-Os` with `-O2` and `-mtune=i386` with `-mtune=i486` by measurement. On a cacheless 386 code size may matter more than clever scheduling.
- Keep `ASSERT` off hot paths. Everything else here costs nothing at run time.
- When quoting a benchmark, say which compiler built the code.

### Era compiler check

`make c89` proves the syntax is old enough, but only GCC says so. Before each phase gate, and whenever a new extension or header is introduced, also compile every C file with Open Watcom (`wcc386`), which the flake does not provide yet: add it to `flake.nix` when the first gate needs it. It checks that the code compiles, not that it links or boots. If a feature breaks it, remove the feature.

## Checks and commits

- There is no CI. The pre-commit hook in `.githooks/` enforces the rules: `clang-tidy` (config in `.clang-tidy`) for naming and readability, `clang-format` (config in `.clang-format`) for layout, and Semgrep (rules in `.semgrep/`) for the comment rule. When the staged files include C, assembly, headers, the `Makefile` or `linker.ld`, the hook also runs the three builds, `make disk` and `check386` on each kernel.
- Verify a change with `make` (GCC), `make clang`, `make c89`, `make disk` and `make check386` (add `BUILD=build/clang` or `BUILD=build/c89` for the other kernels), then `make run` (boots in QEMU with serial on the terminal; quit with Ctrl-A then X) or `make run-disk` (boots through our own loader). A change is done when all three builds pass and the banner appears. The hook runs everything except the boot.
- Commit from inside `nix develop`. The hook needs its tools, and the dev shell is what activates it.
- Fix violations. Never bypass the hook with `--no-verify`.
- Claude Code also runs `clang-format -i` on a C file after each edit when it was started inside `nix develop` (elsewhere `clang-format` is not on `PATH` and the hook does nothing), and asks before `git push` and `gh` commands (both in `.claude/settings.json`).
- Put `Closes #N` in a commit message to close an issue.

## Tracking

- Issues are for trackable tasks, bugs and `to-measure` hypotheses. Open them for the current phase only.
- Labels: `decided`, `proposed`, `to-measure`.
- Tag each passed phase gate, for example `phase1-serial-boot`.
- Benchmark results go in `results/<cpu-config>/` (not created yet).

## Working style

- Do what was asked, completely, and no more. Both halves matter: finish every part of the request, and do not add to it.
- Within the request, carry on without asking. Steps that are inherent to it, such as checking that what you just wrote works, do not need permission.
- Outside the request, do not act. Do not add files, tools, scaffolding, git history or structure that nobody asked for. If something extra looks useful, say so in one line and wait.
- If the scope is unclear, take the smallest reasonable reading, do it fully, and say what you left out.
- Confirm before anything outward-facing: pushing, creating or changing GitHub items.
- When reviewing a change, check correctness against `docs/design.md` and skip style, which the hook enforces. A reviewer asked for problems always finds something, and acting on every finding adds the abstraction layers we avoid.
- The user is learning C through this project and asks many questions. When asked what is best, say which kind of answer it is: verifiable (the standard, the compiler or a datasheet decides), a community convention (name who does it and why), a project rule (point to it), or your own preference (give the tradeoff). Say when you answer from memory.
