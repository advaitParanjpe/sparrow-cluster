# Interface audit

Imported Sparrow-V revision `995ea0f9cada63688c9e21e739bd41d6b1c118af` exposes decoupled 32-bit byte-addressed IMEM and DMEM valid/ready interfaces. IMEM carries an address; DMEM carries aligned address, write flag, data, and little-endian byte strobes. Each core port allows one outstanding request and holds request fields under backpressure. There is no memory-error input and no CSR/hart-ID hook.

`core_adapter` is the integration boundary. It accepts one local port request only while inactive, captures core-local fields, issues exactly once to the system port, and routes the controller response exclusively to its recorded port. Simultaneous local IMEM/DMEM requests alternate deterministically; reset makes IMEM first. The top-level captures global core ID and port in `shared_memory_controller` until response retirement.

Hart ID therefore uses the minimally invasive controller aperture `0x10000000`, not a core edit or CSR. Invalid requests receive a zero data response, the only representable response under this Sparrow-V interface.
