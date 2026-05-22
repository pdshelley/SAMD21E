struct DigitalValue {
    var _value: Bool

    init(_ _value: Bool) {
        self._value = _value
    }

    static var high: DigitalValue { DigitalValue(true) }
    static var low: DigitalValue { DigitalValue(false) }
}

extension DigitalValue: Equatable {
    static func == (lhs: DigitalValue, rhs: DigitalValue) -> Bool {
        lhs._value == rhs._value
    }
}

extension DigitalValue {
    mutating func toggle() { _value = !_value }
}
