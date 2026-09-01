import SwiftUI

enum DetailTab: String, CaseIterable {
    case overview = "Overview"
    case request = "Request"
    case response = "Response"
}

struct TransactionDetailsView: View {
    let transaction: NetworkTransaction
    let initialSearchText: String?
//    @Environment(\.dismiss) private var dismiss

    @State private var showingCopiedAlert = false
    @State private var selectedTab: DetailTab = .overview
    @State private var searchText = ""
    @State private var showHeadersSheet: Bool = false
    @State private var showRequestHeadersSheet: Bool = false
    @State private var searchCommand: JSONSearchCommand? = nil
    
    init(transaction: NetworkTransaction, initialSearchText: String? = nil) {
        self.transaction = transaction
        self.initialSearchText = initialSearchText
    }
    
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    private func activateSearch() {
        if selectedTab == .overview {
            selectedTab = .response
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isSearchActive = true
        }
        isSearchFieldFocused = true
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
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
//                        List { requestTab }.listStyle(.insetGrouped)
                        requestTab
                    case .response:
                        responseTabView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
                .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: selectedTab)
            }

            // Floating search control, bottom-leading
            
            if selectedTab != .overview {
                searchControl
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
            }

            // Hidden keyboard shortcut buttons
            Group {
                Button(action: activateSearch) {
                    EmptyView()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button {
                    searchCommand = .previous
                } label: {
                    EmptyView()
                }
                .keyboardShortcut(.return, modifiers: .shift)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isSearchActive = false
                        searchText = ""
                        isSearchFieldFocused = false
                    }
                } label: {
                    EmptyView()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .navigationTitle("Traffic Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
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
                                .foregroundColor(.teal.opacity(0.8))
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green.opacity(0.6))
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                   Button {
//                       dismiss()
//
//                       // Wait until NetworkInspectorView is visible,
//                       // then tell it to focus the search field.
//                       DispatchQueue.main.async {
//                           NotificationCenter.default.post(
//                               name: Notification.Name("focusGlobalSearch"),
//                               object: nil
//                           )
//                       }
//
//                   } label: {
//                       EmptyView()
//                   }
//                   .keyboardShortcut("f", modifiers: [.command, .shift])
//                   .hidden()
////               }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button {
//                    print("🔥 GLOBAL SHORTCUT FIRED")
//                    print("Current tab: \(selectedTab)")
//
//                    dismiss()
//
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                        NotificationCenter.default.post(
//                            name: Notification.Name("focusGlobalSearch"),
//                            object: nil
//                        )
//                    }
//
//                } label: {
//                    EmptyView()
//                }
//                .keyboardShortcut("f", modifiers: [.command, .shift])
//                .hidden()
//            }
        }
        .onAppear {
            if let initial = initialSearchText, !initial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = initial.trimmingCharacters(in: .whitespacesAndNewlines)
                searchText = trimmed
                isSearchActive = true

                routeToMatchingSection(query: trimmed)
            }
        }
    }

    private func routeToMatchingSection(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let reqBodyMatches = transaction.requestBodyString?.range(of: trimmed, options: .caseInsensitive) != nil
        let resBodyMatches = transaction.responseBodyString?.range(of: trimmed, options: .caseInsensitive) != nil

        let reqHeadersMatches = transaction.request.allHTTPHeaderFields?.contains { key, value in
            key.range(of: trimmed, options: .caseInsensitive) != nil ||
            value.range(of: trimmed, options: .caseInsensitive) != nil
        } ?? false

        let resHeadersMatches = (transaction.response as? HTTPURLResponse)?.allHeaderFields.contains { key, value in
            String(describing: key).range(of: trimmed, options: .caseInsensitive) != nil ||
            String(describing: value).range(of: trimmed, options: .caseInsensitive) != nil
        } ?? false

        let urlMatches = transaction.request.url?.absoluteString.range(of: trimmed, options: .caseInsensitive) != nil
        let methodMatches = transaction.request.httpMethod?.range(of: trimmed, options: .caseInsensitive) != nil
        let statusMatches = transaction.statusCode.map(String.init)?.range(of: trimmed, options: .caseInsensitive) != nil
        let errorMatches = transaction.error?.localizedDescription.range(of: trimmed, options: .caseInsensitive) != nil
        let overviewMatches = urlMatches || methodMatches || statusMatches || errorMatches

        // Priority 1: Response Body match
        if resBodyMatches {
            selectedTab = .response
        }
        // Priority 2: Request Body match
        else if reqBodyMatches {
            selectedTab = .request
        }
        // Priority 3: Request Headers match -> open Request tab and present Request Headers sheet
        else if reqHeadersMatches {
            selectedTab = .request
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.showRequestHeadersSheet = true
            }
        }
        // Priority 4: Response Headers match -> open Response tab and present Response Headers sheet
        else if resHeadersMatches {
            selectedTab = .response
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.showHeadersSheet = true
            }
        }
        // Priority 5: Overview match (URL, Method, Status, Error)
        else if overviewMatches {
            selectedTab = .overview
        }
        // Fallback default
        else {
            if transaction.data != nil && !transaction.data!.isEmpty {
                selectedTab = .response
            } else {
                selectedTab = .overview
            }
        }
    }

    @ViewBuilder
    private var searchControl: some View {
        if isSearchActive {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search payload...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)
                    .frame(width: 180)
                    .onSubmit {
                        searchCommand = .next
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isSearchActive = false
                        searchText = ""
                        isSearchFieldFocused = false
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 4)
            .transition(.scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
        } else {
            Button {
                activateSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .keyboardShortcut("f", modifiers: .command)
            .transition(.scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
        }
    }
    
    private var effectiveSearchText: String {
        searchText.isEmpty ? (initialSearchText ?? "") : searchText
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
                    
                    HighlightedText(
                        text: transaction.request.url?.absoluteString ?? "N/A",
                        query: effectiveSearchText,
                        font: .system(size: 13, weight: .medium),
                        textColor: .primary
                    )
                }
                
                HStack(alignment: .top) {
                    Text("Method")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    
                    HighlightedText(
                        text: transaction.request.httpMethod ?? "N/A",
                        query: effectiveSearchText,
                        font: .system(size: 12, weight: .bold, design: .monospaced),
                        textColor: .blue
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
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
                            HighlightedText(
                                text: "\(response.statusCode)",
                                query: effectiveSearchText,
                                font: .system(size: 12, weight: .bold, design: .monospaced),
                                textColor: isSuccess ? .green : .red
                            )
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
                    HighlightedText(
                        text: error.localizedDescription,
                        query: effectiveSearchText,
                        font: .subheadline,
                        textColor: .red
                    )
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var requestTab: some View {
        ZStack(alignment: .topTrailing) {
            // Body content takes the full screen
            Group {
                if let reqBody = transaction.request.httpBody, !reqBody.isEmpty {
                    if let stringBody = String(data: reqBody, encoding: .utf8) {
                        if let dict = try? JSONSerialization.jsonObject(with: reqBody) as? [String: Any],
                           let query = dict["query"] as? String {

                            // GraphQL case: query text + variables JSONViewer, scrollable together
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    if let opName = dict["operationName"] as? String {
                                        InfoRow(title: "Operation Name", value: opName, highlightQuery: effectiveSearchText)
                                    }

                                    Text("Query").font(.caption).foregroundColor(.secondary)
                                    HighlightedText(
                                        text: formatGraphQLQuery(query),
                                        query: effectiveSearchText,
                                        font: .system(size: 13, design: .monospaced),
                                        textColor: .primary
                                    )
                                    .padding()
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)

                                    if let variables = dict["variables"] as? [String: Any],
                                       let varData = try? JSONSerialization.data(withJSONObject: variables),
                                       let varString = String(data: varData, encoding: .utf8) {
                                        Text("Variables").font(.caption).foregroundColor(.secondary)
                                        JSONViewer(
                                            jsonString: varString,
                                            searchText: effectiveSearchText,
                                            searchCommand: $searchCommand,
                                            onFindRequested: activateSearch
                                        )
                                        .frame(minHeight: 300)
                                    }
                                }
                                .padding()
                            }
                        } else {
                            JSONViewer(
                                jsonString: stringBody,
                                searchText: effectiveSearchText,
                                searchCommand: $searchCommand,
                                onFindRequested: activateSearch
                            )
                        }
                    } else {
                        Text("\(reqBody.count) bytes of binary data").foregroundColor(.secondary)
                    }
                } else {
                    Text("No Request Body").foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating "Headers" button
            if hasRequestHeaders {
                Button {
                    showRequestHeadersSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                        Text("Headers")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .foregroundColor(.teal.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 3)
                }
                .padding(12)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showRequestHeadersSheet) {
            requestHeadersSheetContent
        }
    }

    private var hasRequestHeaders: Bool {
        guard let headers = transaction.request.allHTTPHeaderFields else { return false }
        return !headers.isEmpty
    }

    private var requestHeadersSheetContent: some View {
        NavigationView {
            List {
                if let headers = transaction.request.allHTTPHeaderFields {
                    ForEach(headers.sorted(by: >), id: \.key) { key, value in
                        if key.lowercased() == "authorization" && value.split(separator: ".").count >= 2 {
                            VStack(alignment: .leading, spacing: 4) {
                                InfoRow(title: key, value: value, highlightQuery: effectiveSearchText)
                                NavigationLink(destination: JWTDecoderView(token: String(value.dropFirst(7)))) {
                                    Text("Decode JWT Payload")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 2)
                        } else {
                            InfoRow(title: key, value: value, highlightQuery: effectiveSearchText)
                        }
                    }
                }
            }
            .navigationTitle("Request Headers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showRequestHeadersSheet = false
                    }
                }
            }
        }
    }
    
    private var responseTabView: some View {
        ZStack(alignment: .topTrailing) {
            // JSON viewer takes the full screen
            Group {
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
                            JSONViewer(
                                jsonString: htmlString,
                                searchText: effectiveSearchText,
                                searchCommand: $searchCommand,
                                onFindRequested: activateSearch
                            )
                        } else if let stringBody = String(data: data, encoding: .utf8) {
                            JSONViewer(
                                jsonString: stringBody,
                                searchText: effectiveSearchText,
                                searchCommand: $searchCommand,
                                onFindRequested: activateSearch
                            )
                        } else {
                            Text("\(data.count) bytes of binary data").foregroundColor(.secondary)
                        }
                    } else if let stringBody = String(data: data, encoding: .utf8) {
                        JSONViewer(
                            jsonString: stringBody,
                            searchText: effectiveSearchText,
                            searchCommand: $searchCommand,
                            onFindRequested: activateSearch
                        )
                    } else {
                        Text("\(data.count) bytes of binary data").foregroundColor(.secondary)
                    }
                } else {
                    Text("No Response Body").foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating "Headers" button, hovering over the top-right corner
            if hasResponseHeaders {
                Button {
                    showHeadersSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                        Text("Headers")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .foregroundColor(.teal.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 3)
                }
                .padding(12)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showHeadersSheet) {
            headersSheetContent
        }
    }

    private var hasResponseHeaders: Bool {
        if let httpResponse = transaction.response as? HTTPURLResponse {
            return !httpResponse.allHeaderFields.isEmpty
        }
        return false
    }

    private var headersSheetContent: some View {
        NavigationView {
            List {
                if let httpResponse = transaction.response as? HTTPURLResponse {
                    ForEach(
                        httpResponse.allHeaderFields
                            .reduce(into: [String: String]()) {
                                $0[String(describing: $1.key)] = String(describing: $1.value)
                            }
                            .sorted(by: >),
                        id: \.key
                    ) { key, value in
                        InfoRow(title: key, value: value, highlightQuery: effectiveSearchText)
                    }
                }
            }
            .navigationTitle("Response Headers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showHeadersSheet = false
                    }
                }
            }
        }
    }
    
    private func retryRequest() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MyURLProtocol.self]
        let session = URLSession(configuration: configuration)
        session.dataTask(with: transaction.request).resume()
    }

    private func formatGraphQLQuery(_ query: String) -> String {
        var tokens: [String] = []
        var currentToken = ""
        var inString = false
        var isEscaped = false
        
        let chars = Array(query)
        var i = 0
        while i < chars.count {
            let char = chars[i]
            
            if inString {
                currentToken.append(char)
                if char == "\\" {
                    isEscaped.toggle()
                } else if char == "\"" && !isEscaped {
                    inString = false
                    tokens.append(currentToken)
                    currentToken = ""
                } else {
                    isEscaped = false
                }
                i += 1
                continue
            }
            
            if char == "\"" {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                inString = true
                currentToken.append(char)
                i += 1
                continue
            }
            
            if char == "#" {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                var comment = ""
                while i < chars.count && chars[i] != "\n" && chars[i] != "\r" {
                    comment.append(chars[i])
                    i += 1
                }
                tokens.append(comment)
                continue
            }
            
            if char == "{" || char == "}" || char == "(" || char == ")" || char == ":" || char == "," {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                tokens.append(String(char))
            } else if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else {
                currentToken.append(char)
            }
            
            i += 1
        }
        
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        
        var result = ""
        var indentLevel = 0
        let indent = "  "
        var needIndent = true
        var inArgs = false
        
        func appendIndent() {
            if needIndent {
                result += String(repeating: indent, count: indentLevel)
                needIndent = false
            }
        }
        
        for token in tokens {
            if token.hasPrefix("#") {
                if !result.isEmpty && !result.hasSuffix("\n") {
                    result += "\n"
                }
                needIndent = true
                appendIndent()
                result += token + "\n"
                needIndent = true
            } else if token == "{" {
                if !result.isEmpty && !result.hasSuffix("\n") && !result.hasSuffix(" ") {
                    result += " "
                }
                result += "{\n"
                indentLevel += 1
                needIndent = true
            } else if token == "}" {
                indentLevel = max(0, indentLevel - 1)
                if !result.hasSuffix("\n") {
                    result += "\n"
                }
                needIndent = true
                appendIndent()
                result += "}\n"
                needIndent = true
            } else if token == "(" {
                result += "("
                inArgs = true
            } else if token == ")" {
                result += ")"
                inArgs = false
            } else if token == ":" {
                result += ": "
            } else if token == "," {
                result += ", "
            } else {
                appendIndent()
                
                if !needIndent && !result.hasSuffix("\n") && !result.hasSuffix(" ") && !result.hasSuffix("(") && !result.hasSuffix(":") && !inArgs && indentLevel > 0 {
                    result += "\n"
                    needIndent = true
                    appendIndent()
                } else if !needIndent && !result.hasSuffix(" ") && !result.hasSuffix("(") && !result.hasSuffix(":") {
                    result += " "
                }
                
                result += token
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Highlighted Text View
struct HighlightedText: View {
    let text: String
    let query: String
    var font: Font = .system(size: 13, weight: .medium)
    var textColor: Color = .primary

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text(text)
                .font(font)
                .foregroundColor(textColor)
        } else {
            Text(buildAttributedString(for: text, query: trimmed))
                .font(font)
        }
    }

    private func buildAttributedString(for string: String, query: String) -> AttributedString {
        var attributed = AttributedString(string)
        attributed.foregroundColor = textColor

        let lowerString = string.lowercased()
        let lowerQuery = query.lowercased()

        var searchStart = lowerString.startIndex
        while searchStart < lowerString.endIndex,
              let matchRange = lowerString.range(of: lowerQuery, range: searchStart..<lowerString.endIndex) {
            if let attrLower = AttributedString.Index(matchRange.lowerBound, within: attributed),
               let attrUpper = AttributedString.Index(matchRange.upperBound, within: attributed) {
                attributed[attrLower..<attrUpper].backgroundColor = .yellow
                attributed[attrLower..<attrUpper].foregroundColor = .black
                attributed[attrLower..<attrUpper].inlinePresentationIntent = .stronglyEmphasized
            }
            searchStart = matchRange.upperBound
            if matchRange.upperBound == lowerString.endIndex { break }
        }

        return attributed
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let title: String
    let value: String
    var highlightQuery: String = ""
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
                HighlightedText(
                    text: title,
                    query: highlightQuery,
                    font: .system(size: 12, weight: .semibold, design: .monospaced),
                    textColor: .secondary
                )
                .frame(width: 110, alignment: .leading)
                
                HighlightedText(
                    text: value,
                    query: highlightQuery,
                    font: .system(size: 12, design: .monospaced),
                    textColor: .primary
                )
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
