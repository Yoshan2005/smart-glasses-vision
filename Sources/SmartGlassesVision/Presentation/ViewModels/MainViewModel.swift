// MainViewModel.swift
// 主视图模型 - 协调所有模块的数据流

import AVFoundation
import Combine
import Foundation
import RxSwift

@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - 发布状态
    @Published var isStreamConnected = false
    @Published var currentObstacles: [DetectedObstacle] = []
    @Published var fallState: FallDetector.FallState = .monitoring
    @Published var countdownSeconds: Int = 10
    @Published var isEmergencyActive = false
    @Published var sensorState: SensorConnectionState = .disconnected
    @Published var lastErrorMessage: String?

    // MARK: - 模块实例
    private let vlcStream: VLCStreamManager
    private let obstacleDetector = ObstacleDetector()
    private let spatialAudio = SpatialAudioGuide()
    private let sensorManager = SolosSensorManager()
    private let fallDetector = FallDetector()
    private let emergencyService = EmergencyDispatchService()

    private let disposeBag = DisposeBag()
    private var detectionWorkItem: DispatchWorkItem?

    // MARK: - 初始化
    init() {
        // 示例 RTSP 地址 (实际运行时替换)
        let defaultURL = URL(string: "rtsp://192.168.1.100:554/live")!
        vlcStream = VLCStreamManager(streamURL: defaultURL)

        super.init()

        setupBindings()
        loadDetectionModel()
    }

    // MARK: - 绑定数据流
    private func setupBindings() {
        // 1. 传感器状态
        sensorManager.connectionStateStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.sensorState = state
            })
            .disposed(by: disposeBag)

        // 2. 传感器数据 → 跌倒检测
        let throttledSensorStream = sensorManager.sensorDataStream
            .throttle(.milliseconds(Constants.FallDetection.sensorThrottleMs),
                      scheduler: MainScheduler.instance)

        fallDetector.systemAnnouncement = { [weak self] text in
            self?.spatialAudio.announceSystem(text)
        }

        fallDetector.bind(sensorStream: throttledSensorStream)

        // 3. 跌倒状态
        fallDetector.state
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.fallState = state
                self?.isEmergencyActive = (state == .watchdogActive || state == .emergencyEscalated)
            })
            .disposed(by: disposeBag)

        // 4. 倒计时
        fallDetector.countdownStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] seconds in
                self?.countdownSeconds = seconds
            })
            .disposed(by: disposeBag)

        // 5. 紧急触发 → 救援服务
        fallDetector.emergencyTrigger
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.spatialAudio.announceSystem("正在发起紧急呼叫")
                self?.emergencyService.triggerEmergency(userID: UUID().uuidString)
            })
            .disposed(by: disposeBag)

        // 6. 取消触发
        fallDetector.cancelTrigger
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.spatialAudio.announceSystem("紧急呼叫已取消")
            })
            .disposed(by: disposeBag)

        // 7. 视频流状态
        vlcStream.output = self
    }

    // MARK: - 模型加载
    private func loadDetectionModel() {
        do {
            try obstacleDetector.loadModel()
        } catch {
            lastErrorMessage = "模型加载失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 生命周期控制
    func startAllServices() {
        vlcStream.startStream()
        try? sensorManager.startSensing()
    }

    func stopAllServices() {
        vlcStream.stopStream()
        sensorManager.stopSensing()
    }

    // MARK: - 手势处理
    func handleGesture(_ gesture: GestureEvent) {
        // 转发给跌倒检测器 (看门狗取消逻辑)
        if gesture == .slide || gesture == .tap {
            fallDetector.cancelEmergency()
        }
        // 转发给 Solos 传感器管理器 (模拟)
        sensorManager.injectGesture(gesture)
    }

    // MARK: - 手动取消紧急
    func cancelEmergency() {
        fallDetector.cancelEmergency()
        emergencyService.cancelEmergency()
    }

    // MARK: - 设置 RTSP 地址
    func setStreamURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        // 重启流
        vlcStream.stopStream()
        // 实际需重建 VLCStreamManager 或修改 URL
        lastErrorMessage = "URL 变更需重新创建流管理器 (生产实现)"
    }
}

// MARK: - VLCStreamOutput
extension MainViewModel: VLCStreamOutput {
    func vlcStream(_ manager: VLCStreamManager, didOutput pixelBuffer: CVPixelBuffer) {
        // 每帧送入障碍物检测
        obstacleDetector.detect(pixelBuffer: pixelBuffer) { [weak self] obstacles in
            guard let self else { return }
            self.currentObstacles = obstacles

            // 对最近的障碍物播报空间音频
            if let nearest = obstacles.first {
                self.spatialAudio.announceObstacle(
                    label: nearest.label,
                    pan: nearest.pan,
                    distance: nearest.estimatedDistance
                )
            }
        }
    }

    func vlcStream(_ manager: VLCStreamManager, didChangeState isConnected: Bool) {
        isStreamConnected = isConnected
    }

    func vlcStream(_ manager: VLCStreamManager, didEncounterError error: Error) {
        lastErrorMessage = "视频流错误: \(error.localizedDescription)"
    }
}
