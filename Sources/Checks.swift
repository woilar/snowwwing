import AppKit
import ApplicationServices

func selfTest() {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
        checks += 1
    }
    var tracking = WindowTrackingCache()
    check(!tracking.beginScan(at: 0, hasSurfaces: false), "snowfall-only skips surface polling")
    check(tracking.beginScan(at: 0, hasSurfaces: true), "surface tracking starts immediately")
    check(!tracking.beginScan(at: 0.03, hasSurfaces: true), "animation tick does not trigger another window query")
    check(!tracking.beginScan(at: 0.099, hasSurfaces: true), "window polling never exceeds 10 Hz")
    check(tracking.beginScan(at: 0.1, hasSurfaces: true), "window polling resumes at the next interval")
    let roofA = TrackedRoof(id: "window-1", rect: CGRect(x: 50, y: 100, width: 200, height: 150))
    let roofB = TrackedRoof(id: "window-2", rect: CGRect(x: 100, y: 120, width: 200, height: 150))
    let screen = TrackedScreen(frame: CGRect(x: 0, y: 0, width: 800, height: 600), roofCeiling: 579)
    let layout = WindowLayoutSnapshot(roofs: [roofA, roofB], screens: [screen])
    check(tracking.needsRebuild(layout), "initial window layout builds surfaces")
    check(!tracking.needsRebuild(layout), "unchanged window layout reuses surfaces")
    check(tracking.needsRebuild(WindowLayoutSnapshot(roofs: [roofB, roofA], screens: [screen])),
          "z-order changes invalidate occlusion even when window frames stay the same")
    let moved = TrackedRoof(id: roofA.id, rect: roofA.rect.offsetBy(dx: 20, dy: 0))
    check(tracking.needsRebuild(WindowLayoutSnapshot(roofs: [roofB, moved], screens: [screen])),
          "moving a window invalidates surfaces")
    let resized = TrackedRoof(id: moved.id, rect: CGRect(x: 70, y: 100, width: 100, height: 150))
    check(tracking.needsRebuild(WindowLayoutSnapshot(roofs: [roofB, resized], screens: [screen])),
          "resizing a window invalidates surfaces")
    check(tracking.needsRebuild(WindowLayoutSnapshot(roofs: [roofB], screens: [screen])),
          "closed windows are removed from surfaces")
    let dock = TrackedRoof(id: "dock", rect: CGRect(x: 200, y: 0, width: 300, height: 60))
    check(tracking.needsRebuild(WindowLayoutSnapshot(roofs: [dock, roofB], screens: [screen])),
          "asynchronous Dock geometry updates invalidate surfaces")
    let changedScreen = TrackedScreen(frame: screen.frame, roofCeiling: 599)
    check(tracking.needsRebuild(WindowLayoutSnapshot(roofs: [dock, roofB], screens: [changedScreen])),
          "menu bar and visible screen changes invalidate hidden roof filtering")
    let secondScreen = TrackedScreen(frame: screen.frame.offsetBy(dx: 800, dy: 0), roofCeiling: 579)
    check(tracking.needsRebuild(WindowLayoutSnapshot(roofs: [dock, roofB], screens: [screen, secondScreen])),
          "monitor changes invalidate per-display geometry")
    check(!tracking.beginScan(at: 0.11, hasSurfaces: false), "disabling surfaces stops queries immediately")
    check(tracking.beginScan(at: 0.12, hasSurfaces: true) && tracking.needsRebuild(layout),
          "restoring surfaces refreshes immediately instead of reusing stale geometry")
    tracking.invalidate()
    check(tracking.beginScan(at: 0.13, hasSurfaces: true) && tracking.needsRebuild(layout),
          "screen recreation and resume invalidate equal geometry too")
    let stationary = SnowWorld(size: CGSize(width: 800, height: 600))
    stationary.setLedges([Ledge(id: "window-1", rect: roofA.rect, spans: [50...250])])
    let cachedDrift = stationary.drifts.first { $0.ledge.id == "window-1" }!
    cachedDrift.heights = cachedDrift.heights.map { _ in 8 }
    let cachedHeights = cachedDrift.heights
    stationary.elapsed = 2
    stationary.observeUnchangedLedges()
    check(stationary.drifts.contains { $0 === cachedDrift } && cachedDrift.heights == cachedHeights,
          "cache hits preserve accumulated snow and drift identity")
    check(cachedDrift.updatedAt == 2, "cache hits advance the last geometry observation time")
    stationary.elapsed = 2.1
    stationary.setLedges([Ledge(id: "window-1", rect: roofA.rect.offsetBy(dx: 40, dy: 0), spans: [90...290])])
    check(cachedDrift.heights.reduce(0, +) < cachedHeights.reduce(0, +),
          "fast movement after a stationary interval still sheds snow")

    let fractional = Snowball(x: 100, y: 10, radius: 30.001)
    let initialLanguage = L10n.english
    L10n.english = true
    check(L10n.translations.allSatisfy { L10n.text($0.key) == $0.value && L10n.text($0.value) == $0.value },
          "all UI translations resolve to English and remain stable on repeated refresh")
    L10n.english = false
    check(L10n.translations.allSatisfy { L10n.text($0.value) == $0.key && L10n.text($0.key) == $0.key },
          "all English UI titles switch back to Russian")
    L10n.english = initialLanguage
    let dockIcons = [CGRect(x: 200, y: 1010, width: 56, height: 56), CGRect(x: 264, y: 1010, width: 56, height: 56)]
    let paddedDock = CGRect(x: 188, y: 990, width: 144, height: 90)
    let visibleDock = dockSurfaceBounds(container: paddedDock, items: dockIcons)!
    check(visibleDock == CGRect(x: 200, y: 1010, width: 120, height: 56),
          "Dock snow uses icon row bounds rather than invisible container padding")
    check(visibleDock.minY == dockIcons[0].minY,
          "Dock snow surface has no artificial upward padding")
    check(dockSurfaceBounds(container: CGRect(x: 0, y: 0, width: 1710, height: 1107), items: dockIcons) == visibleDock,
          "fullscreen Dock host does not displace the icon row surface")
    check(dockSurfaceBounds(container: paddedDock, items: []) == paddedDock,
          "Dock falls back to compact container when icon frames are unavailable")
    let rareSkier = SnowWorld(size: CGSize(width: 800, height: 600))
    check(!rareSkier.skierInPile, "skier is absent before the first clearing trip")
    for trip in 1...20 {
        rareSkier.plowActive = false
        rareSkier.useTractor = trip > 10
        rareSkier.startPlow()
        rareSkier.startPlow()
        check(rareSkier.clearingTrips == trip && rareSkier.skierInPile == (trip % 10 == 0),
              "skier appears only every tenth trip; repeated calls during a trip do not advance the counter")
    }
    let onlySnow = SnowWorld(size: CGSize(width: 800, height: 600))
    onlySnow.addBall(at: CGPoint(x: 400, y: 100))
    onlySnow.plowActive = true
    onlySnow.plowX = 200
    onlySnow.nextBallDrop = 0
    onlySnow.snowfallOnly = true
    onlySnow.flakes = [Flake(point: CGPoint(x: 100, y: 5), speed: 60, radius: 2, phase: 0)]
    let preservedSnow = onlySnow.drifts[0].heights
    onlySnow.step(1.0 / 30, allowNewBall: true)
    check(onlySnow.flakes[0].point.y == 3 && onlySnow.drifts[0].heights == preservedSnow,
          "snowfall-only flakes keep falling through hidden drifts without accumulating")
    check(onlySnow.balls.count == 1 && onlySnow.balls[0].point.y == 100 && onlySnow.plowX == 200,
          "snowfall-only freezes characters and transport and suppresses new snowballs")
    onlySnow.snowfallOnly = false
    onlySnow.step(1.0 / 30)
    check(onlySnow.balls[0].point.y < 100 && onlySnow.plowX != 200,
          "turning off snowfall-only resumes existing characters and transport")
    for direction: CGFloat in [-1, 1] {
        let emptyTrain = SnowWorld(size: CGSize(width: 800, height: 600))
        let loadedTrain = SnowWorld(size: CGSize(width: 800, height: 600))
        for engine in [emptyTrain, loadedTrain] {
            engine.resetSnow()
            engine.flakes.removeAll()
            engine.plowActive = true
            engine.plowDirection = direction
            engine.plowX = 400
        }
        loadedTrain.collectedSnow = 12000
        check(emptyTrain.trainFireIntensity == 0 && loadedTrain.trainFireIntensity > 0,
              "chimney fire appears only under heavy snow load")
        let initialFire = loadedTrain.trainFireIntensity
        emptyTrain.step(1.0 / 30)
        loadedTrain.step(1.0 / 30)
        check(abs(loadedTrain.plowX - 400) < abs(emptyTrain.plowX - 400) && loadedTrain.trainLoad > emptyTrain.trainLoad,
              "snow load slows automatic travel in either direction and increases visual effort")
        check(abs(loadedTrain.trainWheelAngle) < abs(emptyTrain.trainWheelAngle),
              "wheels follow the actual slower travel instead of spinning at fixed speed")
        check(loadedTrain.trainSmokePhase > emptyTrain.trainSmokePhase,
              "loaded train emits smoke faster without resetting the animation phase")
        loadedTrain.collectedSnow = 1_000_000
        check(loadedTrain.trainFireIntensity > initialFire && loadedTrain.trainFireIntensity < 1,
              "chimney fire intensifies with load and stays bounded")
        check(loadedTrain.trainSpeed > 88 * 0.65 && loadedTrain.trainSpeed < 88 && loadedTrain.trainLoad < 1,
              "even extreme snow loads cannot stall the train or exceed animation limits")
        loadedTrain.plowDragging = true
        let heldPosition = loadedTrain.plowX, heldAngle = loadedTrain.trainWheelAngle
        loadedTrain.step(1.0 / 30)
        check(loadedTrain.plowX == heldPosition && loadedTrain.trainWheelAngle == heldAngle,
              "held train does not drift or spin its wheels while smoke can continue")
        loadedTrain.resetSnow()
        check(loadedTrain.trainLoad == 0 && loadedTrain.trainSpeed == 88 && loadedTrain.trainFireIntensity == 0,
              "clearing the pile restores unloaded speed and light smoke")
    }
    let train = SnowWorld(size: CGSize(width: 800, height: 600))
    train.useTractor = true
    train.carriageCount = 5
    for direction: CGFloat in [-1, 1] {
        train.plowDirection = direction
        train.plowX = 400
        check(train.trainFrame == CGRect(x: 360, y: 0, width: 80, height: 50) && train.trainTailLength == 0,
              "tractor mode keeps the original compact frame without carriage space")
    }
    train.useTractor = false
    train.flakes.removeAll()
    train.startPlow()
    let selectedCars = train.carriageCount
    train.startPlow()
    train.step(1.0 / 60)
    check((1...5).contains(selectedCars) && train.carriageCount == selectedCars,
          "train chooses one to five carriages once per trip")
    for count in [1, 5] {
        train.carriageCount = count
        for direction: CGFloat in [-1, 1] {
            train.plowActive = true
            train.plowDirection = direction
            train.plowX = 400
            check(train.trainFrame.width == 80 + CGFloat(count) * 60 &&
                  (direction > 0 ? train.trainFrame.maxX == 440 : train.trainFrame.minX == 360),
                  "carriages extend behind the engine without shifting its blade in either direction")
            train.plowX = direction > 0 ? 850 : -50
            train.step(0)
            check(train.plowActive, "train remains visible while trailing carriages are still on screen")
            train.plowX = direction > 0 ? 911 + train.trainTailLength : -111 - train.trainTailLength
            train.step(0)
            check(!train.plowActive, "train finishes its trip only after the full consist exits")
        }
    }
    let normalAccumulation = SnowWorld(size: CGSize(width: 800, height: 600))
    let fastAccumulation = SnowWorld(size: CGSize(width: 800, height: 600))
    fastAccumulation.accumulationRate = 4
    for sceneWorld in [normalAccumulation, fastAccumulation] {
        sceneWorld.resetSnow()
        sceneWorld.flakes = [Flake(point: CGPoint(x: 400, y: 1), speed: 60, radius: 2, phase: 0)]
        sceneWorld.step(1.0 / 30)
    }
    check(abs((fastAccumulation.drifts[0].height(at: 400) - 0.5) -
              4 * (normalAccumulation.drifts[0].height(at: 400) - 0.5)) < 0.001,
          "accumulation setting scales snowfall deposited into drifts")
    for sceneWorld in [normalAccumulation, fastAccumulation] {
        sceneWorld.resetSnow()
        sceneWorld.flakes.removeAll()
        sceneWorld.puffs = [Puff(point: CGPoint(x: 400, y: 1), velocity: CGVector(dx: 0, dy: -60),
                                life: 2, radius: 2, snowAmount: 12)]
        sceneWorld.step(1.0 / 30)
    }
    check(normalAccumulation.drifts[0].heights == fastAccumulation.drifts[0].heights,
          "accumulation setting does not multiply existing snow transferred by falling clumps")
    let fullscreen = SnowWorld(size: CGSize(width: 800, height: 600))
    fullscreen.addBall()
    let disappearingRoof = Ledge(id: "window-fullscreen", rect: CGRect(x: 100, y: 100, width: 400, height: 400), spans: [100...500])
    fullscreen.setLedges([disappearingRoof])
    fullscreen.drifts[0].heights = fullscreen.drifts[0].heights.map { _ in 8 }
    fullscreen.shedSnow(from: fullscreen.drifts[0], between: 100...200, velocity: 0)
    fullscreen.setLedges([], hiddenRoofs: [disappearingRoof.id])
    fullscreen.brushSnow(from: CGPoint(x: 100, y: 599), to: CGPoint(x: 500, y: 599))
    check(fullscreen.puffs.isEmpty && fullscreen.drifts.allSatisfy { $0.ledge.isGround },
          "invisible fullscreen roof neither sheds nor retains brushable snow")
    let elapsedBeforeFullscreen = fullscreen.elapsed
    fullscreen.step(1.0 / 30)
    check(fullscreen.elapsed > elapsedBeforeFullscreen && !fullscreen.flakes.isEmpty && !fullscreen.balls.isEmpty,
          "snowfall and characters keep running without the hidden roof")
    fullscreen.setLedges([disappearingRoof])
    check(fullscreen.drifts[0].heights.allSatisfy { $0 == 0 }, "returning roof starts empty instead of restoring invisible snow")
    fractional.snowCaps[0] = 1
    check(fractional.sphereTop(0, x: fractional.spheres[0].maxX) != nil,
          "fractional-radius snow cap includes its right endpoint despite floating-point rounding")
    let roof = CGRect(x: 100, y: 100, width: 300, height: 100)
    let corners = SnowWorld(size: CGSize(width: 800, height: 600))
    corners.flakes.removeAll()
    corners.balls.removeAll()
    corners.nextPlow = .infinity
    corners.setLedges([Ledge(id: "window-corners", rect: roof, spans: [100...400])])
    let roundedRoof = corners.drifts[0]
    roundedRoof.heights = roundedRoof.heights.map { _ in 10 }
    check(roundedRoof.height(at: 100) == 0 && roundedRoof.height(at: 400) == 0 &&
          roundedRoof.height(at: 108) == 5 && roundedRoof.height(at: 116) == 10,
          "roof snow tapers smoothly to zero at physical corners")
    corners.step(1.0 / 60)
    check(roundedRoof.rawHeight(at: 108) < 10 && roundedRoof.height(at: 250) == 10,
          "corners shed gradually without draining the center of the roof")
    check(corners.puffs.contains { $0.snowAmount > 0 && $0.velocity.dx < 0 } &&
          corners.puffs.contains { $0.snowAmount > 0 && $0.velocity.dx > 0 },
          "both corners release material-bearing snow outward")
    roundedRoof.ledge.spans = [150...350]
    corners.puffs.removeAll()
    corners.nextEdgeSpill = 0
    corners.step(1.0 / 60)
    check(corners.puffs.isEmpty && roundedRoof.height(at: 150) == 10,
          "occlusion boundaries are not mistaken for physical window corners")
    for support in ["ground", "window-impact", "dock"] {
        let impact = SnowWorld(size: CGSize(width: 800, height: 600))
        impact.flakes.removeAll()
        impact.nextPlow = .infinity
        if support != "ground" {
            impact.setLedges([Ledge(id: support, rect: CGRect(x: 100, y: 0, width: 600, height: 100), spans: [100...700])])
        }
        let surface = impact.drifts.first { $0.ledge.id == support }!
        surface.heights = surface.heights.map { _ in 0.5 }
        let snowman = Snowball(x: 400, y: surface.ledge.y + 160)
        snowman.radii = [35, 17, 23]
        snowman.dragging = true
        impact.balls = [snowman]
        impact.step(1.0 / 30)
        check(impact.balls.count == 1, "holding a snowman cannot shatter it")
        impact.release(snowman)
        for _ in 0..<120 { impact.step(1.0 / 60) }
        check(impact.balls.isEmpty && surface.height(at: 400) > surface.height(at: 520),
              "dropped snowman breaks into a mound on \(support)")
        let area = surface.heights.enumerated().reduce(CGFloat(0)) { sum, sample in
            sum + (sample.element - 0.5) * min(Drift.spacing, max(0, surface.ledge.rect.width - CGFloat(sample.offset) * Drift.spacing))
        }
        check(abs(area - snowman.snowArea) < 0.001, "shattering preserves the snow area of custom-sized balls")
        let peak = surface.height(at: 400)
        surface.accumulate(at: 400, amount: 1)
        check(surface.height(at: 400) >= peak, "new snowfall cannot flatten a tall impact mound")
        let collected = surface.clear(from: 100, to: 700)
        check(collected >= snowman.snowArea - 0.001, "impact mound is real collectable snow")
    }
    let gentle = SnowWorld(size: CGSize(width: 800, height: 600))
    gentle.flakes.removeAll()
    gentle.nextPlow = .infinity
    let placed = Snowball(x: 400, y: 0)
    placed.radii = [22, 17, 13]
    placed.point.y = gentle.restingHeight(placed, on: gentle.drifts[0]) + 1
    gentle.balls = [placed]
    gentle.release(placed)
    for _ in 0..<60 { gentle.step(1.0 / 60) }
    check(gentle.balls.count == 1 && placed.support == "ground", "gently placing a snowman keeps it intact")
    let contact = SnowWorld(size: CGSize(width: 800, height: 600))
    contact.flakes.removeAll()
    contact.nextPlow = .infinity
    let resting = Snowball(x: 400, y: 100)
    contact.balls = [resting]
    let bed = contact.drifts[0]
    bed.heights = bed.heights.map { _ in 6 }
    bed.heights[bed.index(408)] = 14
    for _ in 0..<240 { contact.step(1.0 / 60) }
    check(resting.point.y > 10 && abs(resting.point.y - contact.restingHeight(resting, on: bed)) < 0.01,
          "rounded ball rests against a nearby snow ridge rather than sinking through it")
    check(resting.spheres[0].minY == 0, "drawn ball bottom matches its physical contact point")
    let snowTop = resting.snowSurface(at: 400)!.y
    let bedBefore = bed.heights
    contact.flakes = [Flake(point: CGPoint(x: 400, y: snowTop + 1), speed: 60, radius: 2, phase: 0)]
    contact.step(1.0 / 30)
    check(resting.snowCaps[0] > 0 && bed.heights == bedBefore && contact.flakes[0].point.y > 600,
          "snowfall lands on the ball without also accumulating underneath")
    check(resting.snowSurface(at: 400)!.y > snowTop && resting.frame.maxY > resting.snowSurface(at: 400)!.y,
          "fresh cap raises collision surface and fits inside character panel")
    contact.flakes.removeAll()
    let capBefore = resting.snowCaps[0]
    contact.puffs = [Puff(point: CGPoint(x: 400, y: resting.snowSurface(at: 400)!.y + 1),
                          velocity: CGVector(dx: 0, dy: -100), life: 3, radius: 2, snowAmount: 12)]
    contact.step(1.0 / 30)
    check(contact.puffs.isEmpty && resting.snowCaps[0] > capBefore, "detached window snow settles on balls too")
    contact.setLedges([Ledge(id: "window-above", rect: CGRect(x: 300, y: 100, width: 200, height: 100), spans: [300...500])])
    let coveredCap = resting.snowCaps[0]
    contact.settleSnow(x: 400, from: 300, to: 0, amount: 1)
    check(resting.snowCaps[0] == coveredCap && contact.drifts[0].height(at: 400) > 0,
          "higher roof intercepts snow before a ball below even in a long step")
    contact.setLedges([])
    contact.puffs.removeAll()
    resting.radii = [22, 17, 13]
    contact.settleSnow(x: 400, from: 150, to: 0, amount: 1)
    contact.settleSnow(x: 419, from: 150, to: 0, amount: 1)
    check(resting.snowCaps[2] > 0 && resting.snowCaps[0] > coveredCap,
          "snowman head and exposed lower shoulders both collect snow")
    let capsBeforeMiss = resting.snowCaps
    contact.settleSnow(x: 440, from: 150, to: 0, amount: 1)
    check(resting.snowCaps == capsBeforeMiss, "snow outside rounded silhouette misses the snowman")
    contact.resetSnow()
    check(resting.snowCaps == [0, 0, 0], "reset also clears snow on characters")
    let cover = CGRect(x: 180, y: 150, width: 80, height: 100)
    check(exposedSpans(of: roof, behind: [cover]) == [100...180, 260...400], "occluded roof splits into two spans")
    check(exposedSpans(of: roof, behind: [roof.insetBy(dx: -10, dy: -10)]).isEmpty, "covered roof has no snow")
    let world = SnowWorld(size: CGSize(width: 800, height: 600))
    world.flakes.removeAll()
    world.balls.removeAll()
    world.nextPlow = .greatestFiniteMagnitude
    world.setLedges([Ledge(id: "roof", rect: roof, spans: [100...400])])
    let ball = Snowball(x: 150, y: 400)
    world.balls = [ball]
    for _ in 0..<240 { world.step(1.0 / 60) }
    check(ball.support == "roof", "falling ball lands on roof instead of tunnelling through")
    check(ball.point.y >= 200 && ball.point.y < 215, "ball rests on snow height")
    let moved = roof.offsetBy(dx: 90, dy: 35)
    world.setLedges([Ledge(id: "roof", rect: moved, spans: [190...490])])
    world.step(1.0 / 60)
    check(abs(ball.point.x - 240) < 1 && ball.point.y > 235, "ball follows moving support")
    world.setLedges([])
    for _ in 0..<240 { world.step(1.0 / 60) }
    check(ball.support == "ground" && ball.point.y < 30, "closing a window drops its snowball to ground")
    ball.point.y = 0
    ball.support = nil
    world.step(1.0 / 60)
    check(ball.support == "ground" && ball.point.y > 0, "releasing inside the ground drift does not bury the ball")
    ball.point = CGPoint(x: 300, y: 12)
    let second = Snowball(x: 300, y: 30)
    world.balls.append(second)
    world.release(second)
    check(world.balls.count == 1 && ball.pieces == 2, "two balls combine")
    let third = Snowball(x: 300, y: 50)
    world.balls.append(third)
    world.release(third)
    check(world.balls.count == 1 && ball.pieces == 3, "three balls create snowman")
    let fourth = Snowball(x: 300, y: 60)
    world.balls.append(fourth)
    world.release(fourth)
    check(world.balls.count == 2, "finished snowman does not swallow extra balls")
    let custom = SnowWorld(size: CGSize(width: 800, height: 600))
    custom.flakes.removeAll()
    custom.nextPlow = .infinity
    let large = Snowball(x: 400, y: 15, radius: 70)
    let small = Snowball(x: 400, y: 130, radius: 12)
    large.snowCaps[0] = 3
    small.snowCaps[0] = 5
    custom.balls = [large, small]
    custom.release(small)
    check(large.radii == [70, 12] && large.spheres.map(\.width) == [140, 24],
          "assembly preserves the exact diameters of large and small snowballs")
    let bigHead = Snowball(x: 400, y: 155, radius: 50)
    custom.balls.append(bigHead)
    custom.release(bigHead)
    check(large.radii == [70, 12, 50] && large.snowCaps == [3, 5, 0],
          "oversized head stays oversized and existing snow caps survive assembly")
    check(large.spheres.allSatisfy { $0.minX >= 0 && $0.maxX <= large.size.width && $0.maxY <= large.size.height },
          "custom snowman fits its interactive panel")
    check(abs(large.snowSurface(at: 400)!.y - (large.point.y + large.spheres[2].maxY)) < 0.01,
          "snow collision follows the actual large head")
    let singleBase = Snowball(x: 400, y: 10, radius: 9)
    custom.balls.append(singleBase)
    // A two-ball stack can also be placed onto a single ball.
    large.radii = [70, 12]
    large.point.y = 12
    custom.release(large)
    check(singleBase.radii == [9, 70, 12] && singleBase.snowCaps == [0, 3, 5],
          "moving a two-ball stack preserves order, sizes and snow on a small base")
    let ground = world.drifts.first!
    ground.accumulate(at: 400, amount: 1000)
    check(ground.height(at: 400) <= 28, "snow height bounded")
    world.plowActive = true
    world.plowX = 400
    world.step(1.0 / 30)
    check(ground.height(at: 400) <= 0.5, "plow clears snow along its path")
    check(world.collectedSnow > 0, "automatic plow transfers cleared snow into its mound")
    let sweep = SnowWorld(size: CGSize(width: 800, height: 600))
    sweep.flakes.removeAll()
    sweep.drifts[0].heights = sweep.drifts[0].heights.map { _ in 10 }
    sweep.startPlow()
    sweep.plowX = -80
    sweep.plowDirection = 1
    sweep.movePlow(to: 100)
    let initialPile = sweep.plowPileSize
    sweep.movePlow(to: 240)
    check(sweep.plowPileSize.width > initialPile.width && sweep.plowPileSize.height > initialPile.height,
          "mound becomes wider and taller when collecting more snow")
    let volume = sweep.collectedSnow
    sweep.movePlow(to: 240)
    sweep.plowDirection = -1
    sweep.movePlow(to: 100)
    check(sweep.collectedSnow == volume, "standing still and reversing over cleared ground do not create snow")
    sweep.plowActive = false
    sweep.startPlow()
    check(sweep.collectedSnow == 0, "new plow trip starts without the previous mound")
    sweep.movePlow(to: 600)
    sweep.resetSnow()
    check(sweep.collectedSnow == 0 && sweep.plowPileSize == .zero, "clear snow also removes the mound")
    let rolling = SnowWorld(size: CGSize(width: 800, height: 600))
    let floor = rolling.drifts[0]
    for direction: CGFloat in [-1, 1] {
        floor.heights = floor.heights.map { _ in 10 }
        let touching = Snowball(x: 400, y: 10, radius: 60)
        let destination: CGFloat = 400 + direction * 32
        rolling.dragBall(touching, to: CGPoint(x: destination, y: 10))
        check(floor.height(at: destination + direction * 24) == 10,
              "rolling preserves snow ahead of the bottom contact in either direction")
        check(floor.height(at: 400 + direction * 16) == 0.5 && touching.radius > 60,
              "rolling still collects snow and grows along the actual contact trail")
    }
    floor.heights = floor.heights.map { _ in 10 }
    let growing = Snowball(x: 100, y: 10)
    rolling.dragBall(growing, to: CGPoint(x: 260, y: 10))
    check(growing.radius > 18 && growing.rotation != 0 && floor.height(at: 200) == 0.5,
          "rolling on ground grows and rotates the ball and leaves a cleared track")
    let grownRadius = growing.radius
    rolling.dragBall(growing, to: growing.point)
    check(growing.radius == grownRadius, "holding a ball still does not grow it")
    rolling.dragBall(growing, to: CGPoint(x: 260, y: 200))
    rolling.dragBall(growing, to: CGPoint(x: 500, y: 200))
    check(growing.radius == grownRadius && floor.height(at: 450) == 10,
          "airborne dragging leaves both ball size and ground unchanged")
    rolling.dragBall(growing, to: CGPoint(x: 500, y: 10))
    check(growing.radius == grownRadius, "lowering a ball does not collect snow crossed in the air")
    rolling.dragBall(growing, to: CGPoint(x: 400, y: 10))
    check(growing.radius > grownRadius, "rolling left also collects fresh snow")
    rolling.resetSnow()
    let beforeEmpty = growing.radius
    rolling.dragBall(growing, to: CGPoint(x: 200, y: 0))
    check(abs(growing.radius - beforeEmpty) < 0.000001, "cleared ground cannot grow the ball")
    growing.radius = 79
    floor.heights = floor.heights.map { _ in 28 }
    rolling.dragBall(growing, to: CGPoint(x: 800, y: 0))
    check(growing.radius <= 80 && growing.frame.maxX <= 800,
          "growth is bounded and keeps the enlarged ball within the display")
    floor.heights = floor.heights.map { _ in 10 }
    growing.radius = 80
    growing.point = CGPoint(x: 300, y: 10)
    growing.rotation = 0
    rolling.dragBall(growing, to: CGPoint(x: 340, y: 16))
    check(growing.point.y == 10 && growing.rotation < 0 && growing.radius == 80,
          "full-size ball still rests on snow and rotates clockwise when rolled right")
    rolling.dragBall(growing, to: CGPoint(x: 350, y: 100))
    check(growing.point.y == 100, "lifting a rolling ball releases its surface contact")
    let round = Snowball(x: 400, y: 10, radius: 25)
    rolling.balls = [round]
    for _ in 0..<30 { rolling.settleSnow(x: 400, from: 200, to: 30, amount: 1) }
    let circle = round.spheres[0]
    check(circle.width == circle.height && round.radius > 25,
          "accumulated snow grows a round sphere rather than stretching its top into an egg")
    check(abs(round.sphereTop(0, x: circle.midX)! - circle.maxY) < 0.001,
          "snow cap stays inside the circular silhouette")
    let waiting = SnowWorld(size: CGSize(width: 800, height: 600))
    waiting.flakes.removeAll()
    waiting.resetSnow()
    waiting.nextPlow = 0
    for _ in 0..<120 { waiting.step(1.0 / 30) }
    check(!waiting.plowActive, "automatic plow stays away from a clean screen even when its timer expires")
    waiting.drifts[0].heights = waiting.drifts[0].heights.map { _ in 3 }
    waiting.step(1.0 / 30)
    check(!waiting.plowActive, "a thin layer does not trigger an automatic plow trip")
    waiting.drifts[0].heights = waiting.drifts[0].heights.map { _ in 9 }
    waiting.step(1.0 / 30)
    check(waiting.plowActive, "enough accumulated snow triggers the automatic plow")
    let clearing = SnowWorld(size: CGSize(width: 800, height: 600))
    clearing.flakes.removeAll()
    clearing.balls.removeAll()
    clearing.nextPlow = .infinity
    let dock = Ledge(id: "dock", rect: CGRect(x: 100, y: 0, width: 400, height: 70), spans: [100...500])
    clearing.setLedges([dock])
    let dockDrift = clearing.drifts.first { $0.ledge.id == "dock" }!
    dockDrift.heights = dockDrift.heights.map { _ in 6 }
    clearing.drifts.first { $0.ledge.isGround }!.heights = clearing.drifts.first { $0.ledge.isGround }!.heights.map { _ in 0.5 }
    clearing.flakes = [Flake(point: CGPoint(x: 180, y: 77), speed: 60, radius: 2, phase: 0)]
    clearing.step(1.0 / 30)
    check(dockDrift.height(at: 180) > 6, "falling snow accumulates on Dock")
    clearing.flakes.removeAll()
    clearing.brushSnow(from: CGPoint(x: 170, y: 72), to: CGPoint(x: 230, y: 72))
    check(dockDrift.height(at: 200) == 0.5 && dockDrift.height(at: 400) == 6 && !clearing.puffs.isEmpty,
          "Dock brushing clears only the swept snow and produces falling clumps")
    let afterBrush = dockDrift.heights
    clearing.brushSnow(from: CGPoint(x: 230, y: 200), to: CGPoint(x: 450, y: 200))
    check(dockDrift.heights == afterBrush, "dragging away from Dock does not clear distant snow")
    for _ in 0..<120 { clearing.step(1.0 / 30) }
    check(clearing.puffs.isEmpty && clearing.drifts.first { $0.ledge.isGround }!.heights.contains { $0 > 0.5 },
          "brushed snow falls under gravity and accumulates below")
    check(zip(dockDrift.heights, afterBrush).allSatisfy { $0 <= $1 } && dockDrift.height(at: 200) == 0.5,
          "brushed snow does not stick back to Dock while its corners continue shedding")

    let shaking = SnowWorld(size: CGSize(width: 800, height: 600))
    shaking.flakes.removeAll()
    shaking.balls.removeAll()
    var movingRoof = Ledge(id: "window-shake", rect: roof, spans: [100...400])
    shaking.setLedges([movingRoof])
    check(shaking.drifts.first { $0.ledge.id == "window-shake" }!.heights.allSatisfy { $0 == 0 },
          "new or rediscovered window starts empty instead of teleporting a prefab snow layer")
    shaking.drifts.first { $0.ledge.id == "window-shake" }!.heights = shaking.drifts.first { $0.ledge.id == "window-shake" }!.heights.map { _ in 5 }
    shaking.elapsed = 0.1
    movingRoof.rect = roof.offsetBy(dx: 4, dy: 0)
    movingRoof.spans = [104...404]
    shaking.setLedges([movingRoof])
    check(shaking.puffs.isEmpty && shaking.drifts.first { $0.ledge.id == "window-shake" }!.height(at: 250) == 5,
          "gentle motion carries the roof snow without dumping the entire layer")
    shaking.elapsed = 0.2
    movingRoof.rect = roof.offsetBy(dx: 80, dy: 0)
    movingRoof.spans = [180...480]
    shaking.setLedges([movingRoof])
    check(!shaking.puffs.isEmpty && shaking.drifts.first { $0.ledge.id == "window-shake" }!.height(at: 250) < 5,
          "flinging a window sheds snow with inertia")
    check(shaking.puffs.allSatisfy { 104...404 ~= $0.point.x && $0.point.y >= roof.maxY },
          "detached snow starts at the original roof, not at the moved window")
    let detachedPositions = shaking.puffs.map(\.point)
    shaking.elapsed = 0.3
    shaking.setLedges([movingRoof])
    check(shaking.puffs.map(\.point) == detachedPositions,
          "moving the window again cannot teleport already detached snow")
    check(shaking.puffs.allSatisfy { $0.snowAmount > 0 && $0.sourceLedge == "window-shake" },
          "shaken snow carries material and remembers the source roof")
    let currentRoof = shaking.drifts.first { $0.ledge.id == "window-shake" }!
    currentRoof.heights = currentRoof.heights.map { _ in 5 }
    shaking.puffs.removeAll()
    movingRoof.rect.size.width = 200
    movingRoof.spans = [180...380]
    shaking.setLedges([movingRoof])
    check(currentRoof.height(at: 250) == 5 && !shaking.puffs.isEmpty &&
          shaking.puffs.allSatisfy { $0.point.x >= 380 },
          "shrinking a window drops only the overhang and preserves snow on the remaining roof")
    movingRoof.rect.size.width = 500
    movingRoof.spans = [180...680]
    shaking.setLedges([movingRoof])
    check(currentRoof.height(at: 250) == 5 && currentRoof.height(at: 550) == 0,
          "expanding a window preserves old snow but does not invent snow on the extension")
    shaking.brushSnow(from: CGPoint(x: 210, y: 202), to: CGPoint(x: 270, y: 202))
    check(currentRoof.height(at: 250) == 0.5 && currentRoof.height(at: 330) == 5,
          "cursor brushes snow from a window as well as Dock")
    let roofBall = Snowball(x: 280, y: 205)
    shaking.dragBall(roofBall, to: CGPoint(x: 350, y: 205))
    check(roofBall.radius > 18 && roofBall.point.y >= 200, "snowballs grow while rolling on window snow")
    let puffCount = shaking.puffs.count
    shaking.setLedges([])
    check(shaking.puffs.count > puffCount, "closing a window releases its remaining snow")
    for _ in 0..<120 { shaking.step(1.0 / 30) }
    check(shaking.puffs.isEmpty, "detached window snow falls and settles instead of following the window")
    let dropping = SnowWorld(size: CGSize(width: 800, height: 600))
    dropping.flakes.removeAll()
    dropping.nextPlow = .infinity
    dropping.setLedges([Ledge(id: "window-drop", rect: roof, spans: [100...400]), dock])
    let fallingBall = Snowball(x: 250, y: 210)
    dropping.balls = [fallingBall]
    let closedRoof = dropping.drifts.first { $0.ledge.id == "window-drop" }!
    closedRoof.heights = closedRoof.heights.map { _ in 5 }
    dropping.setLedges([dock])
    for _ in 0..<240 { dropping.step(1.0 / 60) }
    check(fallingBall.support == "dock" && fallingBall.point.y >= 70,
          "a snowball on a closed window falls and lands on Dock")
    fallingBall.support = nil
    fallingBall.point.y = 73
    fallingBall.velocity = CGVector(dx: 0, dy: -20)
    let thickDock = dropping.drifts.first { $0.ledge.id == "dock" }!
    thickDock.heights = thickDock.heights.map { _ in 12 }
    dropping.step(1.0 / 60)
    check(fallingBall.support == "dock" && fallingBall.point.y >= 82,
          "a drift growing around an airborne ball catches it instead of letting it tunnel through")
    let dockBall = Snowball(x: 350, y: 76)
    dropping.dragBall(dockBall, to: CGPoint(x: 420, y: 76))
    check(dockBall.radius > 18, "snowballs also grow from snow on Dock")
    let wide = SnowWorld(size: CGSize(width: 4000, height: 1000))
    var wideRoof = Ledge(id: "window-wide", rect: CGRect(x: 0, y: 100, width: 3500, height: 200), spans: [0...3500])
    wide.setLedges([wideRoof])
    wide.drifts.first { $0.ledge.id == "window-wide" }!.heights = wide.drifts.first { $0.ledge.id == "window-wide" }!.heights.map { _ in 5 }
    wide.burst(at: .zero, count: 250)
    wideRoof.rect.origin.x += 100
    wideRoof.spans = [100...3600]
    wide.setLedges([wideRoof])
    check(wide.drifts.first { $0.ledge.id == "window-wide" }!.heights.allSatisfy { $0 <= 0.5 } &&
          abs(wide.puffs.reduce(CGFloat(0)) { $0 + $1.snowAmount } - 3500 * 4.5) < 0.001,
          "wide roof sheds its entire snow mass even when decorative particle slots are full")

    let bulldozer = SnowWorld(size: CGSize(width: 800, height: 600))
    bulldozer.resetSnow()
    let victim = Snowball(x: 250, y: 8); victim.radii = [22, 17, 13]
    let elevated = Snowball(x: 250, y: 100); elevated.radii = [22, 17, 13]
    let held = Snowball(x: 350, y: 8); held.radii = [22, 17, 13]; held.dragging = true
    bulldozer.balls = [victim, elevated, held]
    bulldozer.plowActive = true
    bulldozer.plowX = 100
    bulldozer.movePlow(to: 500)
    check(!bulldozer.balls.contains { $0 === victim } && bulldozer.collectedSnow > 0,
          "fast plow sweep removes a ground snowman and adds it to the pile")
    check(bulldozer.balls.contains { $0 === elevated } && bulldozer.balls.contains { $0 === held },
          "plow leaves elevated snowmen and the dragged character alone")
    let fromSnowman = bulldozer.collectedSnow
    bulldozer.movePlow(to: 100)
    check(bulldozer.collectedSnow == fromSnowman, "snowman material is collected only once")
    held.dragging = false
    bulldozer.plowDirection = -1
    bulldozer.plowX = 500
    bulldozer.movePlow(to: 100)
    check(!bulldozer.balls.contains { $0 === held }, "plow removes snowmen while moving left as well")
    for _ in 0..<40 { world.addBall() }
    check(world.balls.count == 6, "character count bounded")
    let arrivals = SnowWorld(size: CGSize(width: 800, height: 600))
    arrivals.flakes.removeAll()
    arrivals.nextPlow = .infinity
    arrivals.nextBallDrop = 0
    arrivals.step(1.0 / 60, allowNewBall: true)
    let newcomer = arrivals.balls[0]
    check((10...14).contains(newcomer.radius) && newcomer.point.y > arrivals.size.height,
          "automatic snowballs arrive small from above the display")
    for _ in 0..<180 { arrivals.step(1.0 / 60) }
    check(arrivals.balls.count == 1 && newcomer.support == "ground" && newcomer.velocity.dy == 0,
          "a new sky snowball survives its first landing and remains available to roll")
    let arrivalGround = arrivals.drifts[0]
    arrivalGround.heights = arrivalGround.heights.map { _ in 10 }
    newcomer.dragging = true
    let initialRadius = newcomer.radius
    arrivals.dragBall(newcomer, to: CGPoint(x: 400, y: 10))
    arrivals.dragBall(newcomer, to: CGPoint(x: 500, y: 10))
    check(newcomer.radius > initialRadius, "sky snowballs can be rolled into larger balls")
    arrivals.dragBall(newcomer, to: CGPoint(x: 500, y: 250))
    arrivals.release(newcomer)
    for _ in 0..<180 { arrivals.step(1.0 / 60) }
    check(arrivals.balls.isEmpty && arrivalGround.height(at: 500) > 10,
          "lifting and dropping a single snowball shatters it into a real drift")
    let otherDisplay = SnowWorld(size: CGSize(width: 800, height: 600))
    for _ in 0..<10 {
        for sceneWorld in [arrivals, otherDisplay] {
            sceneWorld.nextBallDrop = 0
            sceneWorld.step(1.0 / 60, allowNewBall: arrivals.balls.count + otherDisplay.balls.count < 6)
        }
    }
    check(arrivals.balls.count + otherDisplay.balls.count == 6, "automatic arrivals obey a six-character budget across displays")
    arrivals.balls.removeLast()
    arrivals.nextBallDrop = 0
    arrivals.step(1.0 / 60, allowNewBall: true)
    check(arrivals.balls.count + otherDisplay.balls.count == 6, "automatic arrivals replenish a vacant slot")
    let cleanup = SnowWorld(size: CGSize(width: 800, height: 600))
    for direction: CGFloat in [-1, 1] {
        let mound = SnowWorld(size: CGSize(width: 800, height: 600))
        mound.flakes.removeAll()
        mound.resetSnow()
        mound.plowActive = true
        mound.plowX = 400
        mound.plowDirection = direction
        mound.collectedSnow = 2000
        let touchingPile = Snowball(x: 400 + direction * 98, y: 3, radius: 10)
        let aboveSlope = Snowball(x: 400 + direction * 118, y: 30, radius: 6)
        check(mound.touchesPlowPile(touchingPile, from: 400, to: 400),
              "snowball contacts the visible mound ahead of the blade in either direction")
        check(!mound.touchesPlowPile(aboveSlope, from: 400, to: 400),
              "empty space above the mound slope is not a collision")
        mound.balls = [touchingPile]
        mound.movePlow(to: 400)
        check(mound.balls.isEmpty && abs(mound.collectedSnow - 2000 - touchingPile.snowArea) < 0.001,
              "mound collects a touching ball before the blade reaches it and adds its material once")
        mound.collectedSnow = 8000
        let elevatedContact = Snowball(x: 400, y: 55, radius: 12)
        check(mound.touchesPlowPile(elevatedContact, from: 400 - direction * 200, to: 400 + direction * 200),
              "fast motion sweeps the entire mound across a ball above blade height")
    }
    cleanup.flakes.removeAll()
    cleanup.resetSnow()
    let loose = Snowball(x: 250, y: 1)
    let heldLoose = Snowball(x: 300, y: 1)
    heldLoose.dragging = true
    cleanup.balls = [loose, heldLoose]
    cleanup.plowActive = true
    cleanup.plowX = 100
    cleanup.movePlow(to: 400)
    check(cleanup.balls.count == 1 && cleanup.balls[0] === heldLoose && abs(cleanup.collectedSnow - loose.snowArea) < 0.001,
          "plow collects loose snowballs into its mound while leaving held balls alone")
    world.burst(at: .zero, count: 1000)
    check(world.puffs.count <= 250, "particle count bounded")
    let elapsed = world.elapsed
    world.step(300)
    check(world.elapsed - elapsed < 0.07, "wake after sleep cannot advance physics by minutes")
    print("PASS: \(checks) physics, occlusion and resource-bound checks")
}

