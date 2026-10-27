# GRACEOS

A hybrid kernel for a 386 PC that runs Linux, DOS and Windows 3.1 (386 Enhanced mode) programs side by side, without rebooting. It is also a test bench for ideas from microkernels, BeOS and OS/2, measured on a real 386DX, then with a 387, then on a 486.

> Dedicated to Andrew Tanenbaum and Linus Torvalds, who argued about microkernels and monolithic kernels in 1992. They were both right.

**Status:** just started. So far there is only a dev shell flake, which has not been built or tested yet. The design is a living document: see [docs/design.md](docs/design.md).

## Goals

In order:

1. A working kernel core.
2. DOS games at full speed with sound and joystick. Finish line: X-Wing on a real 386DX.
3. A Linux shell with basic file tools.
4. Windows 3.1 in Enhanced mode: Program Manager and the stock apps.

Stretch goal: the same kernel on a 386SX. Non-goals include the 286, CPUs newer than the 486, Windows 95 or later, and any leaked or disassembled Microsoft code.

## Approach

- **Hybrid structure.** Each service (filesystem, disk, devices, personalities) is written against one message-style interface, built either as direct calls inside the kernel or as IPC to a separate task. Where each line falls is decided by measurement.
- **Languages.** NASM assembly for boot, mode switches, interrupt entry, context switching and fast paths; strict C11 for everything else.
- **Hardware.** DataExpert EXP3406 board. One kernel image for every configuration, built for the plain 386, with 486 features enabled at boot.
- **Debugging.** Serial console on COM1 and port 80h progress codes from day one.
- **Licence.** Our own code is written from scratch under the MIT licence. Any third-party code is permissively licensed and kept separate.

## Development

The toolchain is a Nix flake dev shell: an `i686-elf` GCC and binutils built with `--with-arch=i386`, NASM, Make, QEMU and GDB. Bochs, 86Box and the disk-image tools are added as the phases need them.

```sh
nix develop
```

## Build plan

1. Toolchain and boot, with boot messages over serial.
2. Kernel core and measurement harness.
3. First services: disk and filesystem (ext3).
4. First DOS machine (V86 mode).
5. Multiple DOS machines.
6. Linux personality.
7. Filesystem hardening.
8. Windows Standard mode.
9. Windows Enhanced mode.
10. Architecture review and performance pass.

Each phase ends with a test that must pass; the details are in the [design document](docs/design.md).
