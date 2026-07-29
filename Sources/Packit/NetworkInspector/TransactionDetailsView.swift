import SwiftUI

enum DetailTab: String, CaseIterable {
    case overview = "Overview"
    case request = "Request"
    case response = "Response"
}

struct TransactionDetailsView: View {
    let transaction: NetworkTransaction
    let initialSearchText: String?
    
    @State private var showingCopiedAlert = false
    @State private var selectedTab: DetailTab = .overview
    @State private var searchText = ""
    
    init(transaction: NetworkTransaction, initialSearchText: String? = nil) {
        self.transaction = transaction
        self.initialSearchText = initialSearchText
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Tabs", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            VStack(spacing: 0) {
                switch selectedTab {
                case .overview:
                    List { overviewTab }.listStyle(.insetGrouped)
                case .request:
                    List { requestTab }.listStyle(.insetGrouped)
                case .response:
                    responseTabView
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: selectedTab)
            .searchable(text: $searchText, prompt: "Search payload...")
            .onAppear {
                if let initial = initialSearchText, !initial.isEmpty {
                    // Auto-select response tab as that's where search usually happens
                    selectedTab = .response
                }
            }
        }
        .navigationTitle("Traffic Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
//                Button {
//                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//                    retryRequest()
//                } label: {
//                    Image(systemName: "arrow.triangle.2.circlepath")
//                }
                
                Button {
                    let stringToCopy: String?
                    switch selectedTab {
                    case .overview:
                        stringToCopy = transaction.cURLString
                    case .request:
                        if let reqBody = transaction.request.httpBody, let str = String(data: reqBody, encoding: .utf8) {
                            stringToCopy = str
                        } else {
                            stringToCopy = nil
                        }
                    case .response:
                        if let data = transaction.data, let str = String(data: data, encoding: .utf8) {
                            stringToCopy = str
                        } else {
                            stringToCopy = nil
                        }
                    }
                    
                    if let copyString = stringToCopy {
                        UIPasteboard.general.string = copyString
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showingCopiedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showingCopiedAlert = false }
                        }
                    }
                } label: {
                    if showingCopiedAlert {
                        HStack(spacing: 4) {
                            Text(selectedTab == .overview ? "cURL Copied" : "JSON Copied")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "doc.on.doc")
                            
                    }
                }
            }
        }
    }
    
    // MARK: - Tabs
    
    private var overviewTab: some View {
        Section {
            if transaction.isCacheHit {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Served from Cache")
                }
                .font(.subheadline.bold())
                .foregroundColor(.green)
                .padding(.vertical, 4)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(transaction.request.url?.absoluteString ?? "N/A")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                HStack(alignment: .top) {
                    Text("Method")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(transaction.request.httpMethod ?? "N/A")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                
                if let response = transaction.response as? HTTPURLResponse {
                    HStack(alignment: .top) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        let isSuccess = (200...299).contains(response.statusCode)
                        HStack(spacing: 4) {
                            Circle().fill(isSuccess ? Color.green : Color.red).frame(width: 8, height: 8)
                            Text("\(response.statusCode)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(isSuccess ? .green : .red)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            // Metrics Block
            VStack(alignment: .leading, spacing: 12) {
                if let duration = transaction.duration {
                    HStack {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(String(format: "%.3f s", duration))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                }
                
                if let data = transaction.data {
                    let bytes = data.count
                    HStack {
                        Text("Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    
                    if bytes > 1024 * 1024 {
                        Text("⚠️ Large Payload Detected (\(String(format: "%.1f MB", Double(bytes) / 1048576.0)))")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 4)
            
            if let error = transaction.error {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error").font(.caption.bold()).foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var requestTab: some View {
        Group {
            if let headers = transaction.request.allHTTPHeaderFields, !headers.isEmpty {
                Section {
                    DisclosureGroup("Headers") {
                        ForEach(headers.sorted(by: >), id: \.key) { key, value in
                            if key.lowercased() == "authorization" /*&& value.lowercased().hasPrefix("bearer ")*/ && value.split(separator: ".").count >= 2 {
                                VStack(alignment: .leading, spacing: 4) {
                                    InfoRow(title: key, value: value)
                                    NavigationLink(destination: JWTDecoderView(token: String(value.dropFirst(7)))) {
                                        Text("Decode JWT Payload")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 2)
                            } else {
                                InfoRow(title: key, value: value)
                            }
                        }
                    }
                }
            }
            
            if let reqBody = transaction.request.httpBody, !reqBody.isEmpty {
                if let stringBody = String(data: reqBody, encoding: .utf8) {
                    if let dict = try? JSONSerialization.jsonObject(with: reqBody) as? [String: Any],
                       let query = dict["query"] as? String {
                        Section(header: Text("GraphQL Operation")) {
                            if let opName = dict["operationName"] as? String {
                                InfoRow(title: "Operation Name", value: opName)
                            }
                            Text("Query").font(.caption).foregroundColor(.secondary)
                            Text(query).font(.system(size: 13, design: .monospaced))
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                            
                            if let variables = dict["variables"] as? [String: Any],
                               let varData = try? JSONSerialization.data(withJSONObject: variables),
                               let varString = String(data: varData, encoding: .utf8) {
                                Text("Variables").font(.caption).foregroundColor(.secondary)
                                JSONViewer(jsonString: varString, searchText: searchText.isEmpty ? (initialSearchText ?? "") : searchText)
                                    .frame(minHeight: 300, maxHeight: .infinity)
                            }
                        }
                    } else {
                        Section(header: Text("Body")) {
                            JSONViewer(jsonString: stringBody, searchText: searchText.isEmpty ? (initialSearchText ?? "") : searchText)
                                .frame(minHeight: 300, maxHeight: .infinity)
                        }
                    }
                } else {
                    Section(header: Text("Body")) {
                        Text("\(reqBody.count) bytes of binary data")
                    }
                }
            } else {
                Section {
                    Text("No Request Body").foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var responseTabView: some View {
        VStack(spacing: 0) {
            let headerView = Group {
                if let httpResponse = transaction.response as? HTTPURLResponse,
                   let headers = httpResponse.allHeaderFields as? [String: String], !headers.isEmpty {
                    DisclosureGroup("Response Headers") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(headers.sorted(by: >), id: \.key) { key, value in
                                InfoRow(title: key, value: value)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }
            
            if let data = transaction.data, !data.isEmpty {
                if let response = transaction.response as? HTTPURLResponse,
                   let mimeType = response.mimeType {
                    
                    if mimeType.contains("image") {
                        if let uiImage = UIImage(data: data) {
                            ScrollView {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .padding()
                            }
                        } else {
                            Text("Invalid Image Data").foregroundColor(.secondary)
                        }
                    } else if mimeType.contains("text/html"), let htmlString = String(data: data, encoding: .utf8) {
                        JSONViewer(jsonString: htmlString, searchText: searchText.isEmpty ? (initialSearchText ?? "") : searchText) { headerView }
                            .frame(minHeight: 300, maxHeight: .infinity)
                    } else if let stringBody = String(data: data, encoding: .utf8) {
                        JSONViewer(jsonString: stringBody, searchText: searchText.isEmpty ? (initialSearchText ?? "") : searchText) { headerView }
                            .frame(minHeight: 300, maxHeight: .infinity)
                    } else {
                        VStack {
                            headerView
                            Text("\(data.count) bytes of binary data").foregroundColor(.secondary).padding()
                        }
                    }
                } else if let stringBody = String(data: data, encoding: .utf8) {
                    JSONViewer(jsonString: stringBody, searchText: searchText.isEmpty ? (initialSearchText ?? "") : searchText) { headerView }
                        .frame(minHeight: 300, maxHeight: .infinity)
                } else {
                    VStack {
                        headerView
                        Text("\(data.count) bytes of binary data").foregroundColor(.secondary).padding()
                    }
                }
            } else {
                VStack {
                    headerView
                    Text("No Response Body").foregroundColor(.secondary).padding()
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func retryRequest() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MyURLProtocol.self]
        let session = URLSession(configuration: configuration)
        session.dataTask(with: transaction.request).resume()
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    @State private var showingCopied = false
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = value
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showingCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showingCopied = false
                }
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 8)
                if showingCopied {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "clipboard")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonStyle())
        .padding(.vertical, 4)
    }
}
