import SwiftUI

struct RequestDiffView: View {
    let transaction1: NetworkTransaction
    let transaction2: NetworkTransaction
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Comparing Requests")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Original")
                            .font(.subheadline.bold())
                        Text(transaction1.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        diffSection(title: "URL", val1: transaction1.request.url?.absoluteString, val2: transaction2.request.url?.absoluteString, showOriginal: true)
                        diffSection(title: "Method", val1: transaction1.request.httpMethod, val2: transaction2.request.httpMethod, showOriginal: true)
                        
                        Text("Headers").font(.headline).padding(.top)
                        if let headers = transaction1.request.allHTTPHeaderFields {
                            ForEach(headers.sorted(by: >), id: \.key) { key, value in
                                let val2 = transaction2.request.allHTTPHeaderFields?[key]
                                diffSection(title: key, val1: value, val2: val2, showOriginal: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("Compared To")
                            .font(.subheadline.bold())
                        Text(transaction2.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        diffSection(title: "URL", val1: transaction1.request.url?.absoluteString, val2: transaction2.request.url?.absoluteString, showOriginal: false)
                        diffSection(title: "Method", val1: transaction1.request.httpMethod, val2: transaction2.request.httpMethod, showOriginal: false)
                        
                        Text("Headers").font(.headline).padding(.top)
                        if let headers = transaction2.request.allHTTPHeaderFields {
                            ForEach(headers.sorted(by: >), id: \.key) { key, value in
                                let val1 = transaction1.request.allHTTPHeaderFields?[key]
                                diffSection(title: key, val1: val1, val2: value, showOriginal: false)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        }
        .navigationTitle("Diff")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    func diffSection(title: String, val1: String?, val2: String?, showOriginal: Bool) -> some View {
        let isDifferent = val1 != val2
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if showOriginal {
                Text(val1 ?? "nil")
                    .font(.footnote)
                    .foregroundColor(isDifferent ? .red : .primary)
                    .background(isDifferent ? Color.red.opacity(0.1) : Color.clear)
            } else {
                Text(val2 ?? "nil")
                    .font(.footnote)
                    .foregroundColor(isDifferent ? .green : .primary)
                    .background(isDifferent ? Color.green.opacity(0.1) : Color.clear)
            }
        }
        .padding(.vertical, 2)
    }
}
