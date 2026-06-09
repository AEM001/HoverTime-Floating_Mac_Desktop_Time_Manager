//
//  MainView.swift
//  HoverTime
//

import SwiftUI

struct MainView: View {
    @ObservedObject var manager: TimerManager

    var body: some View {
        SettingsView(manager: manager)
        .frame(minWidth: 560, minHeight: 620)
    }
}
