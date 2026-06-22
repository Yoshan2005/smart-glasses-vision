// EmergencyDispatchService.swift
// Module 5: 自动救援路由 - 使用 Alamofire 发送紧急载荷并启动 RTMP 直播
//
// 功能:
// 1. 发送 GPS + 时间戳 + 救援状态到医疗调度后端
// 2. 指数退避重试机制确保弱网环境送达
// 3. 服务端确认后启动 RTMP 直播推流

import Alamofire
import CoreLocation
import Foundation

// MARK: - 救援载荷
struct EmergencyPayload: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let timestamp: TimeInterval
    let userID: String
    let distressState: String = "FALL_DETECTED_AUTOMATED"
    let deviceInfo: String

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timestamp
        case userID = "user_id"
        case distressState = "distress_state"
        case deviceInfo = "device_info"
    }
}

// MARK: - 服务端确认响应
struct DispatchResponse: Codable, Sendable {
    let status: String
    let dispatchID: String
    let livestreamToken: String?

    enum CodingKeys: String, CodingKey {
        case status
        case dispatchID = "dispatch_id"
        case livestreamToken = "livestream_token"
    }
}

// MARK: - 救援分发服务
final class EmergencyDispatchService: NSObject, CLLocationManagerDelegate {

    // MARK: - 枚举
    enum DispatchError: Error, LocalizedError {
        case locationUnavailable
        case networkFailed(String)
        case serverRejected(String)

        var errorDescription: String? {
            switch self {
            case .locationUnavailable: return "无法获取位置信息"
            case .networkFailed(let msg): return "网络请求失败: \(msg)"
            case .serverRejected(let msg): return "服务器拒绝: \(msg)"
            }
        }
    }

    enum DispatchState: Sendable {
        case idle
        case locating
        case dispatching
        case streaming
        case completed
        case failed(Error)
    }

    // MARK: - 属性和流
    private let locationManager = CLLocationManager()
    private let session: Session
    private let endpointURL: URL
    private let liveStreamURL: URL
    private var currentLocation: CLLocation?

    var state: Observable<DispatchState> {
        stateSubject.asObservable()
    }
    private let stateSubject = BehaviorSubject<DispatchState>(value: .idle)

    // Solos SDK 的 RTMP 直播推流器 (生产替换)
    // private var liveStreamer: SolosLiveStreamer?

    // MARK: - 初始化
    init(
        endpointURL: URL = URL(string: Constants.Emergency.dispatchEndpoint)!,
        liveStreamURL: URL = URL(string: Constants.Emergency.liveStreamEndpoint)!
    ) {
        self.endpointURL = endpointURL
        self.liveStreamURL = liveStreamURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        self.session = Session(configuration: configuration)

        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - 触发救援
    func triggerEmergency(userID: String) {
        stateSubject.onNext(.locating)
        locationManager.requestLocation()
        // 实际用户 ID 由外部传入或从 Keychain 读取
        currentUserID = userID
    }

    private var currentUserID: String = ""

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        sendEmergencyPayload(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        stateSubject.onNext(.failed(DispatchError.locationUnavailable))
    }

    // MARK: - 发送载荷 (Alamofire + 指数退避)
    private func sendEmergencyPayload(location: CLLocation) {
        stateSubject.onNext(.dispatching)

        let payload = EmergencyPayload(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date().timeIntervalSince1970,
            userID: currentUserID,
            deviceInfo: UIDevice.current.model + " iOS " + UIDevice.current.systemVersion
        )

        let retryInterceptor = RetryInterceptor()

        session.request(
            endpointURL,
            method: .post,
            parameters: payload,
            encoder: JSONParameterEncoder.default,
            interceptor: retryInterceptor
        )
        .validate()
        .responseDecodable(of: DispatchResponse.self) { [weak self] response in
            guard let self else { return }
            switch response.result {
            case .success(let dispatchResponse):
                if dispatchResponse.status == "acknowledged" {
                    startLiveStream(token: dispatchResponse.livestreamToken ?? "")
                } else {
                    stateSubject.onNext(.failed(
                        DispatchError.serverRejected(dispatchResponse.status)
                    ))
                }
            case .failure(let error):
                stateSubject.onNext(.failed(
                    DispatchError.networkFailed(error.localizedDescription)
                ))
            }
        }
    }

    // MARK: - 启动 RTMP 直播
    private func startLiveStream(token: String) {
        stateSubject.onNext(.streaming)
        // 生产代码: 调用 Solos SDK Live 推流
        // let streamURL = liveStreamURL.appendingPathComponent(token)
        // liveStreamer?.startStreaming(to: streamURL, with: token) { [weak self] result in
        //     switch result {
        //     case .success:
        //         self?.stateSubject.onNext(.completed)
        //     case .failure(let error):
        //         self?.stateSubject.onNext(.failed(error))
        //     }
        // }

        // 占位: 模拟推流成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.stateSubject.onNext(.completed)
        }
    }

    func cancelEmergency() {
        stateSubject.onNext(.idle)
    }
}

// MARK: - 自定义指数退避拦截器
private final class RetryInterceptor: RequestInterceptor {
    private var retryCount = 0
    private let maxRetryCount = Constants.Emergency.maxRetryCount
    private let baseDelay = Constants.Emergency.retryBaseDelay

    func retry(
        _ request: Alamofire.Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard retryCount < maxRetryCount else {
            completion(.doNotRetry)
            return
        }
        retryCount += 1
        let delay = baseDelay * pow(2.0, Double(retryCount - 1))
        completion(.retryWithDelay(delay))
    }
}
