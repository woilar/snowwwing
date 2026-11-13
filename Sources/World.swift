import Foundation

func dockSurfaceBounds(container: CGRect?, items: [CGRect]) -> CGRect? {
    let icons = items.filter { $0.width > 0 && $0.height > 0 && $0.width < 180 && $0.height < 180 }
    if let first = icons.first {
        // Dock's outer window/list includes transparent padding; use the actual icon row without an upward inset.
        return icons.dropFirst().reduce(first) { $0.union($1) }
    }
    guard let container, min(container.width, container.height) < 180 else { return nil }
    return container
}

// Shared outline for drawing and contact with the snow pushed ahead of the plow.
let plowPileOutline: [CGPoint] = {
    func curve(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> [CGPoint] {
        (0...16).map { i in
            let t = CGFloat(i) / 16, s = 1 - t
            return CGPoint(x: s*s*s*a.x + 3*s*s*t*b.x + 3*s*t*t*c.x + t*t*t*d.x,
                           y: s*s*s*a.y + 3*s*s*t*b.y + 3*s*t*t*c.y + t*t*t*d.y)
        }
    }
    return curve(.zero, CGPoint(x: 0.04, y: 0.5), CGPoint(x: 0.22, y: 1.03), CGPoint(x: 0.32, y: 1)) +
        curve(CGPoint(x: 0.32, y: 1), CGPoint(x: 0.5, y: 0.95), CGPoint(x: 0.73, y: 0.08), CGPoint(x: 1, y: 0)).dropFirst()
}()

struct Ledge {
    let id: String
    var rect: CGRect
    var spans: [ClosedRange<CGFloat>]
    var isGround = false

    var y: CGFloat { rect.maxY }
    func contains(_ x: CGFloat) -> Bool { spans.contains { $0.contains(x) } }
}

// Window rectangles arrive front to back. Only exposed portions of a roof collect snow.
func exposedSpans(of roof: CGRect, behind front: [CGRect]) -> [ClosedRange<CGFloat>] {
    var spans = [roof.minX...roof.maxX]
    for cover in front where cover.minY < roof.maxY + 12 && cover.maxY > roof.maxY - 1 {
        spans = spans.flatMap { span -> [ClosedRange<CGFloat>] in
            guard cover.maxX > span.lowerBound, cover.minX < span.upperBound else { return [span] }
            var result: [ClosedRange<CGFloat>] = []
            if cover.minX > span.lowerBound { result.append(span.lowerBound...cover.minX) }
            if cover.maxX < span.upperBound { result.append(cover.maxX...span.upperBound) }
            return result
        }
    }
    return spans.filter { $0.upperBound - $0.lowerBound > 3 }
}

final class Drift {
    var ledge: Ledge
    var heights: [CGFloat]
    var updatedAt: CGFloat = 0
    static let spacing: CGFloat = 8

    init(_ ledge: Ledge) {
        self.ledge = ledge
        let count = max(2, Int(ceil(ledge.rect.width / Self.spacing)) + 1)
        heights = (0..<count).map { i in
            let wave = 0.6 + 0.22 * sin(CGFloat(i) * 0.24) + 0.18 * cos(CGFloat(i) * 0.61)
            return (ledge.isGround ? 12 : 5) * wave
        }
    }

    func index(_ x: CGFloat) -> Int {
        min(heights.count - 1, max(0, Int((x - ledge.rect.minX) / Self.spacing)))
    }

    func rawHeight(at x: CGFloat) -> CGFloat {
        let position = min(CGFloat(heights.count - 1), max(0, (x - ledge.rect.minX) / Self.spacing))
        let i = Int(position), next = min(i + 1, heights.count - 1)
        return heights[i] + (heights[next] - heights[i]) * (position - CGFloat(i))
    }

    func height(at x: CGFloat) -> CGFloat {
        guard !ledge.isGround else { return rawHeight(at: x) }
        let edgeWidth = min(16, ledge.rect.width / 2)
        let t = min(1, max(0, min(x - ledge.rect.minX, ledge.rect.maxX - x) / max(1, edgeWidth)))
        return rawHeight(at: x) * t * t * (3 - 2 * t)
    }

    func accumulate(at x: CGFloat, amount: CGFloat) {
        let center = index(x)
        for i in max(0, center - 2)...min(heights.count - 1, center + 2) {
            heights[i] = min(max(heights[i], ledge.isGround ? 28 : 14),
                             heights[i] + amount / CGFloat(1 + abs(center - i)))
        }
    }

    func addPile(at x: CGFloat, area: CGFloat) {
        let halfWidth = max(24, sqrt(area * 1.5))
        var weights = Array(repeating: CGFloat(0), count: heights.count)
        var total: CGFloat = 0
        for i in heights.indices {
            let sampleX = ledge.rect.minX + CGFloat(i) * Self.spacing
            let width = min(Self.spacing, max(0, ledge.rect.maxX - sampleX))
            guard ledge.contains(sampleX), width > 0 else { continue }
            let u = (sampleX - x) / halfWidth
            weights[i] = max(0, 1 - u * u)
            total += weights[i] * width
        }
        guard total > 0 else { return }
        for i in heights.indices { heights[i] += area * weights[i] / total }
    }

    @discardableResult
    func clear(from a: CGFloat, to b: CGFloat) -> CGFloat {
        let lower = min(a, b), upper = max(a, b)
        guard upper >= ledge.rect.minX, lower <= ledge.rect.maxX else { return 0 }
        var collected: CGFloat = 0
        for i in index(lower)...index(upper) {
            let cellWidth = min(Self.spacing, max(0, ledge.rect.width - CGFloat(i) * Self.spacing))
            collected += max(0, heights[i] - 0.5) * cellWidth
            heights[i] = 0.5
        }
        return collected
    }
}

struct Flake {
    var point: CGPoint
    var speed: CGFloat
    var radius: CGFloat
    var phase: CGFloat
}

struct Puff {
    var point: CGPoint
    var velocity: CGVector
    var life: CGFloat
    var radius: CGFloat
    var snowAmount: CGFloat = 0
    var sourceLedge: String? = nil
}

final class Snowball {
    let id = UUID()
    var point: CGPoint // Bottom-center, in the display's local coordinates.
    var velocity = CGVector.zero
    var radii: [CGFloat]
    var pieces: Int { radii.count }
    var snowArea: CGFloat { radii.reduce(0) { $0 + .pi * $1 * $1 } }
    var radius: CGFloat {
        get { radii[0] }
        set { radii[0] = newValue }
    }
    var dragging = false
    var breaksOnImpact = false
    var softArrival = false
    var support: String?
    var supportOrigin: CGPoint?
    var rotation: CGFloat = 0
    var snowCaps: [CGFloat] = [0, 0, 0]

    var spheres: [CGRect] {
        let cx = (radii.max() ?? radius) + 2
        var bottom: CGFloat = 0
        return radii.enumerated().map { i, radius in
            if i > 0 { bottom -= min(radii[i - 1], radius) * 0.35 }
            let sphere = CGRect(x: cx - radius, y: bottom, width: radius * 2, height: radius * 2)
            bottom += radius * 2
            return sphere
        }
    }

    func sphereTop(_ index: Int, x: CGFloat, snowy: Bool = true) -> CGFloat? {
        let sphere = spheres[index]
        // Drawing samples include the endpoints; roundoff must not reject the sphere's own edge.
        guard x >= sphere.minX - 1e-9, x <= sphere.maxX + 1e-9 else { return nil }
        let u = min(1, max(-1, (x - sphere.midX) / (sphere.width / 2)))
        return sphere.midY + sphere.height / 2 * sqrt(max(0, 1 - u * u)) -
            (snowy ? 0 : snowCaps[index] * (1 - u * u))
    }

    func snowSurface(at x: CGFloat) -> (index: Int, y: CGFloat)? {
        let localX = x - frame.minX
        return spheres.indices.compactMap { i -> (index: Int, y: CGFloat)? in
            guard let y = sphereTop(i, x: localX) else { return nil }
            return (i, point.y + y)
        }.max { $0.y < $1.y }
    }

    init(x: CGFloat, y: CGFloat, radius: CGFloat = 18) {
        point = CGPoint(x: x, y: y)
        self.radii = [radius]
    }

    var size: CGSize {
        let height = spheres.map(\.maxY).max() ?? 0
        return CGSize(width: (radii.max() ?? radius) * 2 + 4, height: height + 4)
    }
    var frame: CGRect {
        CGRect(x: point.x - size.width / 2, y: point.y, width: size.width, height: size.height)
    }
}

final class SnowWorld {
    var carriageCount = 3
    private(set) var clearingTrips = 0
    var skierInPile: Bool { clearingTrips > 0 && clearingTrips % 10 == 0 }
    var useTractor = false
    var trainTailLength: CGFloat { useTractor ? 0 : CGFloat(carriageCount) * 60 }
    var size: CGSize
    var drifts: [Drift] = []
    var flakes: [Flake] = []
    var puffs: [Puff] = []
    var balls: [Snowball] = []
    var elapsed: CGFloat = 0
    var plowX: CGFloat = -100
    var plowDirection: CGFloat = 1
    var plowActive = false
    var plowDragging = false
    var trainWheelAngle: CGFloat = 0
    var trainSmokePhase: CGFloat = 0
    var collectedSnow: CGFloat = 0
    var nextPlow: CGFloat = 16
    var nextEdgeSpill: CGFloat = 0
    var nextBallDrop: CGFloat = CGFloat.random(in: 1.5...3.5)
    var accumulationRate: CGFloat = 1
    var crystalFlakes = false
    var snowflakeScale: CGFloat = 1
    var snowfallOnly = false
    var infernalMode = false

    init(size: CGSize) {
        self.size = size
        setLedges([])
        let count = min(300, max(100, Int(size.width * size.height / 6500)))
        flakes = (0..<count).map { _ in newFlake(randomY: true) }
    }

    func newFlake(randomY: Bool = false) -> Flake {
        let depth = CGFloat.random(in: 0...1)
        return Flake(point: CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: randomY ? CGFloat.random(in: 0...size.height) : size.height + 6),
                     speed: 23 + depth * 48, radius: 0.65 + depth * 1.8,
                     phase: CGFloat.random(in: 0...6.28))
    }

    func setLedges(_ ledges: [Ledge], hiddenRoofs: Set<String> = []) {
        guard !snowfallOnly else { return }
        let ground = Ledge(id: "ground", rect: CGRect(x: 0, y: 0, width: size.width, height: 0),
                           spans: [0...size.width], isGround: true)
        let previous = Dictionary(uniqueKeysWithValues: drifts.map { ($0.ledge.id, $0) })
        let remaining = Set(ledges.map(\.id))
        for drift in drifts where !drift.ledge.isGround && !remaining.contains(drift.ledge.id) && !hiddenRoofs.contains(drift.ledge.id) {
            shedSnow(from: drift, between: drift.ledge.rect.minX...drift.ledge.rect.maxX, velocity: 0)
        }
        puffs.removeAll { $0.sourceLedge.map { hiddenRoofs.contains($0) } ?? false }
        drifts = (ledges + [ground]).map { ledge in
            if let existing = previous[ledge.id] {
                let old = existing.ledge.rect
                let dt = min(0.25, max(1.0 / 60, elapsed - existing.updatedAt))
                if abs(old.width - ledge.rect.width) > 0.5 {
                    // A resized roof keeps snow at overlapping screen coordinates; only overhang falls.
                    if ledge.rect.minX > old.minX {
                        shedSnow(from: existing, between: old.minX...min(old.maxX, ledge.rect.minX), velocity: -35)
                    }
                    if ledge.rect.maxX < old.maxX {
                        shedSnow(from: existing, between: max(old.minX, ledge.rect.maxX)...old.maxX, velocity: 35)
                    }
                    let count = max(2, Int(ceil(ledge.rect.width / Drift.spacing)) + 1)
                    existing.heights = (0..<count).map { i in
                        let x = ledge.rect.minX + CGFloat(i) * Drift.spacing
                        return x >= old.minX && x <= old.maxX ? existing.rawHeight(at: x) : 0
                    }
                } else if ledge.id.hasPrefix("window-") {
                    let vx = (ledge.rect.minX - old.minX) / dt
                    let vy = (ledge.rect.maxY - old.maxY) / dt
                    let speed = hypot(vx, vy)
                    if speed > 220 {
                        let fraction = min(1, (speed - 220) / 600 * dt * 8)
                        shedSnow(from: existing, between: old.minX...old.maxX,
                                 velocity: min(500, max(-500, vx * 0.65)),
                                 verticalVelocity: min(200, max(-200, vy * 0.5)), fraction: fraction)
                    }
                }
                existing.updatedAt = elapsed
                existing.ledge = ledge
                return existing
            }
            let created = Drift(ledge)
            if ledge.id.hasPrefix("window-") { created.heights = created.heights.map { _ in 0 } }
            created.updatedAt = elapsed
            return created
        }.sorted { $0.ledge.y > $1.ledge.y }
    }

    func restingHeight(_ ball: Snowball, on drift: Drift) -> CGFloat {
        let sphere = ball.spheres[0]
        let rx = sphere.width / 2, ry = sphere.height / 2
        var top = drift.ledge.y + drift.height(at: ball.point.x)
        for dx in stride(from: -rx, through: rx, by: 1) where drift.ledge.contains(ball.point.x + dx) {
            let underside = ry * (1 - sqrt(max(0, 1 - dx * dx / (rx * rx))))
            top = max(top, drift.ledge.y + drift.height(at: ball.point.x + dx) - underside)
        }
        return top
    }

    func landing(x: CGFloat, from oldY: CGFloat, to newY: CGFloat, excluding: String? = nil,
                 ball: Snowball? = nil) -> (Drift, CGFloat)? {
        var hit: (Drift, CGFloat)?
        for drift in drifts where drift.ledge.id != excluding && drift.ledge.contains(x) {
            let top = ball.map { restingHeight($0, on: drift) } ?? (drift.ledge.y + drift.height(at: x))
            // A growing drift can reach an airborne ball between frames.
            let reached = oldY >= (ball == nil ? top - 1 : drift.ledge.y)
            if (reached || drift.ledge.isGround) && newY <= top,
               top > (hit?.1 ?? -.infinity) { hit = (drift, top) }
        }
        return hit
    }

    @discardableResult
    func settleSnow(x: CGFloat, from oldY: CGFloat, to newY: CGFloat, amount: CGFloat,
                    excluding: String? = nil) -> Bool {
        let roof = landing(x: x, from: oldY, to: newY, excluding: excluding)
        var target: (Snowball, Int, CGFloat)?
        for ball in balls {
            guard let surface = ball.snowSurface(at: x), oldY >= surface.y - 1, newY <= surface.y,
                  surface.y > (roof?.1 ?? -.infinity), surface.y > (target?.2 ?? -.infinity) else { continue }
            target = (ball, surface.index, surface.y)
        }
        if let (ball, index, _) = target {
            // shortcut: compact caps stop at 12 points; add shedding if deeper layers are needed.
            let added = min(12 - ball.snowCaps[index], amount)
            ball.snowCaps[index] += added
            ball.radii[index] += added / 2
            return true
        }
        if let (drift, _) = roof { drift.accumulate(at: x, amount: amount); return true }
        return false
    }

    func startPlow() {
        guard !plowActive else { return }
        clearingTrips += 1
        carriageCount = Int.random(in: 1...5)
        plowDirection = Bool.random() ? 1 : -1
        plowX = plowDirection > 0 ? -80 : size.width + 80
        collectedSnow = 0
        plowActive = true
    }

    var hasSnowToPlow: Bool {
        guard let ground = drifts.first(where: { $0.ledge.isGround }) else { return false }
        let samples = ground.heights.dropLast()
        return samples.reduce(0) { $0 + max(0, $1 - 0.5) } >= CGFloat(samples.count) * 6
    }

    func movePlow(to x: CGFloat) {
        guard plowActive else { return }
        let oldX = plowX
        plowX = x
        trainWheelAngle -= (x - oldX) * plowDirection / 6
        guard let ground = drifts.first(where: { $0.ledge.isGround }) else { return }
        let collected = ground.clear(from: min(oldX, x) - 40, to: max(oldX, x) + 40)
        collectedSnow += collected
        let blade = x + plowDirection * 35
        if collected > 0 && blade > 0 && blade < size.width {
            burst(at: CGPoint(x: blade, y: 10), count: 3, direction: plowDirection)
        }
        let sweep = CGRect(x: min(oldX, x) - 40, y: 0, width: abs(x - oldX) + 80, height: 32)
        let removed = balls.filter {
            !$0.dragging && (touchesPlowPile($0, from: oldX, to: x) || $0.frame.intersects(sweep))
        }
        for snowman in removed {
            collectedSnow += snowman.snowArea
            burst(at: CGPoint(x: snowman.point.x, y: snowman.point.y + 35), count: 32,
                  direction: plowDirection)
        }
        let removedIDs = Set(removed.map(\.id))
        balls.removeAll { removedIDs.contains($0.id) }
    }

    func brushSnow(from previous: CGPoint, to point: CGPoint) {
        guard !snowfallOnly else { return }
        let dx = point.x - previous.x, dy = point.y - previous.y
        guard hypot(dx, dy) > 0.5, !balls.contains(where: { $0.dragging }) else { return }
        for drift in drifts where !drift.ledge.isGround {
            let bottom = drift.ledge.y
            let top = bottom + (drift.heights.max() ?? 0) + 4
            var begin: CGFloat = 0, end: CGFloat = 1
            if abs(dy) < 0.001 {
                guard point.y >= bottom && point.y <= top else { continue }
            } else {
                let a = (bottom - previous.y) / dy, b = (top - previous.y) / dy
                begin = max(0, min(a, b)); end = min(1, max(a, b))
                guard begin <= end else { continue }
            }
            let a = previous.x + dx * begin, b = previous.x + dx * end
            shedSnow(from: drift, between: (min(a, b) - 10)...(max(a, b) + 10),
                     velocity: min(240, max(-240, dx * 8)), verticalVelocity: min(60, max(-120, dy * 3)))
        }
    }

    func shedSnow(from drift: Drift, between range: ClosedRange<CGFloat>, velocity: CGFloat,
                  verticalVelocity: CGFloat = 0, fraction: CGFloat = 1) {
        var detached: [(x: CGFloat, y: CGFloat, amount: CGFloat)] = []
        for i in drift.heights.indices {
            let x = min(drift.ledge.rect.maxX, drift.ledge.rect.minX + CGFloat(i) * Drift.spacing)
            guard range.contains(x), drift.ledge.contains(x) else { continue }
            let removed = max(0, drift.heights[i] - 0.5) * fraction
            guard removed > 0.05 else { continue }
            drift.heights[i] -= removed
            let width = min(Drift.spacing, max(0, drift.ledge.rect.width - CGFloat(i) * Drift.spacing))
            guard width > 0 else { continue }
            detached.append((x, drift.ledge.y + removed / 2, removed * width))
        }
        guard !detached.isEmpty else { return }
        // Batch wide roofs into clumps; even a busy particle pool must not leave snow attached.
        let slots = max(1, min(64, 250 - puffs.count))
        let groupSize = (detached.count + slots - 1) / slots
        for start in stride(from: 0, to: detached.count, by: groupSize) {
            let group = detached[start..<min(detached.count, start + groupSize)]
            let amount = group.reduce(CGFloat(0)) { $0 + $1.amount }
            let point = CGPoint(x: group.reduce(CGFloat(0)) { $0 + $1.x * $1.amount } / amount,
                                y: group.reduce(CGFloat(0)) { $0 + $1.y * $1.amount } / amount)
            puffs.append(Puff(point: point,
                              velocity: CGVector(dx: velocity + CGFloat.random(in: -25...25),
                                                 dy: verticalVelocity + CGFloat.random(in: 5...35)),
                              life: max(4, sqrt(2 * max(0, drift.ledge.y) / 500) + 1),
                              radius: min(2.6, 0.8 + sqrt(amount) * 0.08),
                              snowAmount: amount, sourceLedge: drift.ledge.id))
        }
    }

    var plowPileSize: CGSize {
        // Keep the mound's area proportional to the snow removed from the ground.
        let width = sqrt(collectedSnow * 5)
        return CGSize(width: width, height: width * 0.4)
    }

    var trainLoad: CGFloat { collectedSnow / (collectedSnow + 4000) }
    var trainFireIntensity: CGFloat { max(0, (trainLoad - 0.65) / 0.35) }
    var trainSpeed: CGFloat { 88 * (1 - trainLoad * 0.35) }

    var trainFrame: CGRect {
        CGRect(x: plowX - 40 - (plowDirection > 0 ? trainTailLength : 0), y: 0,
               width: 80 + trainTailLength, height: 50)
    }

    func touchesPlowPile(_ ball: Snowball, from oldX: CGFloat, to newX: CGFloat) -> Bool {
        let size = plowPileSize
        guard size.width > 0 else { return false }
        let oldBase = oldX + plowDirection * 28, newBase = newX + plowDirection * 28
        for sphere in ball.spheres {
            let worldSphere = sphere.offsetBy(dx: ball.frame.minX, dy: ball.point.y)
            guard worldSphere.minY <= 1 + size.height * 1.01, worldSphere.maxY >= 1 else { continue }
            // Sample the rounded underside, not the character panel's empty corners.
            for dx in stride(from: -sphere.width / 2, through: sphere.width / 2, by: 1) {
                let x = worldSphere.midX + dx
                let a = (x - oldBase) * plowDirection / size.width
                let b = (x - newBase) * plowDirection / size.width
                let lower = max(0, min(a, b)), upper = min(1, max(a, b))
                guard lower <= upper else { continue }
                let bottom = worldSphere.midY - sphere.height / 2 * sqrt(max(0, 1 - pow(dx / (sphere.width / 2), 2)))
                for i in 1..<plowPileOutline.count {
                    let left = plowPileOutline[i - 1], right = plowPileOutline[i]
                    let lo = max(lower, left.x), hi = min(upper, right.x)
                    guard lo <= hi else { continue }
                    let slope = (right.y - left.y) / (right.x - left.x)
                    let top = max(left.y + slope * (lo - left.x), left.y + slope * (hi - left.x))
                    if bottom <= 1 + top * size.height { return true }
                }
            }
        }
        return false
    }

    func addBall(at point: CGPoint? = nil) {
        guard balls.count < 6 else { return }
        balls.append(Snowball(x: point?.x ?? size.width * 0.5,
                              y: point?.y ?? size.height * 0.55))
    }

    func resetSnow() {
        for drift in drifts { drift.heights = drift.heights.map { _ in 0.5 } }
        for ball in balls { ball.snowCaps = [0, 0, 0] }
        collectedSnow = 0
        puffs.removeAll()
    }

    func dragBall(_ ball: Snowball, to destination: CGPoint) {
        let previous = ball.point
        ball.point = CGPoint(x: min(size.width - ball.size.width / 2,
                                   max(ball.size.width / 2, destination.x)),
                             y: min(size.height - ball.size.height, max(0, destination.y)))
        let distance = ball.point.x - previous.x
        let limit = min(80, min(size.width, size.height) / 4)
        if ball.pieces == 1,
           let surface = drifts.first(where: {
               $0.ledge.contains(previous.x) && $0.ledge.contains(ball.point.x) &&
               previous.y >= $0.ledge.y - 4 && ball.point.y >= $0.ledge.y - 4 &&
                previous.y <= $0.ledge.y + ($0.heights.max() ?? 0) + 8 &&
                ball.point.y <= restingHeight(ball, on: $0) + 8
           }) {
            var snow: CGFloat = 0
            for span in surface.ledge.spans where ball.radius < limit && abs(distance) > 0.1 {
                 // Only the bottom contact sweeps the snow; the full radius would clear ahead of contact.
                 let left = max(span.lowerBound, min(previous.x, ball.point.x))
                 let right = min(span.upperBound, max(previous.x, ball.point.x))
                if left <= right { snow += surface.clear(from: left, to: right) }
            }
            let oldRadius = ball.radius
            // Collected snow adds volume, not diameter, so larger balls grow more slowly.
            if snow > 0 { ball.radius = min(limit, pow(pow(oldRadius, 3) + snow * 10, 1.0 / 3)) }
            ball.rotation -= distance / ((oldRadius + ball.radius) / 2)
            ball.point.y = restingHeight(ball, on: surface)
        }
        ball.point.x = min(size.width - ball.size.width / 2, max(ball.size.width / 2, ball.point.x))
        ball.point.y = min(size.height - ball.size.height, ball.point.y)
    }

    func release(_ ball: Snowball) {
        ball.dragging = false
        ball.breaksOnImpact = true
        ball.softArrival = false
        ball.support = nil
        guard ball.pieces < 3 else { return }
        if let target = balls.first(where: {
            $0 !== ball && !$0.dragging && $0.pieces < 3 && $0.pieces + ball.pieces <= 3 &&
                $0.frame.insetBy(dx: -12, dy: -12).intersects(ball.frame)
        }) {
            let offset = target.pieces
            for i in 0..<ball.pieces { target.snowCaps[offset + i] = ball.snowCaps[i] }
            target.radii.append(contentsOf: ball.radii)
            target.velocity = .zero
            balls.removeAll { $0 === ball }
            burst(at: CGPoint(x: target.point.x, y: target.point.y + target.size.height / 2), count: 24)
        }
    }

    func burst(at point: CGPoint, count: Int, direction: CGFloat = 0) {
        for _ in 0..<min(count, max(0, 250 - puffs.count)) {
            puffs.append(Puff(point: point,
                              velocity: CGVector(dx: direction * 80 + CGFloat.random(in: -65...65),
                                                 dy: CGFloat.random(in: 30...130)),
                              life: CGFloat.random(in: 0.3...0.85), radius: CGFloat.random(in: 1...3)))
        }
    }

    func step(_ delta: CGFloat, allowNewBall: Bool = false) {
        let dt = min(max(delta, 0), 1.0 / 15)
        elapsed += dt
        if !snowfallOnly && allowNewBall && balls.count < 6 && elapsed >= nextBallDrop {
            let radius = CGFloat.random(in: 10...14)
            let ball = Snowball(x: CGFloat.random(in: (radius + 2)...max(radius + 2, size.width - radius - 2)),
                                y: size.height + radius * 2, radius: radius)
            ball.softArrival = true
            balls.append(ball)
            nextBallDrop = elapsed + CGFloat.random(in: 12...22)
        }
        if !snowfallOnly && elapsed >= nextEdgeSpill {
            nextEdgeSpill = elapsed + 0.25
            for drift in drifts where !drift.ledge.isGround {
                let edgeWidth = min(16, drift.ledge.rect.width / 2)
                if puffs.count < 240 && drift.ledge.contains(drift.ledge.rect.minX) {
                    shedSnow(from: drift, between: drift.ledge.rect.minX...(drift.ledge.rect.minX + edgeWidth),
                             velocity: -40, verticalVelocity: -40, fraction: 0.35)
                }
                if puffs.count < 240 && drift.ledge.contains(drift.ledge.rect.maxX) {
                    shedSnow(from: drift, between: (drift.ledge.rect.maxX - edgeWidth)...drift.ledge.rect.maxX,
                             velocity: 40, verticalVelocity: -40, fraction: 0.35)
                }
            }
        }
        for i in flakes.indices {
            let oldY = flakes[i].point.y
            flakes[i].point.x += (13 * sin(elapsed * 0.35) + 12 * sin(elapsed + flakes[i].phase)) * dt
            flakes[i].point.y -= flakes[i].speed * dt
            if flakes[i].point.x < 0 { flakes[i].point.x += size.width }
            if flakes[i].point.x > size.width { flakes[i].point.x -= size.width }
            if !snowfallOnly && settleSnow(x: flakes[i].point.x, from: oldY, to: flakes[i].point.y,
                          amount: flakes[i].radius * 0.15 * accumulationRate) {
                flakes[i] = newFlake()
            } else if flakes[i].point.y < 0 {
                flakes[i] = newFlake()
            }
        }
        guard !snowfallOnly else { return }
        for ball in balls where !ball.dragging {
            if let id = ball.support, let drift = drifts.first(where: { $0.ledge.id == id }),
               let oldOrigin = ball.supportOrigin {
                ball.point.x += drift.ledge.rect.minX - oldOrigin.x
                ball.point.y += drift.ledge.y - oldOrigin.y
                if drift.ledge.contains(ball.point.x) {
                    ball.point.y = restingHeight(ball, on: drift)
                }
            }
            ball.support = nil
            let oldY = ball.point.y
            ball.velocity.dy -= 500 * dt
            ball.point.x += ball.velocity.dx * dt
            ball.point.y += ball.velocity.dy * dt
            let half = ball.size.width / 2
            if ball.point.x < half || ball.point.x > size.width - half {
                ball.point.x = min(max(half, ball.point.x), size.width - half)
                ball.velocity.dx *= -0.45
            }
            if ball.velocity.dy <= 0,
               let (drift, top) = landing(x: ball.point.x, from: oldY, to: ball.point.y, ball: ball) {
                ball.point.y = top
                if (ball.pieces >= 3 || ball.breaksOnImpact) && ball.velocity.dy < -110 {
                    drift.addPile(at: ball.point.x, area: ball.snowArea)
                    burst(at: CGPoint(x: ball.point.x, y: top + ball.radius), count: 32)
                    balls.removeAll { $0 === ball }
                    continue
                }
                if ball.velocity.dy < -110 && !ball.softArrival {
                    ball.velocity.dy *= -0.32
                    burst(at: ball.point, count: 7)
                } else {
                    ball.velocity.dy = 0
                    ball.support = drift.ledge.id
                    ball.supportOrigin = CGPoint(x: drift.ledge.rect.minX, y: drift.ledge.y)
                }
                ball.softArrival = false
                ball.velocity.dx *= pow(0.12, dt)
            }
            if ball.point.y < 0 { ball.point.y = 1; ball.velocity.dy = 0 }
            ball.rotation -= ball.velocity.dx * dt / max(ball.radius, 1)
        }
        if !plowActive && elapsed >= nextPlow && hasSnowToPlow { startPlow() }
        if plowActive {
            trainSmokePhase = (trainSmokePhase + dt * (0.25 + trainLoad * 1.5)).truncatingRemainder(dividingBy: 1)
            movePlow(to: plowX + (plowDragging ? 0 : plowDirection * trainSpeed * dt))
            if !plowDragging && (plowX < -110 - trainTailLength || plowX > size.width + 110 + trainTailLength) {
                plowActive = false
                nextPlow = elapsed + 45
            }
        }
        for i in puffs.indices {
            let oldY = puffs[i].point.y
            puffs[i].life -= dt
            puffs[i].velocity.dy -= (puffs[i].snowAmount > 0 ? 500 : 220) * dt
            puffs[i].point.x += puffs[i].velocity.dx * dt
            puffs[i].point.y += puffs[i].velocity.dy * dt
            if puffs[i].snowAmount > 0, puffs[i].velocity.dy < 0,
               settleSnow(x: puffs[i].point.x, from: oldY, to: puffs[i].point.y,
                          amount: puffs[i].snowAmount / (Drift.spacing * 8 / 3), excluding: puffs[i].sourceLedge) {
                puffs[i].life = 0
            }
        }
        puffs.removeAll { $0.life <= 0 || $0.point.y < 0 }
    }
}
