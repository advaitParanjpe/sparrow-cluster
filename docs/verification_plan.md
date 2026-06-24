# Verification plan

`make sim-unit` covers reset, continuous simultaneous four-way round-robin rotation, controller fixed read/write latency, source retention, byte enables, invalid access response, and adapter IMEM capture/response routing. RTL assertions check no adapter response without an active request, one adapter response port, no duplicate adapter issue, no controller acceptance while a response is pending, and top-level response source range/routing.

`make sim-cluster` runs four real cores through shared fetch, hart-ID load, and result stores. `make sim-multicore` image-loads a bare-metal RV32I program and validates all four IDs, stack locations, release synchronization, checksums, word/byte partition writes, and completion words. `make regress` runs all checks and simulations. The test suite uses Icarus Verilog; its known informational constant-select warnings are not simulation failures.
