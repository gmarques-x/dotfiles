import Darwin
import Foundation

struct TunnelRequest: Codable {
    static let socket = "/Library/PrivilegedHelperTools/com.gmarques.lab-vpn/control.sock"
    static let maximumSize = 131072
    let interface: String
    let configuration: String?

    var validInterface: Bool {
        interface.range(of: #"^lv[0-9a-f]{13}$"#, options: .regularExpression) != nil
    }

    static func setTimeout(_ descriptor: Int32) {
        var timeout = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var enabled: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
    }

    static func read(_ descriptor: Int32, limit: Int) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { return result }
            if count < 0 && errno == EINTR { continue }
            guard count > 0, result.count + count <= limit else {
                throw VPNError("Could not read the Lab VPN helper response or request.")
            }
            result.append(contentsOf: buffer.prefix(count))
        }
    }
}

enum HelperClient {
    static var installed: Bool {
        FileManager.default.fileExists(atPath: TunnelRequest.socket)
    }

    static func perform(_ request: TunnelRequest) throws {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw VPNError("Could not open the Lab VPN control socket.") }
        defer { close(descriptor) }
        TunnelRequest.setTimeout(descriptor)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(TunnelRequest.socket.utf8CString)
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw VPNError("The Lab VPN control socket path is too long.")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path.map(UInt8.init(bitPattern:))) }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard connected == 0, getpeereid(descriptor, &uid, &gid) == 0, uid == 0 else {
            throw VPNError("Could not reach the root-owned Lab VPN service.")
        }
        try FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
            .write(contentsOf: JSONEncoder().encode(request))
        guard shutdown(descriptor, SHUT_WR) == 0 else { throw VPNError("Could not send the tunnel request.") }
        let result = try TunnelRequest.read(descriptor, limit: 1024)
        guard result == Data("OK".utf8) else {
            throw VPNError(String(data: result, encoding: .utf8).flatMap { $0.isEmpty ? nil : $0 } ??
                           "The Lab VPN helper closed the connection.")
        }
    }
}
