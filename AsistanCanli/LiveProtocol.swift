// Asistan Canlı — Mac'teki Asistan uygulamasıyla ortak protokol
// Bu dosyadaki LiveProtocol, Asistan deposundaki app/MobileBridge.swift ile birebir aynı kalmalı.
// Bağlantı: Bonjour (_asistan-canli._tcp, port 47821) + TLS-PSK (anahtar 8 haneli eşleştirme kodundan türetilir).
// Mesajlar: satır başına bir JSON nesnesi.
//   Mac -> iPhone: hello, state, snapshot, reset, line, pong
//   iPhone -> Mac: note {text}, end, ping

import Foundation
import Network
import Security
import CryptoKit

enum LiveProtocol {
    static let serviceType = "_asistan-canli._tcp"
    static let port: UInt16 = 47821
    static let version = 1

    /// Eşleştirme kodundan TLS-PSK seçenekleri (iki uçta da aynı kod -> aynı anahtar)
    static func tlsOptions(code: String) -> NWProtocolTLS.Options {
        let tls = NWProtocolTLS.Options()
        let key = SymmetricKey(data: Data(code.utf8))
        let psk = Data(HMAC<SHA256>.authenticationCode(for: Data("asistan-canli-v1".utf8), using: key))
        let identity = Data("asistan-canli".utf8)
        let pskData = psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let identityData = identity.withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions,
                                                pskData as __DispatchData, identityData as __DispatchData)
        sec_protocol_options_append_tls_ciphersuite(tls.securityProtocolOptions,
                                                    tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!)
        return tls
    }

    static func parameters(code: String) -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 10
        tcp.keepaliveInterval = 5
        tcp.keepaliveCount = 3
        let p = NWParameters(tls: tlsOptions(code: code), tcp: tcp)
        p.includePeerToPeer = true
        return p
    }

    static func encode(_ obj: [String: Any]) -> Data? {
        guard var d = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        d.append(0x0A)
        return d
    }
}
