import Foundation

struct AIScanCaptureAttemptState {
    enum Phase: Equatable {
        case idle
        case capturing
        case diagnosing
        case completed
        case failed
        case cancelled
        case timedOut
    }

    enum Update: Equatable {
        case inactive
        case progress(Double)
        case timedOut
    }

    private(set) var phase: Phase = .idle
    private var startedAt: TimeInterval?

    var isActive: Bool { phase == .capturing }

    @discardableResult
    mutating func begin(at monotonicTime: TimeInterval) -> Bool {
        guard phase == .idle || phase == .cancelled || phase == .timedOut else {
            return false
        }
        phase = .capturing
        startedAt = monotonicTime
        return true
    }

    mutating func cancel() {
        phase = .cancelled
        startedAt = nil
    }

    @discardableResult
    mutating func markDiagnosing() -> Bool {
        guard phase == .capturing else { return false }
        phase = .diagnosing
        startedAt = nil
        return true
    }

    @discardableResult
    mutating func markCompleted() -> Bool {
        guard phase == .diagnosing else { return false }
        phase = .completed
        startedAt = nil
        return true
    }

    @discardableResult
    mutating func markNeedsRetake() -> Bool {
        guard phase == .diagnosing else { return false }
        phase = .failed
        startedAt = nil
        return true
    }

    @discardableResult
    mutating func markFailed() -> Bool {
        guard phase == .idle || phase == .capturing || phase == .diagnosing else {
            return false
        }
        phase = .failed
        startedAt = nil
        return true
    }

    @discardableResult
    mutating func prepareForRetry() -> Bool {
        guard phase == .failed || phase == .timedOut else { return false }
        phase = .idle
        startedAt = nil
        return true
    }

    mutating func update(
        at monotonicTime: TimeInterval,
        duration: TimeInterval
    ) -> Update {
        guard isActive, let startedAt else { return .inactive }
        guard duration > 0 else {
            phase = .timedOut
            self.startedAt = nil
            return .timedOut
        }

        let elapsed = max(0, monotonicTime - startedAt)
        guard elapsed < duration else {
            phase = .timedOut
            self.startedAt = nil
            return .timedOut
        }

        return .progress(min(1, elapsed / duration))
    }
}
