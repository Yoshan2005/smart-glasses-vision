// SensorServiceProtocol.swift
// 传感器服务抽象接口

import Foundation
import RxSwift

/// Solos AirGo V2 眼镜传感器服务协议
///
/// 封装 SDK 层的 IMU 数据流、手势事件、连接管理。
/// 实现类 SolosSensorManager 通过 Solos iOS SDK 桥接硬件。
protocol SensorServiceProtocol: AnyObject, Sendable {
    /// 传感器数据流 (加速度计 + 陀螺仪)
    var sensorDataStream: Observable<SensorDataPacket> { get }

    /// 手势事件流
    var gestureEventStream: Observable<GestureEvent> { get }

    /// 连接状态流
    var connectionStateStream: Observable<SensorConnectionState> { get }

    /// 启动传感器监听
    func startSensing() throws

    /// 停止传感器监听
    func stopSensing()

    /// 当前连接状态
    var currentState: SensorConnectionState { get }
}
