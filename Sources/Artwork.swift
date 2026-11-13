import AppKit

private let bloodRed = NSColor(calibratedRed: 0.8, green: 0.025, blue: 0.055, alpha: 1)
private let bloodDark = NSColor(calibratedRed: 0.18, green: 0.005, blue: 0.02, alpha: 1)

func drawEmberFlame(at point: CGPoint, size: CGFloat, time: CGFloat) {
    for (scale, color) in [(CGFloat(1), NSColor.systemOrange), (CGFloat(0.55), NSColor.systemYellow)] {
        let height = size * scale * (1 + 0.2 * sin(time * 19 + point.x))
        let flame = NSBezierPath()
        flame.move(to: CGPoint(x: point.x - size * scale * 0.3, y: point.y))
        flame.curve(to: CGPoint(x: point.x + sin(time * 13) * scale, y: point.y + height),
                    controlPoint1: CGPoint(x: point.x - size * scale * 0.6, y: point.y + height * 0.4),
                    controlPoint2: CGPoint(x: point.x, y: point.y + height * 0.6))
        flame.line(to: CGPoint(x: point.x + size * scale * 0.3, y: point.y))
        flame.close()
        color.setFill(); flame.fill()
    }
}

func drawBurningSkull(in rect: CGRect, time: CGFloat) {
    rounded(rect, radius: 2, color: bloodDark)
    for x in [rect.midX - 3, rect.midX + 3] {
        drawEmberFlame(at: CGPoint(x: x, y: rect.midY), size: rect.height * 0.65, time: time)
    }
    ellipse(CGRect(x: rect.midX - 4, y: rect.minY + 3, width: 8, height: 7), .white)
    rounded(CGRect(x: rect.midX - 2.5, y: rect.minY + 1.5, width: 5, height: 4), radius: 1, color: .white)
    for x in [rect.midX - 2.7, rect.midX + 0.7] {
        ellipse(CGRect(x: x, y: rect.minY + 5, width: 2, height: 2), .black)
    }
    for x in [rect.midX - 1, rect.midX + 1] {
        line(CGPoint(x: x, y: rect.minY + 1.5), CGPoint(x: x, y: rect.minY + 3), color: .black, width: 0.6)
    }
}

func ellipse(_ rect: CGRect, _ color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func rounded(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func line(_ from: CGPoint, _ to: CGPoint, color: NSColor, width: CGFloat = 1) {
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: from)
    path.line(to: to)
    path.lineWidth = width
    path.lineCapStyle = .round
    path.stroke()
}

func snowSphere(_ rect: CGRect, rotation: CGFloat = 0) {
    let path = NSBezierPath(ovalIn: rect)
    NSGradient(colors: [NSColor.white, NSColor(calibratedRed: 0.91, green: 0.96, blue: 1, alpha: 1),
         NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.86, alpha: 1)])!
        .draw(in: path, relativeCenterPosition: NSPoint(x: -0.35, y: 0.45))
    for i in 0..<12 {
        let angle = CGFloat(i) * 2.4 + rotation
        let distance = rect.width * (0.12 + CGFloat(i % 3) * 0.09)
        ellipse(CGRect(x: rect.midX + cos(angle) * distance,
                       y: rect.midY + sin(angle) * distance, width: 1.2, height: 1.2),
                NSColor(calibratedWhite: 0.5, alpha: 0.15))
    }
}

func drawSkull(in rect: CGRect, rotation: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: rotation * 180 / .pi)
    transform.scaleX(by: rect.width / 40, yBy: rect.height / 40)
    transform.translateX(by: -20, yBy: -20)
    transform.concat()
    let bone = NSColor(calibratedRed: 0.84, green: 0.81, blue: 0.73, alpha: 1)
    ellipse(CGRect(x: 2, y: 8, width: 36, height: 32), bone)
    ellipse(CGRect(x: 6, y: 14, width: 29, height: 25), NSColor(calibratedWhite: 0.94, alpha: 1))
    rounded(CGRect(x: 10, y: 0, width: 20, height: 17), radius: 5, color: bone)
    for x: CGFloat in [8, 24] {
        ellipse(CGRect(x: x, y: 17, width: 9, height: 11), NSColor(calibratedWhite: 0.08, alpha: 1))
    }
    let nose = NSBezierPath()
    nose.move(to: CGPoint(x: 20, y: 17))
    nose.line(to: CGPoint(x: 16.5, y: 11))
    nose.line(to: CGPoint(x: 23.5, y: 11))
    nose.close()
    NSColor.darkGray.setFill(); nose.fill()
    line(CGPoint(x: 12, y: 7), CGPoint(x: 28, y: 7), color: .darkGray, width: 1)
    for x: CGFloat in [14, 18, 22, 26] {
        line(CGPoint(x: x, y: 3), CGPoint(x: x, y: 10), color: .darkGray, width: 0.8)
    }
}

