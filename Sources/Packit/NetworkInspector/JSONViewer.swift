import SwiftUI

struct JSONViewer<Header: View>: View {
    let jsonString: String
    var searchText: String = ""
    let header: Header
    
    struct SearchMatch: Equatable {
        let lineId: Int
        let occurrenceIndex: Int
    }
    
    struct FullScreenImage: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    @State private var lines: [JSONLine] = []
    @State private var matchIndices: [SearchMatch] = []
    @State private var currentMatchIndex: Int = 0
    @State private var selectedImage: FullScreenImage? = nil
    @State private var showCopied: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    init(jsonString: String, searchText: String = "", @ViewBuilder header: () -> Header) {
        self.jsonString = jsonString
        self.searchText = searchText
        self.header = header()
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack (alignment: .bottomTrailing){
                // MARK: - Floating Copy JSON Button
//                VStack {
//                    HStack {
//                        Spacer()
//                        Button {
//                            UIPasteboard.general.string = jsonString
//                            UINotificationFeedbackGenerator().notificationOccurred(.success)
//                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//                                showCopied = true
//                            }
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                                withAnimation { showCopied = false }
//                            }
//                        } label: {
//                            HStack(spacing: 5) {
//                                Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
//                                    .font(.system(size: 12, weight: .semibold))
//                                Text(showCopied ? "Copied!" : "Copy JSON")
//                                    .font(.system(size: 12, weight: .semibold))
//                            }
//                            .foregroundColor(showCopied ? .green : .white)
//                            .padding(.horizontal, 12)
//                            .padding(.vertical, 8)
//                            .background(showCopied ? Color.green.opacity(0.15) : Color.blue)
//                            .clipShape(Capsule())
//                            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
//                        }
//                        .buttonStyle(.plain)
//                        .padding(.trailing, 16)
//                        .padding(.top, 12)
//                    }
//                    Spacer()
//                }
//                .zIndex(10)
                ScrollView(.vertical) {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 0) {
                            header
                                .frame(width: geo.size.width) // Fix header to screen width
                            
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(lines) { line in
                                    let activeOccIdx: Int? = (!matchIndices.isEmpty && currentMatchIndex < matchIndices.count && line.id == matchIndices[currentMatchIndex].lineId)
                                        ? matchIndices[currentMatchIndex].occurrenceIndex
                                        : nil
                                    JSONLineCopyView(line: line) {
                                        highlightedLine(line.text, query: searchText, activeOccurrenceIndex: activeOccIdx) { url in
                                            selectedImage = FullScreenImage(url: url)
                                        }
                                        .font(.system(size: 13, design: .monospaced))
                                    }
                                    .id(line.id)
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 100)
                            .frame(minWidth: geo.size.width, alignment: .topLeading)
                        }
                        .onChange(of: currentMatchIndex) { newValue in
                            if !matchIndices.isEmpty, newValue >= 0, newValue < matchIndices.count {
                                withAnimation {
                                    proxy.scrollTo(matchIndices[newValue].lineId, anchor: .center)
                                }
                            }
                        }
                        .onChange(of: matchIndices) { newIndices in
                            if !newIndices.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(newIndices[currentMatchIndex].lineId, anchor: .center)
                                }
                            }
                        }
                        .onAppear {
                            if !matchIndices.isEmpty {
                                proxy.scrollTo(matchIndices[currentMatchIndex].lineId, anchor: .center)
                            }
                        }
                    }
                }
            
            // Postman-style floating search navigator
            if !matchIndices.isEmpty {
                HStack(spacing: 12) {
                    Text("\(currentMatchIndex + 1) of \(matchIndices.count)")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                    
                    Button {
                        if currentMatchIndex > 0 {
                            currentMatchIndex -= 1
                        } else {
                            currentMatchIndex = matchIndices.count - 1 // wrap around
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "chevron.up")
                            .padding(8)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if currentMatchIndex < matchIndices.count - 1 {
                            currentMatchIndex += 1
                        } else {
                            currentMatchIndex = 0 // wrap around
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "chevron.down")
                            .padding(8)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground).opacity(0.95))
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                .padding()
            }
        }
        }
        .sheet(item: $selectedImage) { item in
            ImagePreviewView(url: item.url)
        }
        .onAppear {
            parseJSON()
        }
        .onChange(of: searchText) { newValue in
            calculateMatches(for: newValue)
        }
    }
    
    // MARK: - Logic
    
    private func parseJSON() {
        let stringToParse = jsonString
        DispatchQueue.global(qos: .userInitiated).async {
            var parsedLines: [JSONLine] = []
            
            if let data = stringToParse.data(using: .utf8),
               let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .withoutEscapingSlashes]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                
                parsedLines = prettyString.components(separatedBy: "\n").enumerated().map { 
                    JSONLine(id: $0.offset, text: $0.element) 
                }
            } else {
                parsedLines = stringToParse.components(separatedBy: "\n").enumerated().map { 
                    JSONLine(id: $0.offset, text: $0.element) 
                }
            }
            
            DispatchQueue.main.async {
                self.lines = parsedLines
                self.calculateMatches(for: self.searchText)
            }
        }
    }
    
    private func calculateMatches(for queryText: String) {
        guard !queryText.isEmpty else {
            matchIndices = []
            currentMatchIndex = 0
            return
        }
        
        let query = queryText.lowercased()
        var newMatches: [SearchMatch] = []
        
        for line in lines {
            let lowerText = line.text.lowercased()
            var currentIndex = lowerText.startIndex
            var occurrence = 0
            
            while let range = lowerText.range(of: query, range: currentIndex..<lowerText.endIndex) {
                newMatches.append(SearchMatch(lineId: line.id, occurrenceIndex: occurrence))
                occurrence += 1
                currentIndex = range.upperBound
            }
        }
        
        matchIndices = newMatches
        
        if !matchIndices.isEmpty {
            currentMatchIndex = 0
        }
    }
    
    // MARK: - Postman-style Colorful Syntax Highlighting
    
    private enum TokenType { case key, string, number, keyword, punct, ws, unknown }
    private struct Token: Identifiable { let id = UUID(); let text: String; let type: TokenType }
    
    private func tokenize(_ line: String) -> [Token] {
        var tokens: [Token] = []
        let nsString = line as NSString
        let matches = JSONLexerConstants.tokenRegex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastIndex = 0
        for match in matches {
            if match.range.location > lastIndex {
                let gap = nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
                tokens.append(Token(text: gap, type: .unknown))
            }
            lastIndex = match.range.location + match.range.length
            
            if match.range(withName: "string").location != NSNotFound {
                let str = nsString.substring(with: match.range(withName: "string"))
                let suffixRange = NSRange(location: match.range.location + match.range.length, length: nsString.length - (match.range.location + match.range.length))
                let suffix = nsString.substring(with: suffixRange)
                if suffix.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
                    tokens.append(Token(text: str, type: .key))
                } else {
                    tokens.append(Token(text: str, type: .string))
                }
            } else if match.range(withName: "number").location != NSNotFound {
                tokens.append(Token(text: nsString.substring(with: match.range(withName: "number")), type: .number))
            } else if match.range(withName: "keyword").location != NSNotFound {
                tokens.append(Token(text: nsString.substring(with: match.range(withName: "keyword")), type: .keyword))
            } else if match.range(withName: "punct").location != NSNotFound {
                tokens.append(Token(text: nsString.substring(with: match.range(withName: "punct")), type: .punct))
            } else if match.range(withName: "ws").location != NSNotFound {
                tokens.append(Token(text: nsString.substring(with: match.range(withName: "ws")), type: .ws))
            }
        }
        if lastIndex < nsString.length {
            let gap = nsString.substring(with: NSRange(location: lastIndex, length: nsString.length - lastIndex))
            tokens.append(Token(text: gap, type: .unknown))
        }
        return tokens
    }
    
    private func extractImageURL(from text: String) -> URL? {
        // Simple regex to find URLs
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches {
            if let url = match.url, let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) {
                let ext = url.pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) {
                    return url
                }
                // Check if URL string contains image extensions before query params
                let urlString = url.absoluteString.lowercased()
                if urlString.contains(".jpg") || urlString.contains(".jpeg") || urlString.contains(".png") {
                    return url
                }
            }
        }
        
        // Fallback for paths starting with "/" and ending with image extension (often used in TMDB)
        if text.contains("\"/") {
            let components = text.components(separatedBy: "\"")
            for comp in components {
                if comp.hasPrefix("/") && (comp.lowercased().hasSuffix(".jpg") || comp.lowercased().hasSuffix(".png")) {
                    // Try to guess TMDB base URL for convenience if it looks like a TMDB path
                    if comp.count > 10 {
                        return URL(string: "https://image.tmdb.org/t/p/w500" + comp)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func color(for type: TokenType, scheme: ColorScheme) -> Color {
        switch type {
        case .key: return scheme == .dark ? Color(red: 0.61, green: 0.86, blue: 0.99) : Color(red: 0.02, green: 0.32, blue: 0.65)
        case .string: return scheme == .dark ? Color(red: 0.81, green: 0.57, blue: 0.47) : Color(red: 0.64, green: 0.08, blue: 0.08)
        case .number: return scheme == .dark ? Color(red: 0.71, green: 0.81, blue: 0.66) : Color(red: 0.04, green: 0.53, blue: 0.35)
        case .keyword: return scheme == .dark ? Color(red: 0.34, green: 0.61, blue: 0.84) : Color(red: 0.0, green: 0.0, blue: 1.0)
        case .punct: return .secondary
        case .unknown: return .primary
        case .ws: return .clear
        }
    }
    
    private func highlightedLine(_ fullString: String, query: String, activeOccurrenceIndex: Int?, onImageTap: @escaping (URL) -> Void) -> some View {
        let tokens = tokenize(fullString)
        
        let colonIndex = tokens.firstIndex(where: { $0.type == .punct && $0.text == ":" })
        var splitIndex = 0
        if let ci = colonIndex {
            splitIndex = ci + 1
            while splitIndex < tokens.count && tokens[splitIndex].type == .ws { splitIndex += 1 }
        } else if let firstNonWs = tokens.firstIndex(where: { $0.type != .ws }) {
            splitIndex = firstNonWs
        }
        
        let leadingTokens = Array(tokens[0..<splitIndex])
        let trailingTokens = Array(tokens[splitIndex...])
        
        var counter = 0
        let leadingAttr = buildAttributedString(from: leadingTokens, query: query, activeOccurrenceIndex: activeOccurrenceIndex, counter: &counter)
        let trailingAttr = buildAttributedString(from: trailingTokens, query: query, activeOccurrenceIndex: activeOccurrenceIndex, counter: &counter)
        
        return HStack(alignment: .top, spacing: 0) {
            if !leadingTokens.isEmpty { Text(leadingAttr) }
            if !trailingTokens.isEmpty { Text(trailingAttr) }
            
            if let imageURL = extractImageURL(from: fullString) {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                            .onTapGesture {
                                onImageTap(imageURL)
                            }
                    } else if phase.error != nil {
                        Image(systemName: "photo").resizable().scaledToFit().frame(width: 14, height: 14).foregroundColor(.secondary)
                    } else {
                        ProgressView().frame(width: 14, height: 14)
                    }
                }
                .padding(.leading, 8)
                .offset(y: 1)
            }
        }
    }
    
    private func buildAttributedString(from tokens: [Token], query: String, activeOccurrenceIndex: Int?, counter: inout Int) -> AttributedString {
        var attrString = AttributedString()
        
        for token in tokens {
            let baseColor = color(for: token.type, scheme: colorScheme)
            if query.isEmpty || !token.text.lowercased().contains(query.lowercased()) {
                var attrToken = AttributedString(token.text)
                attrToken.foregroundColor = baseColor
                attrString.append(attrToken)
            } else {
                for fragment in splitString(token.text, by: query) {
                    var attrFrag = AttributedString(fragment.text)
                    if fragment.isMatch {
                        let isActiveOccurrence = (activeOccurrenceIndex != nil && counter == activeOccurrenceIndex!)
                        attrFrag.foregroundColor = .black
                        attrFrag.backgroundColor = isActiveOccurrence ? .orange : .yellow
                        counter += 1
                    } else {
                        attrFrag.foregroundColor = baseColor
                    }
                    attrString.append(attrFrag)
                }
            }
        }
        return attrString
    }
    
    private struct StringFragment: Identifiable {
        let id = UUID()
        let text: String
        let isMatch: Bool
    }
    
    private func splitString(_ fullString: String, by query: String) -> [StringFragment] {
        var fragments: [StringFragment] = []
        let lowerFull = fullString.lowercased()
        let lowerQuery = query.lowercased()
        
        var currentIndex = fullString.startIndex
        
        while let range = lowerFull.range(of: lowerQuery, range: currentIndex..<fullString.endIndex) {
            let prefix = String(fullString[currentIndex..<range.lowerBound])
            if !prefix.isEmpty {
                fragments.append(StringFragment(text: prefix, isMatch: false))
            }
            
            let match = String(fullString[range])
            fragments.append(StringFragment(text: match, isMatch: true))
            
            currentIndex = range.upperBound
        }
        
        let suffix = String(fullString[currentIndex..<fullString.endIndex])
        if !suffix.isEmpty {
            fragments.append(StringFragment(text: suffix, isMatch: false))
        }
        
        return fragments
    }
}

struct ImagePreviewView: View {
    @Environment(\.dismiss) var dismiss
    let url: URL
    
    var body: some View {
        NavigationView {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable()
                        .scaledToFit()
                        .padding()
                } else if phase.error != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Failed to load image")
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct JSONLine: Identifiable {
    let id: Int
    let text: String
}

struct JSONLineCopyView<Content: View>: View {
    let line: JSONLine
    let content: Content
    
    @State private var showingCopied = false
    @State private var isHovered = false
    
    init(line: JSONLine, @ViewBuilder content: () -> Content) {
        self.line = line
        self.content = content()
    }
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
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
            HStack(alignment: .top, spacing: 4) {
                content
                
                Spacer(minLength: 8)
                if showingCopied {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if isHovered {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

extension JSONViewer where Header == EmptyView {
    init(jsonString: String, searchText: String = "") {
        self.init(jsonString: jsonString, searchText: searchText, header: { EmptyView() })
    }
}

private enum JSONLexerConstants {
    static let tokenPattern = "(?<string>\"(?:\\\\.|[^\"])*\")|(?<number>-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)|(?<keyword>\\b(?:true|false|null)\\b)|(?<punct>[\\[\\]\\{\\}\\:\\,])|(?<ws>\\s+)"
    static let tokenRegex = try! NSRegularExpression(pattern: tokenPattern, options: [])
}


//import SwiftUI
//
//struct JSONViewer<Header: View>: View {
//    let jsonString: String
//    var searchText: String = ""
//    let header: Header
//    
//    struct SearchMatch: Equatable {
//        let lineId: Int
//        let occurrenceIndex: Int
//    }
//    
//    struct FullScreenImage: Identifiable {
//        let id = UUID()
//        let url: URL
//    }
//    
//    @State private var lines: [JSONLine] = []
//    @State private var matchIndices: [SearchMatch] = []
//    @State private var currentMatchIndex: Int = 0
//    @State private var selectedImage: FullScreenImage? = nil
//    @Environment(\.colorScheme) var colorScheme
//    
//    init(jsonString: String, searchText: String = "", @ViewBuilder header: () -> Header) {
//        self.jsonString = jsonString
//        self.searchText = searchText
//        self.header = header()
//    }
//    
//    var body: some View {
//        ZStack(alignment: .bottomTrailing) {
//            ScrollView(.vertical) {
//                ScrollViewReader { proxy in
//                    VStack(alignment: .leading, spacing: 0) {
//                        header
//                            .frame(maxWidth: .infinity, alignment: .leading) // Fix header to screen width, dynamic
//                        
//                        LazyVStack(alignment: .leading, spacing: 4) {
//                            ForEach(lines) { line in
//                                let activeOccIdx: Int? = (!matchIndices.isEmpty && currentMatchIndex < matchIndices.count && line.id == matchIndices[currentMatchIndex].lineId)
//                                    ? matchIndices[currentMatchIndex].occurrenceIndex
//                                    : nil
//                                JSONLineCopyView(line: line) {
//                                    highlightedLine(line.text, query: searchText, activeOccurrenceIndex: activeOccIdx) { url in
//                                        selectedImage = FullScreenImage(url: url)
//                                    }
//                                    .font(.system(size: 13, design: .monospaced))
//                                }
//                                .id(line.id)
//                            }
//                        }
//                        .padding(16)
//                        .padding(.bottom, 100)
//                        .frame(maxWidth: .infinity, alignment: .topLeading)
//                    }
//                    .onChange(of: currentMatchIndex) { newValue in
//                        if !matchIndices.isEmpty, newValue >= 0, newValue < matchIndices.count {
//                            withAnimation {
//                                proxy.scrollTo(matchIndices[newValue].lineId, anchor: .center)
//                            }
//                        }
//                    }
//                    .onChange(of: matchIndices) { newIndices in
//                        if !newIndices.isEmpty {
//                            withAnimation {
//                                proxy.scrollTo(newIndices[currentMatchIndex].lineId, anchor: .center)
//                            }
//                        }
//                    }
//                    .onAppear {
//                        if !matchIndices.isEmpty {
//                            proxy.scrollTo(matchIndices[currentMatchIndex].lineId, anchor: .center)
//                        }
//                    }
//                }
//            }
//            
//            // Postman-style floating search navigator
//            if !matchIndices.isEmpty {
//                HStack(spacing: 12) {
//                    Text("\(currentMatchIndex + 1) of \(matchIndices.count)")
//                        .font(.caption.bold())
//                        .foregroundColor(.primary)
//                    
//                    Button {
//                        if currentMatchIndex > 0 {
//                            currentMatchIndex -= 1
//                        } else {
//                            currentMatchIndex = matchIndices.count - 1 // wrap around
//                        }
//                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                    } label: {
//                        Image(systemName: "chevron.up")
//                            .padding(8)
//                            .background(Color(UIColor.systemGray5))
//                            .clipShape(Circle())
//                    }
//                    .buttonStyle(.plain)
//                    
//                    Button {
//                        if currentMatchIndex < matchIndices.count - 1 {
//                            currentMatchIndex += 1
//                        } else {
//                            currentMatchIndex = 0 // wrap around
//                        }
//                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                    } label: {
//                        Image(systemName: "chevron.down")
//                            .padding(8)
//                            .background(Color(UIColor.systemGray5))
//                            .clipShape(Circle())
//                    }
//                    .buttonStyle(.plain)
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 10)
//                .background(Color(UIColor.systemBackground).opacity(0.95))
//                .cornerRadius(25)
//                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
//                .padding()
//            }
//        }
//        .sheet(item: $selectedImage) { item in
//            ImagePreviewView(url: item.url)
//        }
//        .onAppear {
//            parseJSON()
//        }
//        .onChange(of: searchText) { newValue in
//            calculateMatches(for: newValue)
//        }
//    }
//    
//    // MARK: - Logic
//    
//    private func parseJSON() {
//        let stringToParse = jsonString
//        DispatchQueue.global(qos: .userInitiated).async {
//            var parsedLines: [JSONLine] = []
//            
//            if let data = stringToParse.data(using: .utf8),
//               let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []),
//               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .withoutEscapingSlashes]),
//               let prettyString = String(data: prettyData, encoding: .utf8) {
//                
//                parsedLines = prettyString.components(separatedBy: "\n").enumerated().map {
//                    JSONLine(id: $0.offset, text: $0.element)
//                }
//            } else {
//                parsedLines = stringToParse.components(separatedBy: "\n").enumerated().map {
//                    JSONLine(id: $0.offset, text: $0.element)
//                }
//            }
//            
//            DispatchQueue.main.async {
//                self.lines = parsedLines
//                self.calculateMatches(for: self.searchText)
//            }
//        }
//    }
//    
//    private func calculateMatches(for queryText: String) {
//        guard !queryText.isEmpty else {
//            matchIndices = []
//            currentMatchIndex = 0
//            return
//        }
//        
//        let query = queryText.lowercased()
//        var newMatches: [SearchMatch] = []
//        
//        for line in lines {
//            let lowerText = line.text.lowercased()
//            var currentIndex = lowerText.startIndex
//            var occurrence = 0
//            
//            while let range = lowerText.range(of: query, range: currentIndex..<lowerText.endIndex) {
//                newMatches.append(SearchMatch(lineId: line.id, occurrenceIndex: occurrence))
//                occurrence += 1
//                currentIndex = range.upperBound
//            }
//        }
//        
//        matchIndices = newMatches
//        
//        if !matchIndices.isEmpty {
//            currentMatchIndex = 0
//        }
//    }
//    
//    // MARK: - Postman-style Colorful Syntax Highlighting
//    
//    private enum TokenType { case key, string, number, keyword, punct, ws, unknown }
//    private struct Token: Identifiable { let id = UUID(); let text: String; let type: TokenType }
//    
//    private func tokenize(_ line: String) -> [Token] {
//        var tokens: [Token] = []
//        let nsString = line as NSString
//        let matches = JSONLexerConstants.tokenRegex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
//        
//        var lastIndex = 0
//        for match in matches {
//            if match.range.location > lastIndex {
//                let gap = nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
//                tokens.append(Token(text: gap, type: .unknown))
//            }
//            lastIndex = match.range.location + match.range.length
//            
//            if match.range(withName: "string").location != NSNotFound {
//                let str = nsString.substring(with: match.range(withName: "string"))
//                let suffixRange = NSRange(location: match.range.location + match.range.length, length: nsString.length - (match.range.location + match.range.length))
//                let suffix = nsString.substring(with: suffixRange)
//                if suffix.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
//                    tokens.append(Token(text: str, type: .key))
//                } else {
//                    tokens.append(Token(text: str, type: .string))
//                }
//            } else if match.range(withName: "number").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "number")), type: .number))
//            } else if match.range(withName: "keyword").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "keyword")), type: .keyword))
//            } else if match.range(withName: "punct").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "punct")), type: .punct))
//            } else if match.range(withName: "ws").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "ws")), type: .ws))
//            }
//        }
//        if lastIndex < nsString.length {
//            let gap = nsString.substring(with: NSRange(location: lastIndex, length: nsString.length - lastIndex))
//            tokens.append(Token(text: gap, type: .unknown))
//        }
//        return tokens
//    }
//    
//    private func extractImageURL(from text: String) -> URL? {
//        // Simple regex to find URLs
//        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
//        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
//        
//        for match in matches {
//            if let url = match.url, let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) {
//                let ext = url.pathExtension.lowercased()
//                if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) {
//                    return url
//                }
//                // Check if URL string contains image extensions before query params
//                let urlString = url.absoluteString.lowercased()
//                if urlString.contains(".jpg") || urlString.contains(".jpeg") || urlString.contains(".png") {
//                    return url
//                }
//            }
//        }
//        
//        // Fallback for paths starting with "/" and ending with image extension (often used in TMDB)
//        if text.contains("\"/") {
//            let components = text.components(separatedBy: "\"")
//            for comp in components {
//                if comp.hasPrefix("/") && (comp.lowercased().hasSuffix(".jpg") || comp.lowercased().hasSuffix(".png")) {
//                    // Try to guess TMDB base URL for convenience if it looks like a TMDB path
//                    if comp.count > 10 {
//                        return URL(string: "https://image.tmdb.org/t/p/w500" + comp)
//                    }
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    private func color(for type: TokenType, scheme: ColorScheme) -> Color {
//        switch type {
//        case .key: return scheme == .dark ? Color(red: 0.61, green: 0.86, blue: 0.99) : Color(red: 0.02, green: 0.32, blue: 0.65)
//        case .string: return scheme == .dark ? Color(red: 0.81, green: 0.57, blue: 0.47) : Color(red: 0.64, green: 0.08, blue: 0.08)
//        case .number: return scheme == .dark ? Color(red: 0.71, green: 0.81, blue: 0.66) : Color(red: 0.04, green: 0.53, blue: 0.35)
//        case .keyword: return scheme == .dark ? Color(red: 0.34, green: 0.61, blue: 0.84) : Color(red: 0.0, green: 0.0, blue: 1.0)
//        case .punct: return .secondary
//        case .unknown: return .primary
//        case .ws: return .clear
//        }
//    }
//    
//    private func highlightedLine(_ fullString: String, query: String, activeOccurrenceIndex: Int?, onImageTap: @escaping (URL) -> Void) -> some View {
//        let tokens = tokenize(fullString)
//        
//        let colonIndex = tokens.firstIndex(where: { $0.type == .punct && $0.text == ":" })
//        var splitIndex = 0
//        if let ci = colonIndex {
//            splitIndex = ci + 1
//            while splitIndex < tokens.count && tokens[splitIndex].type == .ws { splitIndex += 1 }
//        } else if let firstNonWs = tokens.firstIndex(where: { $0.type != .ws }) {
//            splitIndex = firstNonWs
//        }
//        
//        let leadingTokens = Array(tokens[0..<splitIndex])
//        let trailingTokens = Array(tokens[splitIndex...])
//        
//        var counter = 0
//        let leadingAttr = buildAttributedString(from: leadingTokens, query: query, activeOccurrenceIndex: activeOccurrenceIndex, counter: &counter)
//        let trailingAttr = buildAttributedString(from: trailingTokens, query: query, activeOccurrenceIndex: activeOccurrenceIndex, counter: &counter)
//        
//        return HStack(alignment: .top, spacing: 4) {
//            if !leadingTokens.isEmpty {
//                Text(leadingAttr)
//                    .fixedSize(horizontal: false, vertical: true) // let key wrap within its own width instead of overflowing
//            }
//            if !trailingTokens.isEmpty {
//                Text(trailingAttr)
//                    .fixedSize(horizontal: false, vertical: true) // let value wrap within its own width instead of overflowing
//                    .frame(maxWidth: .infinity, alignment: .leading) // value takes remaining width so it wraps there
//            }
//            
//            if let imageURL = extractImageURL(from: fullString) {
//                AsyncImage(url: imageURL) { phase in
//                    if let image = phase.image {
//                        image.resizable()
//                            .scaledToFill()
//                            .frame(width: 14, height: 14)
//                            .cornerRadius(2)
//                            .onTapGesture {
//                                onImageTap(imageURL)
//                            }
//                    } else if phase.error != nil {
//                        Image(systemName: "photo").resizable().scaledToFit().frame(width: 14, height: 14).foregroundColor(.secondary)
//                    } else {
//                        ProgressView().frame(width: 14, height: 14)
//                    }
//                }
//                .padding(.leading, 8)
//                .offset(y: 1)
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//    
//    private func buildAttributedString(from tokens: [Token], query: String, activeOccurrenceIndex: Int?, counter: inout Int) -> AttributedString {
//        var attrString = AttributedString()
//        
//        for token in tokens {
//            let baseColor = color(for: token.type, scheme: colorScheme)
//            if query.isEmpty || !token.text.lowercased().contains(query.lowercased()) {
//                var attrToken = AttributedString(token.text)
//                attrToken.foregroundColor = baseColor
//                attrString.append(attrToken)
//            } else {
//                for fragment in splitString(token.text, by: query) {
//                    var attrFrag = AttributedString(fragment.text)
//                    if fragment.isMatch {
//                        let isActiveOccurrence = (activeOccurrenceIndex != nil && counter == activeOccurrenceIndex!)
//                        attrFrag.foregroundColor = .black
//                        attrFrag.backgroundColor = isActiveOccurrence ? .orange : .yellow
//                        counter += 1
//                    } else {
//                        attrFrag.foregroundColor = baseColor
//                    }
//                    attrString.append(attrFrag)
//                }
//            }
//        }
//        return attrString
//    }
//    
//    private struct StringFragment: Identifiable {
//        let id = UUID()
//        let text: String
//        let isMatch: Bool
//    }
//    
//    private func splitString(_ fullString: String, by query: String) -> [StringFragment] {
//        var fragments: [StringFragment] = []
//        let lowerFull = fullString.lowercased()
//        let lowerQuery = query.lowercased()
//        
//        var currentIndex = fullString.startIndex
//        
//        while let range = lowerFull.range(of: lowerQuery, range: currentIndex..<fullString.endIndex) {
//            let prefix = String(fullString[currentIndex..<range.lowerBound])
//            if !prefix.isEmpty {
//                fragments.append(StringFragment(text: prefix, isMatch: false))
//            }
//            
//            let match = String(fullString[range])
//            fragments.append(StringFragment(text: match, isMatch: true))
//            
//            currentIndex = range.upperBound
//        }
//        
//        let suffix = String(fullString[currentIndex..<fullString.endIndex])
//        if !suffix.isEmpty {
//            fragments.append(StringFragment(text: suffix, isMatch: false))
//        }
//        
//        return fragments
//    }
//}
//
//struct ImagePreviewView: View {
//    @Environment(\.dismiss) var dismiss
//    let url: URL
//    
//    var body: some View {
//        NavigationView {
//            AsyncImage(url: url) { phase in
//                if let image = phase.image {
//                    image.resizable()
//                        .scaledToFit()
//                        .padding()
//                } else if phase.error != nil {
//                    VStack(spacing: 12) {
//                        Image(systemName: "exclamationmark.triangle")
//                            .font(.system(size: 40))
//                            .foregroundColor(.red)
//                        Text("Failed to load image")
//                    }
//                } else {
//                    ProgressView()
//                }
//            }
//            .navigationTitle("Preview")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//struct JSONLine: Identifiable {
//    let id: Int
//    let text: String
//}
//
//struct JSONLineCopyView<Content: View>: View {
//    let line: JSONLine
//    let content: Content
//    
//    @State private var showingCopied = false
//    @State private var isHovered = false
//    
//    init(line: JSONLine, @ViewBuilder content: () -> Content) {
//        self.line = line
//        self.content = content()
//    }
//    
//    var body: some View {
//        Button(action: {
//            UIPasteboard.general.string = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
//            UINotificationFeedbackGenerator().notificationOccurred(.success)
//            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//                showingCopied = true
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                withAnimation {
//                    showingCopied = false
//                }
//            }
//        }) {
//            HStack(alignment: .top, spacing: 4) {
//                content
//                
//                Spacer(minLength: 8)
//                if showingCopied {
//                    Image(systemName: "checkmark")
//                        .font(.caption.bold())
//                        .foregroundColor(.green)
//                        .transition(.scale.combined(with: .opacity))
//                } else if isHovered {
//                    Image(systemName: "doc.on.doc")
//                        .font(.caption)
//                        .foregroundColor(.gray.opacity(0.5))
//                }
//            }
//            .contentShape(Rectangle())
//            .frame(maxWidth: .infinity, alignment: .leading) // gives the row a defined width so key/value can wrap within it
//        }
//        .buttonStyle(.plain)
//        .onHover { hovering in
//            withAnimation(.easeInOut(duration: 0.2)) {
//                isHovered = hovering
//            }
//        }
//    }
//}
//
//extension JSONViewer where Header == EmptyView {
//    init(jsonString: String, searchText: String = "") {
//        self.init(jsonString: jsonString, searchText: searchText, header: { EmptyView() })
//    }
//}
//
//private enum JSONLexerConstants {
//    static let tokenPattern = "(?<string>\"(?:\\\\.|[^\"])*\")|(?<number>-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)|(?<keyword>\\b(?:true|false|null)\\b)|(?<punct>[\\[\\]\\{\\}\\:\\,])|(?<ws>\\s+)"
//    static let tokenRegex = try! NSRegularExpression(pattern: tokenPattern, options: [])
//}
//
//
//import SwiftUI
//
//struct JSONViewer<Header: View>: View {
//    let jsonString: String
//    var searchText: String = ""
//    let header: Header
//    
//    struct SearchMatch: Equatable {
//        let lineId: Int
//        let occurrenceIndex: Int
//    }
//    
//    struct FullScreenImage: Identifiable {
//        let id = UUID()
//        let url: URL
//    }
//    
//    @State private var lines: [JSONLine] = []
//    @State private var matchIndices: [SearchMatch] = []
//    @State private var currentMatchIndex: Int = 0
//    @State private var selectedImage: FullScreenImage? = nil
//    @Environment(\.colorScheme) var colorScheme
//    
//    init(jsonString: String, searchText: String = "", @ViewBuilder header: () -> Header) {
//        self.jsonString = jsonString
//        self.searchText = searchText
//        self.header = header()
//    }
//    
//    var body: some View {
//        ZStack(alignment: .bottomTrailing) {
//            ScrollView(.vertical) {
//                ScrollViewReader { proxy in
//                    VStack(alignment: .leading, spacing: 0) {
//                        header
//                            .frame(maxWidth: .infinity, alignment: .leading) // Fix header to screen width, dynamic
//                        
//                        LazyVStack(alignment: .leading, spacing: 4) {
//                            ForEach(lines) { line in
//                                let activeOccIdx: Int? = (!matchIndices.isEmpty && currentMatchIndex < matchIndices.count && line.id == matchIndices[currentMatchIndex].lineId)
//                                    ? matchIndices[currentMatchIndex].occurrenceIndex
//                                    : nil
//                                JSONLineCopyView(line: line) {
//                                    highlightedLine(line.text, query: searchText, activeOccurrenceIndex: activeOccIdx) { url in
//                                        selectedImage = FullScreenImage(url: url)
//                                    }
//                                    .font(.system(size: 13, design: .monospaced))
//                                }
//                                .id(line.id)
//                            }
//                        }
//                        .padding(16)
//                        .padding(.bottom, 100)
//                        .frame(maxWidth: .infinity, alignment: .topLeading)
//                    }
//                    .onChange(of: currentMatchIndex) { newValue in
//                        if !matchIndices.isEmpty, newValue >= 0, newValue < matchIndices.count {
//                            withAnimation {
//                                proxy.scrollTo(matchIndices[newValue].lineId, anchor: .center)
//                            }
//                        }
//                    }
//                    .onChange(of: matchIndices) { newIndices in
//                        if !newIndices.isEmpty {
//                            withAnimation {
//                                proxy.scrollTo(newIndices[currentMatchIndex].lineId, anchor: .center)
//                            }
//                        }
//                    }
//                    .onAppear {
//                        if !matchIndices.isEmpty {
//                            proxy.scrollTo(matchIndices[currentMatchIndex].lineId, anchor: .center)
//                        }
//                    }
//                }
//            }
//            
//            // Postman-style floating search navigator
//            if !matchIndices.isEmpty {
//                HStack(spacing: 12) {
//                    Text("\(currentMatchIndex + 1) of \(matchIndices.count)")
//                        .font(.caption.bold())
//                        .foregroundColor(.primary)
//                    
//                    Button {
//                        if currentMatchIndex > 0 {
//                            currentMatchIndex -= 1
//                        } else {
//                            currentMatchIndex = matchIndices.count - 1 // wrap around
//                        }
//                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                    } label: {
//                        Image(systemName: "chevron.up")
//                            .padding(8)
//                            .background(Color(UIColor.systemGray5))
//                            .clipShape(Circle())
//                    }
//                    .buttonStyle(.plain)
//                    
//                    Button {
//                        if currentMatchIndex < matchIndices.count - 1 {
//                            currentMatchIndex += 1
//                        } else {
//                            currentMatchIndex = 0 // wrap around
//                        }
//                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                    } label: {
//                        Image(systemName: "chevron.down")
//                            .padding(8)
//                            .background(Color(UIColor.systemGray5))
//                            .clipShape(Circle())
//                    }
//                    .buttonStyle(.plain)
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 10)
//                .background(Color(UIColor.systemBackground).opacity(0.95))
//                .cornerRadius(25)
//                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
//                .padding()
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity) // fill whatever space the parent gives us, so the floating pill anchors to the screen corner, not to the content's total height
//        .sheet(item: $selectedImage) { item in
//            ImagePreviewView(url: item.url)
//        }
//        .onAppear {
//            parseJSON()
//        }
//        .onChange(of: searchText) { newValue in
//            calculateMatches(for: newValue)
//        }
//    }
//    
//    // MARK: - Logic
//    
//    private func parseJSON() {
//        let stringToParse = jsonString
//        DispatchQueue.global(qos: .userInitiated).async {
//            var parsedLines: [JSONLine] = []
//            
//            if let data = stringToParse.data(using: .utf8),
//               let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []),
//               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .withoutEscapingSlashes]),
//               let prettyString = String(data: prettyData, encoding: .utf8) {
//                
//                parsedLines = prettyString.components(separatedBy: "\n").enumerated().map {
//                    JSONLine(id: $0.offset, text: $0.element)
//                }
//            } else {
//                parsedLines = stringToParse.components(separatedBy: "\n").enumerated().map {
//                    JSONLine(id: $0.offset, text: $0.element)
//                }
//            }
//            
//            DispatchQueue.main.async {
//                self.lines = parsedLines
//                self.calculateMatches(for: self.searchText)
//            }
//        }
//    }
//    
//    private func calculateMatches(for queryText: String) {
//        guard !queryText.isEmpty else {
//            matchIndices = []
//            currentMatchIndex = 0
//            return
//        }
//        
//        let query = queryText.lowercased()
//        var newMatches: [SearchMatch] = []
//        
//        for line in lines {
//            let lowerText = line.text.lowercased()
//            var currentIndex = lowerText.startIndex
//            var occurrence = 0
//            
//            while let range = lowerText.range(of: query, range: currentIndex..<lowerText.endIndex) {
//                newMatches.append(SearchMatch(lineId: line.id, occurrenceIndex: occurrence))
//                occurrence += 1
//                currentIndex = range.upperBound
//            }
//        }
//        
//        matchIndices = newMatches
//        
//        if !matchIndices.isEmpty {
//            currentMatchIndex = 0
//        }
//    }
//    
//    // MARK: - Postman-style Colorful Syntax Highlighting
//    
//    private enum TokenType { case key, string, number, keyword, punct, ws, unknown }
//    private struct Token: Identifiable { let id = UUID(); let text: String; let type: TokenType }
//    
//    private func tokenize(_ line: String) -> [Token] {
//        var tokens: [Token] = []
//        let nsString = line as NSString
//        let matches = JSONLexerConstants.tokenRegex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
//        
//        var lastIndex = 0
//        for match in matches {
//            if match.range.location > lastIndex {
//                let gap = nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
//                tokens.append(Token(text: gap, type: .unknown))
//            }
//            lastIndex = match.range.location + match.range.length
//            
//            if match.range(withName: "string").location != NSNotFound {
//                let str = nsString.substring(with: match.range(withName: "string"))
//                let suffixRange = NSRange(location: match.range.location + match.range.length, length: nsString.length - (match.range.location + match.range.length))
//                let suffix = nsString.substring(with: suffixRange)
//                if suffix.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
//                    tokens.append(Token(text: str, type: .key))
//                } else {
//                    tokens.append(Token(text: str, type: .string))
//                }
//            } else if match.range(withName: "number").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "number")), type: .number))
//            } else if match.range(withName: "keyword").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "keyword")), type: .keyword))
//            } else if match.range(withName: "punct").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "punct")), type: .punct))
//            } else if match.range(withName: "ws").location != NSNotFound {
//                tokens.append(Token(text: nsString.substring(with: match.range(withName: "ws")), type: .ws))
//            }
//        }
//        if lastIndex < nsString.length {
//            let gap = nsString.substring(with: NSRange(location: lastIndex, length: nsString.length - lastIndex))
//            tokens.append(Token(text: gap, type: .unknown))
//        }
//        return tokens
//    }
//    
//    private func extractImageURL(from text: String) -> URL? {
//        // Simple regex to find URLs
//        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
//        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
//        
//        for match in matches {
//            if let url = match.url, let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) {
//                let ext = url.pathExtension.lowercased()
//                if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) {
//                    return url
//                }
//                // Check if URL string contains image extensions before query params
//                let urlString = url.absoluteString.lowercased()
//                if urlString.contains(".jpg") || urlString.contains(".jpeg") || urlString.contains(".png") {
//                    return url
//                }
//            }
//        }
//        
//        // Fallback for paths starting with "/" and ending with image extension (often used in TMDB)
//        if text.contains("\"/") {
//            let components = text.components(separatedBy: "\"")
//            for comp in components {
//                if comp.hasPrefix("/") && (comp.lowercased().hasSuffix(".jpg") || comp.lowercased().hasSuffix(".png")) {
//                    // Try to guess TMDB base URL for convenience if it looks like a TMDB path
//                    if comp.count > 10 {
//                        return URL(string: "https://image.tmdb.org/t/p/w500" + comp)
//                    }
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    private func color(for type: TokenType, scheme: ColorScheme) -> Color {
//        switch type {
//        case .key: return scheme == .dark ? Color(red: 0.61, green: 0.86, blue: 0.99) : Color(red: 0.02, green: 0.32, blue: 0.65)
//        case .string: return scheme == .dark ? Color(red: 0.81, green: 0.57, blue: 0.47) : Color(red: 0.64, green: 0.08, blue: 0.08)
//        case .number: return scheme == .dark ? Color(red: 0.71, green: 0.81, blue: 0.66) : Color(red: 0.04, green: 0.53, blue: 0.35)
//        case .keyword: return scheme == .dark ? Color(red: 0.34, green: 0.61, blue: 0.84) : Color(red: 0.0, green: 0.0, blue: 1.0)
//        case .punct: return .secondary
//        case .unknown: return .primary
//        case .ws: return .clear
//        }
//    }
//    
//    private func highlightedLine(_ fullString: String, query: String, activeOccurrenceIndex: Int?, onImageTap: @escaping (URL) -> Void) -> some View {
//        let tokens = tokenize(fullString)
//        
//        var counter = 0
//        // Build ONE AttributedString for the whole line (key + colon + value together) and render it as a
//        // single Text. Splitting key/value into two separate wrapping Text views caused SwiftUI to break lines
//        // at attribute-run boundaries unpredictably (the multi-run AttributedString wrap bug), which is what
//        // made the value appear on its own offset row instead of staying next to its key. A single Text wraps
//        // as one paragraph, so long lines wrap as a unit within the available width, and key/value stay glued.
//        let fullAttr = buildAttributedString(from: tokens, query: query, activeOccurrenceIndex: activeOccurrenceIndex, counter: &counter)
//        
//        return HStack(alignment: .top, spacing: 4) {
//            Text(fullAttr)
//                .fixedSize(horizontal: false, vertical: true) // allow wrapping within available width instead of overflowing
//                .frame(maxWidth: .infinity, alignment: .leading)
//            
//            if let imageURL = extractImageURL(from: fullString) {
//                AsyncImage(url: imageURL) { phase in
//                    if let image = phase.image {
//                        image.resizable()
//                            .scaledToFill()
//                            .frame(width: 14, height: 14)
//                            .cornerRadius(2)
//                            .onTapGesture {
//                                onImageTap(imageURL)
//                            }
//                    } else if phase.error != nil {
//                        Image(systemName: "photo").resizable().scaledToFit().frame(width: 14, height: 14).foregroundColor(.secondary)
//                    } else {
//                        ProgressView().frame(width: 14, height: 14)
//                    }
//                }
//                .padding(.leading, 8)
//                .offset(y: 1)
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//    
//    private func buildAttributedString(from tokens: [Token], query: String, activeOccurrenceIndex: Int?, counter: inout Int) -> AttributedString {
//        var attrString = AttributedString()
//        
//        for token in tokens {
//            let baseColor = color(for: token.type, scheme: colorScheme)
//            if query.isEmpty || !token.text.lowercased().contains(query.lowercased()) {
//                var attrToken = AttributedString(token.text)
//                attrToken.foregroundColor = baseColor
//                attrString.append(attrToken)
//            } else {
//                for fragment in splitString(token.text, by: query) {
//                    var attrFrag = AttributedString(fragment.text)
//                    if fragment.isMatch {
//                        let isActiveOccurrence = (activeOccurrenceIndex != nil && counter == activeOccurrenceIndex!)
//                        attrFrag.foregroundColor = .black
//                        attrFrag.backgroundColor = isActiveOccurrence ? .orange : .yellow
//                        counter += 1
//                    } else {
//                        attrFrag.foregroundColor = baseColor
//                    }
//                    attrString.append(attrFrag)
//                }
//            }
//        }
//        return attrString
//    }
//    
//    private struct StringFragment: Identifiable {
//        let id = UUID()
//        let text: String
//        let isMatch: Bool
//    }
//    
//    private func splitString(_ fullString: String, by query: String) -> [StringFragment] {
//        var fragments: [StringFragment] = []
//        let lowerFull = fullString.lowercased()
//        let lowerQuery = query.lowercased()
//        
//        var currentIndex = fullString.startIndex
//        
//        while let range = lowerFull.range(of: lowerQuery, range: currentIndex..<fullString.endIndex) {
//            let prefix = String(fullString[currentIndex..<range.lowerBound])
//            if !prefix.isEmpty {
//                fragments.append(StringFragment(text: prefix, isMatch: false))
//            }
//            
//            let match = String(fullString[range])
//            fragments.append(StringFragment(text: match, isMatch: true))
//            
//            currentIndex = range.upperBound
//        }
//        
//        let suffix = String(fullString[currentIndex..<fullString.endIndex])
//        if !suffix.isEmpty {
//            fragments.append(StringFragment(text: suffix, isMatch: false))
//        }
//        
//        return fragments
//    }
//}
//
//struct ImagePreviewView: View {
//    @Environment(\.dismiss) var dismiss
//    let url: URL
//    
//    var body: some View {
//        NavigationView {
//            AsyncImage(url: url) { phase in
//                if let image = phase.image {
//                    image.resizable()
//                        .scaledToFit()
//                        .padding()
//                } else if phase.error != nil {
//                    VStack(spacing: 12) {
//                        Image(systemName: "exclamationmark.triangle")
//                            .font(.system(size: 40))
//                            .foregroundColor(.red)
//                        Text("Failed to load image")
//                    }
//                } else {
//                    ProgressView()
//                }
//            }
//            .navigationTitle("Preview")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//struct JSONLine: Identifiable {
//    let id: Int
//    let text: String
//}
//
//struct JSONLineCopyView<Content: View>: View {
//    let line: JSONLine
//    let content: Content
//    
//    @State private var showingCopied = false
//    @State private var isHovered = false
//    
//    init(line: JSONLine, @ViewBuilder content: () -> Content) {
//        self.line = line
//        self.content = content()
//    }
//    
//    var body: some View {
//        Button(action: {
//            UIPasteboard.general.string = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
//            UINotificationFeedbackGenerator().notificationOccurred(.success)
//            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//                showingCopied = true
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                withAnimation {
//                    showingCopied = false
//                }
//            }
//        }) {
//            HStack(alignment: .top, spacing: 4) {
//                content
//                
//                Spacer(minLength: 8)
//                if showingCopied {
//                    Image(systemName: "checkmark")
//                        .font(.caption.bold())
//                        .foregroundColor(.green)
//                        .transition(.scale.combined(with: .opacity))
//                } else if isHovered {
//                    Image(systemName: "doc.on.doc")
//                        .font(.caption)
//                        .foregroundColor(.gray.opacity(0.5))
//                }
//            }
//            .contentShape(Rectangle())
//            .frame(maxWidth: .infinity, alignment: .leading) // gives the row a defined width so key/value can wrap within it
//        }
//        .buttonStyle(.plain)
//        .onHover { hovering in
//            withAnimation(.easeInOut(duration: 0.2)) {
//                isHovered = hovering
//            }
//        }
//    }
//}
//
//extension JSONViewer where Header == EmptyView {
//    init(jsonString: String, searchText: String = "") {
//        self.init(jsonString: jsonString, searchText: searchText, header: { EmptyView() })
//    }
//}
//
//private enum JSONLexerConstants {
//    static let tokenPattern = "(?<string>\"(?:\\\\.|[^\"])*\")|(?<number>-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)|(?<keyword>\\b(?:true|false|null)\\b)|(?<punct>[\\[\\]\\{\\}\\:\\,])|(?<ws>\\s+)"
//    static let tokenRegex = try! NSRegularExpression(pattern: tokenPattern, options: [])
//}
