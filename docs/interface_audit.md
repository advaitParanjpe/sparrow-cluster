# Interface audit

Imported Sparrow-V revision `995ea0f9cada63688c9e21e739bd41d6b1c118af` exposes decoupled 32-bit byte-addressed IMEM and DMEM valid/ready interfaces. IMEM carries an address; DMEM carries aligned address, write flag, data, and little-endian byte strobes. Each core port allows one outstanding request and holds request fields under backpressure. There is no memory-error input and no CSR/hart-ID hook.

`l1_instruction_cache` preserves that IMEM contract on its core side: the core holds a request until acceptance, and L1I emits exactly one response only after a hit or complete refill. The imported core supports a stale response only when its epoch has changed; because L1I accepts at most one request and the core cannot redirect an unaccepted request, no cancellation interface is needed. L1I connects its lower word-read port to the adapter IMEM port. `core_adapter` accepts one local port request only while inactive, captures fields, issues exactly once to the system port, and routes the controller response exclusively to its recorded port. Simultaneous lower-IMEM/DMEM requests alternate deterministically; reset makes IMEM first.

Hart ID therefore uses the minimally invasive controller aperture `0x10000000`, not a core edit or CSR. Invalid requests receive a zero data response, the only representable response under this Sparrow-V interface.
