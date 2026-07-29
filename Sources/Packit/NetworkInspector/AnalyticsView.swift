import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var store = NetworkStore.shared
    
    var body: some View {
        NavigationStack {
            List(store.averageResponseTimes, id: \.path) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.path)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Text("\(item.count) calls")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    let ms = Int(item.avgDuration * 1000)
                    Text("\(ms) ms avg")
                        .font(.subheadline.bold())
                        .foregroundColor(ms < 100 ? .green : (ms < 500 ? .yellow : .red))
                }
            }
            .navigationTitle("Response Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
