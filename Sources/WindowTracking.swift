import Foundation

struct TrackedRoof: Equatable {
    let id: String
    let rect: CGRect
}

struct TrackedScreen: Equatable {
    let frame: CGRect
    let roofCeiling: CGFloat
}

struct WindowLayoutSnapshot: Equatable {
    // Order matters: bringing a window forward changes the exposed surfaces.
    let roofs: [TrackedRoof]
    let screens: [TrackedScreen]
}

struct WindowTrackingCache {
    private var nextScan: TimeInterval?
    private var snapshot: WindowLayoutSnapshot?

    mutating func invalidate() {
        nextScan = nil
        snapshot = nil
    }

    mutating func beginScan(at now: TimeInterval, hasSurfaces: Bool) -> Bool {
        guard hasSurfaces else {
            invalidate()
            return false
        }
        guard nextScan.map({ now >= $0 }) ?? true else { return false }
        // Animation remains at 30 FPS; system window queries run at most 10 Hz.
        nextScan = now + 0.1
        return true
    }

    mutating func needsRebuild(_ current: WindowLayoutSnapshot) -> Bool {
        guard snapshot != current else { return false }
        snapshot = current
        return true
    }
}
