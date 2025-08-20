class WebSocketService {
    static let shared = WebSocketService()
    private var managers: [Int: WebSocketManager] = [:]
    
    func connect(tripId: Int) {
        if managers[tripId] == nil {
            managers[tripId] = WebSocketManager(tripId: tripId)
        }
        managers[tripId]?.connect()
    }
    
    func disconnect(tripId: Int) {
        managers[tripId]?.disconnect()
        managers.removeValue(forKey: tripId)
    }
    
    func manager(for tripId: Int) -> WebSocketManager? {
        return managers[tripId]
    }
}
