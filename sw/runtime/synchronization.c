#include "sparrow_runtime.h"

uint32_t sparrow_atomic_inc(volatile uint32_t *addr) {
    uint32_t old_value;
    do {
        old_value = sparrow_lr_w(addr);
    } while (sparrow_sc_w(addr, old_value + 1u) != 0u);
    return old_value + 1u;
}

int sparrow_try_lock(sparrow_spinlock_t *lock) {
    if (sparrow_lr_w(lock) != 0u) {
        return 0;
    }
    return sparrow_sc_w(lock, 1u) == 0u;
}

void sparrow_lock(sparrow_spinlock_t *lock) {
    while (!sparrow_try_lock(lock)) {
    }
}

void sparrow_barrier(volatile uint32_t *count, volatile uint32_t *generation,
                     uint32_t active_harts) {
    uint32_t observed = *generation;
    uint32_t arrival = sparrow_atomic_inc(count);

    if (arrival == active_harts) {
        *count = 0u;
        *generation = observed + 1u;
    } else {
        while (*generation == observed) {
        }
    }
}
