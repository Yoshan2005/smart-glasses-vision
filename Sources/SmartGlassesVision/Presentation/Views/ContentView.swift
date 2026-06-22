// ContentView.swift
// 主内容视图 - 融合视频预览 / 障碍物信息 / 紧急覆盖层

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部状态栏
                statusBar
                    .padding(.horizontal)

                // 视频预览区域 (VLC 渲染层)
                CameraFeedView()
                    .frame(maxHeight: .infinity)

                // 障碍物信息面板
                obstaclePanel
                    .padding()
            }

            // 紧急覆盖层
            if viewModel.isEmergencyActive {
                EmergencyOverlayView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isEmergencyActive)
        .onAppear {
            viewModel.startAllServices()
        }
        .onDisappear {
            viewModel.stopAllServices()
        }
        .alert("提示", isPresented: .init(
            get: { viewModel.lastErrorMessage != nil },
            set: { if ! { viewModel.lastErrorMessage = nil } }
        )) {
            Text(viewModel.lastErrorMessage ?? "")
        }
    }

    // MARK: - 状态栏
    private var statusBar: some View {
        HStack {
            // 视频流状态
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isStreamConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isStreamConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // 传感器状态
            HStack(spacing: 6) {
                Circle()
                    .fill(sensorColor)
                    .frame(width: 8, height: 8)
                Text(sensorLabel)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // 障碍物数量
            Text("\(viewModel.currentObstacles.count) 个障碍物")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }

    private var sensorColor: Color {
        switch viewModel.sensorState {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        case .error: return .orange
        }
    }

    private var sensorLabel: String {
        switch viewModel.sensorState {
        case .connected: return "传感器就绪"
        case .connecting: return "连接中"
        case .disconnected: return "未连接"
        case .error: return "传感器错误"
        }
    }

    // MARK: - 障碍物面板
    private var obstaclePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.currentObstacles.isEmpty {
                Text("前方无障碍物")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.currentObstacles.prefix(5)) { obstacle in
                            ObstacleBadge(obstacle: obstacle)
                        }
                    }
                }
            }
        }
        .frame(height: 44)
    }
}

// MARK: - 障碍物标签
struct ObstacleBadge: View {
    let obstacle: DetectedObstacle

    var body: some View {
        HStack(spacing: 4) {
            Text(obstacle.label)
                .font(.caption2.weight(.semibold))

            Text(directionArrow)
                .font(.caption2)

            Text("\(Int(obstacle.confidence * 100))%")
                .font(.caption2)
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.15))
        .clipShape(Capsule())
    }

    private var directionArrow: String {
        switch obstacle.pan {
        case ..<(-0.33): return "←"
        case (-0.33)...0.33: return "↑"
        default: return "→"
        }
    }
}
