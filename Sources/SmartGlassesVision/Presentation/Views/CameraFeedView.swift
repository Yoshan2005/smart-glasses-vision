// CameraFeedView.swift
// VLC 视频渲染视图 - 使用 UIViewRepresentable 桥接 VLCVideoView

import SwiftUI
import UIKit

/// VLC 视频渲染 SwiftUI 包装
///
/// 实际集成时需使用 VLCVideoView (VLCKit 4.x) 或
/// VLCOpenGLES2VideoView (VLCKit 3.x)。
/// 当前为占位实现，展示黑色预览区域。
struct CameraFeedView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFit

        // ---- 生产替换 ----
        // VLCKit 4.x:
        // let videoView = VLCVideoView()
        // videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // mediaPlayer.drawable = videoView
        // view.addSubview(videoView)

        // VLCKit 3.x:
        // let glView = VLCOpenGLES2VideoView()
        // mediaPlayer.drawable = glView
        // view.addSubview(glView)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 帧率更新等由 VLC 内部渲染循环处理
    }
}
