/* C-callable LR/SC ABI reference. The generated fallback emits these
 * instruction encodings directly and rejects all other AMOs.
 */

    .text
    .globl sparrow_lr_w
sparrow_lr_w:
    lr.w    a0, (a0)
    ret

    .globl sparrow_sc_w
sparrow_sc_w:
    sc.w    a0, a1, (a0)
    ret
