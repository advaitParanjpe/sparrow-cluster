# MSI coherence protocol

Milestone 4 implements only transport encodings: `BUS_RD=0`, `BUS_RDX=1`, `BUS_UPGR=2`, and `WRITEBACK=3`, from `coherence_pkg`. Production MSI state transitions remain absent. Test snoopers may report clean presence, one modified owner, full 16-byte data, and invalidation acknowledgement.

Stable states: I (absent), S (clean shared), M (dirty exclusive). Required transients: IS (BusRd pending), IM (BusRdX pending), SM (BusUpgr pending), MI (writeback/invalidate pending), and victim writeback pending. A requester does not complete until its transient resolves.

| Event | I | S | M |
| --- | --- | --- | --- |
| Local read | BusRd→IS | serve | serve |
| Local write | BusRdX→IM | BusUpgr→SM | merge |
| Snoop BusRd | I | remain S | supply/flush, M→S |
| Snoop BusRdX | I | invalidate | supply/flush, M→I |
| Snoop BusUpgr | I | invalidate | invalid command invariant |
| Evict | I | I | writeback→I |

Modified owner intervention supplies authoritative block data to requester and updates SRAM in the coupled writeback phase. A dirty victim completes before its replacement transaction. Invalidation clears block reservations.

Assertions: at most one M per block; M excludes all other S/M; I never supplies data; dirty data is written or transferred before loss; snoops observe ordered bus commands; transient requests eventually resolve.
