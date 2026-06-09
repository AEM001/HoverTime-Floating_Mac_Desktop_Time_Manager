//
//  MainView.swift
//  HoverTime
//

import SwiftUI

struct MainView: View {
    @ObservedObject var manager: TimerManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsView(manager: manager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .tag(1)
        }
        .frame(minWidth: 560, minHeight: 620)
    }
}
