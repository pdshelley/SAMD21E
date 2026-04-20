//
//  PeriodicTimer.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/20/26.
//

/// A non-blocking periodic timer backed by the SysTick millisecond counter.
///
/// Use `hasElapsed()` inside a polling loop to check whether the configured
/// interval has passed without ever blocking. Multiple independent timers can
/// be created as value-type instances at no heap cost.
///
/// Example:
/// ```swift
/// var blinkTimer = PeriodicTimer(interval: 1000)
///
/// func appInit() {
///     blinkTimer.reset()   // sync to actual start time
/// }
///
/// func appMain() {
///     if blinkTimer.hasElapsed() {
///         // runs once per second, appMain() returns immediately otherwise
///     }
/// }
/// ```
///
/// - Note: Uses wrapping subtraction when comparing timestamps, so rollover of
///   `millis()` at ~49 days is handled correctly.
struct PeriodicTimer {

    /// How many milliseconds between firings.
    var interval: UInt32

    /// Timestamp (ms) of the most recent firing, anchored to `lastFiredAt + interval`
    /// on each successive fire to prevent drift.
    private(set) var lastFiredAt: UInt32

    /// Creates a timer that fires every `interval` milliseconds.
    ///
    /// `lastFiredAt` is initialised to `0`. The timer will fire as soon as
    /// `millis()` reaches `interval`. Call `reset()` from `appInit()` if you
    /// want the first firing to occur exactly one interval after start-up.
    @inline(__always)
    init(interval: UInt32) {
        self.interval = interval
        self.lastFiredAt = 0
    }

    /// Returns `true` if the interval has elapsed since the last firing and
    /// advances the internal timestamp by exactly `interval` (drift-free).
    ///
    /// Call this every iteration of your main loop. When it returns `true`,
    /// perform the desired action; the next firing will be scheduled
    /// `interval` milliseconds after the *previous* fire time, not after
    /// the current call — so accumulated latency never causes timer drift.
    @inline(__always)
    mutating func hasElapsed() -> Bool {
        let now = UInt32(truncatingIfNeeded: millis())
        // Wrapping subtraction handles the ~49-day millis() rollover correctly.
        if now &- lastFiredAt >= interval {
            lastFiredAt = lastFiredAt &+ interval
            return true
        }
        return false
    }

    /// Resets the timer so the next firing occurs exactly `interval`
    /// milliseconds from now.
    ///
    /// Call this from `appInit()` after any initialisation that takes
    /// non-trivial time, so the first event fires on a clean boundary.
    @inline(__always)
    mutating func reset() {
        lastFiredAt = UInt32(truncatingIfNeeded: millis())
    }
}