func smokeTest(_ delegate: AppDelegate) {
    let savedOnlySnow = delegate.snowfallOnly
    if savedOnlySnow { delegate.toggleSnowfallOnly() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
        let scenes = delegate.scenes
        let savedRate = delegate.accumulationRate
        let testRate: Double = savedRate == 3.7 ? 5.2 : 3.7
        delegate.accumulationSlider.doubleValue = testRate
        delegate.accumulationSlider.sendAction(delegate.accumulationSlider.action, to: delegate.accumulationSlider.target)
        let settingWorks = scenes.allSatisfy { $0.world.accumulationRate == CGFloat(testRate) } &&
            UserDefaults.standard.double(forKey: "accumulationRate") == testRate &&
            delegate.accumulationLabel.stringValue.contains(String(format: "%.1f", testRate)) &&
            delegate.accumulationSlider.isContinuous && delegate.accumulationSlider.superview != nil
        delegate.accumulationSlider.doubleValue = savedRate
        delegate.changeAccumulation(delegate.accumulationSlider)
        guard settingWorks else { fputs("FAIL: accumulation setting must update all displays, menu and saved preference\n", stderr); exit(1) }
        print("PASS: continuous accumulation slider applies and saves fractional rates with a live label")
        let savedTransport = delegate.useTractor
        let transportScene = scenes[0]
        transportScene.world.plowActive = true
        transportScene.world.plowX = 300
        transportScene.world.collectedSnow = 1234
        delegate.changeTransport(delegate.transportMenu.item(withTag: 1)!)
        let tractorWorks = scenes.allSatisfy { $0.world.useTractor } &&
            transportScene.plow?.frame.width == 80 && UserDefaults.standard.bool(forKey: "useTractor") &&
            delegate.transportMenu.items.filter { $0.state == .on }.map(\.tag) == [1]
        delegate.changeTransport(delegate.transportMenu.item(withTag: 0)!)
        let trainWorks = scenes.allSatisfy { !$0.world.useTractor } &&
            (transportScene.plow?.frame.width ?? 0) > 80 && transportScene.world.collectedSnow == 1234 &&
            transportScene.world.plowX == 300 && !UserDefaults.standard.bool(forKey: "useTractor")
        delegate.changeTransport(delegate.transportMenu.item(withTag: savedTransport ? 1 : 0)!)
        guard tractorWorks && trainWorks else { fputs("FAIL: transport switch must update panels and preserve snow\n", stderr); exit(1) }
        print("PASS: saved transport choice applies on all displays and resizes an active vehicle without losing snow")
        let savedFlakes = delegate.crystalFlakes
        let flakeCounts = scenes.map { $0.world.flakes.count }
        let driftHeights = scenes.map { $0.world.drifts.map(\.heights) }
        delegate.changeSnowflakes(delegate.snowflakeMenu.item(withTag: 1)!)
        let flakesWork = scenes.allSatisfy { $0.world.crystalFlakes } &&
            UserDefaults.standard.bool(forKey: "crystalFlakes") &&
            delegate.snowflakeMenu.items.filter { $0.state == .on }.map(\.tag) == [1] &&
            scenes.map({ $0.world.flakes.count }) == flakeCounts &&
            scenes.map({ $0.world.drifts.map(\.heights) }) == driftHeights
        delegate.changeSnowflakes(delegate.snowflakeMenu.item(withTag: savedFlakes ? 1 : 0)!)
        guard flakesWork else { fputs("FAIL: snowflake style must update and persist without resetting snow\n", stderr); exit(1) }
        print("PASS: saved snowflake style updates all displays without changing accumulated snow")
        let savedSize = delegate.snowflakeSize
        var sizesWork = true
        for size in [50, 100, 137, 200] {
            delegate.snowflakeSizeSlider.doubleValue = Double(size)
            delegate.snowflakeSizeSlider.sendAction(delegate.snowflakeSizeSlider.action, to: delegate.snowflakeSizeSlider.target)
            sizesWork = sizesWork && scenes.allSatisfy { $0.world.snowflakeScale == CGFloat(size) / 100 } &&
                UserDefaults.standard.integer(forKey: "snowflakeSize") == size &&
                delegate.snowflakeSizeLabel.stringValue.contains("\(size)%") &&
                delegate.snowflakeSizeSlider.isContinuous && delegate.snowflakeSizeSlider.superview != nil
        }
        delegate.snowflakeSizeSlider.doubleValue = Double(savedSize)
        delegate.changeSnowflakeSize(delegate.snowflakeSizeSlider)
        guard sizesWork && scenes.map({ $0.world.drifts.map(\.heights) }) == driftHeights else {
            fputs("FAIL: snowflake size must persist and update all displays without changing drifts\n", stderr); exit(1)
        }
        print("PASS: continuous size slider applies intermediate values and endpoints without changing accumulation")
        let savedEnglish = L10n.english
        let positionsBeforeLanguage = scenes.map { $0.world.balls.map(\.point) }
        delegate.changeLanguage(delegate.languageMenu.item(withTag: 1)!)
        func englishMenu(_ menu: NSMenu) -> Bool {
            menu.items.allSatisfy { item in
                let titleOK = item.title == "Русский" || !item.title.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
                return titleOK && (item.submenu.map(englishMenu) ?? true)
            }
        }
        let englishWorks = englishMenu(delegate.statusItem.menu!) &&
            L10n.help.contains(L10n.accessibilityNotice) &&
            L10n.accessibilityNotice.contains("not limited to Dock") &&
            delegate.snowfallOnlyItem.title == "Disable snow accumulation" &&
            delegate.accumulationLabel.stringValue.hasPrefix("Accumulation speed:") &&
            delegate.snowflakeSizeLabel.stringValue.hasPrefix("Snowflake size:") &&
            L10n.help.hasPrefix("Drag snowballs") && UserDefaults.standard.string(forKey: "language") == "en"
        delegate.changeLanguage(delegate.languageMenu.item(withTag: 0)!)
        let russianWorks = delegate.snowfallOnlyItem.title == "Отключить сугробы" &&
            L10n.help.contains(L10n.accessibilityNotice) &&
            L10n.accessibilityNotice.contains("не ограничено Dock") &&
            delegate.accumulationLabel.stringValue.hasPrefix("Скорость накопления:") && L10n.help.hasPrefix("Перетаскивай")
        delegate.changeLanguage(delegate.languageMenu.item(withTag: savedEnglish ? 1 : 0)!)
        guard englishWorks && russianWorks && scenes.map({ $0.world.balls.map(\.point) }) == positionsBeforeLanguage else {
            fputs("FAIL: language switching must translate menus, sliders and help without resetting the scene\n", stderr); exit(1)
        }
        print("PASS: Russian/English switches live, persists and translates menus, sliders and help")
        let savedInfernal = delegate.infernalMode
        let preservedPositions = scenes.map { $0.world.balls.map(\.point) }
        let preservedPiles = scenes.map { $0.world.collectedSnow }
        delegate.toggleInfernalMode()
        let infernalWorks = scenes.allSatisfy { $0.world.infernalMode == !savedInfernal } &&
            UserDefaults.standard.bool(forKey: "infernalMode") == !savedInfernal &&
            delegate.infernalItem.state == (!savedInfernal ? .on : .off) &&
            scenes.map({ $0.world.balls.map(\.point) }) == preservedPositions &&
            scenes.map({ $0.world.collectedSnow }) == preservedPiles
        delegate.toggleInfernalMode()
        guard infernalWorks else { fputs("FAIL: infernal theme must persist and preserve the physical scene\n", stderr); exit(1) }
        print("PASS: infernal theme toggles on all displays, persists and preserves snow and characters")
        guard !scenes.isEmpty, scenes.allSatisfy({
            return $0.overlay.isVisible && $0.overlay.ignoresMouseEvents && !$0.overlay.canBecomeKey &&
            $0.characters.count == $0.world.balls.count &&
            $0.characters.values.allSatisfy { $0.isVisible && !$0.ignoresMouseEvents && !$0.canBecomeKey } &&
            $0.world.elapsed > 0.5
        }) else { fputs("FAIL: live overlay smoke test\n", stderr); exit(1) }
        print("PASS: overlays on all \(scenes.count) displays animate and preserve input behavior, including fullscreen Spaces")
        print("Tracked roofs: \(scenes.map { $0.world.drifts.filter { !$0.ledge.isGround }.count })")
        let dockCount = scenes.filter { $0.world.drifts.contains { $0.ledge.id == "dock" } }.count
        print("Dock accessibility: \(AXIsProcessTrusted()); tracked Dock surfaces: \(dockCount)")
        for scene in scenes {
            let screenTop = NSScreen.screens.first { $0.frame == scene.frame }!.visibleFrame.maxY
            let ceiling = min(scene.frame.maxY - 20, screenTop - 1) - scene.frame.minY
            guard scene.world.drifts.filter({ $0.ledge.id.hasPrefix("window-") }).allSatisfy({
                $0.ledge.rect.height > 40 && $0.ledge.y < ceiling
            }) else { fputs("FAIL: hidden top bars must not support snowballs\n", stderr); exit(1) }
            if scene.world.drifts.allSatisfy({ $0.ledge.isGround }) {
                guard !scene.world.balls.isEmpty, scene.world.balls.allSatisfy({ $0.point.y < scene.frame.height / 2 }) else {
                    fputs("FAIL: sky snowballs stuck near the top of an unobstructed display\n", stderr); exit(1)
                }
            }
            let entering = Snowball(x: scene.frame.width / 2, y: scene.frame.height + 40, radius: 12)
            scene.world.balls.append(entering)
            scene.syncCharacters()
            let expected = entering.frame.offsetBy(dx: scene.frame.minX, dy: scene.frame.minY)
            guard scene.characters[entering.id]!.frame == expected else {
                fputs("FAIL: character panel pinned to screen edge instead of physics position\n", stderr); exit(1)
            }
            scene.world.balls.removeAll { $0 === entering }
            scene.syncCharacters()
        }
        print("PASS: hidden menu/tool bars excluded; entering snowball panels keep exact physics coordinates on both displays")
        let scene = scenes[0]
        scene.world.setLedges([Ledge(id: "dock", rect: CGRect(x: 100, y: 0, width: 300, height: 70), spans: [100...400])])
        scene.syncCharacters()
        scene.brush(from: CGPoint(x: scene.frame.minX + 140, y: scene.frame.minY + 72),
                    to: CGPoint(x: scene.frame.minX + 170, y: scene.frame.minY + 72))
        guard scene.world.drifts.first(where: { $0.ledge.id == "dock" })!.height(at: 150) == 0.5 else {
            fputs("FAIL: cursor brush in screen coordinates\n", stderr); exit(1)
        }
        scene.setVisible(false)
        guard !scene.overlay.isVisible && scene.overlay.ignoresMouseEvents else {
            fputs("FAIL: brush overlay must remain click-through and obey pause\n", stderr); exit(1)
        }
        print("PASS: cursor brush in display coordinates, no input-stealing Dock panel, pause hides effects")
        scene.setVisible(true)
        delegate.toggleSnowfallOnly()
        let addSnowballItem = delegate.statusItem.menu!.items.first { $0.action == #selector(AppDelegate.addBall) }!
        delegate.statusItem.menu!.update()
        let addDisabled = !addSnowballItem.isEnabled
        let onlySnowWorks = scenes.allSatisfy {
            $0.world.snowfallOnly && $0.overlay.isVisible &&
                $0.characters.values.allSatisfy { !$0.isVisible } && $0.plow?.isVisible != true
        } && UserDefaults.standard.bool(forKey: "snowfallOnly") && delegate.snowfallOnlyItem.state == .on
        delegate.toggleSnowfallOnly()
        delegate.statusItem.menu!.update()
        guard onlySnowWorks && addDisabled && addSnowballItem.isEnabled else {
            fputs("FAIL: snowfall-only must hide extras and disable adding snowballs until restored\n", stderr); exit(1)
        }
        print("PASS: saved snowfall-only mode hides extras and restores the scene")
        let image = NSImage(size: NSSize(width: 600, height: 500))
        image.lockFocus()
        let crystalPreview = SnowWorld(size: CGSize(width: 600, height: 500))
        crystalPreview.crystalFlakes = true
        crystalPreview.flakes = [0.65, 1.5, 2.4].enumerated().map { i, radius in
            Flake(point: CGPoint(x: 40 + i * 30, y: 160), speed: 30, radius: CGFloat(radius), phase: 0.3)
        }
        drawWinter(crystalPreview)
        crystalPreview.infernalMode = true
        crystalPreview.plowActive = true
        crystalPreview.collectedSnow = 2000
        crystalPreview.plowX = 250
        for tractor in [false, true] {
            crystalPreview.useTractor = tractor
            drawWinter(crystalPreview)
        }
        crystalPreview.infernalMode = false
        for crystals in [false, true] {
            crystalPreview.crystalFlakes = crystals
            for scale: CGFloat in [0.5, 2] {
                crystalPreview.snowflakeScale = scale
                drawWinter(crystalPreview)
            }
        }
        crystalPreview.plowActive = true
        crystalPreview.collectedSnow = 4000
        crystalPreview.plowX = 250
        crystalPreview.useTractor = true
        drawWinter(crystalPreview)
        crystalPreview.snowfallOnly = true
        drawWinter(crystalPreview)
        drawTractor(in: CGRect(x: 0, y: 60, width: 80, height: 50), direction: 1, time: 0.25, wheelAngle: 1)
        drawTractor(in: CGRect(x: 100, y: 60, width: 80, height: 50), direction: -1, time: 0.75, wheelAngle: 2)
        drawTractor(in: CGRect(x: 200, y: 60, width: 80, height: 50), direction: -1, time: 0.75, wheelAngle: 2, infernal: true)
        drawPlow(in: CGRect(x: 200, y: 200, width: 380, height: 50), direction: -1, time: 0.75, carriageCount: 5,
                 load: 1, fire: 1, wheelAngle: 1.5, infernal: true)
        drawPlow(in: CGRect(x: 0, y: 0, width: 140, height: 50), direction: 1, time: 0.25, carriageCount: 1,
                 load: 0, fire: 0, wheelAngle: 0.5)
        drawPlow(in: CGRect(x: 200, y: 0, width: 380, height: 50), direction: -1, time: 0.75, carriageCount: 5,
                 load: 1, fire: 1, wheelAngle: 1.5)
        for radii: [CGFloat] in [[30.001], [70.123, 12.789, 30.002], [9.234, 79.999, 14.567]] {
            let ball = Snowball(x: 100, y: 0)
            ball.radii = radii
            ball.snowCaps = [4, 5, 6]
            drawSnowball(ball, in: ball.frame)
            ball.rotation = .pi / 4
            drawSnowball(ball, in: ball.frame, infernal: true)
        }
        image.unlockFocus()
        print("PASS: fractional-radius snowballs and snowmen render their snow caps without crashing")
        if savedOnlySnow { delegate.toggleSnowfallOnly() }
        NSApp.terminate(nil)
    }
}

func renderPreview(to path: String) throws {
    let size = CGSize(width: 1100, height: 700)
    let world = SnowWorld(size: size)
    world.crystalFlakes = true
    world.infernalMode = UserDefaults.standard.bool(forKey: "infernalMode")
    world.useTractor = UserDefaults.standard.bool(forKey: "useTractor")
    let roof = CGRect(x: 560, y: 220, width: 440, height: 260)
    let dock = CGRect(x: 330, y: 14, width: 400, height: 58)
    world.setLedges([Ledge(id: "preview-window", rect: roof, spans: [560...1000]),
                     Ledge(id: "preview-dock", rect: dock, spans: [330...730])])
    world.balls = [Snowball(x: 505, y: 75), Snowball(x: 710, y: 484), Snowball(x: 820, y: 10)]
    world.balls[0].radii = [36, 17, 25]
    for (i, ball) in world.balls.enumerated() {
        ball.point.y = world.restingHeight(ball, on: world.drifts.first {
            $0.ledge.id == (i == 0 ? "preview-dock" : i == 1 ? "preview-window" : "ground")
        }!)
        ball.snowCaps = i == 0 ? [2, 3, 6] : [5, 0, 0]
    }
    world.plowActive = true
    world.plowX = 260
    world.collectedSnow = 18000
    let image = NSImage(size: size)
    image.lockFocus()
    NSGradient(starting: NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.23, alpha: 1),
               ending: NSColor(calibratedRed: 0.15, green: 0.27, blue: 0.39, alpha: 1))!
        .draw(in: CGRect(origin: .zero, size: size), angle: 90)
    rounded(roof, radius: 12, color: NSColor(calibratedWhite: 0.12, alpha: 1))
    rounded(CGRect(x: roof.minX, y: roof.maxY - 40, width: roof.width, height: 40), radius: 10,
            color: NSColor(calibratedWhite: 0.19, alpha: 1))
    for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        ellipse(CGRect(x: roof.minX + 16 + CGFloat(i) * 20, y: roof.maxY - 25, width: 12, height: 12), color)
    }
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.white]
    ("Твои окна и обои остаются на месте" as NSString).draw(at: CGPoint(x: 590, y: 350), withAttributes: attributes)
    rounded(dock, radius: 14, color: NSColor.white.withAlphaComponent(0.14))
    for i in 0..<7 {
        rounded(CGRect(x: dock.minX + 15 + CGFloat(i) * 53, y: 24, width: 38, height: 38), radius: 9,
                color: NSColor(calibratedHue: CGFloat(i) / 8, saturation: 0.55, brightness: 0.85, alpha: 1))
    }
    ("WINTER DESKTOP" as NSString).draw(at: CGPoint(x: 64, y: 595), withAttributes: [
        .font: NSFont.systemFont(ofSize: 34, weight: .light), .foregroundColor: NSColor.white])
    ("Снег • снежки • снеговик • снегоуборочный транспорт" as NSString)
        .draw(at: CGPoint(x: 65, y: 561), withAttributes: attributes)
    drawWinter(world)
    for ball in world.balls { drawSnowball(ball, in: ball.frame, infernal: world.infernalMode) }
    if world.useTractor {
        drawTractor(in: world.trainFrame, direction: 1, time: world.elapsed,
                    wheelAngle: world.trainWheelAngle, infernal: world.infernalMode)
    } else {
        drawPlow(in: world.trainFrame, direction: 1, time: world.elapsed, carriageCount: world.carriageCount,
                 load: world.trainLoad, fire: world.infernalMode ? 1 : world.trainFireIntensity,
                 wheelAngle: world.trainWheelAngle, infernal: world.infernalMode)
    }
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "WinterDesktop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Preview rendering failed"])
    }
    try png.write(to: URL(fileURLWithPath: path))
    print("Preview: \(path)")
}

