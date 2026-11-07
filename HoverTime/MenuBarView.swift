//
//  MenuBarView.swift
//  HoverTime
//

import AppKit

/// Keep native menu identities stable throughout AppKit's tracking loop.
/// Timer ticks update the floating display, never rebuild an open submenu.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let manager: TimerManager
    private weak var appDelegate: AppDelegate?
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let modeMenu = NSMenu(title: "Mode")
    private var visibilityItem: NSMenuItem!
    private var clickThroughItem: NSMenuItem!
    private var startItem: NSMenuItem!
    private var resetItem: NSMenuItem!
    private var timerSeparator: NSMenuItem!

    init(manager: TimerManager, appDelegate: AppDelegate) {
        self.manager = manager
        self.appDelegate = appDelegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "HoverTime")
        statusItem.button?.toolTip = "HoverTime"
        menu.autoenablesItems = false
        menu.delegate = self
        visibilityItem = addItem("Hide Timer", action: #selector(togglePanel), key: "h")
        addItem("Recenter at Top", action: #selector(recenter), key: "c")
        menu.addItem(.separator())

        let modeItem = menu.addItem(withTitle: "Mode", action: nil, keyEquivalent: "")
        modeMenu.autoenablesItems = false
        for mode in TimeMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            modeMenu.addItem(item)
        }
        modeItem.submenu = modeMenu
        clickThroughItem = addItem("Click-through (disable to drag)", action: #selector(toggleClickThrough))
        menu.addItem(.separator())
        startItem = addItem("Start", action: #selector(toggleTimer), key: "p")
        resetItem = addItem("Reset", action: #selector(resetTimer), key: "r")
        timerSeparator = .separator()
        menu.addItem(timerSeparator)
        addItem("Settings…", action: #selector(openSettings), key: ",")
        menu.addItem(.separator())
        addItem("Quit HoverTime", action: #selector(quit), key: "q")
        statusItem.menu = menu
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        visibilityItem.title = appDelegate?.panel?.isVisible == true ? "Hide Timer" : "Show Timer"
        clickThroughItem.state = manager.clickThrough ? .on : .off
        for item in modeMenu.items {
            item.state = (item.representedObject as? String) == manager.mode.rawValue ? .on : .off
        }
        let isClock = manager.mode == .clock
        let isRunning = manager.mode == .countdown ? manager.countdownRunning : manager.stopwatchRunning
        startItem.title = isRunning ? "Pause" : "Start"
        startItem.isHidden = isClock
        resetItem.isHidden = isClock
        timerSeparator.isHidden = isClock
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = TimeMode(rawValue: raw) else { return }
        manager.mode = mode
        manager.saveSettings()
    }

    @objc private func togglePanel() { appDelegate?.togglePanel() }
    @objc private func recenter() { appDelegate?.showPanelAtTopCenter(manager: manager) }
    @objc private func toggleClickThrough() {
        manager.clickThrough.toggle()
        manager.saveSettings()
    }
    @objc private func toggleTimer() { manager.toggleStartPause() }
    @objc private func resetTimer() { manager.resetCurrent() }
    @objc private func openSettings() { appDelegate?.openSettingsWindow() }
    @objc private func quit() { NSApp.terminate(nil) }
}
