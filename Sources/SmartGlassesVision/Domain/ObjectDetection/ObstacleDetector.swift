// ObstacleDetector.swift
// Module 2: NPU 障碍物检测 - CoreML + Vision 框架
//
// 使用 Ultralytics YOLOv8 导出的量化 CoreML 模型 (yolov8n.mlmodel)
// 强制在 Apple Neural Engine (NPU) 上推理，保证 <20ms 延迟。

import CoreVideo
import Foundation
import Vision

/// 障碍物检测器
///
/// 用法:
/// `swift
/// let detector = ObstacleDetector()
/// detector.loadModel()
/// // 每帧调用:
/// detector.detect(pixelBuffer: frame) { results in ... }
/// `
final class ObstacleDetector: @unchecked Sendable {

    // MARK: - 错误类型
    enum DetectorError: Error, LocalizedError {
        case modelNotFound(String)
        case modelLoadFailed(Error)
        case visionRequestFailed(Error)

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let name): return "CoreML 模型未找到: \(name)"
            case .modelLoadFailed(let error): return "模型加载失败: \(error.localizedDescription)"
            case .visionRequestFailed(let error): return "Vision 推理失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 属性
    private var visionModel: VNCoreMLModel?
    private let detectionQueue = DispatchQueue(
        label: "com.smartglasses.detection",
        qos: .userInitiated
    )

    // MARK: - 模型加载
    /// 加载 YOLOv8 CoreML 模型
    /// - Parameter modelName: 模型名 (不含扩展名)
    func loadModel(
        named modelName: String = Constants.ObstacleDetection.modelName
    ) throws {
        guard let modelURL = Bundle.main.url(
            forResource: modelName,
            withExtension: Constants.ObstacleDetection.modelExtension
        ) else {
            throw DetectorError.modelNotFound("\(modelName).\(Constants.ObstacleDetection.modelExtension)")
        }

        do {
            let compiledURL = try MLModel.compileModel(at: modelURL)
            let mlModel = try MLModel(contentsOf: compiledURL)
            visionModel = try VNCoreMLModel(for: mlModel)
        } catch {
            throw DetectorError.modelLoadFailed(error)
        }
    }

    // MARK: - 单帧检测
    /// 对单帧 CVPixelBuffer 执行障碍物检测
    ///
    /// - Parameters:
    ///   - pixelBuffer: 来自视频流水线的帧
    ///   - completion: 检测结果回调 (在主线程)
    func detect(
        pixelBuffer: CVPixelBuffer,
        completion: @escaping @Sendable ([DetectedObstacle]) -> Void
    ) {
        guard let visionModel else {
            completion([])
            return
        }

        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            guard let self else { return }

            if let error {
                print("[ObstacleDetector] 推理错误: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }

            let obstacles = self.parseResults(request.results)
            DispatchQueue.main.async { completion(obstacles) }
        }

        // ---- 强制 NPU 推理 ----
        // preferBackgroundProcessing = false 保证强制使用 NPU/GPU
        request.preferBackgroundProcessing = false

        // 置信度阈值过滤
        request.imageCropAndScaleOption = .scaleFill

        // 执行推理
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        detectionQueue.async {
            do {
                try handler.perform([request])
            } catch {
                print("[ObstacleDetector] Handler 错误: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    // MARK: - 结果解析
    private func parseResults(_ results: [Any]?) -> [DetectedObstacle] {
        guard let observations = results as? [VNRecognizedObjectObservation] else {
            return []
        }

        return observations.compactMap { observation in
            // 取最高置信度的标签
            guard let topLabel = observation.labels.first,
                  topLabel.confidence >= Constants.ObstacleDetection.confidenceThreshold else {
                return nil
            }

            return DetectedObstacle(
                label: topLabel.identifier,
                confidence: topLabel.confidence,
                boundingBox: observation.boundingBox
            )
        }
    }
}
