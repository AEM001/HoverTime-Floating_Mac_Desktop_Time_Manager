
extension MenuBarController {
    static func runMenuRegressions(manager: TimerManager) {
        let delegate = AppDelegate()
        let controller = MenuBarController(manager: manager, appDelegate: delegate)
        controller.menuWillOpen(controller.menu)
        let modeItem = controller.menu.items.first { $0.title == "Mode" }!
        let items = controller.modeMenu.items
        for _ in 0..<20 {
            manager.currentTime = Date()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            precondition(modeItem.submenu === controller.modeMenu)
            precondition(zip(items, controller.modeMenu.items).allSatisfy { $0 === $1 })
        }
        print("PASS: timer publications preserve native submenu and item identities")
        for item in items {
            controller.selectMode(item)
            controller.menuWillOpen(controller.menu)
            precondition(item.state == .on)
            precondition(controller.startItem.isHidden == (manager.mode == .clock))
        }
        controller.toggleClickThrough()
        controller.menuWillOpen(controller.menu)
        precondition(controller.clickThroughItem.state == .on)
        precondition(controller.startItem.keyEquivalent == "p" && controller.resetItem.keyEquivalent == "r")
        NSStatusBar.system.removeStatusItem(controller.statusItem)
        print("PASS: mode selection, checkmarks, click-through, shortcuts")
    }
}
