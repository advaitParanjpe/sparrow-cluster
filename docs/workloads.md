# Workloads

Milestone 7 generates and simulates these workloads:

| ID | Workload | Active harts | Checks |
| --- | --- | --- | --- |
| 1 | runtime smoke | 1, 2, 4 | hart IDs, stacks, active filtering, completion |
| 2 | atomic counter | 1, 2, 4 | exact LR/SC increment result |
| 3 | spinlock | 4 | mutual exclusion by exact protected update count |
| 4 | reusable barrier | 1, 2, 4 | five barrier generations per active hart |
| 5 | producer-consumer | 2 | ordered payload handoff |
| 6 | shared reduction | 1, 2, 4 | exact sum 36 |
| 7 | ownership ping-pong | 2 | alternating ownership transfers |
| 8 | false sharing | 4 | four harts update words in one block |
| 9 | padded comparison | 4 | four harts update separate blocks |
| 10 | read mostly | 1, 2, 4 | repeated shared reads with exact aggregate |
| 11 | mixed private/shared | 1, 2, 4 | private stack traffic plus shared barrier/read |

The runtime testbench validates result magic, active count, failure word, final result, active-hart L1D activity, LR/SC activity for synchronization workloads, and coherence traffic for ownership-sensitive workloads. Timeout diagnostics include workload ID, active count, completion words, release/result/failure words, coherence transactions, and per-hart PC/trap state where visible.
