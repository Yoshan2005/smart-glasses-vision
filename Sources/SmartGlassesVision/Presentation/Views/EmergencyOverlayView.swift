// EmergencyOverlayView.swift
// 紧急救援覆盖层 - 10 秒倒计时 + 取消按钮

import SwiftUI

struct EmergencyOverlayView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        ZStack {
            // 半透明红色背景
            Color.red.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                // 状态文字
                if case .watchdogActive = viewModel.fallState {
                    VStack(spacing: 8) {
                        Text("检测到跌倒!")
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)

                        Text("\(viewModel.countdownSeconds)")
                            .font(.system(size: 72, weight: .heavy))
                            .foregroundColor(.yellow)
                            .contentTransition(.numericText())

                        Text("秒后将自动发起紧急呼叫")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                } else if case .emergencyEscalated = viewModel.fallState {
                    VStack(spacing: 8) {
                        Text("正在发起紧急救援...")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }

                Spacer().frame(height: 20)

                // 取消按钮
                Button(action: {
                    viewModel.cancelEmergency()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                        Text("取消紧急呼叫")
                            .font(.title3.weight(.semibold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                }

                Text("或触摸眼镜滑条取消")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
        }
    }
}
