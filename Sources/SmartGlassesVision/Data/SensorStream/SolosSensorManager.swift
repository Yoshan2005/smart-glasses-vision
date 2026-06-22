// SolosSensorManager.swift
// Solos AirGo V2 传感器服务具体实现
//
// 桥接 Solos iOS SDK (硬件层) 到 RxSwift 数据流管道。
// 实际开发中需集成 Solos SDK framework 并实现 BLE/WiFi 连接协议。

import CoreMotion
import Foundation
import RxSwift

/// Solos AirGo V2 IMU 传感器管理器
///
/// 通过 Solos SDK 的 BLE 通道接收眼镜端 IMU 数据。
/// 当前实现使用 iOS 内部 CMMotionManager 作为模拟占位，
/// 实际对接时替换为 Solos SDK 的原生数据回调。
final class SolosSensorManager: NSObject, SensorServiceProtocol {

    // MARK: - RxSwift 数据流
    private let sensorDataSubject = PublishSubject<SensorDataPacket>()
    private let gestureEventSubject = PublishSubject<GestureEvent>()
    private let connectionStateSubject = BehaviorSubject<SensorConnectionState>(
        value: .disconnected
    )

    var sensorDataStream: Observable<SensorDataPacket> {
        sensorDataSubject.asObservable()
    }

    var gestureEventStream: Observable<GestureEvent> {
        gestureEventSubject.asObservable()
    }

    var connectionStateStream: Observable<SensorConnectionState> {
        connectionStateSubject.asObservable()
    }

    var currentState: SensorConnectionState {
        (try? connectionStateSubject.value()) ?? .disconnected
    }

    // MARK: - 内部状态
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private let disposeBag = DisposeBag()
    private let throttleInterval = RxTimeInterval.milliseconds(
        Constants.FallDetection.sensorThrottleMs
    )

    // Solos SDK 相关 (实际需集成)
    // private var solosDevice: SolosGlassesDevice?

    // MARK: - 初始化
    override init() {
        motionQueue.name = "com.smartglasses.sensor.motion"
        motionQueue.maxConcurrentOperationCount = 1
        super.init()
    }

    // MARK: - 传感器控制
    func startSensing() throws {
        connectionStateSubject.onNext(.connecting)

        // ---- 实际生产替换 ----
        // Solos SDK 连接示例:
        // solosDevice?.startIMUStream(
        //     frequency: .hz100,
        //     onData: { [weak self] packet in
        //         self?.handleSolosIMUPacket(packet)
        //     },
        //     onGesture: { [weak self] gesture in
        //         self?.handleGesture(gesture)
        //     }
        // )

        // ---- 开发模拟占位 ----
        guard motionManager.isDeviceMotionAvailable else {
            connectionStateSubject.onNext(.error(
                NSError(domain: "SolosSensor", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "设备运动数据不可用"])
            ))
            return
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0 // 100Hz
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self, let motion else {
                if let error { self?.connectionStateSubject.onNext(.error(error)) }
                return
            }
            let packet = SensorDataPacket(
                timestamp: motion.timestamp,
                accelerometer: AccelerometerData(
                    x: motion.userAcceleration.x,
                    y: motion.userAcceleration.y,
                    z: motion.userAcceleration.z
                ),
                gyroscope: GyroscopeData(
                    x: motion.rotationRate.x,
                    y: motion.rotationRate.y,
                    z: motion.rotationRate.z
                )
            )
            sensorDataSubject.onNext(packet)
        }

        connectionStateSubject.onNext(.connected)
    }

    func stopSensing() {
        motionManager.stopDeviceMotionUpdates()
        connectionStateSubject.onNext(.disconnected)
    }

    // MARK: - Solos SDK 桥接方法 (生产替换占位)
    private func handleSolosIMUPacket(_ packet: SensorDataPacket) {
        sensorDataSubject.onNext(packet)
    }

    func injectGesture(_ gesture: GestureEvent) {
        gestureEventSubject.onNext(gesture)
    }
}