func drawSnowball(_ ball: Snowball, in destination: CGRect, infernal: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let transform = NSAffineTransform()
    transform.translateX(by: destination.minX, yBy: destination.minY)
    transform.concat()
    let rect = CGRect(origin: .zero, size: destination.size)
    let cx = rect.midX
    if infernal {
        for sphere in ball.spheres {
            drawSkull(in: sphere, rotation: ball.pieces == 1 ? ball.rotation : 0)
        }
        return
    }
    for (index, sphere) in ball.spheres.enumerated() {
        snowSphere(sphere, rotation: ball.pieces == 1 ? ball.rotation : 0)
        guard ball.snowCaps[index] > 0 else { continue }
        let cap = NSBezierPath()
        cap.move(to: CGPoint(x: sphere.minX, y: sphere.midY))
        for x in stride(from: sphere.minX, through: sphere.maxX, by: 1) {
            cap.line(to: CGPoint(x: x, y: ball.sphereTop(index, x: x)!))
        }
        for x in stride(from: sphere.maxX, through: sphere.minX, by: -1) {
            cap.line(to: CGPoint(x: x, y: ball.sphereTop(index, x: x, snowy: false)! - 1))
        }
        cap.close()
        NSColor.white.setFill(); cap.fill()
    }
    if ball.pieces == 1 {
        return
    }
    guard ball.pieces >= 3 else { return }
    let coal = NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.24, alpha: 1)
    let head = ball.spheres[2], middle = ball.spheres[1], base = ball.spheres[0]
    NSGraphicsContext.saveGraphicsState()
    let face = NSAffineTransform()
    face.translateX(by: head.midX, yBy: head.minY)
    face.scale(by: head.width / 26)
    face.concat()
    for x: CGFloat in [-5, 4] { ellipse(CGRect(x: x, y: 14, width: 2.6, height: 2.6), coal) }
    for i in 0..<5 {
        let angle = CGFloat(i) * .pi / 6 + .pi * 7 / 6
        ellipse(CGRect(x: cos(angle) * 7, y: 11 + sin(angle) * 5, width: 1.5, height: 1.5), coal)
    }
    let carrot = NSBezierPath()
    carrot.move(to: CGPoint(x: 0, y: 12))
    carrot.line(to: CGPoint(x: 12, y: 9))
    carrot.line(to: CGPoint(x: 0, y: 8))
    carrot.close()
    NSColor.systemOrange.setFill(); carrot.fill()
    NSGraphicsContext.restoreGraphicsState()
    let scarfWidth = min(head.width, middle.width) * 0.9
    let scarfHeight = scarfWidth / 6
    rounded(CGRect(x: cx - scarfWidth / 2, y: head.minY + scarfHeight / 2,
                   width: scarfWidth, height: scarfHeight), radius: 2,
            color: NSColor(calibratedRed: 0.83, green: 0.17, blue: 0.23, alpha: 1))
    rounded(CGRect(x: cx + scarfWidth / 4, y: head.minY - middle.height * 0.3,
                   width: scarfHeight, height: middle.height * 0.3 + scarfHeight), radius: 2, color: .systemRed)
    for y in [middle.midY - middle.height * 0.15, middle.midY + middle.height * 0.15, base.midY] {
        ellipse(CGRect(x: cx - 1.8, y: y, width: 3.6, height: 3.6), coal)
    }
    line(CGPoint(x: middle.minX + 2, y: middle.midY), CGPoint(x: 1, y: middle.midY + middle.height * 0.25), color: .brown, width: 2)
    line(CGPoint(x: middle.maxX - 2, y: middle.midY), CGPoint(x: rect.maxX - 1, y: middle.midY + middle.height * 0.2), color: .brown, width: 2)
}

