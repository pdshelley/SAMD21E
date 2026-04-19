/// USBDescriptors — all USB descriptor byte arrays, stored in flash.
///
/// Contains:
///   - Device Descriptor (18 bytes)
///   - Configuration Descriptor block (config + interfaces + CDC functional + endpoints)
///   - String Descriptors (LangID, Manufacturer, Product, Serial)
///
/// CDC class structure:
///   Interface 0 — Communication Class (0x02 / ACM 0x02 / AT-commands 0x01)
///     EP1 IN  — Interrupt, 8 bytes, 255 ms (serial state notifications)
///   Interface 1 — Data Class (0x0A / 0x00 / 0x00)
///     EP2 OUT — Bulk, 64 bytes (host → device)
///     EP2 IN  — Bulk, 64 bytes (device → host)
///
/// Milestone coverage: M4 (CDC descriptors)

// MARK: - Milestone 4: Descriptors (stub)
// TODO: Define deviceDescriptor as a [UInt8] or fixed-size tuple.
//       Define configurationDescriptor as the full concatenated block (compute wTotalLength carefully).
//       Define string descriptors; index 0 = LangID 0x0409.
//       Expose a lookup function: descriptor(type:index:) → UnsafeBufferPointer<UInt8>
//       used by USBDevice SETUP handler.
