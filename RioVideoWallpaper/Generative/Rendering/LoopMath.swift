import Foundation

enum LoopMath {
    static func cyclicPaletteProgress(_ value: Float, states: Int) -> Float {
        let position = value * Float(states)
        let state = floor(position)
        let next = (state + 1).truncatingRemainder(dividingBy: Float(states))
        // A narrow continuous transition avoids unstable palette jumps at quantization boundaries.
        let t = min(1, max(0, (position - state - 0.98) / 0.02))
        let blend = t * t * (3 - 2 * t)
        return (state + (next - state) * blend) / Float(max(1, states - 1))
    }

    static func lifetimeEnvelope(_ age: Float) -> Float {
        let attack = min(1, max(0, age / 0.06))
        let release = min(1, max(0, (1 - age) / 0.06))
        let value = min(attack, release)
        return value * value * (3 - 2 * value)
    }
}
