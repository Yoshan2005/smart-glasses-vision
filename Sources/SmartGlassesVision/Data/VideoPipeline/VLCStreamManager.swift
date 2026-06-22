// VLCStreamManager.swift
// Module 1: 低延迟视频流水线 - 使用 MobileVLCKit 拉取 RTSP/RTMP 眼镜摄像头画面
//
// 依赖: pod 'MobileVLCKit' (videolan/vlc-ios)
// 低延迟参数:
//   --network-caching=150 (网络缓冲上限 150ms)
//   --clock-jitter=0, --clock-synchro=0 (禁用帧同步平滑)
//   --skip-frames (丢弃迟到帧以追上当前实时帧)

import AVFoundation
import Foundation
import UIKit

// MARK: - 视频帧输出协议
protocol VLCStreamOutput: AnyObject, Sendable {
    /// 接收解码后的 CVPixelBuffer 帧
    func vlcStream(_ manager: VLCStreamManager, didOutput pixelBuffer: CVPixelBuffer)
    /// 流连接状态变化
    func vlcStream(_ manager: VLCStreamManager, didChangeState isConnected: Bool)
    /// 错误回调
    func vlcStream(_ manager: VLCStreamManager, didEncounterError error: Error)
}

// MARK: - 视频流管理器
final class VLCStreamManager: NSObject {

    // MARK: - 属性
    weak var output: VLCStreamOutput?

    private let streamURL: URL
    private let mediaPlayer: VLCMediaPlayer

    // 帧提取链路
    private let videoOutputQueue = DispatchQueue(
        label: "com.smartglasses.vlc.output",
        qos: .userInitiated
    )

    private var isStreaming = false

    // MARK: - 初始化
    /// - Parameter url: RTSP 或 RTMP 流地址 (如 rtsp://192.168.1.100:554/live)
    init(streamURL: URL) {
        self.streamURL = streamURL
        self.mediaPlayer = VLCMediaPlayer(options: Self.lowLatencyOptions)
        super.init()
        setupMediaPlayer()
    }

    // MARK: - 低延迟配置
    private static let lowLatencyOptions: [String] = [
        "--network-caching=\(Constants.VideoPipeline.networkCaching)",
        "--clock-jitter=0",
        "--clock-synchro=0",
        "--skip-frames",
        // 进一步降低延迟
        "--live-caching=50",
        "--tcp-caching=50",
        "--rtsp-caching=50",
        "--no-audio",
        "--no-osd",
        "--no-video-title-show",
    ]

    // MARK: - 设置媒体播放器
    private func setupMediaPlayer() {
        let media = VLCMedia(url: streamURL)
        media.addOptions([
            "network-caching": String(Constants.VideoPipeline.networkCaching),
        ])
        mediaPlayer.media = media
        mediaPlayer.delegate = self
        mediaPlayer.drawable = NSNull() // 不关联 UIView，纯帧提取模式
    }

    // MARK: - 生命周期控制
    func startStream() {
        guard !isStreaming else { return }
        isStreaming = true
        videoOutputQueue.async { [weak self] in
            self?.mediaPlayer.play()
        }
    }

    func stopStream() {
        guard isStreaming else { return }
        isStreaming = false
        videoOutputQueue.async { [weak self] in
            self?.mediaPlayer.stop()
        }
    }

    var isPlaying: Bool { mediaPlayer.isPlaying }
}

// MARK: - VLCMediaPlayerDelegate
extension VLCStreamManager: VLCMediaPlayerDelegate {

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        let state = mediaPlayer.state
        let connected: Bool
        switch state {
        case .playing, .paused:
            connected = true
        default:
            connected = false
        }
        output?.vlcStream(self, didChangeState: connected)
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        // VLC 的 drawable 设为 NSNull 时通过此回调自行提取帧
        // 实际帧提取策略：VLC 渲染回调通过 CVPixelBuffer
        // 注意: VLCKit 在不同版本中提取 CVPixelBuffer 的方式不同
        // 以下使用通用的 libvlc 视频帧回调内存拷贝方式
        extractCurrentFrame()
    }

    // MARK: - 帧提取
    private func extractCurrentFrame() {
        guard let videoSize = mediaPlayer.videoSize,
              videoSize.width > 0, videoSize.height > 0 else { return }

        // 从 VLC 内存中提取 BGRA 帧数据
        // VLCMediaPlayer 提供 videoSnapshot 方法获取 UIImage，
        // 但在高帧率下性能不足。推荐的做法是使用 libvlc_video_set_callbacks
        // 自行注册帧回调。这里保留两个策略：

        // 策略 A: 通过 VLCVideoView 的 CVPixelBuffer 渲染路径（需 VLCKit >= 4.0）
        // 策略 B: 通过 videoSnapshot 降级方案（兼容旧版本 VLCKit）

        // 由于 MobileVLCKit 3.x 不直接暴露 CVPixelBuffer，
        // 真实项目中应使用 VLCKit 4.x 的 VLCVideoView 或 libvlc_video_set_callbacks。
        // 以下为示例标注，实际部署需根据 VLCKit 版本调整。
        #warning("""
        生产部署说明：
        1. VLCKit 4.x: 使用 VLCVideoView 的 pixelBuffer 属性直接获取 CVPixelBuffer
        2. VLCKit 3.x: 使用 libvlc_video_set_callbacks + libvlc_video_set_format 自定义帧回调
        3. 在 VLCFrameExtractor 中实现帧拷贝到 CVPixelBufferPool
        """)
    }
}

// MARK: - VLC 状态包装
extension VLCMediaPlayerState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .stopped:       return "stopped"
        case .opening:       return "opening"
        case .buffering:     return "buffering"
        case .playing:       return "playing"
        case .paused:        return "paused"
        case .error:         return "error"
        case .esAdded:       return "esAdded"
        case .ended:         return "ended"
        @unknown default:    return "unknown(\(rawValue))"
        }
    }
}
