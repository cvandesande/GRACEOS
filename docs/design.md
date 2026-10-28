# GRACEOS: Design Notes

Oct 15, 2026 · @Chris

> **Dedication.** This kernel is dedicated to Andrew Tanenbaum and Linus Torvalds, whose 1992 debate over microkernels and monolithic kernels inspired it. Tanenbaum was right that a microkernel is the cleaner design; Torvalds was right that speed on real hardware decides everything. This design only works by taking both seriously.
>
> The dedication appears in the boot messages:
>
> ```
> GRACEOS 0.1 - dedicated to Andrew Tanenbaum and Linus Torvalds,
> who argued about this in 1992. They were both right.
> ```

## How to read this document

This is a living design document for a learning project. Every item carries one of three labels:

- **Decided**: settled. Changing it means a new entry in the decision log.
- **Proposed**: a suggested approach, not yet tested, which may be replaced.
- **To measure**: a performance or behaviour claim that only a benchmark can settle.

As experiments run, items move from Proposed or To measure to Decided, and the decision log records what was learned.

## Goal (Decided)

A hybrid kernel for a 386 PC that runs Linux, DOS and Windows 3.1 in 386 Enhanced mode at the same time, so programs from the era run side by side without rebooting. It's also a test bench: try ideas from microkernels, BeOS and OS/2, and measure which run best on a 386, then with a 387 and on a 486.

**Aims**

- See whether modern software engineering techniques, such as batched ring interfaces, strict static analysis and host-side tests, can get better results out of retro hardware.
- Play the DOS games of the era on our own kernel.
- Learn how microkernels work by combining the best of OS/2, BeOS, NT and Windows 3.1 Enhanced mode.

**Milestones, in order**

1. A working kernel core.
2. DOS games at full speed with sound and joystick. Finish line: X-Wing on a real 386DX.
3. A Linux shell with basic file tools.
4. Windows 3.1 in Enhanced mode: Program Manager and the stock apps.

**Stretch goal**: the same kernel running on a 386SX. Until then, no decision may rule it out (see the 386SX row under Decisions).

**Other architectures**: not a goal for this kernel, which is x86 by design (V86 mode, segments, the PC chipset). The project may later extend to other architectures as a learning exercise, so the design avoids needlessly x86-only structure where that costs nothing; no abstraction layer is added for it before a second architecture exists.

**Non-goals**

- Making CPU-bound code faster than the bare CPU.
- The 286: it lacks paging, V86 mode and 32-bit registers, which all three personalities depend on. A 286 system would be a separate project, in the spirit of OS/2 1.x or ELKS.
- CPUs newer than the 486.
- Using leaked or disassembled Microsoft code.
- Windows 95 or later.

## Decisions

| Area | Decision | Why |
| --- | --- | --- |
| Kernel style | Hybrid: microkernel-like structure, with each service placed inside or outside the kernel according to measurements | Isolation where it's cheap, speed where it matters; where each line falls is an experiment |
| Personalities | Linux, DOS and Windows 3.1 Enhanced mode, running at the same time | The point of the project: era programs without rebooting |
| Filesystem | ext3 as the main filesystem; DOS attributes in an ext3 extended attribute (`user.DOSATTRIB`); FAT only for floppies and DOS boot images | Journaling for fast crash recovery; attributes follow files when renamed or moved |
| First architecture to test | Requests and results travel in shared-memory rings, many per kernel crossing: the most work for the fewest costly calls. The request, not the call, is the unit of work, and a synchronous call is a batch of one (see "Service interface: rings and batching"). A plain synchronous interface is built alongside as the baseline, so every claim for the ring is measured against it | It is the modern technique this project most wants to try on retro hardware. Whether it pays on a 386 is the experiment, not an assumption |
| Hardware | DataExpert EXP3406 1.1 board; test order 386DX, then 386DX with 387, then 486DX, then 486DX2 | One board covers every configuration |
| 386SX compatibility | Keep it possible: everything must work within 16MB of physical memory and 24-bit addresses; ISA-only cards must work, with VLB an optional speed-up; no reliance on an FPU; memory budgets fit 16MB | The 386SX is the same CPU inside, with a 16-bit bus and 16MB limit, so keeping these rules costs little |
| Kernel image | One image for every configuration, built for the plain 386, with 486 features enabled at boot | The same disk works in every configuration |
| Languages | Assembly (NASM) for boot, mode switches, interrupt entry, context switching and fast paths; strict C for everything else | Learn the CPU first-hand, with C's structure where it helps |
| Licence | Our own code is MIT, written from scratch. Third-party code is allowed only under a permissive licence (MIT, BSD, ISC or 0BSD), kept in a separate directory with its licence intact. Nothing shipped may carry an incompatible licence; GPL and Microsoft code used only as behaviour references. Where a component would force one, write our own | Freedom to share, no tainted code |
| Debugging | Serial console on COM1 and port 80h progress codes from day one | Both work before anything else does |
| Development | NixOS flake dev shell; QEMU, Bochs and 86Box before real hardware | Reproducible toolchain |
| Dedication | Andrew Tanenbaum and Linus Torvalds, printed in the boot messages | Their 1992 debate is the question this project tests |
| Design principle | Code need not be perfect, but it must be simple and easy to read. Small designs with few options: no configurability, abstraction layers or negotiation until a measurement or a concrete need justifies them | Simple code can be read and audited end to end, and fixed choices leave nothing to misconfigure; imperfect code that is easy to read can be fixed, while clever code cannot. WireGuard, a few thousand lines with one fixed set of cryptographic primitives, is the model. The experiment harness is the deliberate exception, since it exists to measure |

### Target hardware

