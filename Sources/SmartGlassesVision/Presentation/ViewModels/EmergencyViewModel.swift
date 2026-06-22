// EmergencyViewModel.swift
// 紧急救援视图模型

import Foundation
import RxSwift

@MainActor
final class EmergencyViewModel: ObservableObject {

    @Published var state: EmergencyDispatchService.DispatchState = .idle
    @Published var countdownSeconds: Int = 10
    @Published var isEmergencyActive = false

    private let emergencyService: EmergencyDispatchService
    private let fallDetector: FallDetector
    private let disposeBag = DisposeBag()

    init(
        emergencyService: EmergencyDispatchService,
        fallDetector: FallDetector
    ) {
        self.emergencyService = emergencyService
        self.fallDetector = fallDetector

        bind()
    }

    private func bind() {
        // 紧急救援状态
        emergencyService.state
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.state = state
            })
            .disposed(by: disposeBag)

        // 倒计时
        fallDetector.countdownStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] sec in
                self?.countdownSeconds = sec
            })
            .disposed(by: disposeBag)

        // 紧急激活
        fallDetector.state
            .map { state in
                if case .watchdogActive = state { return true }
                if case .emergencyEscalated = state { return true }
                return false
            }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] active in
                self?.isEmergencyActive = active
            })
            .disposed(by: disposeBag)
    }

    func cancel() {
        fallDetector.cancelEmergency()
        emergencyService.cancelEmergency()
    }
}
