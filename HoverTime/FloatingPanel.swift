//
//  FloatingPanel.swift
//  HoverTime
//

import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
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
        isMovableByWindowBackground = true

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

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        // Save position after drag
        savePosition()
    }
}
