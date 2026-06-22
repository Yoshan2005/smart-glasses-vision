// SmartGlassesVisionApp.swift
// AI 导盲与紧急救援智能眼镜 iOS 端入口

import SwiftUI

@main
struct SmartGlassesVisionApp: App {
    @StateObject private var mainViewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mainViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
