# GRACEOS: notes for agents

GRACEOS is a hybrid kernel for a 386 PC that runs Linux, DOS and Windows 3.1 (386 Enhanced mode) programs side by side. It is a learning project and a test bench for architecture ideas. The name is written in capitals.

## Where to look

- `docs/design.md`: the source of truth. Decisions, proposals, hypotheses, build plan and decision log. Read it before proposing anything.
- `README.md`: short summary of the project.
- `flake.nix`: the dev shell (`nix develop`).
- GitHub milestones: one per build-plan phase, with the phase gate as the description. Check the current phase there.

## Working with the design doc

- Every item in the design doc is **Decided**, **Proposed** or **To measure**. Do not treat Proposed items as settled.
- Changing a Decided item means a new entry in the decision log, not a silent edit.
- Results of a measurement go into the doc and its decision log. Issues only point to them.
- Never use leaked or disassembled Microsoft code. GPL and Microsoft code are behaviour references only.
- The project is MIT only. Do not add, vendor or ship code or software under an incompatible licence. If a component needs one, say so and propose writing our own.

## Conventions from the plan

- Assembly (NASM) for boot, mode switches, interrupt entry, context switching and fast paths; strict C11 for everything else (`-std=c11 -ffreestanding -nostdlib -Wall -Wextra -Werror`).
- One kernel image for every CPU configuration, built for the plain 386. Do not use 486-only instructions (cmpxchg, xadd, invlpg, bswap and so on) outside paths guarded by boot-time CPU detection.
- Nothing may rule out the 386SX: work within 16MB and 24-bit addresses, with no reliance on an FPU.
- Code need not be perfect, but it must be simple and easy to read. Prefer small designs with few options. Do not add configurability, abstraction layers or negotiation until a measurement or a concrete need justifies it. The in-kernel or IPC experiment harness is the deliberate exception. This is a Decided principle in `docs/design.md`.
- Keep code compiler-neutral: strict C11 that builds with both GCC and Clang, with no extensions beyond inline assembly and attributes both accept. GCC is the primary compiler. As code lands, also build with Clang and compare the generated assembly and speed.
- Names must be self-explanatory: functions, variables, constants, enums and types. If code seems to need a comment, rename or restructure it first. A comment is the exception, only for an unexpected workaround, and it says why the workaround is needed. Never write comments that restate what the code does.
- Serial console on COM1 and port 80h progress codes from the start.
- The 386 has no cycle counter. Benchmarks use the 8254 timer.

## Tracking

- Issues are for trackable tasks, bugs and `to-measure` hypotheses. Open them for the current phase only.
- Labels: `decided`, `proposed`, `to-measure`.
- Put `Closes #N` in a commit message to close an issue.
- Tag each passed phase gate, for example `phase1-serial-boot`.
- There is no CI. The pre-commit hook in `.githooks/` enforces the rules: `clang-tidy` (config in `.clang-tidy`) for naming and readability, and Semgrep (rules in `.semgrep/`) for the comment rule. The dev shell activates the hook. Fix violations; never bypass it with `--no-verify`. Comments in code must start with `WORKAROUND:`.
- Benchmark results are planned for a `results/` directory, one folder per CPU configuration.

## Working style

- Do what was asked, completely, and no more. Both halves matter: finish every part of the request, and do not add to it.
- Within the request, carry on without asking. Steps that are inherent to it, such as checking that what you just wrote works, do not need permission.
- Outside the request, do not act. Do not add files, tools, scaffolding, git history or structure that nobody asked for. If something extra looks useful, say so in one line and wait.
- If the scope is unclear, take the smallest reasonable reading, do it fully, and say what you left out.
- Confirm before anything outward-facing: pushing, creating or changing GitHub items.
- The git remote is SSH (`git@github.com:cvandesande/GRACEOS.git`).
