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

- The project is MIT only. Do not add, vendor or ship code or software under an incompatible licence. If a component needs one, say so and propose writing our own.
- Never use leaked or disassembled Microsoft code. GPL and Microsoft code are behaviour references only.

## Code conventions

- Assembly (NASM) for boot, mode switches, interrupt entry, context switching and fast paths; strict C11 for everything else (`-std=c11 -ffreestanding -nostdlib -Wall -Wextra -Werror`).
- Keep C compiler-neutral: it must build with both GCC and Clang, with no extensions beyond inline assembly and attributes both accept. GCC is the primary compiler. As code lands, also build with Clang and compare the generated assembly and speed.
- One kernel image for every CPU configuration, built for the plain 386. Do not use 486-only instructions (cmpxchg, xadd, invlpg, bswap and so on) outside paths guarded by boot-time CPU detection.
- Nothing may rule out the 386SX: work within 16MB and 24-bit addresses, with no reliance on an FPU.
- The 386 has no cycle counter. Benchmarks use the 8254 timer.
- Emit port 80h progress codes and serial output on COM1 at each boot stage.
- Code need not be perfect, but it must be simple and easy to read. Prefer small designs with few options. Do not add configurability, abstraction layers or negotiation until a measurement or a concrete need justifies it. The in-kernel or IPC experiment harness is the deliberate exception.
- Names must be self-explanatory: functions, variables, constants, enums and types. If code seems to need a comment, rename or restructure it first. A comment is the exception: only for an unexpected workaround, starting with `WORKAROUND:` (`// WORKAROUND:` in C, `; WORKAROUND:` in assembly) and saying why it is needed.

## Checks and commits

- There is no CI. The pre-commit hook in `.githooks/` enforces the rules: `clang-tidy` (config in `.clang-tidy`) for naming and readability, and Semgrep (rules in `.semgrep/`) for the comment rule.
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
