# GRACEOS: notes for agents and contributors

GRACEOS is a hybrid kernel for a 386 PC that runs Linux, DOS and Windows 3.1 (386 Enhanced mode) programs side by side. It is a learning project and a test bench for architecture ideas. The name is written in capitals.

## Where to look

- `docs/design.md`: the source of truth. Decisions, proposals, hypotheses, build plan and decision log. Read it before proposing anything.
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
- Keep C compiler-neutral: it must build with both GCC and Clang, with no extensions beyond inline assembly and attributes both accept. GCC is the primary compiler. As code lands, also build with Clang and compare the generated assembly and speed.
- One kernel image for every CPU configuration, built for the plain 386. Do not use 486-only instructions (cmpxchg, xadd, invlpg, bswap and so on) outside paths guarded by boot-time CPU detection.
- Nothing may rule out the 386SX: work within 16MB and 24-bit addresses, with no reliance on an FPU.
- The 386 has no cycle counter. Benchmarks use the 8254 timer.
- Emit port 80h progress codes and serial output on COM1 at each boot stage.
- Code need not be perfect, but it must be simple and easy to read. Prefer small designs with few options. Do not add configurability, abstraction layers or negotiation until a measurement or a concrete need justifies it. The in-kernel or IPC experiment harness is the deliberate exception.
- Names must be self-explanatory: functions, variables, constants, enums and types. If code seems to need a comment, rename or restructure it first. A comment is the exception, and it starts with a tag (`/* ` in C, since `//` is not C89; `; ` in assembly): `WORKAROUND:` for an unexpected workaround, saying why it is needed, or `WHY:` for a fact a name cannot carry, such as a hardware behaviour, an ordering constraint or a datasheet reference.

## Checks and commits

- There is no CI. The pre-commit hook in `.githooks/` enforces the rules: `clang-tidy` (config in `.clang-tidy`) for naming and readability, `clang-format` (config in `.clang-format`) for layout, and Semgrep (rules in `.semgrep/`) for the comment rule.
- Commit from inside `nix develop`. The hook needs its tools, and the dev shell is what activates it.
- Fix violations. Never bypass the hook with `--no-verify`.
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
- The user is learning C through this project and asks many questions. When asked what is best, say which kind of answer it is: verifiable (the standard, the compiler or a datasheet decides), a community convention (name who does it and why), a project rule (point to it), or your own preference (give the tradeoff). Say when you answer from memory.