| Board feature | Detail |
| --- | --- |
| CPU sockets | 386DX (PGA132), 387DX coprocessor (PGA68), 486 (Socket 1) |
| Bus speeds | 25, 33, 40 or 50MHz |
| Slots | 2 × 32-bit VLB, 7 × 16-bit ISA |
| External cache | 256KB fitted, write-back |
| RAM | Up to 64MB in 30-pin SIMMs, in banks of four; 16MB is the development target |

- **Cards**: VLB video card and VLB IDE controller (ideally multi-I/O); ISA Sound Blaster, NE2000-compatible or 3Com 3C509 network card, joystick port.
- **Board notes**: the clock battery is a non-rechargeable lithium cell, so check the board doesn't try to charge it, or move to an external battery with a blocking diode. Clean and continuity-test the scraped traces between the 386 socket and the chipset before first power-on. With both VLB slots in use at 40MHz or above, check stability. Keep DMA buffers below 16MB and check the BIOS cache settings, since the write-back cache needs care with DMA.

**What the CPUs lack**

| Feature | 386DX | 486DX / DX2 | Why it matters |
| --- | --- | --- | --- |
| On-chip cache | None (board's external cache only) | 8KB | Kernel hot paths must be tiny |
| TLB (address translation cache) | Flushed on every CR3 change | Same, but INVLPG can remove single entries | Switching address spaces is the main cost |
| Write protect in kernel mode (CR0.WP) | No | Yes | Copy-on-write needs extra checks on the 386 |
| Compare-and-swap (CMPXCHG) | No | Yes | Atomics on the 386 briefly disable interrupts or use flag-testing tricks |
| Cycle counter (RDTSC) | No | No | Time benchmarks with the 8254 timer chip instead |
| FPU | Separate 387, optional | Built in | No-FPU handling on a bare 386 |
| V86 mode extensions (VME) | No | No | DOS code traps on CLI, STI, PUSHF, POPF, INT unless IOPL=3 |
| Fast system call instruction | No | No | Use INT or call gates |

### Strict C

- `-std=c11 -ffreestanding -nostdlib -Wall -Wextra -Werror`, plus GCC's `-fanalyzer` or Clang's static analyzer.
- Old-compiler compatibility: our C also compiles as C89 (`make c89` builds with `-std=c89 -pedantic`), so old compilers can build it. That means `/* */` comments only, declarations at the top of a block, no trailing comma after the last enumerator, and no `inline`, `restrict`, `long long`, `bool` or designated initialisers. `src/compat.h` supplies the missing pieces: `uint8_t`, `uint16_t` and `uint32_t` (checked at compile time, with no 64-bit type), `STATIC_ASSERT`, `STATIC_INLINE`, `RESTRICT`, `NORETURN` and `ALIGNED`. `bool`, designated initialisers, mixed declarations and compound literals have no workaround.
- Code stays compiler-neutral: strict C11 that builds with both GCC and Clang, with no extensions beyond inline assembly and attributes both accept. GCC is the primary compiler; build with Clang too as code lands and compare the generated assembly and speed on the target.
- Kernel logic and services also compile as ordinary programs on the host, run under AddressSanitizer and UndefinedBehaviorSanitizer.
- Buffers passed as pointer-and-length pairs with bounds checked in one place; one documented owner for every object; distinct types for physical and virtual addresses; assertions for invariants in debug builds.
- Names carry the meaning: functions, variables, constants, enums and types explain themselves, so the code reads without comments. A comment is the exception, written as `/* */` in C and tagged `WORKAROUND:` for an unexpected workaround (saying why it is needed) or `WHY:` for a fact a name cannot carry, such as a hardware behaviour, an ordering constraint or a datasheet reference.
- Read the generated assembly (`gcc -S` or Compiler Explorer) to keep learning how C maps onto the machine.
- Open Watcom for 16-bit pieces near the end (Windows `.DRV` drivers, DOS stubs). Rust stays an option for individual services later.

## Architecture experiments

The central question: where should each service live — inside the kernel, beside it in a protected ring, or in its own address space — on a CPU where switching address spaces is expensive? Rather than decide now, build so the answer can be measured.

**The experiment harness (Proposed)**: every service (filesystem, disk, devices, personalities) is written against one message-style interface, the request ring described under "Service interface: rings and batching", that can be built two ways: as direct function calls inside the kernel, one per request, or as IPC messages to a separate task. Moving a service across the line becomes a build option, so its cost can be measured directly on each CPU configuration.

**Candidate designs (all Proposed)**

- **A. L4-style microkernel**: only IPC, scheduling, memory mapping and interrupts in the kernel; every server in its own address space. The cleanest isolation, but on a 386 every call between servers costs an address space switch and TLB flush. Reference: Liedtke's L4.
- **B. Shared-region servers in ring 1**: servers mapped into the top of every address space and isolated by rings and segment limits, so calls to them need no CR3 change. It uses 386 features most systems ignored.

&#91;embedded content: system architecture · 3 rings, 6 servers\]

Candidate B in detail: server pages are marked supervisor-only so ring 3 programs can't touch them, and segment limits keep ring 1 servers out of the kernel's memory and out of each other's, since paging treats rings 0–2 alike.

- **C. BeOS-style**: a monolithic core with loadable drivers, user-space servers for higher-level services, pervasive threads, real-time priority bands and cheap locks (benaphores). A cautionary note: BeOS first ran networking as a user-space server, found it too slow, and moved it into the kernel.
- **D. OS/2-style**: the DOS virtual machine manager and virtual device drivers inside the kernel, ring 2 for code allowed direct I/O, and Windows hosted by standing in for its manager, as WIN-OS/2 did.
- **E. NT-style hybrid**: microkernel structure, but servers running in kernel space for speed.

**Build order (Decided)**: start with the conventional layout, Candidate A, with servers in ring 3, and cut the number of address space switches instead of making each one cheaper: zero-copy buffers, batching, client-side caching and a shared kernel page (see "Fast paths for user-level services"). On a 386 the TLB has no tags, so a CR3 reload always flushes it and the count is the only lever. Candidate B stays an experiment, and it has to beat A by a clear margin on the board to justify its risk: ring 1 gets no protection from paging, and the 386 has no CR0.WP. Ring 3 servers also use only the two privilege levels that other architectures have.

The likely outcome is a mix — for example, device virtualization and the DOS machine manager in the kernel (OS/2-like), the filesystem and Linux personality outside it (microkernel-like) — but the measurements decide.

## What we borrow (Proposed)

Ideas taken from the systems this project studies, in order of how much they matter to the aims. Each is a candidate to try, not a settled choice.

1. **NT's I/O request packets (IRPs)**: every I/O is a request packet that can be passed down a stack of drivers and completes asynchronously. This is close to the ring design: the request is the unit of work. Take the idea; leave out NT's object manager and security descriptors.
2. **BeOS loopers**: each server is a thread with a message queue that handles one message at a time and never blocks in the middle. Also BeOS's priority bands and benaphores, which are already hypotheses below. The cautionary tale is that BeOS moved networking into the kernel for speed.
3. **OS/2's virtual DOS machines and virtual device drivers, and Windows 3.1 Enhanced mode's VMM and VxDs**: essential for the DOS and Windows personalities, since they do the same job. Behaviour reference only.
4. **L4's fast IPC and user-level pagers**: the direct switch to the receiver, small address spaces and a pager the kernel calls only on a miss.
5. **NT's hardware abstraction layer**: a thin layer between the kernel and the hardware. The `cpu_operations` table in `AGENTS.md` is the same idea, and should stay that small.

Not borrowed, because they are large and add nothing for DOS games or for learning microkernels: OS/2's Workplace Shell and object model, BeOS's large application API, and most of NT's Win32 subsystem.

## Hypotheses to measure

The 386 has no cycle counter, so benchmarks use the 8254 timer chip's counter (about 1.19 million ticks a second) or time many repetitions.

| Hypothesis | Why it might hold | How to test | Status |
| --- | --- | --- | --- |
| Short IPC in registers, with a direct switch to the receiver, is cheap enough for services outside the kernel | L4's results on the 486 | Time IPC round trips on each CPU configuration | To measure |
| Shared-region servers (B) are much cheaper to call than separate address spaces (A) | No CR3 reload or TLB refill | The same service in both layouts: time calls and a file-copy benchmark | To measure |
| Batching requests in rings cuts the cost per request enough to justify making rings the core interface | A crossing costs about as much as the work behind a small request, and a server that sees a batch can sort and merge it | Doorbell with 1, 2, 4, 8 and 16 requests against the same requests as separate synchronous calls: time per request, and a file-copy benchmark, on each CPU | To measure |
| Benaphores beat plain kernel semaphores | Uncontended locks skip the kernel | A million lock-unlock pairs, uncontended and contended. May matter little if services handle one message at a time | To measure |
| Priority bands keep sound and input smooth under load | BeOS experience | X-Wing music while Linux copies files: count sound buffer underruns and keyboard delay. Services a session depends on must sit at or above its priority, or priority inversion results | To measure |
| Disk access beats native DOS | RAM-wide cache, read-ahead, 32-bit code instead of real-mode BIOS and DOS | Game level loads and file copies against real DOS, with and without SMARTDRV | To measure |
| 32-bit INT 21h handling in the DPMI host beats DOS extender round trips | No real-mode switches or extra buffer copies | File reads from a DOS4GW program against real DOS | To measure |
| Foreground pass-through gives native game speed | No traps on VGA and Sound Blaster ports | Frame rates against bare hardware | To measure |
| Lazy FPU switching pays off | Most threads never use the FPU; 387 saves are slow | Context switch time with and without, 386 with 387 against 486 | To measure |
| A 387 can run slow arithmetic in the background while the 386 does integer work | The FPU runs an instruction on its own until the next `fwait` or FPU instruction. It is useful only if the coprocessor interface and the `fwait` bookkeeping cost less than the overlap saves. The kernel would then depend on FPU state, which also conflicts with lazy FPU switching | A long division or scaling loop with and without FPU offload, 386 with 387 against 486 | To measure |
| VLB IDE 32-bit transfers roughly double disk throughput | Half the I/O operations per sector | Throughput with ISA against VLB controller, 16-bit against 32-bit transfers | To measure |
| Queued INT 21h file calls keep other sessions running while a DOS machine waits, and write-behind and read-ahead shorten level loads | The CPU is free during every disk wait; the cache answers repeat and sequential access early | Level load time in X-Wing, and Linux copy speed running alongside it, against synchronous handling (step 2 against step 3 of "INT 21h through the request queue") | To measure |
| A tickless timer and lazy interrupt masking reduce overhead | Fewer interrupts and slow ISA I/O cycles | Idle CPU use and interrupt latency | To measure |

## Proposed components

How each piece might work. Everything in this section is **Proposed** unless marked otherwise, and will change as the architecture experiments settle where each piece lives.

### Kernel core

- **IPC**: requests travel in shared-memory rings, many per crossing (see "Service interface: rings and batching"). The kernel call that rings the doorbell is a synchronous send-and-wait, and it is also the whole path for a single urgent request: short messages in registers, longer ones by mapping pages; the sender switches straight to the receiver without the scheduler; a hand-written assembly fast path.
- **Scheduling**: priority bands borrowed from BeOS — a real-time band for sound, input and console services and the foreground DOS game, a normal band for interactive work, a low band for background sessions — with round robin inside each band. Services must sit at or above the priority of the sessions that use them. Tickless timer.
- **Memory**: one page table per Linux process, DOS machine and Windows session; pages granted, mapped and revoked between address spaces; a user-level pager for page faults; on the 386, explicit write checks for copy-on-write.
- **Interrupts and system calls**: interrupts delivered as messages to the service that owns them; handlers do the minimum and wake a high-priority thread; lazy masking at the 8259; system calls via INT or a call gate, whichever measures faster; software task switching with one TSS for the stack pointer and I/O bitmap.
- **CPU and FPU detection**: detect the 486 at boot (it can set the AC flag in EFLAGS; a 386 can't) and enable 486-only paths such as INVLPG and CMPXCHG. With no FPU, set CR0.EM so FPU instructions trap; the Linux userland uses software floating point. FPU errors arrive on IRQ 13 for both the 387 and the 486. Lazy FPU saving only when an FPU is present. Switch on the 486's internal cache at boot. Boot messages report what was found and print the dedication.
- **Locks: benaphores**: a counter in shared memory, starting at −1 (free), plus a counting kernel semaphore. To lock, `lock inc` the counter: a result of 0 means it was free, anything higher means sleep on the semaphore. To unlock, `lock dec`: a negative result means nobody is waiting, otherwise signal one waiter. Works on the 386 without XADD because `inc` and `dec` set the CPU flags in the same indivisible instruction, and suits ring 3, where disabling interrupts isn't allowed.

### Service interface: rings and batching

This is the first architecture to test (see the Decisions table); the details below are **Proposed**. The synchronous baseline is the same services behind plain send-and-wait calls, one request per crossing, and the benchmarks compare the two on each CPU, concentrating on warm-cache, small-request paths, since requests that wait on the disk hide the crossing cost.

- **Shape**: each service has a request ring and a completion ring in shared memory. A client writes as many requests as it has, then makes one kernel call, the doorbell. The kernel switches to the server, which works through the whole batch, posts the results and gives the CPU back.
- **Synchronous callers are a batch of one**: a DOS `INT 21h`, a trapped port access or a Linux system call posts one request and blocks. It costs about what a plain synchronous call would, and it lets other sessions run during the wait. Batches form where there is more than one thing to do: block cache write-out and read-ahead, directory listings with attributes, input events, and our own tools.
- **Batches pass down the chain**: the filesystem server turns the requests it receives into block requests and posts them to the disk driver in the same turn, so the disk driver is crossed once per batch.
- **One CPU, no polling**: producer and consumer cannot run at the same time, so the doorbell is the crossing, and the gain is the crossings saved plus what the server can do with a whole batch, such as sorting by disk position and merging adjacent blocks.
- **To work out**: a fixed request size and fixed ring sizes (pools, as the Robust C tiers require); what a full ring does (the client blocks); a flag in the ring so a server that is already awake needs no doorbell; completions in any order; cancelling a request.

### Fast paths for user-level services

Ways to keep the common case out of the IPC path for services that run outside the kernel, such as the pager, the filesystem and a network stack. On a cacheless 386 an avoided copy matters most, so zero-copy buffers and the pager fast path come first; the rest wait for a measurement.

- **Zero-copy shared buffers**: client and server map the same pages, and only a short message moves between them.
- **Pager fast path**: the kernel keeps the page tables and the resident pages and calls the user-level pager only on a fault for a page that is not in memory.
- **Packet demultiplexing at the edge**: a small lookup table in the driver or kernel sends each incoming packet straight to the right program, with no central network server in between.
- **Batching**: a client queues several requests and makes one call, so one switch serves many operations.
- **Client-side caching**: the client library answers repeated lookups, such as file descriptors, names and file attributes, without calling the server.
- **Shared request and completion rings**, as in Linux's io_uring, are now the core service interface (see above). Where batches are most likely to form, best fit first:
  - filesystem server to disk driver: read-ahead, journal writes and the periodic write-out arrive as batches, and the interrupt posts the completions;
  - input service to the foreground session: keyboard and mouse events in a ring, with no call per event;
  - Linux personality to filesystem server: batch internally, for example the stat calls of `ls -l`. Linux programs cannot use rings themselves, since their syscall table is 2.0-era; our own tools could use a native one.

  A poor fit for the DOS and Windows personalities: a DOS program waits for each INT 21h answer, and trapped port I/O needs its result immediately.

### Shared services

**Disk**

- 32-bit IDE driver with multi-sector transfers, reaching beyond the BIOS's 504MB limit once running; chipset modules for VLB IDE 32-bit transfers and faster timings.
- Other programs keep running while a disk request is in progress.

**Filesystem** (the formats are Decided; the rest is Proposed)

- ext3, built in stages: first ext2-level reading and writing of the ext3 disk (cleaning the journal with `e2fsck` on the development PC after crashes), then journal replay at boot, then full ordered-mode journaling.
- FAT12/16 for floppies and each DOS machine's private boot disk, a FAT image stored as an ordinary file on ext3.
- One interface for redirected DOS INT 21h file calls and Linux file calls, answered in 32-bit code.
- DOS sees long names as 8.3 short names, with case-insensitive lookups and a rule for clashes such as `README` and `readme`. Read-only maps to Unix permissions; hidden, system and archive bits live in the `user.DOSATTRIB` extended attribute.
- Windows 3.1 uses a temporary swap file and runs with 32-bit disk access off.

**Block cache**

- Starts inside the filesystem service; a table of blocks with least-recently-used eviction, dirty flags, a periodic write-out timer and a flush on `halt`.
- Uses all free RAM outside every DOS machine's address space, so unlike SMARTDRV it costs no conventional memory; no SMARTDRV inside DOS machines or Windows.
- Later: read-ahead, giving memory back on demand, and write ordering so ext3 journal blocks reach the disk before the changes they describe.

**Device virtualization** (the equivalent of WIN386's VxDs, shared by DOS and Windows)

| Device | Foreground session | Background sessions |
| --- | --- | --- |
| VGA display | Direct hardware access | Writes go to a shadow copy of video memory; state saved and restored on switch |
| Keyboard and mouse | Receives input | No input |
| Timer (8253/8254) | Virtual timer per session | Virtual timer at reduced priority |
| Sound Blaster | DSP ports passed through | Paused or silenced |
| Joystick (201h) | Passed through untouched | None |
| Serial, parallel | Assigned to one session at a time | Blocked until released |

Always trapped, even for the foreground session, because these can bypass the CPU's protection: the DMA controller (addresses checked and translated, since DMA ignores paging), the 8259 interrupt controllers and timer (virtual copies per session), the keyboard controller (it can reset the CPU and controls the A20 line) and the disk controller. The foreground session runs at IOPL=3, so a game that hangs with interrupts off can freeze the machine, as on real DOS. Also here: the console switcher (Alt+F1, F2, F3) and idle detection for DOS programs spinning on the keyboard.

### DOS personality

- Each DOS program runs in its own V86 virtual machine with a private first megabyte, booting MS-DOS 4.0 (MIT licence) by default. The DOS is a replaceable component: users can substitute FreeDOS or any other DOS that boots from a FAT image. FreeDOS is GPL, so it is never committed or shipped.
- Foreground fast path: IOPL=3 with the session's hardware ports opened in the I/O bitmap.
- Expanded memory (LIM EMS 4.0) by mapping pages into the EMS window, which X-Wing needs; a built-in 32-bit DPMI host for DOS4GW and other extenders.
- Each machine boots from its own FAT image as C:; shared ext3 directories appear as further drive letters through DOS's network redirector (INT 2Fh).
- Instant sessions: snapshot a booted DOS machine at the prompt and clone it with copy-on-write.
- Typing a DOS `.EXE` at the Linux shell starts it in a new DOS machine.

**Writing our own INT 21h: trace, then replace**

1. Boot a real DOS (MS-DOS 4.0, or FreeDOS as a user-supplied alternative) and run the target games unchanged.
2. Trap every INT 21h (and INT 10h, 13h, 16h and 2Fh) and log function numbers, registers and results per program: a DOS equivalent of `strace`.
3. Rank the functions by use; games typically need 20–30 of DOS's roughly 100.
4. Point INT 21h at our handler, answering what we've written and passing the rest to the DOS.
5. Compare each function against the DOS for the same inputs: registers, carry flag, error codes and memory.
6. Repeat until the DOS handles nothing.

Tracing won't catch programs that walk DOS's internal tables directly (via the List of Lists, function 52h), undocumented side effects, or direct BIOS and hardware access. Known hard cases: floppy copy protection, timing-dependent programs, and unusual VGA modes whose state is hard to save. References: Ralf Brown's Interrupt List, the MS-DOS 4.0 source, *Undocumented DOS* (Schulman) and its INTRSPY tool, DOSBox-X's debugger.

**INT 21h through the request queue (Proposed)**

Goal: serve a DOS machine's file calls through the filesystem server's request queue, so other sessions keep the CPU while a DOS machine waits for the disk, and calls the cache can answer return at once.

What the research found:

- With IOPL below 3, an `INT n` in V86 mode raises a general-protection fault, and the monitor may emulate the service or reflect it to the DOS ([Intel 386 manual, section 15.4](https://css.csail.mit.edu/6.5660/2010/readings/i386/s15_04.htm)). To check against the manual: that the foreground session at IOPL=3 reaches the kernel too, through the IDT.
- DOS is not reentrant. It is safe to call it again only when the InDOS and critical-error flags are both zero, and INT 28h marks moments when calls above function 0Ch are safe ([Art of Assembly, chapter 18](https://shrek.unideb.hu/~gjhalasz/assembly/masm/Chapter_18/CH18-3.html)). So the kernel never injects DOS calls into a machine from outside; a completion only resumes the machine after the `INT 21h` that is waiting.
- There is precedent for serving `INT 21h` in protected mode instead of in DOS: Windows for Workgroups 3.11 32-bit file access did it ([Wikipedia](https://en.wikipedia.org/wiki/Microsoft_32-bit_file_access)).
- Write-behind caching has a known cost: SMARTDRV held writes until the cache filled or about five seconds of idle time, and data could be lost if the machine was switched off right after quitting a program ([cache.txt](https://surfhelpt.duckdns.org/textfiles.com/computers/cache.txt)).

Steps, each with a gate:

1. **Trace first** (the trace-and-replace step above): record which file functions each target game calls, and how often during play compared with loading. Gate: if play makes almost no file calls, the queue only matters for loading, and step 4 can be dropped.
2. **Synchronous trap path**: `INT 21h` from the V86 machine goes to the kernel, which calls the filesystem server directly. Measure the trap cost per call at IOPL below 3 and at IOPL=3, on each CPU.
3. **Queue path**: the handler builds a request (function, handle, buffer in the machine's memory mapped without copying, length), posts it to the ring, marks the machine blocked and switches to another session. The completion sets the registers and the carry flag and resumes the machine after the `INT`. Start with read and write (3Fh, 40h), then open, close and seek.
4. **Early answers**: write-behind and read-ahead, only for handles on ext3 files. Rules: size and timestamps are correct at once; a late error is reported at the next call on that handle; a machine's dirty data is flushed on close, on exit (4Ch) and when the machine is killed.
5. **Compare** with step 2 using the same benchmarks.

Risks: a program that hooks `INT 21h` sees our handler last in the chain, which should be harmless but needs testing with a resident program such as a mouse driver; late write errors such as a full disk reach programs that do not expect them; losing power loses the write-behind data, which ext3's ordered journal limits but does not remove.

### Linux personality

**Open question**: run original binaries from the era, small tools recompiled for the 386, or both.

- **Proposed: speak Linux's own system call interface** (`int 0x80`, the 32-bit Linux table, stable since the 1990s), starting with the Linux 2.0-era core and adding newer calls as programs need them. Original binaries and recompiled ones both use it, and the same program can be run on real Linux under `strace` and compared call by call. Unimplemented calls return `ENOSYS` and are logged; `uname` reports a matching Linux version.
- **Alternative**: a C library ported to talk to our services directly, as GNU Hurd and Redox do. Cleaner, but loses the comparison with real Linux; a possible later experiment.
- **First target**: NetBSD's `sh` (BSD-licensed), plus `ls`, `cp`, `mv`, `rm`, `mkdir`, `cat` and `less` (source for the tools still open), statically linked against musl patched for the 386, roughly 40–60 system calls. BusyBox and htop are GPL, so they are not used. Later, our own process viewer could show DOS machines and services as processes through `/proc`.
- **Our own tracer**: one hook in the IPC path logs every request between programs, personalities and services.

### Windows 3.1 personality

The goal is **Decided**: Windows 3.1 in 386 Enhanced mode, running Program Manager and the stock apps alongside Linux and DOS. How to get there is open.

**Approaches**

1. **Stand in for WIN386** (leading proposal, the OS/2 approach): `WIN.COM` loads a stub `WIN386.EXE` that hands over to our Windows personality, so Microsoft's WIN386 never runs. KRNL386 then runs as a DPMI client, and we provide 32-bit DPMI, the INT 2Fh 16xxh calls and the VxD entry points Program Manager and the stock apps actually use.
2. **Patch Windows to cooperate with our kernel**: modify WIN386 or its drivers at load time, applied to your own copy and never distributing Microsoft code. It needs a much deeper understanding of WIN386's internals, so it's the riskier path, but worth comparing.
3. **Step aside** (fallback): freeze everything and hand the whole machine to stock Windows on MS-DOS until it exits.

In all cases, Standard mode comes first, on our DPMI host.

**Details for approach 1**

- Our own 16-bit Windows display, keyboard and mouse drivers (`.DRV` files, documented in the DDK), talking straight to the device virtualization service.
- Our DOS supports the undocumented hooks Windows depends on: INT 2Fh 1605h, the Swappable Data Area (INT 21h 5D06h) and the List of Lists (52h).
- Typing `win` at the Linux shell, or `WIN` at a DOS prompt, creates a DOS machine running MS-DOS 4.0 on the next free console and starts Windows; exiting closes it and switches back.
- Behaviour comes from documentation and tracing: the Windows 3.1 DDK, the DPMI 0.9 specification, *Undocumented Windows* (Schulman), *Windows Internals* (Pietrek), Geoff Chappell's notes and Ralf Brown's Interrupt List; log every DPMI call, INT 2Fh call and VxD entry from stock Windows and implement the most frequent first. Wine's 16-bit code, HX DOS Extender and DOSEMU2 are references.
- Never copy disassembled Windows code. EU law permits reverse engineering for interoperability under certain conditions (not legal advice).
- The AARD check in a 1991 beta is disabled in the retail release. FreeDOS has historically struggled with stock WIN386 in Enhanced mode, which approach 1 sidesteps.

**Extra: a Linux shell in a window**

A 16-bit Windows terminal app (Open Watcom), a Linux pseudo-terminal with our shell attached, and a private virtual device in our WIN386 stand-in, found through INT 2Fh 1684h like any VxD, carrying bytes between them and posting a message to the app's window when output arrives. Later: clipboard, several windows, opening files in Windows apps from Linux.

## Build plan (Proposed)

Each phase ends with a test that must pass. Experiment results from each phase go into the decision log.

1. **Toolchain and boot**: cross-compiler, boot loader, protected mode, serial console, boot messages with the dedication.
   - Gate: boot messages over serial in Bochs and on the real 386DX.
2. **Kernel core and measurement harness**: paging, threads, IPC, interrupts, CPU and FPU detection, timer-based benchmarks.
   - Gate: IPC round-trip time measured on the 386DX; first comparison of candidates A and B.
3. **First services, switchable in or out of the kernel**: disk and filesystem (ext3 at ext2 level), console.
   - Gate: files written to an ext3 image pass `e2fsck`; filesystem call cost measured inside and outside the kernel.
4. **First DOS machine**: MS-DOS 4.0 in V86 mode, foreground pass-through with trapped controllers, EMS, the INT 21h tracer.
   - Gate: X-Wing at full speed with sound and joystick on the real 386DX.
5. **Multiple DOS machines**: device virtualization, console switching, redirected drives, snapshot cloning, idle detection, DPMI host.
   - Gate: two DOS sessions switch with Alt+F keys, the background one keeps running, and a DPMI program runs.
6. **Linux personality**: ELF loader, the 2.0-era system call core, basic `/proc` and `/dev`, NetBSD's `sh` and file tools.
   - Gate: our shell manages files on ext3 alongside a running DOS session.
7. **Filesystem hardening**: journal replay, ordered-mode journaling, the block cache.
   - Gate: a crash during heavy file activity recovers at the next boot without `e2fsck`.
8. **Windows Standard mode** on the DPMI host.
   - Gate: Program Manager and the stock apps run.
9. **Windows Enhanced mode**, by the approach the experiments favour.
   - Gate: Program Manager and the stock apps run in Enhanced mode alongside Linux and DOS sessions.
10. **Architecture review and performance pass**: settle where each service lives; run every benchmark on the 386DX, 386DX with 387, 486DX and 486DX2.
    - Gate: results recorded and the architecture decisions logged.

The "step aside" mode for stock Windows can be added any time after phase 4.

## Tools, testing and references

**Tools**

- Compilers: GCC built for the 386 (`i686-elf` target with `--with-arch=i386`), NASM, and later Open Watcom for 16-bit pieces.
- Userland: musl patched for the 386, plus NetBSD's `sh` and file tools; static linking first.
- Emulators: QEMU (with GDB), Bochs (debugger), 86Box (a 386DX VLB machine with a POST card), DOSBox-X's debugger for DOS behaviour.
- Disk images: `mkfs.ext3`, `e2fsck`, `mkfs.fat`, `mtools`.
- Measurement: 8254 timer-based timing, port 80h codes on the POST card, the IPC tracer.
- Real machine: the EXP3406 board, an ISA POST card with code history, a null-modem serial cable, an industrial CF card in an IDE adapter, later a network card.

**Test programs**

- DOS: X-Wing (EMS, Sound Blaster, joystick), a text-mode app, a DPMI program, a Mode X demo.
- Linux: our shell and file tools; later a process viewer.
- Windows: Program Manager and the stock apps, in Standard then Enhanced mode.
- Benchmarks: the hypotheses table above, on each CPU configuration.

**References**

- Jochen Liedtke, "On µ-Kernel Construction" (1995) and "Improving IPC by Kernel Design" (1993); Härtig et al., "The Performance of µ-Kernel-Based Systems" (1997); Engler et al., "Exokernel" (1995).
- Andrew Tanenbaum, *Operating Systems: Design and Implementation*, and the 1992 Tanenbaum–Torvalds debate on comp.os.minix.
- Intel 80386, 387 and i486 Programmer's Reference Manuals; the EXP3406 jumper manual and OPTi 82C495SLC brochure; the OSDev wiki.
- Microsoft DPMI 0.9 specification; Windows 3.1 DDK; Ralf Brown's Interrupt List.
- Schulman, *Undocumented DOS* and *Undocumented Windows*; Pietrek, *Windows Internals*; Geoff Chappell's research notes.
- IBM Redbooks on OS/2 MVDM and WIN-OS/2.
- Systems to study: BeOS and Haiku (threads, priority bands, benaphores, BFS attributes; Haiku is MIT-licensed), OS/2, Windows NT, GNU Hurd, Redox OS, MINIX 3, HelenOS.
- Source to study for behaviour only: FreeDOS, MS-DOS 4.0, Linux 1.x and 2.0, DOSEMU2, Wine, musl, BusyBox, lwIP.

## Decision log

| Date | Decision |
| --- | --- |
| 2026-10-15 | Project started: run Linux, DOS and Windows 3.1 programs together on our own kernel for a 386 |
| 2026-10-16 | Milestones set: kernel core, DOS games with X-Wing as the finish line, Linux shell, Windows 3.1 Enhanced mode |
| 2026-10-18 | Permissive licence, written from scratch |
| 2026-10-18 | ext3 as the main filesystem; FAT only for floppies and DOS boot images |
| 2026-10-18 | EXP3406 board; test order 386DX, 386DX with 387, 486DX, 486DX2 |
| 2026-10-18 | Assembly for low-level paths, strict C for everything else |
| 2026-10-24 | DOS attributes stored in ext3 extended attributes |
| 2026-10-25 | Kernel style: hybrid, with each service's placement decided by measurement. Document restructured into decisions, experiments, hypotheses and proposals |
| 2026-10-25 | 386SX support is a stretch goal; no decision may rule it out. The 286 is out of scope, since it lacks paging, V86 mode and 32-bit registers |
| 2026-10-27 | Project named GRACEOS. Design principle: code need not be perfect but must be simple and easy to read; small designs with few options, and no configurability, abstraction layers or negotiation without a measurement or a concrete need |
| 2026-10-27 | Commenting rule: self-explanatory names for functions, variables, constants, enums and types; comments only for an unexpected workaround, saying why it is needed |
| 2026-10-27 | Rules enforced by pre-commit hooks, not CI: clang-tidy for naming and readability, Semgrep for custom rules such as comments (comments must start with `WORKAROUND:`) |
| 2026-10-27 | Code stays compiler-neutral (GCC and Clang); GCC is the primary compiler and Clang builds are compared as code lands |
| 2026-10-27 | Licence narrowed from MIT or BSD to MIT only. No shipped code or software with an incompatible licence; if that rules out a component, such as BusyBox, write our own |
| 2026-10-27 | DOS: MS-DOS 4.0 (MIT) replaces FreeDOS as the default DOS. The DOS stays replaceable by any DOS that boots from a FAT image, such as a user-supplied FreeDOS, which is never committed or shipped |
| 2026-10-27 | Linux userland: a custom shell and file tools replace BusyBox, and our own process viewer replaces htop, both being GPL. musl (MIT) stays |
| 2026-10-27 | Linux shell: NetBSD `sh` (BSD-licensed) replaces the custom shell. Licence clarified: our own code is MIT; permissively licensed third-party code is allowed in a separate directory with its licence intact |
| 2026-10-27 | Commenting rule widened: besides `WORKAROUND:`, a `WHY:` comment is allowed for a fact a name cannot carry, such as a hardware behaviour, an ordering constraint or a datasheet reference. Semgrep accepts both tags and rejects untagged comments |
| 2026-10-27 | Old-compiler compatibility is a goal: our C must also compile as C89 (`make c89`, GCC with `-std=c89 -pedantic`). Comments in C are `/* */` only, so the `WORKAROUND:` and `WHY:` tags go inside `/* */`; `clang-tidy`'s trailing-comma check is off. `<stdint.h>` is still used, because current compilers ship it for freestanding builds |
| 2026-10-27 | `src/compat.h` replaces `<stdint.h>` and supplies C89 workarounds for missing features: fixed-width types (no 64-bit type), `STATIC_ASSERT`, `STATIC_INLINE`, `RESTRICT`, `NORETURN` and `ALIGNED`. Features with no workaround (`bool`, designated initialisers, mixed declarations, compound literals) stay unavailable. This supersedes the earlier note that `<stdint.h>` stays |
| 2026-10-28 | Build order for the architecture experiments: Candidate A (servers in ring 3) first, with fewer address space switches as the strategy; Candidate B (ring 1 shared region) must beat it by a clear margin. Extending to other architectures is possible later but not a goal; no abstraction layer for it until a second architecture exists |
| 2026-10-28 | Rings with batching are the core service interface from the first version: requests and results travel in shared-memory rings, many per kernel crossing, and a synchronous call is a batch of one. The aim is the most work for the fewest costly calls. This is a deliberate exception to the design principle of no abstraction before a measurement, like the experiment harness: the interface is the project's central idea, and the matching hypothesis is measured from the first IPC benchmark |
| 2026-10-28 | Aims stated: try modern software engineering techniques on retro hardware, play the era's DOS games on our own kernel, and learn microkernels by combining the best of OS/2, BeOS, NT and Windows 3.1 Enhanced mode. The ring architecture is the first architecture to test, with a plain synchronous interface as the measured baseline; this refines the entry above, which made rings the core interface from the first version |

## Glossary

Plain-language meanings of the terms used in this plan.

| Term | Meaning |
| --- | --- |
| Address space | One program's private view of memory, defined by its page table |
| a.out / ELF | Executable file formats used by Linux binaries |
| BusyBox | A shell and about 300 Unix tools in one small program |
| Call gate | A kernel-defined entry point programs can jump through to reach more privileged code |
| CLI / STI | Instructions that disable / enable hardware interrupts |
| CMPXCHG | Compare-and-swap instruction (486+), used for atomic operations |
| CR0 / CR3 | CPU control registers: CR0 holds mode flags, CR3 points to the current page table |
| CR0.EM | Flag that makes FPU instructions trap, used when no FPU is fitted |
| CR0.TS | Flag that makes the next FPU instruction trap, used for lazy FPU saving |
| CR0.WP | Flag (486+) that makes kernel code respect read-only pages |
| DMA | Hardware copying data between a device and memory without the CPU |
| DOS4GW | Popular DOS extender used by many 32-bit DOS games |
| DPMI | DOS Protected Mode Interface, standard services for protected-mode DOS programs |
| EMS | Expanded memory: extra memory DOS programs reach through a window in upper memory |
| EOI | End Of Interrupt, the "done" signal sent to the interrupt controller |
| ext2 / ext3 | Linux disk formats; ext3 is ext2 plus a journal |
| FAT | The DOS and Windows 3.1 disk format |
| FPU | Floating-point unit (the 387 chip, or built into the 486DX) |
| GDT / LDT | Global / Local Descriptor Tables, which define memory segments |
| IDT | Interrupt Descriptor Table, which maps interrupts to handler addresses |
| Inode | The on-disk record describing a file in Unix filesystems |
| INT | Software interrupt instruction, used for system calls |
| INT 21h | The DOS system call interface |
| INVLPG | 486 instruction that removes one page from the TLB |
| I/O port, I/O bitmap | Numbered hardware addresses for devices; the bitmap lists which ports a task may use directly |
| IOPL | I/O Privilege Level, controls who may use CLI, STI and I/O instructions |
| IPC | Inter-Process Communication, programs sending messages through the kernel |
| ISA | The PC's slow 8 MHz expansion bus |
| Journal | A log of pending filesystem changes, replayed after a crash |
| Microkernel | A kernel that does only the minimum, with other services in separate servers |
| musl | A small C library, the layer between programs and system calls |
| Page table | Map from a program's addresses to real memory |
| Personality | A server that makes the system look like a particular OS (Linux, DOS, Windows) to programs |
| PIC | Programmable Interrupt Controller, the 8259 chip |
| Redirector | DOS's interface for network-style drives, used here for shared ext3 directories |
| Ring | CPU privilege level, 0 (kernel) to 3 (applications) |
| Server | A program that waits for request messages and replies to them |
| TLB | Translation Lookaside Buffer, the CPU's cache of address translations |
| TSS | Task State Segment, holds the kernel stack pointer and I/O bitmap |
| V86 mode | Virtual 8086 mode, runs real-mode DOS code inside a protected task |
| VGA | The PC graphics standard of the era |
| VLB | VESA Local Bus, a fast 32-bit slot for video and disk cards on 486 (and a few 386DX) boards |
| VME | Virtual Mode Extensions (Pentium+), not available on 386/486 |
| VxD | A virtual device driver for Windows 3.1's WIN386 |
| WIN386 | The ring 0 manager that runs Windows 3.1's Enhanced mode |
