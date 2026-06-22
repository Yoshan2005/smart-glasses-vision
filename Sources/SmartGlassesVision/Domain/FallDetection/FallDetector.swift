// FallDetector.swift
// Module 4: 跌倒检测 & 手势看门狗 (RxSwift)
//
// 算法:
// 1. 计算 SVM (Signal Vector Magnitude): A_total = sqrt(Ax^2 + Ay^2 + Az^2)
// 2. 当 A_total > 阈值 (3.5G) 且 角度偏移 > 45° (100ms 窗口内) → 触发"疑似跌倒"
// 3. 启动 10 秒看门狗:
//    - 播报警告
//    - 等待手势取消 (滑条滑动 / 按钮点击)
//    - 超时则触发紧急救援

import Foundation
import RxSwift

/// 跌倒检测 & 手势看门狗控制器
final class FallDetector {

    // MARK: - 状态
    enum FallState: Sendable {
        case monitoring
        case suspiciousFall
        case watchdogActive(remainingSeconds: Int)
        case cancelled
        case emergencyEscalated
    }

    // MARK: - 属性和流
    private let disposeBag = DisposeBag()
    private let stateSubject = BehaviorSubject<FallState>(value: .monitoring)

    var state: Observable<FallState> {
        stateSubject.asObservable()
    }

    var currentState: FallState {
        (try? stateSubject.value()) ?? .monitoring
    }

    /// 看门狗倒计时信号
    let countdownStream = PublishSubject<Int>()

    /// 紧急救援触发信号 (外部监听后调 EmergencyDispatchService)
    let emergencyTrigger = PublishSubject<Void>()

    /// 取消事件信号 (外部监听后关闭看门狗)
    let cancelTrigger = PublishSubject<Void>()

    // 内部状态
    private var watchdogTimer: Disposable?

    // 回调: 语音播报接口 (由外层注入)
    var systemAnnouncement: ((String) -> Void)?

    // MARK: - 绑定传感器流
    /// 绑定传感器数据流启动跌倒检测
    /// - Parameter sensorStream: 经节流的 IMU 数据流
    func bind(sensorStream: Observable<SensorDataPacket>) {
        sensorStream
            .subscribe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] packet in
                self?.analyzeMotion(packet)
            })
            .disposed(by: disposeBag)

        // 手势监听: 任何手势事件在看门狗激活时取消紧急
        // (外部通过 call 方法注入手势事件)
    }

    // MARK: - 运动分析
    private func analyzeMotion(_ packet: SensorDataPacket) {
        // SVM 计算
        let ax = packet.accelerometer.x
        let ay = packet.accelerometer.y
        let az = packet.accelerometer.z
        let svm = sqrt(ax * ax + ay * ay + az * az)

        // 角度估计 (使用重力方向变化)
        let angleChange = abs(atan2(sqrt(ax * ax + az * az), ay)) * (180.0 / .pi)

        // 冲击 + 角度偏移联合判定
        if svm > Constants.FallDetection.impactThreshold
            && angleChange > Constants.FallDetection.angleThreshold {
            handleSuspiciousFall()
        }
    }

    // MARK: - 疑似跌倒处理
    private func handleSuspiciousFall() {
        guard case .monitoring = currentState else { return }

        stateSubject.onNext(.suspiciousFall)

        // ---- 10 秒看门狗协议 ----
        systemAnnouncement?(
            "检测到跌倒。即将在10秒后发起紧急呼叫。请滑动触控条或点击取消按钮取消。"
        )

        stateSubject.onNext(.watchdogActive(remainingSeconds: 10))
        startWatchdog()
    }

    // MARK: - 看门狗倒计时
    private func startWatchdog() {
        watchdogTimer?.dispose()

        var remaining = 10
        watchdogTimer = Observable<Int>
            .interval(.seconds(1), scheduler: MainScheduler.instance)
            .take(until: { [weak self] _ in
                guard let self else { return true }
                // 当状态不再是 watchdogActive 时停止
                if case .watchdogActive = self.currentState {
                    return false
                }
                return true
            })
            .subscribe(onNext: { [weak self] elapsed in
                guard let self else { return }
                remaining = 10 - (elapsed + 1)
                if remaining > 0 {
                    self.stateSubject.onNext(.watchdogActive(remainingSeconds: remaining))
                    self.countdownStream.onNext(remaining)
                } else {
                    // 超时 → 紧急升级
                    self.escalateEmergency()
                }
            })

        watchdogTimer?.disposed(by: disposeBag)
    }

    // MARK: - 手势取消
    /// 外部调用: 用户通过手势取消了紧急
    func cancelEmergency() {
        guard case .watchdogActive = currentState else { return }

        watchdogTimer?.dispose()
        stateSubject.onNext(.cancelled)
        cancelTrigger.onNext(())

        systemAnnouncement?("紧急呼叫已取消")
    }

    // MARK: - 紧急升级
    private func escalateEmergency() {
        watchdogTimer?.dispose()
        stateSubject.onNext(.emergencyEscalated)
        emergencyTrigger.onNext(())
    }

    /// 重置为监控状态
    func reset() {
        watchdogTimer?.dispose()
        stateSubject.onNext(.monitoring)
    }
}
