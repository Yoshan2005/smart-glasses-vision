// DetectedObstacle.swift
// 障碍物检测结果模型

import CoreGraphics
import Foundation

/// 检测到的障碍物
struct DetectedObstacle: Sendable, Identifiable, Equatable {
    let id: UUID
    /// 标签 (如 "person", "car", "chair")
    let label: String
    /// 置信度 (0.0 ~ 1.0)
    let confidence: Float
    /// 归一化边界框 (由 VNRecognizedObjectObservation.boundingBox 转换)
    let boundingBox: CGRect

    /// 归一化中心点 X (0.0 ~ 1.0)
    var centerX: CGFloat { boundingBox.midX }

    /// 空间平衡参数 pan [-1.0 (左) ... 0.0 (中) ... +1.0 (右)]
    var pan: Float {
        Float((centerX - 0.5) * 2)
    }

    /// 障碍物距离估计 (基于边框高度做简单判定，实际可用深度传感器)
    var estimatedDistance: Float {
        // 高度越大越近，归一化到 0~1
        let heightRatio = Float(boundingBox.height)
        // 简单映射: 0.1 -> 远, 0.9 -> 近
        let normalized = min(max(heightRatio / 0.6, 0.0), 1.0)
        return 1.0 - normalized
    }

    init(
        id: UUID = UUID(),
        label: String,
        confidence: Float,
        boundingBox: CGRect
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
