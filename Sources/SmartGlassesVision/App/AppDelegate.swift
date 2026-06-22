// AppDelegate.swift
// 应用生命周期管理，配置后台音频会话 & Solos SDK 初始化

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureAudioSession()
        return true
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 保持音频播放在后台运行，用于空间音频导航
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[AudioSession] 配置失败: \(error.localizedDescription)")
        }
    }
}
