/// USBCDC — USB CDC-ACM class implementation.
///
/// Responsibilities:
///   - Configure EP1 (interrupt IN) and EP2 (bulk OUT/IN) after SET_CONFIGURATION
///   - Circular TX/RX buffers (no heap: fixed-size module-level arrays)
///   - Handle CDC class requests forwarded from USBDevice:
///       SET_LINE_CODING, GET_LINE_CODING, SET_CONTROL_LINE_STATE
///   - Public read/write API for application use
///
/// Depends on USBDevice being initialized first.
///
/// Milestone coverage: M5 (bulk data transfer), M6 (CDC class requests + line coding)

// MARK: - Milestone 5: Bulk Data Transfer (stub)
// TODO: 256-byte circular TX buffer, 256-byte circular RX buffer (module-level storage).
//       EP2 OUT (RX): poll TRCPT0 → copy Bank0 → RX ring → clear BK0RDY to re-arm.
//       EP2 IN  (TX): when TX ring non-empty and BK1RDY clear → copy ≤64 bytes → set BK1RDY.
//       Public API: write(_ bytes: [UInt8]), read() -> UInt8?, available() -> Int

// MARK: - Milestone 6: CDC Class Requests (stub)
// TODO: Handle SET_LINE_CODING (32+8+8+8 bits: baud, stopBits, parity, dataBits) — store, ACK.
//       Handle GET_LINE_CODING — return stored LineCoding struct.
//       Handle SET_CONTROL_LINE_STATE (DTR bit 0, RTS bit 1) — store, ACK.
//       EP1 IN: send SERIAL_STATE notification (10-byte header + 2-byte wSerialState) on connect/disconnect.
