# Interface audit

Imported Sparrow-V revision `995ea0f9cada63688c9e21e739bd41d6b1c118af` exposes decoupled 32-bit byte-addressed IMEM and DMEM valid/ready interfaces. IMEM carries an address; DMEM carries aligned address, write flag, data, and little-endian byte strobes. Each core port allows one outstanding request and holds request fields under backpressure. There is no memory-error input and no CSR/hart-ID hook.

`l1_instruction_cache` preserves the IMEM contract. `l1_data_cache` preserves the DMEM contract on its CPU side for normal operations: it accepts one request, returns exactly one response, and leaves load extension to Sparrow-V. Milestone 6 adds one local core-to-L1D metadata field for atomic intent (`normal`, `LR.W`, `SC.W`); it does not alter the external adapter or shared SRAM interfaces. Uncached DMEM requests keep the prior word-oriented lower interface. Cacheable DMEM requests use the internal block coherence requester/snooper interface and do not alter the audited external memory contract.

The coherence interface is internal: requester valid/ready, 3-bit command, 16-byte-aligned address, optional 128-bit writeback data, response valid/data/shared/modified/complete/error, and peer snoop valid/command/address/requester plus present/modified/data/ack response. `sparrow_cluster_top` connects all four production L1Ds to this interface and routes transport SRAM words through the same shared memory controller as L1I and uncached traffic.

Hart ID uses `0x10000000`; `0x200..0x20f`, `0x300..0x30f`, `0x400..0x40f`, and `0x600..0x60f` bypass MSI. Invalid requests still receive zero, the only representable error behavior.
