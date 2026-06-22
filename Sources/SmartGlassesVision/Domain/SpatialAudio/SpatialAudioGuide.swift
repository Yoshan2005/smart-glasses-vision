// SpatialAudioGuide.swift
// Module 3: 反向空间音频导引 - "Hear to See"
//
// 使用 AVSpeechSynthesizer 将障碍物位置映射到立体声场，
// 通过 Solos AirGo V2 眼镜的左右扬声器输出定向音频反馈。

import AVFoundation
import Foundation
import UIKit

/// 空间音频导引器
///
/// 工作流程:
/// 1. 收到障碍物检测结果 (label + pan)
/// 2. 抢占式清空当前语音队列
/// 3. 快速合成 TTS 指令并设置立体声平衡 (pan)
/// 4. 眼镜左右扬声器输出，用户"听声辨位"
final class SpatialAudioGuide: NSObject {

    // MARK: - 属性
    private let synthesizer = AVSpeechSynthesizer()
    private let audioQueue = DispatchQueue(
        label: "com.smartglasses.audio",
        qos: .userInitiated
    )

    // MARK: - 初始化
    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 障碍物语音播报
    /// 播报障碍物方向信息
    /// - Parameters:
    ///   - label: 障碍物标签 (如 "person", "car")
    ///   - pan: 空间平衡参数 [-1.0, +1.0]
    func announceObstacle(label: String, pan: Float, distance: Float? = nil) {
        let clampedPan = max(-1.0, min(1.0, pan))

        // 构建自然语言描述
        let direction = directionDescription(pan: clampedPan)
        let distanceText = distance.map { distDescription() } ?? ""
        let text = "\(label)\(distanceText), \(direction)"

        // 抢占式打断当前语音
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)

        // ---- 低延迟配置 ----
        utterance.rate = Constants.SpatialAudio.speechRate          // 加速语速
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0

        // ---- 立体声映射 ----
        // 通过 pan 将音频能量导向对应扬声器
        // pan = -1.0: 全左声道 (左侧障碍物)
        // pan =  0.0: 中间 (前方)
        // pan = +1.0: 全右声道 (右侧障碍物)
        utterance.pan = clampedPan

        // 使用标准中文语音
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")

        audioQueue.async { [weak self] in
            self?.synthesizer.speak(utterance)
        }
    }

    /// 播报系统消息 (非空间)
    func announceSystem(_ message: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = Constants.SpatialAudio.speechRate
        utterance.volume = 1.0
        utterance.pan = 0.0 // 居中
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")

        synthesizer.speak(utterance)
    }

    // MARK: - 辅助方法
    private func directionDescription(pan: Float) -> String {
        switch pan {
        case ..<(-0.33): return "左侧"
        case (-0.33)...0.33: return "前方"
        default: return "右侧"
        }
    }

    private func distDescription(_ distance: Float) -> String {
        // distance: 0.0 (远) ~ 1.0 (近)
        switch distance {
        case ..<0.3: return "，较远"
        case 0.3..<0.6: return ""
        default: return "，很近"
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension SpatialAudioGuide: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        // 语音播放完成后的清理 (如有需要)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        // 被抢占打断时触发
    }
}
