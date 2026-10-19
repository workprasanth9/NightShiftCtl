import Foundation

struct InterfaceAddress {
    let interface: String
    let address: String
}

enum Network {
    /// IPv4 addresses of active, non loopback interfaces.
    static func localAddresses() -> [InterfaceAddress] {
        var result: [InterfaceAddress] = []
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }
        var node: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = node {
            defer { node = entry.pointee.ifa_next }
            let flags = Int32(entry.pointee.ifa_flags)
            guard let addr = entry.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            result.append(InterfaceAddress(interface: name, address: String(cString: host)))
        }
        return result.sorted { $0.interface < $1.interface }
    }

    /// Looks up the public IP address. Only called when the user asks for it.
    static func fetchPublicIP(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.ipify.org") else { completion(nil); return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let ip = data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { completion(ip?.isEmpty == false ? ip : nil) }
        }.resume()
    }
}