func drawTractor(in rect: CGRect, direction: CGFloat, time: CGFloat, wheelAngle: CGFloat, infernal: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let transform = NSAffineTransform()
    transform.translateX(by: rect.minX, yBy: rect.minY)
    if direction < 0 {
        transform.translateX(by: rect.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
    }
    transform.concat()
    let paint = infernal ? NSColor.darkGray : NSColor(calibratedRed: 1, green: 0.44, blue: 0.06, alpha: 1)
    rounded(CGRect(x: 3, y: 12, width: 59, height: 6), radius: 2, color: .darkGray)
    let hopper = NSBezierPath()
    hopper.move(to: CGPoint(x: 5, y: 37))
    hopper.line(to: CGPoint(x: 31, y: 37))
    hopper.line(to: CGPoint(x: 28, y: 20))
    hopper.line(to: CGPoint(x: 10, y: 20))
    hopper.close()
    NSGradient(starting: infernal ? .black : paint, ending: infernal ? .darkGray : .systemYellow)!.draw(in: hopper, angle: 90)
    rounded(CGRect(x: 3, y: 36, width: 30, height: 3), radius: 1, color: .lightGray)
    for x: CGFloat in [12, 23] {
        line(CGPoint(x: x, y: 22), CGPoint(x: x - 1, y: 35), color: paint, width: 2)
    }
    let cab = NSBezierPath()
    cab.move(to: CGPoint(x: 34, y: 17))
    cab.line(to: CGPoint(x: 34, y: 41))
    cab.line(to: CGPoint(x: 51, y: 41))
    cab.line(to: CGPoint(x: 59, y: 28))
    cab.line(to: CGPoint(x: 61, y: 17))
    cab.close()
    paint.setFill(); cab.fill()
    let glass = NSBezierPath()
    glass.move(to: CGPoint(x: 38, y: 29))
    glass.line(to: CGPoint(x: 38, y: 38))
    glass.line(to: CGPoint(x: 49, y: 38))
    glass.line(to: CGPoint(x: 55, y: 29))
    glass.close()
    NSColor(calibratedRed: 0.37, green: 0.72, blue: 0.88, alpha: 1).setFill(); glass.fill()
    line(CGPoint(x: 47, y: 30), CGPoint(x: 47, y: 37), color: .white)
    line(CGPoint(x: 37, y: 19), CGPoint(x: 37, y: 27), color: .darkGray)
    rounded(CGRect(x: 39, y: 25, width: 4, height: 1.5), radius: 0.5, color: .darkGray)
    line(CGPoint(x: 4, y: 18), CGPoint(x: 59, y: 18), color: .white, width: 2)
    rounded(CGRect(x: 56, y: 21, width: 4, height: 4), radius: 1, color: .white)
    rounded(CGRect(x: 3, y: 17, width: 2, height: 4), radius: 0.5, color: .systemRed)
    rounded(CGRect(x: 57, y: 14, width: 6, height: 3), radius: 1, color: .lightGray)
    for x: CGFloat in [14, 47] {
        ellipse(CGRect(x: x - 8, y: 1, width: 16, height: 16), .black)
        ellipse(CGRect(x: x - 5.5, y: 3.5, width: 11, height: 11), .darkGray)
        ellipse(CGRect(x: x - 3, y: 6, width: 6, height: 6), .lightGray)
        line(CGPoint(x: x - cos(wheelAngle) * 4, y: 9 - sin(wheelAngle) * 4),
             CGPoint(x: x + cos(wheelAngle) * 4, y: 9 + sin(wheelAngle) * 4), color: .gray)
    }
    rounded(CGRect(x: 39, y: 41, width: 13, height: 2), radius: 1, color: .darkGray)
    rounded(CGRect(x: 42, y: 43, width: 7, height: 4), radius: 1, color: .systemOrange)
    if sin(time * 8) > 0 {
        ellipse(CGRect(x: 38, y: 40, width: 15, height: 10), NSColor.systemOrange.withAlphaComponent(0.25))
    }
    line(CGPoint(x: 58, y: 15), CGPoint(x: 69, y: 10), color: .darkGray, width: 3)
    let blade = NSBezierPath()
    blade.move(to: CGPoint(x: 67, y: 3))
    blade.line(to: CGPoint(x: 78, y: 4))
    blade.line(to: CGPoint(x: 72, y: 27))
    blade.curve(to: CGPoint(x: 67, y: 3), controlPoint1: CGPoint(x: 59, y: 26),
                controlPoint2: CGPoint(x: 60, y: 10))
    NSGradient(starting: .white, ending: NSColor(calibratedWhite: 0.65, alpha: 1))!.draw(in: blade, angle: 0)
    if infernal {
        drawBurningSkull(in: CGRect(x: 37, y: 27, width: 15, height: 13), time: time)
        for x: CGFloat in [14, 47] {
            drawEmberFlame(at: CGPoint(x: x, y: 7), size: 11, time: time)
        }
    }
}

func drawPlow(in rect: CGRect, direction: CGFloat, time: CGFloat, carriageCount: Int,
              load: CGFloat, fire: CGFloat, wheelAngle: CGFloat, infernal: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    let transform = AffineTransform(translationByX: rect.minX, byY: rect.minY)
    (transform as NSAffineTransform).concat()
    if direction < 0 {
        let flip = NSAffineTransform()
        flip.translateX(by: rect.width, yBy: 0)
        flip.scaleX(by: -1, yBy: 1)
        flip.concat()
    }
    let engineOffset = NSAffineTransform()
    let tailLength = CGFloat(carriageCount) * 60
    engineOffset.translateX(by: tailLength, yBy: 0)
    engineOffset.concat()
    let carriageColors: [NSColor] = [.systemBlue, .systemRed,
                                     NSColor(calibratedRed: 0.56, green: 0.34, blue: 0.2, alpha: 1)]
    for i in 0..<carriageCount {
        let color = infernal ? NSColor.darkGray : carriageColors[i % carriageColors.count]
        let x = -tailLength + CGFloat(i) * 60 + 4
        line(CGPoint(x: x + 48, y: 17), CGPoint(x: x + 60, y: 17), color: .darkGray, width: 2)
        NSGraphicsContext.saveGraphicsState()
        let carriageShake = NSAffineTransform()
        carriageShake.translateX(by: 0, yBy: fire * (0.7 + 0.7 * sin(time * 24 - CGFloat(i) * 0.8)))
        carriageShake.concat()
        rounded(CGRect(x: x, y: 17, width: 50, height: 22), radius: 3, color: color)
        rounded(CGRect(x: x - 2, y: 38, width: 54, height: 4), radius: 2, color: .darkGray)
        rounded(CGRect(x: x, y: 41, width: 50, height: 2), radius: 1, color: infernal ? bloodRed : .white)
        for (seat, windowX) in [x + 4, x + 20, x + 35].enumerated() {
            let window = CGRect(x: windowX, y: 25, width: 11, height: 11)
            rounded(window, radius: 1.5,
                     color: NSColor(calibratedRed: 1, green: 0.89, blue: 0.56, alpha: 1))
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: window, xRadius: 1.5, yRadius: 1.5).addClip()
            let person = i * 3 + seat
            let bob = sin(time * 2 + CGFloat(person)) * 0.25
            let cx = window.midX
            let coats: [NSColor] = [.systemPurple, .systemTeal, .systemBlue, .systemRed]
            let coat = coats[person % coats.count]
            let skin = person % 3 == 1 ? NSColor(calibratedRed: 0.65, green: 0.4, blue: 0.25, alpha: 1) :
                NSColor(calibratedRed: 1, green: 0.79, blue: 0.62, alpha: 1)
            rounded(CGRect(x: cx - 3, y: 24 + bob, width: 6, height: 6), radius: 2, color: coat)
            ellipse(CGRect(x: cx - 2, y: 29 + bob, width: 4, height: 4.5), skin)
            rounded(CGRect(x: cx - 2.3, y: 32.5 + bob, width: 4.6, height: 1.8), radius: 0.8,
                    color: person % 2 == 0 ? coat : .brown)
            if person % 2 == 0 {
                ellipse(CGRect(x: cx - 0.7, y: 34 + bob, width: 1.4, height: 1.4), .white)
            }
            for eyeX in [cx - 1, cx + 0.8] {
                ellipse(CGRect(x: eyeX, y: 31 + bob, width: 0.5, height: 0.65), .black)
            }
            line(CGPoint(x: cx - 0.5, y: 30 + bob), CGPoint(x: cx + 0.6, y: 30 + bob),
                 color: .brown, width: 0.4)
            if person % 3 == 0 {
                let wave = sin(time * 4 + CGFloat(person))
                line(CGPoint(x: cx + 2, y: 28), CGPoint(x: cx + 4, y: 30), color: coat, width: 1.5)
                line(CGPoint(x: cx + 4, y: 30), CGPoint(x: cx + 4 + wave * 0.5, y: 32 + wave * 0.5),
                     color: skin, width: 1.3)
            }
            NSGraphicsContext.restoreGraphicsState()
            line(CGPoint(x: window.minX + 1, y: 25.5), CGPoint(x: window.maxX - 1, y: 25.5),
                 color: .lightGray, width: 0.7)
        }
        line(CGPoint(x: x + 2, y: 20), CGPoint(x: x + 48, y: 20), color: .lightGray)
        NSGraphicsContext.restoreGraphicsState()
        for wheelX in [x + 10, x + 40] {
            ellipse(CGRect(x: wheelX - 5, y: 6, width: 10, height: 10), .darkGray)
            ellipse(CGRect(x: wheelX - 3, y: 8, width: 6, height: 6), .gray)
            line(CGPoint(x: wheelX, y: 11),
                 CGPoint(x: wheelX + cos(wheelAngle * 1.2) * 3, y: 11 + sin(wheelAngle * 1.2) * 3), color: .lightGray)
            if infernal { drawEmberFlame(at: CGPoint(x: wheelX, y: 8), size: 11, time: time) }
        }
    }
    NSGraphicsContext.saveGraphicsState()
    let effort = NSAffineTransform()
    effort.translateX(by: (load * 0.35 + fire * 1.5) * sin(time * 19),
                      yBy: (load * 0.45 + fire * 2) * (1 + sin(time * 24)))
    effort.concat()
    let engineGreen = infernal ? NSColor.darkGray : NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.32, alpha: 1)
    rounded(CGRect(x: 4, y: 17, width: 57, height: 5), radius: 2, color: .systemRed)
    rounded(CGRect(x: 6, y: 21, width: 23, height: 20), radius: 3, color: engineGreen)
    rounded(CGRect(x: 3, y: 40, width: 29, height: 4), radius: 2, color: .darkGray)
    rounded(CGRect(x: 9, y: 26, width: 17, height: 13), radius: 2,
             color: NSColor(calibratedRed: 0.58, green: 0.82, blue: 0.94, alpha: 1))
    rounded(CGRect(x: 11, y: 26.5, width: 4, height: 5), radius: 1, color: .darkGray)
    rounded(CGRect(x: 13, y: 26.5, width: 10, height: 5.5), radius: 2, color: .systemRed)
    ellipse(CGRect(x: 14, y: 30.5, width: 7, height: 6),
            NSColor(calibratedRed: 1, green: 0.79, blue: 0.64, alpha: 1))
    let beard = NSBezierPath()
    beard.move(to: CGPoint(x: 13.5, y: 32.5))
    beard.curve(to: CGPoint(x: 18, y: 27.5), controlPoint1: CGPoint(x: 13, y: 29),
                controlPoint2: CGPoint(x: 16, y: 28))
    beard.curve(to: CGPoint(x: 21, y: 32.5), controlPoint1: CGPoint(x: 21, y: 29),
                controlPoint2: CGPoint(x: 22, y: 31))
    beard.close()
    NSColor.white.setFill(); beard.fill()
    let hat = NSBezierPath()
    hat.move(to: CGPoint(x: 13.5, y: 35))
    hat.line(to: CGPoint(x: 16, y: 38.5))
    hat.line(to: CGPoint(x: 21, y: 36.5))
    hat.line(to: CGPoint(x: 21, y: 35))
    hat.close()
    NSColor.systemRed.setFill(); hat.fill()
    rounded(CGRect(x: 13, y: 34.5, width: 8.5, height: 1.5), radius: 0.7, color: .white)
    ellipse(CGRect(x: 20, y: 36, width: 2, height: 2), .white)
    ellipse(CGRect(x: 18.8, y: 33.3, width: 0.8, height: 0.8), .black)
    ellipse(CGRect(x: 19.5, y: 31.8, width: 2.5, height: 1.8), .systemPink)
    line(CGPoint(x: 21, y: 28.5), CGPoint(x: 24, y: 30), color: .systemRed, width: 2)
    line(CGPoint(x: 10, y: 26.5), CGPoint(x: 25, y: 26.5), color: .lightGray)
    if infernal { drawBurningSkull(in: CGRect(x: 9, y: 26, width: 17, height: 13), time: time) }
    rounded(CGRect(x: 29, y: 21, width: 30, height: 15), radius: 6, color: engineGreen)
    for x: CGFloat in [36, 50] {
        line(CGPoint(x: x, y: 23), CGPoint(x: x, y: 34), color: .systemYellow, width: 2)
    }
    rounded(CGRect(x: 45, y: 34, width: 7, height: 8), radius: 1, color: .darkGray)
    rounded(CGRect(x: 43, y: 41, width: 11, height: 3), radius: 1, color: .darkGray)
    ellipse(CGRect(x: 57, y: 27, width: 5, height: 5), .systemYellow)
    NSGraphicsContext.restoreGraphicsState()
    let angle = wheelAngle
    for x: CGFloat in [14, 32, 50] {
        ellipse(CGRect(x: x - 6, y: 6, width: 12, height: 12), .darkGray)
        ellipse(CGRect(x: x - 4.5, y: 7.5, width: 9, height: 9), .systemRed)
        line(CGPoint(x: x, y: 12), CGPoint(x: x + cos(angle) * 4, y: 12 + sin(angle) * 4),
             color: .lightGray, width: 1.5)
        if infernal { drawEmberFlame(at: CGPoint(x: x, y: 9), size: 12, time: time) }
    }
    line(CGPoint(x: 14 + cos(angle) * 3, y: 12 + sin(angle) * 3),
         CGPoint(x: 50 + cos(angle) * 3, y: 12 + sin(angle) * 3), color: .lightGray, width: 2)
    line(CGPoint(x: 53, y: 16), CGPoint(x: 64, y: 13), color: .darkGray, width: 4)
    let blade = NSBezierPath()
    blade.move(to: CGPoint(x: 58, y: 7))
    blade.line(to: CGPoint(x: 60, y: 31))
    blade.line(to: CGPoint(x: 78, y: 7))
    blade.close()
    NSGradient(starting: NSColor(calibratedWhite: 0.42, alpha: 1), ending: .lightGray)!.draw(in: blade, angle: 0)
    let face = NSBezierPath()
    face.move(to: CGPoint(x: 60, y: 31))
    face.line(to: CGPoint(x: 67, y: 10))
    face.line(to: CGPoint(x: 78, y: 7))
    face.close()
    NSGradient(starting: .lightGray, ending: .white)!.draw(in: face, angle: 35)
    line(CGPoint(x: 60, y: 31), CGPoint(x: 78, y: 7), color: .white, width: 1)
    line(CGPoint(x: 58, y: 7), CGPoint(x: 78, y: 7), color: .darkGray, width: 1.5)
    NSGraphicsContext.restoreGraphicsState()
}

