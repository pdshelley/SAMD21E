//
//  shims.c
//  SAMD21E
//
//  Created by Paul Shelley on 4/18/26.
//


#include "BridgingHeader.h"
#include <stddef.h>

/// Stack Canary Guard Value
///
/// Swift's LLVM backend emits stack overflow protection code for functions with
/// local variables. At function entry it copies this global onto the stack; at
/// return it verifies the copy is unchanged. If the value differs, a stack
/// smash has occurred and __stack_chk_fail is called.
///
/// On a hosted OS this value is seeded randomly at startup (via arc4random).
/// On bare metal a fixed sentinel is the accepted approach — 0xDEADBEEF is a
/// traditional embedded marker that is easy to spot in a memory dump.
///
/// This definition must exist or the linker will fail to resolve the symbol.
uintptr_t __stack_chk_guard = 0xDEADBEEF;

/// Stack Smash Handler
///
/// Called by the compiler-generated canary check if __stack_chk_guard has been
/// overwritten, indicating a stack buffer overflow. On a hosted OS this would
/// terminate the process; on bare metal we spin forever, which will trigger the
/// watchdog timer if one is configured.
///
/// This definition must exist or the linker will fail to resolve the symbol.
void __stack_chk_fail(void) { while (1) {} }

/// arc4random_buf Stub
///
/// The C runtime startup (crt0) calls arc4random_buf to seed __stack_chk_guard
/// with a random value before main() runs. On bare metal there is no OS entropy
/// source, so we provide this stub which satisfies the call without pulling in
/// newlib's arc4random implementation. That implementation requires getentropy,
/// which has no nosys stub and would otherwise cause a link error.
///
/// The stub fills the buffer with a fixed byte. Because __stack_chk_guard is
/// already initialised above, the value written here is immediately overwritten
/// by the guard definition and has no practical effect.
void arc4random_buf(void *buf, size_t nbytes) {
    unsigned char *b = (unsigned char *)buf;
    for (size_t i = 0; i < nbytes; i++) b[i] = 0xA5;
}

/// Volatile Register Read
///
/// This could be achieved in Swift only with the following code, however while the compiler seems to mark this as volitile it is
/// not guaranteed so for now we are bridging this from C.
/// ```
/// @inlinable
/// @inline(__always)
/// public func _volatileRegisterReadUInt32(_ address: UInt) -> UInt32 {
///     UnsafeMutablePointer<UInt32>(bitPattern: address)!.pointee
/// }
///  ```
/// At some point in the future this might be added to Swift, if so this should be removed in favor of a Swift only approach.
///
/// Swift forums "Low-level operations for volatile memory accesses"
/// Remove if/when Swift recieves volatile memory accesses.
/// https://forums.swift.org/t/pitch-low-level-operations-for-volatile-memory-accesses/69483
uint32_t _volatileRegisterReadUInt32(uintptr_t address) {
    return *(volatile uint32_t *)address;
}

/// Volatile Register Write
///
/// This could be achieved in Swift only with the following code, however while the compiler seems to mark this as volitile it is
/// not guaranteed so for now we are bridging this from C.
/// ```
/// @inlinable
/// @inline(__always)
/// public func _volatileRegisterWriteUInt32(_ address: UInt, _ newValue: UInt32) {
///     UnsafeMutablePointer<UInt32>(bitPattern: address)!.pointee = newValue
/// }
///  ```
/// At some point in the future this might be added to Swift, if so this should be removed in favor of a Swift only approach.
///
/// Swift forums "Low-level operations for volatile memory accesses"
/// Remove if/when Swift recieves volatile memory accesses.
/// https://forums.swift.org/t/pitch-low-level-operations-for-volatile-memory-accesses/69483
void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value) {
    *(volatile uint32_t *)address = value;
}
