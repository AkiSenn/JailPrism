#include <TargetConditionals.h>
#if defined(__arm64__) && !TARGET_OS_SIMULATOR
.text
.p2align 2
.globl _IGKernelReadOpen
_IGKernelReadOpen:
    // Narrow read-only probe: cannot accept caller-supplied open flags.
    mov x1, #0
    mov x2, #0
    mov x16, #5
    svc #0x80
    b.cc 1f
    neg x0, x0
1:  ret
.globl _IGKernelReadClose
_IGKernelReadClose:
    mov x16, #6
    svc #0x80
    ret
#endif
