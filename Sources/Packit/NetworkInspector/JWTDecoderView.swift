import SwiftUI

struct JWTDecoderView: View {
    let token: String
    
    var body: some View {
        VStack {
            if let payload = decodeJWTPayload(token: token) {
                JSONViewer(jsonString: payload)
                    .padding()
            } else {
                
                Text("Invalid JWT Token")
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .navigationTitle("Decoded JWT")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func decodeJWTPayload(token: String) -> String? {
        let components = token.split(separator: ".")
        guard components.count >= 2 else { return nil }
        
        let payloadSegment = String(components[1])
        return base64UrlDecode(payloadSegment)
    }
    
    func base64UrlDecode(_ value: String) -> String? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            base64 += padding
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
