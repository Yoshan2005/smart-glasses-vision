// Extensions.swift
// 全局扩展方法

import CoreGraphics
import Foundation

// MARK: - BinaryFloatingPoint 角度转换
extension BinaryFloatingPoint {
    /// 角度转弧度
    var degreesToRadians: Self { self * .pi / 180 }
}

// MARK: - CGSize 工厂
extension CGSize {
    static func square(_ side: CGFloat) -> CGSize {
        CGSize(width: side, height: side)
    }
}
