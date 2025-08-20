import Foundation
import SocketIO
import Combine
import Network

class WebSocketManager {
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    private var isNetworkAvailable = true
    private var manager: SocketManager?
    var socket: SocketIOClient?
    private let tripId: Int
    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    private var isConnecting = false
    private static var sharedManagers: [Int: (manager: WebSocketManager, refCount: Int)] = [:]
    private var retryCount = 0
    private let maxRetries = 5
    private var lastConnectionAttempt: Date?
    private var hasJoinedTrip = false // Theo dõi trạng thái joinTrip
    
    enum WebSocketMessage {
        case connected
        case disconnected(String, UInt16)
        case message([String: Any])
        case error(Error?)
    }
    
    var messagePublisher: AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    init(tripId: Int) {
        self.tripId = tripId
        print("🚀 Khởi tạo WebSocketManager cho tripId=\(tripId)")
        
        // Theo dõi trạng thái mạng
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            print("📡 Trạng thái mạng: \(isAvailable ? "Có kết nối" : "Mất kết nối")")
            self?.isNetworkAvailable = isAvailable
            if !isAvailable {
                self?.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mất kết nối mạng"])))
                self?.disconnect()
            }
        }
        networkMonitor.start(queue: queue)
        
        setupSocket()
    }
    
    deinit {
        networkMonitor.cancel()
        disconnect()
        print("🗑️ WebSocketManager deinit")
    }
    
    static func shared(for tripId: Int) -> WebSocketManager {
            if let existing = sharedManagers[tripId] {
                sharedManagers[tripId] = (existing.manager, existing.refCount + 1)
                print("📋 Sử dụng WebSocketManager chia sẻ cho tripId=\(tripId), refCount=\(existing.refCount + 1)")
                return existing.manager
            } else {
                let newManager = WebSocketManager(tripId: tripId)
                sharedManagers[tripId] = (newManager, 1)
                print("🚀 Tạo mới WebSocketManager chia sẻ cho tripId=\(tripId)")
                return newManager
            }
        }

        static func release(for tripId: Int) {
            if let existing = sharedManagers[tripId] {
                let newCount = existing.refCount - 1
                if newCount <= 0 {
                    existing.manager.disconnect()
                    sharedManagers.removeValue(forKey: tripId)
                    print("🗑️ Đã release và deinit WebSocketManager cho tripId=\(tripId)")
                } else {
                    sharedManagers[tripId] = (existing.manager, newCount)
                    print("📋 Release WebSocketManager cho tripId=\(tripId), refCount còn lại=\(newCount)")
                }
            }
        }
    
    private func setupSocket() {
        guard let url = URL(string: "https://travel-api-79ct.onrender.com") else {
            print("❌ URL Socket.IO không hợp lệ")
            messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL Socket.IO không hợp lệ"])))
            return
        }

        manager = SocketManager(socketURL: url, config: [
            .log(true),
            .compress,
            .reconnects(true),
            .reconnectAttempts(maxRetries),
            .reconnectWait(5),
            .connectParams(["token": UserDefaults.standard.string(forKey: "authToken") ?? ""])
        ])
        socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            print("✅ Socket.IO đã kết nối")
            self.isConnecting = false
            self.retryCount = 0
            self.lastConnectionAttempt = nil
            self.messageSubject.send(.connected)
            self.sendJoinTripIfConnected()
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            guard let self = self else { return }
            print("❌ Socket.IO ngắt kết nối")
            self.isConnecting = false
            self.hasJoinedTrip = false
            self.messageSubject.send(.disconnected("Disconnected", 0))
            self.retryConnection()
        }
        
        socket?.on(clientEvent: .error) { [weak self] data, ack in
            guard let self = self else { return }
            print("❌ Lỗi Socket.IO: \(data)")
            self.isConnecting = false
            self.hasJoinedTrip = false
            self.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi Socket.IO: \(data)"])))
            self.retryConnection()
        }
        
        // Lắng nghe các sự kiện tùy chỉnh từ server
        socket?.on("newActivity") { [weak self] data, ack in
            guard let self = self, let json = data.first as? [String: Any] else {
                print("❌ Lỗi: Không thể phân tích dữ liệu newActivity")
                self?.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu newActivity không hợp lệ"])))
                return
            }
            print("📥 Nhận tin nhắn newActivity: \(json)")
            self.messageSubject.send(.message(["event": "newActivity", "data": json]))
        }
        
        socket?.on("updateActivity") { [weak self] data, ack in
            guard let self = self, let json = data.first as? [String: Any] else {
                print("❌ Lỗi: Không thể phân tích dữ liệu updateActivity")
                self?.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu updateActivity không hợp lệ"])))
                return
            }
            print("📥 Nhận tin nhắn updateActivity: \(json)")
            self.messageSubject.send(.message(["event": "updateActivity", "data": json]))
        }
        
        socket?.on("deleteActivity") { [weak self] data, ack in
            guard let self = self, let json = data.first as? [String: Any] else {
                print("❌ Lỗi: Không thể phân tích dữ liệu deleteActivity")
                self?.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu deleteActivity không hợp lệ"])))
                return
            }
            print("📥 Nhận tin nhắn deleteActivity: \(json)")
            self.messageSubject.send(.message(["event": "deleteActivity", "activityId": json["activityId"] ?? 0, "tripDayId": json["tripDayId"] ?? 0]))
        }
        
        socket?.on("newParticipant") { [weak self] data, ack in
            guard let self = self, let json = data.first as? [String: Any] else {
                print("❌ Lỗi: Không thể phân tích dữ liệu newParticipant")
                self?.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu newParticipant không hợp lệ"])))
                return
            }
            print("📥 Nhận tin nhắn newParticipant: \(json)")
            self.messageSubject.send(.message(["event": "newParticipant", "data": json]))
        }
        
        socket?.on("updateParticipant") { [weak self] data, ack in
            guard let self = self, let json = data.first as? [String: Any] else {
                print("❌ Lỗi: Không thể phân tích dữ liệu updateParticipant")
                self?.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu updateParticipant không hợp lệ"])))
                return
            }
            print("📥 Nhận tin nhắn updateParticipant: \(json)")
            self.messageSubject.send(.message(["event": "updateParticipant", "data": json]))
        }
        
        socket?.on("deleteParticipant") { [weak self] data, ack in
            guard let self = self, let json = data.first as? [String: Any] else {
                print("❌ Lỗi: Không thể phân tích dữ liệu deleteParticipant")
                self?.messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu deleteParticipant không hợp lệ"])))
                return
            }
            print("📥 Nhận tin nhắn deleteParticipant: \(json)")
            self.messageSubject.send(.message(["event": "deleteParticipant", "data": json]))
        }
    }
    
    func connect() {
        guard isNetworkAvailable else {
            print("⚠️ Không có kết nối mạng, bỏ qua kết nối WebSocket, tripId=\(tripId)")
            messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không có kết nối mạng"])))
            return
        }
        guard !isConnecting, retryCount < maxRetries else {
            print("⚠️ Đang kết nối hoặc vượt quá số lần thử: \(retryCount)/\(maxRetries), tripId=\(tripId)")
            return
        }
        
        if let lastAttempt = lastConnectionAttempt, Date().timeIntervalSince(lastAttempt) < 5 {
            print("⚠️ Kết nối quá nhanh, bỏ qua, tripId=\(tripId)")
            return
        }
        
        isConnecting = true
        lastConnectionAttempt = Date()
       
        socket?.connect(timeoutAfter: 20) { [weak self] in
            print("❌ Hết thời gian kết nối Socket.IO cho tripId=\(self?.tripId ?? 0)")
            self?.isConnecting = false
            self?.retryConnection()
        }
    }
    
    func disconnect() {
        if socket?.status == .connected, hasJoinedTrip {
            socket?.emit("leaveTrip", tripId)
            print("📤 Đã emit leaveTrip: \(tripId)")
        }
        socket?.disconnect()
        socket = nil
        manager = nil
        isConnecting = false
        retryCount = 0
        hasJoinedTrip = false
        print("🔌 Ngắt kết nối Socket.IO")
    }
    
    private func sendJoinTripIfConnected() {
        guard socket?.status == .connected else {
            
            return
        }
        guard !hasJoinedTrip else {
            print("⚠️ Đã tham gia phòng tripId=\(tripId), bỏ qua joinTrip")
            return
        }
        socket?.emit("joinTrip", tripId)
        hasJoinedTrip = true
        
    }
    
    private func retryConnection() {
        guard retryCount < maxRetries else {
            print("❌ Vượt quá số lần thử kết nối lại: \(retryCount)/\(maxRetries), tripId=\(tripId)")
            messageSubject.send(.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể kết nối lại Socket.IO"])))
            return
        }
        retryCount += 1
        print("🔄 Thử kết nối lại Socket.IO (lần \(retryCount)/\(maxRetries), tripId=\(tripId))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.connect()
        }
    }
}
