/* Reference startup for the Milestone 7 generated runtime images.
 * The current build uses scripts/build_runtime_sw.py to emit equivalent
 * RV32I/LRSC instructions because no repository-local RISC-V C toolchain is
 * required. Keep this file as the ABI contract for a later ELF flow.
 */

    .section .init, "ax"
    .globl _start
_start:
    lw      a0, 0(x0)              /* placeholder: generated flow reads hart ID */
    j       sparrow_runtime_main
