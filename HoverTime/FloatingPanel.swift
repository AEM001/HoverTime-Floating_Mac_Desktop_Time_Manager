//
//  FloatingPanel.swift
//  HoverTime
//

import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    var clickAction: (() -> Void)?
    var dragAction: (() -> Void)?
    private var mouseDownLocation: NSPoint?
    private var dragOrigin: NSPoint?
    private var didDrag = false

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            mouseDownLocation = convertPoint(toScreen: event.locationInWindow)
            dragOrigin = frame.origin
            didDrag = false
        case .leftMouseDragged:
            guard let start = mouseDownLocation, let origin = dragOrigin else { break }
            let current = convertPoint(toScreen: event.locationInWindow)
            let delta = NSPoint(x: current.x - start.x, y: current.y - start.y)
            if didDrag || hypot(delta.x, delta.y) >= 4 {
                if !didDrag { dragAction?() }
                didDrag = true
                setFrameOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            }
        case .leftMouseUp:
            guard mouseDownLocation != nil else { break }
            mouseDownLocation = nil
            dragOrigin = nil
            if didDrag {
                constrainToScreen()
                savePosition()
            } else {
                clickAction?()
            }
        default:
            super.sendEvent(event)
        }
    }

    func constrainToScreen() {
        let target = NSScreen.screens.max { first, second in
            let firstIntersection = frame.intersection(first.visibleFrame)
            let secondIntersection = frame.intersection(second.visibleFrame)
            return firstIntersection.width * firstIntersection.height < secondIntersection.width * secondIntersection.height
        }
        guard let visible = target?.visibleFrame else { return }
        setFrameOrigin(NSPoint(
            x: max(visible.minX, min(frame.minX, visible.maxX - frame.width)),
            y: max(visible.minY, min(frame.minY, visible.maxY - frame.height))
        ))
    }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView

        // Always on top
        level = .floating
        
        // Visible on all Spaces, floats over fullscreen
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Transparent background
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Non-activating: won't steal focus
        hidesOnDeactivate = false
        isMovableByWindowBackground = false

        // Restore saved position
        restorePosition()
    }

    // MARK: - Click-through support

    var isClickThrough: Bool = false {
        didSet {
            ignoresMouseEvents = isClickThrough
        }
    }

    override var canBecomeKey: Bool { !isClickThrough }
    override var canBecomeMain: Bool { false }


    // MARK: - Position memory

    func savePosition() {
        let d = UserDefaults.standard
        d.set(Double(frame.origin.x), forKey: "panelX")
        d.set(Double(frame.origin.y), forKey: "panelY")
    }

    func restorePosition() {
        let d = UserDefaults.standard
        if d.object(forKey: "panelX") != nil {
            let x = CGFloat(d.double(forKey: "panelX"))
            let y = CGFloat(d.double(forKey: "panelY"))
            setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            center()
        }
    }

}
