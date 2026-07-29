import SwiftUI

struct WaterfallView: View {
    let transaction: NetworkTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let duration = transaction.duration, duration > 0 {
                let total = duration
                
                waterfallRow(title: "DNS Lookup", duration: transaction.dnsDuration ?? 0, total: total, color: .purple)
                waterfallRow(title: "Connect", duration: transaction.connectDuration ?? 0, total: total, color: .orange)
                waterfallRow(title: "TLS Handshake", duration: transaction.tlsDuration ?? 0, total: total, color: .pink)
                waterfallRow(title: "Waiting (TTFB)", duration: transaction.ttfbDuration ?? 0, total: total, color: .blue)
                waterfallRow(title: "Download", duration: transaction.downloadDuration ?? 0, total: total, color: .green)
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.caption.bold())
                    Spacer()
                    Text(String(format: "%.1f ms", total * 1000))
                        .font(.caption.bold())
                }
            } else {
                Text("Waterfall data not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    func waterfallRow(title: String, duration: TimeInterval, total: TimeInterval, color: Color) -> some View {
        if duration > 0 {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                
                GeometryReader { geometry in
                    let ratio = CGFloat(duration / total)
                    Rectangle()
                        .fill(color)
                        .frame(width: max(geometry.size.width * ratio, 2))
                }
                .frame(height: 12)
                
                Text(String(format: "%.1f ms", duration * 1000))
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }
}
