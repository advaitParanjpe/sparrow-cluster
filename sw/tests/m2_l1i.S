/* Hand-encoded instruction-cache-focused program exercised by tb_cluster.
 * Every hart reads mhartid, writes its result, then executes JALs at 0x18,
 * 0x400, and 0x800.  Those three addresses map to L1I set zero and force
 * repeated two-way conflict replacement while each hart's uncached result
 * store contends with refill traffic.  The testbench supplies the literal
 * instructions because the baseline deliberately has no required host
 * RISC-V toolchain.
 */
