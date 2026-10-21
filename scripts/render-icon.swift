import AppKit

guard CommandLine.arguments.count == 2 else { exit(2) }
let image = NSImage(size: NSSize(width: 32, height: 32))
image.lockFocus()
NSColor.black.setStroke()
let pad = NSBezierPath(roundedRect: NSRect(x: 2, y: 3, width: 28, height: 23), xRadius: 4, yRadius: 4)
pad.lineWidth = 1.8
pad.stroke()
let ink = NSBezierPath()
ink.move(to: NSPoint(x: 8, y: 10))
ink.curve(to: NSPoint(x: 13, y: 21), controlPoint1: NSPoint(x: 22, y: 27), controlPoint2: NSPoint(x: 21, y: 25))
ink.curve(to: NSPoint(x: 25, y: 13), controlPoint1: NSPoint(x: 3, y: 11), controlPoint2: NSPoint(x: 20, y: 5))
ink.lineWidth = 2.1
ink.lineCapStyle = .round
ink.stroke()
image.unlockFocus()
guard let data = image.tiffRepresentation else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
