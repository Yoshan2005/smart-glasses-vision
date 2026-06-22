// Constants.swift
// 全局常量和配置项

import Foundation

enum Constants {

    // MARK: - 视频流水线
    enum VideoPipeline {
        /// VLC 低延迟网络缓存 (ms)
        static let networkCaching: Int = 150
        /// 目标帧率
        static let targetFPS: Double = 18.0
        /// 最大分辨率宽度
        static let maxResolutionWidth: Int = 960
    }

    // MARK: - 障碍物检测
    enum ObstacleDetection {
        /// CoreML 模型名称 (需由 Ultralytics YOLOv8 导出为 CoreML 格式)
        static let modelName: String = "yolov8n"
        /// 模型扩展名
        static let modelExtension: String = "mlmodelc"
        /// 置信度阈值
        static let confidenceThreshold: Float = 0.45
        /// 检测间隔 (秒)，用于节流
        static let detectionInterval: TimeInterval = 0.15
    }

    // MARK: - 空间音频
    enum SpatialAudio {
        /// TTS 语速 (0.0 ~ 1.0)
        static let speechRate: Float = 0.6
    }

    // MARK: - 跌倒检测
    enum FallDetection {
        /// 高冲击 SVM 阈值 (G-Force)
        static let impactThreshold: Double = 3.5
        /// 角度偏移阈值 (度)
        static let angleThreshold: Double = 45.0
        /// 检测时间窗口 (毫秒)
        static let detectionWindowMs: Int = 100
        /// 看门狗等待时间 (秒)
        static let watchdogTimeout: TimeInterval = 10.0
        /// 传感器采样节流 (毫秒)
        static let sensorThrottleMs: Int = 50
    }

    // MARK: - 紧急救援
    enum Emergency {
        /// 救援 API 端点
        static let dispatchEndpoint: String = "https://api.smartglasses-rescue.example.com/v1/emergency"
        /// 直播 RTMP 端点
        static let liveStreamEndpoint: String = "rtmp://live.smartglasses-rescue.example.com/ingest"
        /// 最大重试次数
        static let maxRetryCount: Int = 3
        /// 指数退避基数 (秒)
        static let retryBaseDelay: Double = 2.0
    }
}
