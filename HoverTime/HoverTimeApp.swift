//
//  HoverTimeApp.swift
//  HoverTime
//

import SwiftUI

@main
struct HoverTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            MainView(manager: TimerManager.shared)
        }
    }
}