func cloudLobes(_ seed: Int) -> [(dx: CGFloat, dy: CGFloat, scale: CGFloat)] {
    switch seed % 4 {
    case 0: return [(-0.45, 0, 0.62), (0.05, 0.22, 0.85), (0.45, 0.02, 0.55), (-0.15, 0.28, 0.5), (0.25, -0.05, 0.45)]
    case 1: return [(-0.30, 0.10, 0.6), (0.10, 0.28, 0.7), (0.42, 0, 0.45), (-0.05, -0.06, 0.55), (0.05, 0.05, 0.75)]
    case 2: return [(-0.42, 0.04, 0.5), (-0.05, 0.24, 0.72), (0.32, 0.10, 0.55), (0.48, -0.05, 0.35)]
    default: return [(-0.20, 0, 0.7), (0.18, 0.20, 0.6), (0.45, 0, 0.4), (-0.42, 0.10, 0.4), (0.02, 0.30, 0.42)]
    }
}

func drawSnowScenery(_ world: SnowWorld) {
    if world.plowActive && !world.useTractor {
        let load = world.trainLoad
        let fire: CGFloat = world.infernalMode ? 1 : world.trainFireIntensity
        for i in 0..<5 {
            let strength = min(1, max(0, 1 + load * 4 - CGFloat(i)))
            let phase = (world.trainSmokePhase + CGFloat(i) / 5).truncatingRemainder(dividingBy: 1)
            let diameter = (12 + phase * 14) * (1 + load * 1.5) * (0.9 + 0.2 * CGFloat((i * 7 + 3) % 5) / 4)
            let sway = sin(CGFloat(i) * 2.3 + world.trainSmokePhase * 6.3) * diameter * 0.5
            let x = world.plowX + world.plowDirection * (8 - phase * (40 + load * 70) - fire * 70) + sway
            let y = 44 + phase * (64 + load * 110) + fire * 35
            let mirror: CGFloat = (i / 4) % 2 == 0 ? 1 : -1
            let cloud = NSBezierPath()
            for lobe in cloudLobes(i) {
                let size = diameter * lobe.scale
                cloud.appendOval(in: CGRect(x: x + diameter * lobe.dx * mirror - size / 2, y: y + diameter * lobe.dy,
                                            width: size, height: size * 0.82))
            }
            NSColor(calibratedWhite: 0.92 - load * 0.3,
                    alpha: strength * (0.26 + load * 0.5) * (1 - phase * 0.6) * max(0, 1 - fire * 3)).setFill()
            cloud.fill()
        }
        if fire > 0 {
            let x = world.plowX + world.plowDirection * (8 + (load * 0.35 + fire * 1.5) * sin(world.elapsed * 19))
            let baseY = 44 + (load * 0.45 + fire * 2) * (1 + sin(world.elapsed * 24))
            let flicker = 0.85 + 0.15 * sin(world.elapsed * 27)
            let height = fire * (24 + 12 * flicker)
            let width = 3 + fire * 4
            let lean = -world.plowDirection * fire * (5 + 3 * sin(world.elapsed * 19))
            ellipse(CGRect(x: x - width * 2, y: baseY - 4, width: width * 4, height: height + 10),
                    NSColor.systemOrange.withAlphaComponent(fire * 0.18))
            for (scale, color) in [(CGFloat(1), NSColor.systemOrange), (CGFloat(0.55), NSColor.systemYellow)] {
                let flame = NSBezierPath()
                flame.move(to: CGPoint(x: x - width * scale, y: baseY))
                flame.curve(to: CGPoint(x: x + lean * scale, y: baseY + height * scale),
                            controlPoint1: CGPoint(x: x - width * 1.5 * scale, y: baseY + height * 0.4 * scale),
                            controlPoint2: CGPoint(x: x + lean * scale, y: baseY + height * 0.6 * scale))
                flame.curve(to: CGPoint(x: x + width * scale, y: baseY),
                            controlPoint1: CGPoint(x: x + width * 0.5 * scale, y: baseY + height * 0.5 * scale),
                            controlPoint2: CGPoint(x: x + width * 1.5 * scale, y: baseY + height * 0.3 * scale))
                flame.close()
                color.withAlphaComponent(min(1, fire * 3) * flicker).setFill()
                flame.fill()
            }
        }
    }
    for drift in world.drifts {
        for span in drift.ledge.spans {
            let path = NSBezierPath()
            let y = drift.ledge.y
            path.move(to: CGPoint(x: span.lowerBound, y: y))
            path.line(to: CGPoint(x: span.lowerBound, y: y + drift.height(at: span.lowerBound)))
            for x in stride(from: span.lowerBound, to: span.upperBound, by: 2) {
                path.line(to: CGPoint(x: x, y: y + drift.height(at: x)))
            }
            path.line(to: CGPoint(x: span.upperBound, y: y + drift.height(at: span.upperBound)))
            path.line(to: CGPoint(x: span.upperBound, y: y))
            path.close()
            NSGradient(starting: world.infernalMode ? bloodDark : NSColor(calibratedRed: 0.79, green: 0.87, blue: 0.96, alpha: 0.95),
                       ending: world.infernalMode ? bloodRed : .white)!.draw(in: path, angle: 90)
            if world.infernalMode {
                NSGraphicsContext.saveGraphicsState()
                path.addClip()
                for layer in 0..<2 {
                    let stream = NSBezierPath()
                    for (i, x) in stride(from: span.lowerBound, through: span.upperBound, by: 3).enumerated() {
                        let point = CGPoint(x: x, y: y + drift.height(at: x) * (0.3 + CGFloat(layer) * 0.35) +
                                            sin(x * 0.07 - world.elapsed * 1.5 + CGFloat(layer) * 2) * 1.5)
                        if i == 0 { stream.move(to: point) } else { stream.line(to: point) }
                    }
                    bloodDark.withAlphaComponent(0.65).setStroke()
                    stream.lineWidth = 1.5
                    stream.stroke()
                }
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
    if !world.useTractor {
        for x in stride(from: CGFloat(4), to: world.size.width, by: 18) {
            rounded(CGRect(x: x, y: 0, width: 9, height: 7), radius: 1,
                    color: NSColor(calibratedRed: 0.32, green: 0.23, blue: 0.19, alpha: 1))
        }
        for y: CGFloat in [2, 6] {
            line(CGPoint(x: 0, y: y), CGPoint(x: world.size.width, y: y), color: .gray, width: 1.5)
            line(CGPoint(x: 0, y: y + 0.6), CGPoint(x: world.size.width, y: y + 0.6), color: .lightGray, width: 0.5)
        }
    }
    if world.plowActive && world.collectedSnow > 0 {
        let size = world.plowPileSize
        let base = world.plowX + world.plowDirection * 28
        let direction = world.plowDirection
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: base + direction * size.width * x, y: 1 + size.height * y)
        }
        if world.skierInPile && size.height > 18 {
            let anchor = point(0.36, 1)
            NSGraphicsContext.saveGraphicsState()
            let skierScale = NSAffineTransform()
            skierScale.translateX(by: anchor.x, yBy: anchor.y)
            skierScale.scale(by: 0.45)
            skierScale.concat()
            let sway = sin(world.elapsed * 5) * 1.5
            func skierPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: direction * x, y: y)
            }
            for side: CGFloat in [-1, 1] {
                let footX = side * 12 + sway
                let footY: CGFloat = side < 0 ? 22 : 27
                line(skierPoint(side * 3, -9), skierPoint(side * 7, 9),
                     color: NSColor(calibratedRed: 0.16, green: 0.3, blue: 0.65, alpha: 1), width: 7)
                line(skierPoint(side * 7, 9), skierPoint(footX, footY), color: .systemBlue, width: 6)
                line(skierPoint(footX, footY - 2), skierPoint(footX, footY + 4), color: .darkGray, width: 8)
                line(skierPoint(footX - 3, footY + 4), skierPoint(footX + 5, footY + 4), color: .black, width: 4)
                line(skierPoint(footX - 2, footY), skierPoint(footX + 2, footY), color: .lightGray, width: 1.5)
                let skiColor: NSColor = side < 0 ? .systemRed : .systemOrange
                let tilt = side * 0.2
                line(skierPoint(footX - 19, footY + 7 - tilt * 19),
                     skierPoint(footX + 19, footY + 7 + tilt * 19), color: skiColor, width: 3)
                line(skierPoint(footX + 19, footY + 7 + tilt * 19),
                      skierPoint(footX + 23, footY + 10 + tilt * 19), color: skiColor, width: 3)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        let pile = NSBezierPath()
        pile.move(to: point(0, 0))
        for sample in plowPileOutline.dropFirst() { pile.line(to: point(sample.x, sample.y)) }
        pile.close()
        NSGradient(starting: world.infernalMode ? bloodDark : NSColor(calibratedRed: 0.65, green: 0.77, blue: 0.9, alpha: 1),
                   ending: world.infernalMode ? bloodRed : .white)!.draw(in: pile, angle: 90)
    }
}

func drawWinter(_ world: SnowWorld) {
    if !world.snowfallOnly { drawSnowScenery(world) }
    for group in 0..<3 {
        let path = NSBezierPath()
        for flake in world.flakes where min(2, Int(flake.radius)) == group {
            if world.infernalMode {
                let radius = flake.radius * world.snowflakeScale
                let angle = flake.phase + world.elapsed * 0.8
                for (i, corner) in [CGPoint(x: -0.8, y: -0.3), CGPoint(x: 0.25, y: -0.65),
                                    CGPoint(x: 0.9, y: 0.2), CGPoint(x: -0.2, y: 0.75)].enumerated() {
                    let point = CGPoint(x: flake.point.x + radius * (corner.x * cos(angle) - corner.y * sin(angle)),
                                        y: flake.point.y + radius * (corner.x * sin(angle) + corner.y * cos(angle)))
                    if i == 0 { path.move(to: point) } else { path.line(to: point) }
                }
                path.close()
            } else if world.crystalFlakes {
                let radius = (flake.radius * 2 + 1) * world.snowflakeScale
                for ray in 0..<6 {
                    let angle = flake.phase + world.elapsed * 0.25 + CGFloat(ray) * .pi / 3
                    let axis = CGVector(dx: cos(angle), dy: sin(angle))
                    let tip = CGPoint(x: flake.point.x + axis.dx * radius, y: flake.point.y + axis.dy * radius)
                    path.move(to: flake.point)
                    path.line(to: tip)
                    if flake.radius > 1 {
                        let joint = CGPoint(x: flake.point.x + axis.dx * radius * 0.58,
                                            y: flake.point.y + axis.dy * radius * 0.58)
                        for side: CGFloat in [-1, 1] {
                            let branchAngle = angle + side * .pi / 3
                            path.move(to: joint)
                            path.line(to: CGPoint(x: joint.x + cos(branchAngle) * radius * 0.32,
                                                  y: joint.y + sin(branchAngle) * radius * 0.32))
                        }
                    }
                }
            } else {
                let radius = flake.radius * world.snowflakeScale
                path.appendOval(in: CGRect(x: flake.point.x + flake.radius - radius,
                                           y: flake.point.y + flake.radius - radius,
                                           width: radius * 2, height: radius * 2))
            }
        }
        let color = (world.infernalMode ? NSColor(calibratedWhite: 0.62 + CGFloat(group) * 0.12, alpha: 1) : NSColor.white)
            .withAlphaComponent(0.35 + CGFloat(group) * 0.22)
        if world.crystalFlakes && !world.infernalMode {
            color.setStroke()
            path.lineWidth = (0.6 + CGFloat(group) * 0.15) * world.snowflakeScale
            path.lineCapStyle = .round
            path.stroke()
        } else {
            color.setFill()
            path.fill()
        }
    }
    guard !world.snowfallOnly else { return }
    for puff in world.puffs {
        if puff.snowAmount > 0 {
            line(puff.point, CGPoint(x: puff.point.x - puff.velocity.dx * 0.012,
                                     y: puff.point.y - puff.velocity.dy * 0.012),
                 color: (world.infernalMode ? bloodRed : NSColor.white).withAlphaComponent(min(0.4, puff.life)), width: puff.radius)
        }
        ellipse(CGRect(x: puff.point.x, y: puff.point.y, width: puff.radius * 2, height: puff.radius * 2),
                (world.infernalMode ? bloodRed : NSColor.white).withAlphaComponent(min(1, puff.life * 2)))
    }
}
