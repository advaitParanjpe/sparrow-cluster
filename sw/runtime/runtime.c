#include "sparrow_runtime.h"

uint32_t sparrow_hart_id(void) {
    return *(volatile uint32_t *)SPARROW_HART_ID_ADDR;
}

uint32_t sparrow_active_harts(void) {
    return *(volatile uint32_t *)(SPARROW_CFG_BASE + 4u);
}

int sparrow_hart_is_active(void) {
    return sparrow_hart_id() < sparrow_active_harts();
}

void sparrow_unlock(sparrow_spinlock_t *lock) {
    *lock = 0u;
}
