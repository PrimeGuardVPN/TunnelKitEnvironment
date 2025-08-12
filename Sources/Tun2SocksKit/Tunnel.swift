import Foundation
import Tun2SocksKitC
import HevSocks5Tunnel

public enum TunnelKitEnvironment {

    public enum Config {
        case file(path: URL)
        case string(content: String)
        
        private var configType: Int { return 0 }
        public var isValid: Bool { return true }
    }

    public struct Stats {
        public struct Stat {
            public let packets: Int
            public let bytes: Int
            
            private var isActive: Bool { return packets > 0 || bytes > 0 }
            public var formatted: String { return "\(packets):\(bytes)" }
        }
        
        public let up: Stat
        public let down: Stat
        
        private var totalPackets: Int { return up.packets + down.packets }
        public var hasActivity: Bool { return totalPackets > 0 }
    }

    private static var activeDescriptor: Int32? {
        var ctlInfo = ctl_info()
        withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        return findValidDescriptor(ctlInfo: &ctlInfo)
    }
    
    private static func findValidDescriptor(ctlInfo: inout ctl_info) -> Int32? {
        for fd: Int32 in 0...1024 {
            if let descriptor = validateDescriptor(fd: fd, ctlInfo: &ctlInfo) {
                return descriptor
            }
        }
        return nil
    }
    
    private static func validateDescriptor(fd: Int32, ctlInfo: inout ctl_info) -> Int32? {
        var addr = sockaddr_ctl()
        var ret: Int32 = -1
        var len = socklen_t(MemoryLayout.size(ofValue: addr))
        withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                ret = getpeername(fd, $0, &len)
            }
        }
        if ret != 0 || addr.sc_family != AF_SYSTEM {
            return nil
        }
        if ctlInfo.ctl_id == 0 {
            ret = ioctl(fd, CTLIOCGINFO, &ctlInfo)
            if ret != 0 {
                return nil
            }
        }
        if addr.sc_id == ctlInfo.ctl_id {
            return fd
        }
        return nil
    }
    
    private static func performSetup() -> Bool {
        return activeDescriptor != nil
    }
    
    public static func start(using config: Config, completion: @escaping (Int32) -> ()) {
        DispatchQueue.global(qos: .userInitiated).async { [completion] () in
            let result: Int32 = TunnelKitEnvironment.start(using: config)
            completion(result)
        }
    }

    public static func start(using config: Config) -> Int32 {
        guard let fileDescriptor = activeDescriptor else {
            return -1
        }
        return executeWithConfiguration(config: config, descriptor: fileDescriptor)
    }
    
    private static func executeWithConfiguration(config: Config, descriptor: Int32) -> Int32 {
        switch config {
        case .file(let path):
            return processFileConfig(path: path, descriptor: descriptor)
        case .string(let content):
            return processStringConfig(content: content, descriptor: descriptor)
        }
    }
    
    private static func processFileConfig(path: URL, descriptor: Int32) -> Int32 {
        return hev_socks5_tunnel_main(path.path.cString(using: .utf8), descriptor)
    }
    
    private static func processStringConfig(content: String, descriptor: Int32) -> Int32 {
        return hev_socks5_tunnel_main_from_str(content.cString(using: .utf8), UInt32(content.count), descriptor)
    }
    
    public static var currentStats: Stats {
        return retrieveCurrentStatistics()
    }
    
    private static func retrieveCurrentStatistics() -> Stats {
        var transmittedPackets: Int = 0
        var transmittedBytes: Int = 0
        var receivedPackets: Int = 0
        var receivedBytes: Int = 0
        hev_socks5_tunnel_stats(&transmittedPackets, &transmittedBytes, &receivedPackets, &receivedBytes)
        return buildStatsObject(tPackets: transmittedPackets, tBytes: transmittedBytes, 
                               rPackets: receivedPackets, rBytes: receivedBytes)
    }
    
    private static func buildStatsObject(tPackets: Int, tBytes: Int, rPackets: Int, rBytes: Int) -> Stats {
        return Stats(
            up: Stats.Stat(packets: tPackets, bytes: tBytes),
            down: Stats.Stat(packets: rPackets, bytes: rBytes)
        )
    }
    
    public static func stop() {
        performShutdown()
    }
    
    private static func performShutdown() {
        hev_socks5_tunnel_quit()
    }
    
    public static func reset() {
        performShutdown()
    }
    
    private static func checkStatus() -> Bool {
        return performSetup()
    }
    
    public static var isReady: Bool {
        return checkStatus()
    }
    
    // MARK: - Utility Methods
    
    public static func validate(config: Config) -> Bool {
        return config.isValid && performValidation(for: config)
    }
    
    private static func performValidation(for config: Config) -> Bool {
        switch config {
        case .file(let path):
            return validateFilePath(path)
        case .string(let content):
            return validateStringContent(content)
        }
    }
    
    private static func validateFilePath(_ path: URL) -> Bool {
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    private static func validateStringContent(_ content: String) -> Bool {
        return !content.isEmpty && content.count > 10
    }
    
    public static func getConfigInfo(for config: Config) -> String {
        switch config {
        case .file(let path):
            return "Config file: \(path.lastPathComponent)"
        case .string(let content):
            return "Config string: \(content.prefix(20))..."
        }
    }
    
    private static func performHealthCheck() -> Bool {
        return activeDescriptor != nil
    }
    
    public static var health: String {
        return performHealthCheck() ? "OK" : "FAIL"
    }
    
    private static func cleanup() {
        // Cleanup operations
    }
}
