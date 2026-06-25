#ifndef SPARROW_RUNTIME_H
#define SPARROW_RUNTIME_H

#include <stdint.h>

#define SPARROW_MAX_HARTS 4u
#define SPARROW_HART_ID_ADDR 0x10000000u

#define SPARROW_RESULT_BASE 0x00000200u
#define SPARROW_CFG_BASE 0x00000300u
#define SPARROW_HART_RESULT_BASE 0x00000400u
#define SPARROW_HART_DONE_BASE 0x00000600u
#define SPARROW_SHARED_BASE 0x00001000u
#define SPARROW_RESULT_MAGIC 0xc1a57e07u

typedef volatile uint32_t sparrow_spinlock_t;

uint32_t sparrow_hart_id(void);
uint32_t sparrow_active_harts(void);
int sparrow_hart_is_active(void);
uint32_t sparrow_lr_w(volatile uint32_t *addr);
uint32_t sparrow_sc_w(volatile uint32_t *addr, uint32_t value);
uint32_t sparrow_atomic_inc(volatile uint32_t *addr);
void sparrow_lock(sparrow_spinlock_t *lock);
int sparrow_try_lock(sparrow_spinlock_t *lock);
void sparrow_unlock(sparrow_spinlock_t *lock);
void sparrow_barrier(volatile uint32_t *count, volatile uint32_t *generation,
                     uint32_t active_harts);
void sparrow_runtime_main(void);

#endif
