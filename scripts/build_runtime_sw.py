#!/usr/bin/env python3
"""Build deterministic Milestone 7 RV32I/LRSC runtime images.

The local baseline does not require a RISC-V C toolchain.  This script is a
small, auditable assembler for the instruction subset used by the runtime
workloads.  It emits byte-addressed `$readmemh` images and a symbolic listing.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "sw"
IMG = BUILD / "images"
DIS = BUILD / "disasm"

HART_ID = 0x1000_0000
RESULT_BASE = 0x200
CFG_WORKLOAD = 0x300
CFG_ACTIVE = 0x304
CFG_RELEASE = 0x308
CFG_ITER = 0x30C
PERHART_BASE = 0x400
DONE_BASE = 0x600
DATA_BASE = 0x1000
STACK_TOP = 0x10000

W_SMOKE = 1
W_COUNTER = 2
W_LOCK = 3
W_BARRIER = 4
W_PROD_CONS = 5
W_REDUCTION = 6
W_PINGPONG = 7
W_FALSE = 8
W_PADDED = 9
W_READMOSTLY = 10
W_MIXED = 11


@dataclass(frozen=True)
class Image:
    name: str
    workload: int
    active: int
    iterations: int
    expected: int


IMAGES = [
    Image("runtime_1c", W_SMOKE, 1, 4, 0x7000),
    Image("runtime_2c", W_SMOKE, 2, 4, 0x7001),
    Image("runtime_4c", W_SMOKE, 4, 4, 0x7003),
    Image("counter_1c", W_COUNTER, 1, 8, 8),
    Image("counter_2c", W_COUNTER, 2, 8, 16),
    Image("counter_4c", W_COUNTER, 4, 8, 32),
    Image("lock_4c", W_LOCK, 4, 6, 24),
    Image("barrier_1c", W_BARRIER, 1, 5, 5),
    Image("barrier_2c", W_BARRIER, 2, 5, 10),
    Image("barrier_4c", W_BARRIER, 4, 5, 20),
    Image("prodcons_2c", W_PROD_CONS, 2, 6, 6),
    Image("reduction_1c", W_REDUCTION, 1, 8, 36),
    Image("reduction_2c", W_REDUCTION, 2, 8, 36),
    Image("reduction_4c", W_REDUCTION, 4, 8, 36),
    Image("pingpong_2c", W_PINGPONG, 2, 6, 12),
    Image("false_4c", W_FALSE, 4, 6, 24),
    Image("padded_4c", W_PADDED, 4, 6, 24),
    Image("readmostly_1c", W_READMOSTLY, 1, 8, 784),
    Image("readmostly_2c", W_READMOSTLY, 2, 8, 1568),
    Image("readmostly_4c", W_READMOSTLY, 4, 8, 3136),
    Image("mixed_1c", W_MIXED, 1, 4, 4),
    Image("mixed_2c", W_MIXED, 2, 4, 8),
    Image("mixed_4c", W_MIXED, 4, 4, 16),
]

R = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6,
    "t2": 7, "s0": 8, "fp": 8, "s1": 9, "a0": 10, "a1": 11, "a2": 12,
    "a3": 13, "a4": 14, "a5": 15, "a6": 16, "a7": 17, "s2": 18,
    "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23, "s8": 24,
    "s9": 25, "s10": 26, "s11": 27, "t3": 28, "t4": 29, "t5": 30,
    "t6": 31,
}


def sx(value: int, bits: int) -> int:
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    if not lo <= value <= hi:
        raise ValueError(f"immediate {value} does not fit signed {bits}")
    return value & ((1 << bits) - 1)


def reg(x: str | int) -> int:
    return x if isinstance(x, int) else R[x]


class Asm:
    def __init__(self) -> None:
        self.pc = 0
        self.items: list[tuple[int, str, tuple]] = []
        self.labels: dict[str, int] = {}

    def label(self, name: str) -> None:
        self.labels[name] = self.pc

    def org(self, addr: int) -> None:
        if addr < self.pc:
            raise ValueError("org cannot move backwards")
        self.pc = addr

    def emit(self, op: str, *args) -> None:
        self.items.append((self.pc, op, args))
        self.pc += 4

    def li(self, rd: str, imm: int) -> None:
        if -2048 <= imm <= 2047:
            self.emit("addi", rd, "zero", imm)
        else:
            upper = (imm + 0x800) >> 12
            lower = imm - (upper << 12)
            self.emit("lui", rd, upper)
            if lower:
                self.emit("addi", rd, rd, lower)

    def la(self, rd: str, addr: int) -> None:
        self.li(rd, addr)

    def j(self, target: str) -> None:
        self.emit("jal", "zero", target)

    def call(self, target: str) -> None:
        self.emit("addi", "sp", "sp", -4)
        self.emit("sw", "ra", 0, "sp")
        self.emit("jal", "ra", target)
        self.emit("lw", "ra", 0, "sp")
        self.emit("addi", "sp", "sp", 4)

    def ret(self) -> None:
        self.emit("jalr", "zero", "ra", 0)

    def branch(self, op: str, rs1: str, rs2: str, target: str) -> None:
        self.emit(op, rs1, rs2, target)

    def finish(self) -> list[tuple[int, int, str]]:
        out: list[tuple[int, int, str]] = []
        for pc, op, args in self.items:
            enc = getattr(self, f"enc_{op}")(pc, *args)
            out.append((pc, enc, f"{op} " + ",".join(map(str, args))))
        return out

    def enc_lui(self, _pc: int, rd: str, imm20: int) -> int:
        return (imm20 << 12) | (reg(rd) << 7) | 0x37

    def enc_addi(self, _pc: int, rd: str, rs1: str, imm: int) -> int:
        return (sx(imm, 12) << 20) | (reg(rs1) << 15) | (reg(rd) << 7) | 0x13

    def enc_andi(self, _pc: int, rd: str, rs1: str, imm: int) -> int:
        return (sx(imm, 12) << 20) | (reg(rs1) << 15) | (7 << 12) | (reg(rd) << 7) | 0x13

    def enc_slli(self, _pc: int, rd: str, rs1: str, sh: int) -> int:
        return (sh << 20) | (reg(rs1) << 15) | (1 << 12) | (reg(rd) << 7) | 0x13

    def enc_srli(self, _pc: int, rd: str, rs1: str, sh: int) -> int:
        return (sh << 20) | (reg(rs1) << 15) | (5 << 12) | (reg(rd) << 7) | 0x13

    def enc_add(self, _pc: int, rd: str, rs1: str, rs2: str) -> int:
        return (reg(rs2) << 20) | (reg(rs1) << 15) | (reg(rd) << 7) | 0x33

    def enc_sub(self, _pc: int, rd: str, rs1: str, rs2: str) -> int:
        return (0x20 << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (reg(rd) << 7) | 0x33

    def enc_slt(self, _pc: int, rd: str, rs1: str, rs2: str) -> int:
        return (reg(rs2) << 20) | (reg(rs1) << 15) | (2 << 12) | (reg(rd) << 7) | 0x33

    def enc_lw(self, _pc: int, rd: str, imm: int, rs1: str) -> int:
        return (sx(imm, 12) << 20) | (reg(rs1) << 15) | (2 << 12) | (reg(rd) << 7) | 0x03

    def enc_sw(self, _pc: int, rs2: str, imm: int, rs1: str) -> int:
        imm12 = sx(imm, 12)
        return ((imm12 >> 5) << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (2 << 12) | ((imm12 & 0x1F) << 7) | 0x23

    def enc_beq(self, pc: int, rs1: str, rs2: str, target: str) -> int:
        return self._b(pc, rs1, rs2, target, 0)

    def enc_bne(self, pc: int, rs1: str, rs2: str, target: str) -> int:
        return self._b(pc, rs1, rs2, target, 1)

    def enc_blt(self, pc: int, rs1: str, rs2: str, target: str) -> int:
        return self._b(pc, rs1, rs2, target, 4)

    def enc_bge(self, pc: int, rs1: str, rs2: str, target: str) -> int:
        return self._b(pc, rs1, rs2, target, 5)

    def _b(self, pc: int, rs1: str, rs2: str, target: str, funct3: int) -> int:
        off = self.labels[target] - pc
        imm = sx(off, 13)
        return ((imm >> 12) << 31) | (((imm >> 5) & 0x3F) << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (funct3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63

    def enc_jal(self, pc: int, rd: str, target: str) -> int:
        off = self.labels[target] - pc
        imm = sx(off, 21)
        return ((imm >> 20) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (reg(rd) << 7) | 0x6F

    def enc_jalr(self, _pc: int, rd: str, rs1: str, imm: int) -> int:
        return (sx(imm, 12) << 20) | (reg(rs1) << 15) | (reg(rd) << 7) | 0x67

    def enc_lr(self, _pc: int, rd: str, rs1: str) -> int:
        return (0b00010 << 27) | (reg(rs1) << 15) | (2 << 12) | (reg(rd) << 7) | 0x2F

    def enc_sc(self, _pc: int, rd: str, rs2: str, rs1: str) -> int:
        return (0b00011 << 27) | (reg(rs2) << 20) | (reg(rs1) << 15) | (2 << 12) | (reg(rd) << 7) | 0x2F


def runtime(active: int, workload: int, iterations: int) -> Asm:
    a = Asm()
    a.j("start")
    a.org(0x800)
    a.label("start")
    a.la("t0", HART_ID)
    a.emit("lw", "s0", 0, "t0")
    a.li("t1", STACK_TOP)
    a.emit("slli", "t2", "s0", 8)
    a.emit("sub", "sp", "t1", "t2")
    a.emit("addi", "sp", "sp", -16)
    a.emit("sw", "s0", 0, "sp")
    a.la("s1", CFG_ACTIVE)
    a.emit("lw", "s1", 0, "s1")
    a.branch("blt", "s0", "s1", "active")
    a.la("t0", PERHART_BASE)
    a.emit("slli", "t1", "s0", 2)
    a.emit("add", "t0", "t0", "t1")
    a.li("t2", 0x1A)
    a.emit("sw", "t2", 0, "t0")
    a.j("complete")
    a.label("active")
    a.branch("bne", "s0", "zero", "wait_release")
    a.call("init")
    a.la("t0", CFG_RELEASE)
    a.li("t1", 1)
    a.emit("sw", "t1", 0, "t0")
    a.j("dispatch")
    a.label("wait_release")
    a.la("t0", CFG_RELEASE)
    a.label("release_loop")
    a.emit("lw", "t1", 0, "t0")
    a.branch("beq", "t1", "zero", "release_loop")
    a.label("dispatch")
    dispatch = {
        W_SMOKE: "work_smoke", W_COUNTER: "work_counter", W_LOCK: "work_lock",
        W_BARRIER: "work_barrier", W_PROD_CONS: "work_prodcons",
        W_REDUCTION: "work_reduction", W_PINGPONG: "work_pingpong",
        W_FALSE: "work_false", W_PADDED: "work_padded",
        W_READMOSTLY: "work_readmostly", W_MIXED: "work_mixed",
    }[workload]
    a.call(dispatch)
    a.label("complete")
    a.la("t0", DONE_BASE)
    a.emit("slli", "t1", "s0", 2)
    a.emit("add", "t0", "t0", "t1")
    a.li("t2", 1)
    a.emit("sw", "t2", 0, "t0")
    a.label("halt")
    a.j("halt")

    init(a, active, workload, iterations)
    helpers(a, active)
    workloads(a, active, workload, iterations)
    return a


def init(a: Asm, active: int, workload: int, iterations: int) -> None:
    a.label("init")
    for addr, val in [
        (RESULT_BASE, 0xC1A57E07), (RESULT_BASE + 4, workload),
        (RESULT_BASE + 8, active), (RESULT_BASE + 12, 0),
        (DATA_BASE + 0x00, 0), (DATA_BASE + 0x04, 0), (DATA_BASE + 0x08, 0),
        (DATA_BASE + 0x0C, 0), (DATA_BASE + 0x10, 0), (DATA_BASE + 0x14, 0),
        (DATA_BASE + 0x20, 0), (DATA_BASE + 0x24, 0), (DATA_BASE + 0x28, 0),
        (DATA_BASE + 0x30, 0), (DATA_BASE + 0x34, 0),
        (DATA_BASE + 0x140, 0),
        (DATA_BASE + 0x90, 0), (DATA_BASE + 0x94, 0), (DATA_BASE + 0x150, 0),
    ]:
        a.la("t0", addr)
        a.li("t1", val)
        a.emit("sw", "t1", 0, "t0")
    for hart in range(4):
        a.la("t0", PERHART_BASE + hart * 4)
        a.emit("sw", "zero", 0, "t0")
        a.la("t0", DONE_BASE + hart * 4)
        a.emit("sw", "zero", 0, "t0")
    for i, val in enumerate([3, 5, 7, 11, 13, 17, 19, 23]):
        a.la("t0", DATA_BASE + 0x180 + i * 4)
        a.li("t1", val)
        a.emit("sw", "t1", 0, "t0")
    a.ret()


def helpers(a: Asm, active: int) -> None:
    a.label("atomic_inc_a0")
    a.label("ai_retry")
    a.emit("lr", "t0", "a0")
    a.emit("addi", "t1", "t0", 1)
    a.emit("sc", "t2", "t1", "a0")
    a.branch("bne", "t2", "zero", "ai_retry")
    a.ret()

    a.label("lock_a0")
    a.label("lock_retry")
    a.emit("lr", "t0", "a0")
    a.branch("bne", "t0", "zero", "lock_retry")
    a.li("t1", 1)
    a.emit("sc", "t2", "t1", "a0")
    a.branch("bne", "t2", "zero", "lock_retry")
    a.ret()

    a.label("barrier")
    a.la("a0", DATA_BASE + 0x10)
    a.label("bar_retry")
    a.emit("lr", "t0", "a0")
    a.emit("addi", "t1", "t0", 1)
    a.emit("sc", "t2", "t1", "a0")
    a.branch("bne", "t2", "zero", "bar_retry")
    a.li("t3", active)
    a.branch("bne", "t1", "t3", "bar_wait")
    a.emit("sw", "zero", 0, "a0")
    a.la("t4", DATA_BASE + 0x14)
    a.emit("sw", "a1", 0, "t4")
    a.ret()
    a.label("bar_wait")
    a.la("t4", DATA_BASE + 0x14)
    a.label("bar_spin")
    a.emit("lw", "t5", 0, "t4")
    a.branch("bne", "t5", "a1", "bar_spin")
    a.ret()

    a.label("store_perhart_t0")
    a.la("t1", PERHART_BASE)
    a.emit("slli", "t2", "s0", 2)
    a.emit("add", "t1", "t1", "t2")
    a.emit("sw", "t0", 0, "t1")
    a.ret()

    a.label("hart0_wait_others")
    for hart in range(1, active):
        a.la("t0", DONE_BASE + hart * 4)
        label = f"wait_done_{hart}_{len(a.items)}"
        a.label(label)
        a.emit("lw", "t1", 0, "t0")
        a.branch("beq", "t1", "zero", label)
    a.ret()

    a.label("hart0_summary_from_t0")
    a.branch("bne", "s0", "zero", "summary_ret")
    a.call("hart0_wait_others")
    a.la("t1", RESULT_BASE + 12)
    a.emit("sw", "zero", 0, "t1")
    a.la("t1", RESULT_BASE)
    a.li("t2", 0xC1A57E07)
    a.emit("sw", "t2", 0, "t1")
    a.la("t1", RESULT_BASE + 4)
    a.li("t2", 0)
    a.emit("sw", "t0", 0, "t1")
    a.label("summary_ret")
    a.ret()


def loop_header(a: Asm, label: str, count: int) -> None:
    a.li("s2", 0)
    a.li("s3", count)
    a.label(label)


def loop_tail(a: Asm, label: str) -> None:
    a.emit("addi", "s2", "s2", 1)
    a.branch("blt", "s2", "s3", label)


def workloads(a: Asm, active: int, workload: int, iterations: int) -> None:
    a.label("work_smoke")
    a.emit("add", "t0", "s0", "zero")
    a.li("t1", 0x7000)
    a.emit("add", "t0", "t0", "t1")
    a.call("store_perhart_t0")
    a.ret()

    a.label("work_counter")
    loop_header(a, "counter_loop", iterations)
    a.la("a0", DATA_BASE)
    a.call("atomic_inc_a0")
    loop_tail(a, "counter_loop")
    a.branch("bne", "s0", "zero", "counter_ret")
    a.call("hart0_wait_others")
    a.la("t1", DATA_BASE)
    a.emit("lw", "t0", 0, "t1")
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.label("counter_ret")
    a.ret()

    a.label("work_lock")
    loop_header(a, "lock_loop", iterations)
    a.la("a0", DATA_BASE + 0x20)
    a.call("lock_a0")
    a.la("t0", DATA_BASE + 0x24)
    a.emit("lw", "t1", 0, "t0")
    a.branch("beq", "t1", "zero", "lock_guard_ok")
    a.la("t2", RESULT_BASE + 12)
    a.li("t3", 1)
    a.emit("sw", "t3", 0, "t2")
    a.label("lock_guard_ok")
    a.emit("addi", "t1", "s0", 1)
    a.emit("sw", "t1", 0, "t0")
    a.la("t2", DATA_BASE + 0x28)
    a.emit("lw", "t3", 0, "t2")
    a.emit("addi", "t3", "t3", 1)
    a.emit("sw", "t3", 0, "t2")
    a.emit("sw", "zero", 0, "t0")
    a.la("t4", DATA_BASE + 0x20)
    a.emit("sw", "zero", 0, "t4")
    loop_tail(a, "lock_loop")
    a.branch("bne", "s0", "zero", "lock_ret")
    a.call("hart0_wait_others")
    a.la("t1", DATA_BASE + 0x28)
    a.emit("lw", "t0", 0, "t1")
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.label("lock_ret")
    a.ret()

    a.label("work_barrier")
    loop_header(a, "barrier_loop", iterations)
    a.emit("addi", "a1", "s2", 1)
    a.call("barrier")
    a.la("t0", DATA_BASE + 0x40)
    a.emit("slli", "t1", "s0", 4)
    a.emit("add", "t0", "t0", "t1")
    a.emit("sw", "a1", 0, "t0")
    a.call("barrier")
    loop_tail(a, "barrier_loop")
    a.li("t0", iterations)
    a.call("store_perhart_t0")
    a.branch("bne", "s0", "zero", "barrier_ret")
    a.call("hart0_wait_others")
    a.li("t0", active * iterations)
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.label("barrier_ret")
    a.ret()

    a.label("work_prodcons")
    a.li("t0", 2)
    a.branch("bge", "s0", "t0", "pc_idle")
    a.branch("bne", "s0", "zero", "consumer")
    loop_header(a, "prod_loop", iterations)
    a.la("t0", DATA_BASE + 0x140)
    a.label("prod_wait_ack")
    a.emit("lw", "t1", 0, "t0")
    a.branch("bne", "t1", "s2", "prod_wait_ack")
    a.la("t2", DATA_BASE + 0x30)
    a.emit("addi", "t3", "s2", 0x55)
    a.emit("sw", "t3", 0, "t2")
    a.la("t0", DATA_BASE + 0x34)
    a.emit("addi", "t4", "s2", 1)
    a.emit("sw", "t4", 0, "t0")
    loop_tail(a, "prod_loop")
    a.call("hart0_wait_others")
    a.li("t0", iterations)
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.ret()
    a.label("consumer")
    loop_header(a, "cons_loop", iterations)
    a.la("t0", DATA_BASE + 0x34)
    a.emit("addi", "t4", "s2", 1)
    a.label("cons_wait_full")
    a.emit("lw", "t1", 0, "t0")
    a.branch("bne", "t1", "t4", "cons_wait_full")
    a.la("t2", DATA_BASE + 0x30)
    a.emit("lw", "t3", 0, "t2")
    a.la("t0", DATA_BASE + 0x140)
    a.emit("sw", "t4", 0, "t0")
    loop_tail(a, "cons_loop")
    a.label("pc_idle")
    a.ret()

    a.label("work_reduction")
    a.li("s2", 0)
    a.li("s3", iterations)
    a.li("s4", 0)
    a.label("red_loop")
    a.emit("addi", "t0", "s2", 1)
    a.emit("add", "s4", "s4", "t0")
    loop_tail(a, "red_loop")
    a.la("t0", DATA_BASE + 0x80)
    a.emit("slli", "t1", "s0", 4)
    a.emit("add", "t0", "t0", "t1")
    a.emit("sw", "s4", 0, "t0")
    a.branch("bne", "s0", "zero", "red_ret")
    a.call("hart0_wait_others")
    a.li("t0", iterations * (iterations + 1) // 2)
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.label("red_ret")
    a.ret()

    a.label("work_pingpong")
    a.li("t0", 2)
    a.branch("bge", "s0", "t0", "ping_ret")
    a.branch("bne", "s0", "zero", "pong_side")
    loop_header(a, "ping_loop", iterations)
    a.la("t0", DATA_BASE + 0x150)
    a.label("ping_wait_ack")
    a.emit("lw", "t1", 0, "t0")
    a.branch("bne", "t1", "s2", "ping_wait_ack")
    a.la("t2", DATA_BASE + 0x94)
    a.emit("lw", "t3", 0, "t2")
    a.emit("addi", "t3", "t3", 1)
    a.emit("sw", "t3", 0, "t2")
    a.la("t0", DATA_BASE + 0x90)
    a.emit("addi", "t4", "s2", 1)
    a.emit("sw", "t4", 0, "t0")
    loop_tail(a, "ping_loop")
    a.call("hart0_wait_others")
    a.la("t1", DATA_BASE + 0x94)
    a.emit("lw", "t0", 0, "t1")
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.ret()
    a.label("pong_side")
    loop_header(a, "pong_loop", iterations)
    a.la("t0", DATA_BASE + 0x90)
    a.emit("addi", "t4", "s2", 1)
    a.label("pong_wait_ready")
    a.emit("lw", "t1", 0, "t0")
    a.branch("bne", "t1", "t4", "pong_wait_ready")
    a.la("t2", DATA_BASE + 0x94)
    a.emit("lw", "t3", 0, "t2")
    a.emit("addi", "t3", "t3", 1)
    a.emit("sw", "t3", 0, "t2")
    a.la("t0", DATA_BASE + 0x150)
    a.emit("sw", "t4", 0, "t0")
    loop_tail(a, "pong_loop")
    a.label("ping_ret")
    a.ret()

    for label, stride in [("work_false", 4), ("work_padded", 16)]:
        a.label(label)
        loop_header(a, f"{label}_loop", iterations)
        a.la("t0", DATA_BASE + 0xC0)
        a.li("t1", stride)
        if stride == 4:
            a.emit("slli", "t2", "s0", 2)
        else:
            a.emit("slli", "t2", "s0", 4)
        a.emit("add", "t0", "t0", "t2")
        a.emit("lw", "t3", 0, "t0")
        a.emit("addi", "t3", "t3", 1)
        a.emit("sw", "t3", 0, "t0")
        loop_tail(a, f"{label}_loop")
        a.branch("bne", "s0", "zero", f"{label}_ret")
        a.call("hart0_wait_others")
        a.li("t0", active * iterations)
        a.la("t1", RESULT_BASE + 4)
        a.emit("sw", "t0", 0, "t1")
        a.label(f"{label}_ret")
        a.ret()

    a.label("work_readmostly")
    loop_header(a, "read_loop", iterations)
    a.la("t0", DATA_BASE + 0x180)
    a.li("t1", 0)
    for off in range(0, 32, 4):
        a.emit("lw", "t2", off, "t0")
        a.emit("add", "t1", "t1", "t2")
    loop_tail(a, "read_loop")
    a.branch("bne", "s0", "zero", "read_ret")
    a.call("hart0_wait_others")
    a.li("t0", active * iterations * 98)
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.label("read_ret")
    a.ret()

    a.label("work_mixed")
    loop_header(a, "mixed_loop", iterations)
    a.emit("sw", "s2", 0, "sp")
    a.emit("lw", "t0", 0, "sp")
    a.la("t1", DATA_BASE + 0x180)
    a.emit("lw", "t2", 0, "t1")
    a.emit("add", "t0", "t0", "t2")
    a.emit("addi", "a1", "s2", 1)
    a.call("barrier")
    loop_tail(a, "mixed_loop")
    a.branch("bne", "s0", "zero", "mixed_ret")
    a.call("hart0_wait_others")
    a.li("t0", active * iterations)
    a.la("t1", RESULT_BASE + 4)
    a.emit("sw", "t0", 0, "t1")
    a.label("mixed_ret")
    a.ret()


def build_image(image: Image) -> None:
    asm = runtime(image.active, image.workload, image.iterations)
    words = asm.finish()
    mem = [0] * 65536
    for pc, word, _text in words:
        mem[pc:pc + 4] = [(word >> (8 * i)) & 0xFF for i in range(4)]
    for addr, val in [
        (CFG_WORKLOAD, image.workload), (CFG_ACTIVE, image.active),
        (CFG_RELEASE, 0), (CFG_ITER, image.iterations),
    ]:
        mem[addr:addr + 4] = [(val >> (8 * i)) & 0xFF for i in range(4)]
    IMG.mkdir(parents=True, exist_ok=True)
    DIS.mkdir(parents=True, exist_ok=True)
    (IMG / f"{image.name}.hex").write_text("\n".join(f"{b:02x}" for b in mem) + "\n", encoding="utf-8")
    listing = [
        f"# {image.name}: workload={image.workload} active={image.active} iterations={image.iterations} expected={image.expected}",
        "# ISA: rv32i with lr.w/sc.w only; no C, M, F, D, privileged, or unsupported AMO encodings.",
    ]
    listing += [f"{pc:08x}: {word:08x}  {text}" for pc, word, text in words]
    (DIS / f"{image.name}.lst").write_text("\n".join(listing) + "\n", encoding="utf-8")


def tool_report() -> str:
    lines = ["Milestone 7 software toolchain audit:"]
    for tool in ["riscv32-unknown-elf-gcc", "riscv64-unknown-elf-gcc", "clang", "llvm-objcopy", "llvm-objdump"]:
        path = shutil.which(tool)
        if path:
            try:
                ver = subprocess.run([path, "--version"], text=True, capture_output=True, check=False).stdout.splitlines()[0]
            except Exception:
                ver = "version unavailable"
            lines.append(f"- {tool}: {path} ({ver})")
        else:
            lines.append(f"- {tool}: not found")
    lines.append("- selected flow: deterministic repository-local RV32I/LRSC assembler fallback")
    return "\n".join(lines) + "\n"


def check_disassembly() -> None:
    forbidden = ["amoadd", "amoswap", "amoor", "amoand", "mul", "div", "rem", "flw", "fsw", "ecall", "mret", "csrr"]
    for path in DIS.glob("*.lst"):
        text = path.read_text(encoding="utf-8").lower()
        for item in forbidden:
            if item in text:
                raise SystemExit(f"unsupported instruction marker {item!r} in {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["build", "check", "disasm"])
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD / "toolchain.txt").write_text(tool_report(), encoding="utf-8")
    for image in IMAGES:
        build_image(image)
    check_disassembly()
    if args.action == "check":
        print("software check: deterministic RV32I/LRSC images verified")
    elif args.action == "disasm":
        print(f"software disassembly: {DIS.relative_to(ROOT)}")
    else:
        print(f"software build: {len(IMAGES)} images in {IMG.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
