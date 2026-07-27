//
//  HoverTimeApp.swift
//  HoverTime
//

import SwiftUI

@main
struct HoverTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = TimerManager.shared

    var body: some Scene {
        MenuBarExtra("HoverTime Desktop Timer", systemImage: "clock") {
            MenuBarView(manager: manager, appDelegate: appDelegate)
        }
    }
}
