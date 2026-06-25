OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  sram (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  . = ORIGIN(sram);
  .reset : { KEEP(*(.init)) } > sram
  . = 0x00000800;
  .text : { *(.text*) *(.rodata*) } > sram
  .data : { *(.data*) } > sram
  .bss (NOLOAD) : { *(.bss*) *(COMMON) } > sram
  .shared 0x00001000 : { *(.shared*) } > sram
  . = 0x00010000;
  __stack_top = .;
  __stack_hart0 = 0x00010000;
  __stack_hart1 = 0x0000ff00;
  __stack_hart2 = 0x0000fe00;
  __stack_hart3 = 0x0000fd00;
  __stack_bottom = 0x0000fc00;
}

ASSERT(__stack_bottom >= ADDR(.shared) + SIZEOF(.shared), "shared data overlaps stacks")
ASSERT(__stack_hart0 - __stack_hart1 == 0x100, "hart stack stride mismatch")
ASSERT(__stack_hart1 - __stack_hart2 == 0x100, "hart stack stride mismatch")
ASSERT(__stack_hart2 - __stack_hart3 == 0x100, "hart stack stride mismatch")
ASSERT(SIZEOF(.text) + SIZEOF(.data) + SIZEOF(.bss) < 0xf000, "program image exceeds SRAM layout")
