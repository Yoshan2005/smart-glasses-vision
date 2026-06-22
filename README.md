# SmartGlassesVision

**AI 导盲与紧急救援智能眼镜 — iOS 客户端**

基于 **Solos AirGo V2** 智能眼镜硬件，为视障用户提供实时环境感知、障碍物规避和跌倒自动救援功能。

---

## 系统架构

`
┌─────────────────────────────────────────────────────────┐
│                     Presentation Layer                    │
│  SwiftUI (ContentView / CameraFeedView / EmergencyView) │
├─────────────────────────────────────────────────────────┤
│                     Domain Layer                          │
│  障碍物检测    空间音频导引    跌倒检测 & 看门狗         │
│  (CoreML+Vision)  (AVSpeechSynthesizer)  (RxSwift)      │
├─────────────────────────────────────────────────────────┤
│                       Data Layer                          │
│  VLCStreamManager  SolosSensorManager  EmergencyService  │
│  (MobileVLCKit)     (Solos SDK)        (Alamofire)      │
└─────────────────────────────────────────────────────────┘
`

## 5 大核心模块

| 模块 | 技术栈 | 功能 |
|------|--------|------|
| **视频流水线** | MobileVLCKit | 低延迟 RTSP/RTMP 帧推送到 CVPixelBuffer (≤150ms) |
| **NPU 障碍物检测** | CoreML + Vision (YOLOv8) | Neural Engine 上 <20ms 推理，输出 bounding box + 空间定位 |
| **反向空间音频** | AVSpeechSynthesizer | 立体声 pan 映射障碍物方向，听声辨位 |
| **跌倒检测** | RxSwift + IMU | SVM 冲击检测 + 角度偏移，10 秒手势看门狗 |
| **紧急救援** | Alamofire + CoreLocation | GPS 上传 + 指数退避重试 + RTMP 直播推流 |

---

## 快速开始

### 前置要求

- macOS 14+ (Sonoma)
- Xcode 16+
- CocoaPods 1.15+ (gem install cocoapods)
- iOS 18+ 真机 (需 Apple Neural Engine: A12+)
- Solos AirGo V2 智能眼镜

### 1. 克隆并安装依赖

`ash
# 安装 CocoaPods 依赖 (MobileVLCKit)
pod install

# SPM 依赖 (RxSwift, Alamofire) 在 Xcode 中自动解析
open SmartGlassesVision.xcworkspace
`

### 2. 导出 YOLOv8 CoreML 模型

`ash
# 在 Ultralytics 环境中
yolo export model=yolov8n.pt format=coreml int8=true
# 将生成的 yolov8n.mlpackage 拖入 Xcode 项目
`

### 3. 配置 Solos SDK

将 Solos AirGo V2 iOS SDK 集成到项目中，参考 Solos 官方文档配置 BLE 连接。

### 4. 修改 RTSP 地址

在 MainViewModel.swift 中修改 defaultURL 为您的眼镜 RTSP 流地址。

### 5. 构建 & 运行

- 在 Xcode 中选择您的 iOS 18+ 真机
- Signing & Capabilities 配置您的 Apple Developer Team
- Cmd+R 运行

---

## 项目结构

`
SmartGlassesVision/
├── Sources/SmartGlassesVision/
│   ├── App/                     # 应用入口 & 生命周期
│   │   ├── SmartGlassesVisionApp.swift
│   │   └── AppDelegate.swift
│   ├── Data/                    # 硬件抽象层 (Solos SDK 封装)
│   │   ├── VideoPipeline/       # VLC 低延迟流水线
│   │   ├── SensorStream/        # IMU + 手势传感器
│   │   └── Emergency/           # 救援路由 + 直播
│   ├── Domain/                  # 核心业务逻辑
│   │   ├── ObjectDetection/     # YOLOv8 + Vision 推理
│   │   ├── SpatialAudio/        # 立体声定向导引
│   │   └── FallDetection/       # 跌倒算法 + 看门狗
│   ├── Presentation/            # SwiftUI 界面
│   │   ├── ViewModels/          # 状态管理
│   │   └── Views/               # UI 组件
│   └── Shared/                  # 常量 & 扩展
├── Resources/
│   └── Info.plist
├── Package.swift                 # SPM 依赖
└── README.md
`

## 低延迟配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| --network-caching | 150ms | 网络缓冲上限 |
| --clock-jitter | 0 | 禁用帧同步抖动 |
| --clock-synchro | 0 | 禁用帧同步平滑 |
| --skip-frames | on | 丢弃迟到帧 |
| Detection interval | 150ms | 目标检测推理间隔 |
| Speech rate | 0.6 | TTS 加速播报 |

## 开源依赖

| 库 | 版本 | 用途 |
|----|------|------|
| [vlc-ios](https://github.com/videolan/vlc-ios) | latest | RTSP/RTMP 硬件解码 |
| [Ultralytics](https://github.com/ultralytics/ultralytics) | v8.4.75 | YOLOv8 CoreML 导出 |
| [RxSwift](https://github.com/ReactiveX/RxSwift) | 6.10.2 | 响应式传感器流 |
| [Alamofire](https://github.com/Alamofire/Alamofire) | 5.12.0 | 网络请求 & 重试 |

## 许可证

本项目基于 GPLv2 + MPLv2 许可证。
