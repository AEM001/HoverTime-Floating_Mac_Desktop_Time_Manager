//
//  HoverTimeApp.swift
//  HoverTime
//

import SwiftUI

@main
struct HoverTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = TimerManager()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("HoverTime", systemImage: "clock") {
            MenuBarView(manager: manager, appDelegate: appDelegate)
        }

        Window("HoverTime", id: "main") {
            MainView(manager: manager)
                .onAppear {
                    appDelegate.setupPanel(with: manager)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 580, height: 640)
        .defaultLaunchBehavior(.presented)
    }
}
