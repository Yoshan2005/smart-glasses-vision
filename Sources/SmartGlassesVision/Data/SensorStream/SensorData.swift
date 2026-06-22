// SensorData.swift
// 传感器数据类型定义

import Foundation

// MARK: - IMU 数据包
struct SensorDataPacket: Sendable, Equatable {
    let timestamp: TimeInterval
    let accelerometer: AccelerometerData
    let gyroscope: GyroscopeData
}

struct AccelerometerData: Sendable, Equatable {
    let x: Double
    let y: Double
    let z: Double
}

struct GyroscopeData: Sendable, Equatable {
    let x: Double
    let y: Double
    let z: Double
}

// MARK: - 手势事件
enum GestureEvent: Sendable, Equatable {
    /// 触摸滑条滑动
    case slide
    /// 虚拟按钮点击
    case tap
    /// 双击
    case doubleTap
    /// 长按
    case longPress
    /// 未知手势
    case unknown(Int)
}

// MARK: - 传感器状态
enum SensorConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case error(Error)

    static func == (lhs: SensorConnectionState, rhs: SensorConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.connecting, .connecting): return true
        case (.connected, .connected): return true
        case (.error, .error): return true
        default: return false
        }
    }
}
