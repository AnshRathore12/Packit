//import UIKit
//import SwiftUI
//
//// MARK: - JSON Viewer
//
///// High-performance JSON viewer.
/////
///// Architecture:
///// JSON String
/////     ↓
///// Background JSON parsing
/////     ↓
///// Flattened JSONLine models
/////     ↓
///// UICollectionView
/////     ↓
///// Reusable cells
/////
///// Expensive work is performed before rendering:
///// - JSON parsing
///// - syntax tokenization
///// - searchable text generation
///// - image URL detection
/////
///// The collection view only renders visible rows.
/////
/////
//
//final class LeftIndicatorCollectionView: UICollectionView {
///// Adjusts layout subviews to pin the vertical scroll indicator to the left margin.
//
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        
//        guard let verticalIndicator = subviews.first(where: {
//            $0.frame.width <= 4 &&
//            $0.frame.height > $0.frame.width
//        }) else {
//            return
//        }
//        
//        var frame = verticalIndicator.frame
//        frame.origin.x = 2
//        
//        verticalIndicator.frame = frame
//    }
//}
//
//final class JSONViewerController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
//    // MARK: Input
//    
//    private let jsonString: String
//    private let headerView: UIView
//    private let searchNavigator = UIView()
//    private let matchCountLabel = UILabel()
//    private let previousButton = UIButton(type: .system)
//    private let nextButton = UIButton(type: .system)
//    // MARK: UI
//    
//    
//    private var collectionView: UICollectionView!
//    
//    private let bodyScrollView = UIScrollView()
//    private let bodyContentView = UIView()
//    
//    private var bodyContentWidthConstraint: NSLayoutConstraint!
//    private var bodyContentWidth: CGFloat = 0
//    
//    // MARK: Data
//    
//    private var lines: [JSONLine] = []
//    
//    // MARK: Search
//    
//    private(set) var searchText: String = ""
//    
//    private var matches: [SearchMatch] = []
//    private var currentMatchIndex: Int = 0
//    private var navigationRepeatTimer: Timer?
//    
//    /// Invalidates older parsing/search operations.
//    private var generation: UInt64 = 0
//    private var parserGeneration = 0
//    private var searchGeneration = 0
//    
//    // MARK: Tasks
//    
//    private var parserWorkItem: DispatchWorkItem?
//    private var searchWorkItem: DispatchWorkItem?
//    
//    // MARK: Image
//    
//    private var selectedImageURL: URL?
//    
//    // MARK: Appearance
//    
//    private var currentColorScheme: UIUserInterfaceStyle {
//        traitCollection.userInterfaceStyle
//    }
//    
//    // MARK: Configuration
//    
//    private let rowHeight: CGFloat = 22
//    private let horizontalPadding: CGFloat = 16
//    private let imageSize: CGFloat = 18
//    
//    // MARK: Init
//    
//    var onFindRequested: (() -> Void)?
//    
//    override var canBecomeFirstResponder: Bool {
//        true
//    }
//    
//    override var keyCommands: [UIKeyCommand]? {
//        [
//            UIKeyCommand(
//                title: "Find in JSON",
//                action: #selector(handleCmdF),
//                input: "f",
//                modifierFlags: .command
//            ),
//            UIKeyCommand(
//                title: "Next Match",
//                action: #selector(nextMatch),
//                input: "\r"
//            ),
//            UIKeyCommand(
//                title: "Previous Match",
//                action: #selector(previousMatch),
//                input: "\r",
//                modifierFlags: .shift
//            )
//        ]
//    }
//        /// Responds to Command+F shortcut by invoking the find request closure.
//    @objc private func handleCmdF() {
//        onFindRequested?()
//    }
//    /// Initializes the controller with the raw JSON string and an optional top header view.
//    init(
//        jsonString: String,
//        headerView: UIView
//    ) {
//        self.jsonString = jsonString
//        self.headerView = headerView
//        
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    deinit {
//        parserWorkItem?.cancel()
//        searchWorkItem?.cancel()
//        navigationRepeatTimer?.invalidate()
//    }
//    
//    // MARK: Lifecycle
//    /// Sets up the collection view, header view, search bar overlay, and starts background JSON parsing.
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupCollectionView()
//        setupHeader()
//        parseJSON()
//        setupSearchNavigator()
//    }
//    /// Adjusts horizontal content width constraint to match view width on layout updates.
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        //        headerView.frame.size.width = view.bounds.width
//        let width = view.bounds.width
//        
//        guard width > 0 else {
//            return
//        }
//        
//        if bodyContentWidth < width {
//            bodyContentWidth = width
//            bodyContentWidthConstraint.constant = width
//        }
//    }
//    
//    // MARK: Setup
//    
//    /// Builds and constrains the floating search match navigation pill overlay.
//    private func setupSearchNavigator() {
//        searchNavigator.translatesAutoresizingMaskIntoConstraints = false
//        searchNavigator.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
//        
//        searchNavigator.layer.cornerRadius = 25
//        searchNavigator.layer.shadowColor = UIColor.black.cgColor
//        searchNavigator.layer.shadowOpacity = 0.15
//        searchNavigator.layer.shadowRadius = 10
//        searchNavigator.layer.shadowOffset = CGSize(width: 0, height: 5)
//        
//        view.addSubview(searchNavigator)
//        
//        NSLayoutConstraint.activate([
//            searchNavigator.trailingAnchor.constraint(equalTo: view.trailingAnchor,constant: -16),
//            searchNavigator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,constant: -66),
//            searchNavigator.heightAnchor.constraint(equalToConstant: 50)
//        ])
//        
//        // MARK: Count
//        
//        matchCountLabel.translatesAutoresizingMaskIntoConstraints = false
//        matchCountLabel.font = .systemFont(ofSize: 13, weight: .bold)
//        matchCountLabel.textColor = .label
//        
//        // MARK: Previous
//        previousButton.translatesAutoresizingMaskIntoConstraints = false
//        previousButton.setImage(UIImage(systemName: "chevron.up"),for: .normal)
//        previousButton.tintColor = .label
//        previousButton.addTarget(self,action: #selector(previousMatch),for: .touchUpInside)
//        let previousLongPress = UILongPressGestureRecognizer(
//            target: self,
//            action: #selector(handlePreviousLongPress(_:))
//        )
//        
//        previousButton.addGestureRecognizer(previousLongPress)
//        
//        // MARK: Next
//        
//        nextButton.translatesAutoresizingMaskIntoConstraints = false
//        nextButton.setImage(UIImage(systemName: "chevron.down"),for: .normal)
//        nextButton.tintColor = .label
//        nextButton.addTarget(self,action: #selector(nextMatch),for: .touchUpInside)
//        let nextLongPress = UILongPressGestureRecognizer(
//            target: self,
//            action: #selector(handleNextLongPress(_:))
//        )
//        
//        nextButton.addGestureRecognizer(nextLongPress)
//        
//        searchNavigator.addSubview(matchCountLabel)
//        searchNavigator.addSubview(previousButton)
//        searchNavigator.addSubview(nextButton)
//        
//        NSLayoutConstraint.activate([
//            matchCountLabel.leadingAnchor.constraint(equalTo: searchNavigator.leadingAnchor, constant: 16),
//            matchCountLabel.centerYAnchor.constraint(equalTo: searchNavigator.centerYAnchor),
//            
//            previousButton.leadingAnchor.constraint(equalTo: matchCountLabel.trailingAnchor, constant: 12),
//            previousButton.centerYAnchor.constraint(equalTo: searchNavigator.centerYAnchor),
//            previousButton.widthAnchor.constraint(equalToConstant: 32),
//            previousButton.heightAnchor.constraint(equalToConstant: 32),
//            
//            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 4),
//            nextButton.trailingAnchor.constraint(equalTo: searchNavigator.trailingAnchor, constant: -8),
//            nextButton.centerYAnchor.constraint(equalTo: searchNavigator.centerYAnchor),
//            nextButton.widthAnchor.constraint(equalToConstant: 32),
//            nextButton.heightAnchor.constraint(equalToConstant: 32)
//        ])
//        
//        searchNavigator.isHidden = true
//    }
//    
//    /// Handles long press gesture on the previous button to trigger repeating navigation.
//    @objc
//    private func handlePreviousLongPress(
//        _ gesture: UILongPressGestureRecognizer
//    ) {
//        switch gesture.state {
//        case .began:
//            startRepeatingNavigation { [weak self] in
//                self?.previousMatch()
//            }
//            
//        case .ended, .cancelled, .failed:
//            stopRepeatingNavigation()
//            
//        default:
//            break
//        }
//    }
//    
//    /// Handles long press gesture on the next button to trigger repeating navigation.
//
//    @objc
//    private func handleNextLongPress(
//        _ gesture: UILongPressGestureRecognizer
//    ) {
//        switch gesture.state {
//        case .began:
//            startRepeatingNavigation { [weak self] in
//                self?.nextMatch()
//            }
//            
//        case .ended, .cancelled, .failed:
//            stopRepeatingNavigation()
//            
//        default:
//            break
//        }
//    }
//    
//    /// Configures the horizontal scroll view container and embeds the vertical UICollectionView inside it.
//    private func setupCollectionView() {
//        let layout = UICollectionViewFlowLayout()
//        
//        layout.scrollDirection = .vertical
//        layout.minimumLineSpacing = 0
//        layout.minimumInteritemSpacing = 0
//        layout.sectionInset = .zero
//        
//        collectionView = LeftIndicatorCollectionView(frame: .zero,collectionViewLayout: layout)
//        collectionView.backgroundColor = .systemBackground
//        
//        // Vertical scrolling remains owned by UICollectionView.
//        collectionView.alwaysBounceVertical = true
//        collectionView.showsVerticalScrollIndicator = true
//        collectionView.dataSource = self
//        collectionView.delegate = self
//        collectionView.register(JSONLineCell.self, forCellWithReuseIdentifier: JSONLineCell.reuseIdentifier)
//        
//        // MARK: Horizontal body container
//        
//        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
//        bodyScrollView.backgroundColor = .systemBackground
//        
//        bodyScrollView.alwaysBounceHorizontal = true
//        bodyScrollView.alwaysBounceVertical = false
//        
//        bodyScrollView.showsHorizontalScrollIndicator = true
//        bodyScrollView.showsVerticalScrollIndicator = false
//        
//        bodyScrollView.isDirectionalLockEnabled = true
//        bodyScrollView.bounces = true
//        
//        bodyContentView.translatesAutoresizingMaskIntoConstraints = false
//        collectionView.translatesAutoresizingMaskIntoConstraints = false
//        
//        view.addSubview(bodyScrollView)
//        bodyScrollView.addSubview(bodyContentView)
//        bodyContentView.addSubview(collectionView)
//        
//        bodyContentWidth = view.bounds.width
//        
//        bodyContentWidthConstraint = bodyContentView.widthAnchor.constraint(equalToConstant: max(bodyContentWidth, 1))
//        
//        NSLayoutConstraint.activate([
//            // Scroll view
//            bodyScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            bodyScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            bodyScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            
//            // Content
//            bodyContentView.leadingAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.leadingAnchor),
//            bodyContentView.trailingAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.trailingAnchor),
//            bodyContentView.topAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.topAnchor),
//            bodyContentView.bottomAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.bottomAnchor),
//            bodyContentWidthConstraint,
//            
//            // Collection view fills the horizontally-scrollable content.
//            collectionView.leadingAnchor.constraint(equalTo: bodyContentView.leadingAnchor),
//            collectionView.trailingAnchor.constraint(equalTo: bodyContentView.trailingAnchor),
//            collectionView.topAnchor.constraint(equalTo: bodyContentView.topAnchor),
//            collectionView.bottomAnchor.constraint(equalTo: bodyContentView.bottomAnchor),
//            
//            // Keep vertical scrolling owned by UICollectionView.
//            collectionView.heightAnchor.constraint(equalTo: bodyScrollView.frameLayoutGuide.heightAnchor)
//        ])
//    }
//    /// Pins the custom top header view directly above the scrollable JSON body.
//    private func setupHeader() {
//        headerView.translatesAutoresizingMaskIntoConstraints = false
//        
//        view.addSubview(headerView)
//        
//        NSLayoutConstraint.activate([
//            headerView.topAnchor.constraint(equalTo: view.topAnchor),
//            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1),
//            
//            // Body starts immediately below the header.
//            bodyScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor)
//        ])
//    }
//    
//    // MARK: Parsing
//    /// Asynchronously parses the raw JSON string into tokenized JSONLine models on a background thread.
//    private func parseJSON() {
//        print("🔥 parseJSON CALLED")
//        parserWorkItem?.cancel()
//        
//        parserGeneration &+= 1
//        let currentGeneration = parserGeneration
//        
//        let input = jsonString
//        
//        let workItem = DispatchWorkItem { [weak self] in
//            
//            guard let self else { return }
//            print("🔥 parser work started")
//            
//            let parsedLines = JSONViewerParser.shared.parse(input)
//            
//            print("🔥 parsed lines:",parsedLines.count)
//            
//            guard !Thread.current.isCancelled else {
//                print("🔥 parser cancelled")
//                return
//            }
//            
//            DispatchQueue.main.async { [weak self] in
//                guard let self else {
//                    return
//                }
//                print("🔥 MAIN: assigning lines:", parsedLines.count)
//                guard currentGeneration == self.parserGeneration else {
//                    print("🔥 parser generation mismatch")
//                    return
//                }
//                self.lines = parsedLines
//                self.updateBodyContentWidth()
//                print("🔥 lines assigned:",self.lines.count)
//                self.collectionView.reloadData()
//                print("🔥 reloadData called")
//                self.scheduleSearch( self.searchText)
//            }
//        }
//        
//        parserWorkItem = workItem
//        
//        DispatchQueue.global(
//            qos: .userInitiated
//        ).async(
//            execute: workItem
//        )
//    }
//    
//    // MARK: Search
//    /// Updates the active search query and initiates a background query scan.
//
//    func updateSearchText( _ text: String) {
////        searchText = normalizedSearchText(text)
//        searchText = text
//        scheduleSearch(text)
//    }
//    
//    private func normalizedSearchText(_ text: String) -> String {
//        text
//            .replacingOccurrences(of: "“", with: "\"")
//            .replacingOccurrences(of: "”", with: "\"")
//            .replacingOccurrences(of: "‘", with: "'")
//            .replacingOccurrences(of: "’", with: "'")
//            .lowercased()
//    }
//    /// Schedules an asynchronous background search across all parsed lines using generation tracking.
//    private func scheduleSearch(_ text: String) {
//        searchWorkItem?.cancel()
//        generation &+= 1
//        let currentGeneration = generation
////        let query = normalizedSearchText(text)
//        let query = text
//            .trimmingCharacters(in: .whitespacesAndNewlines)
//            .lowercased()
//        print("QUERY:", query)
//        print("QUERY UTF8:", Array(query.utf8))
//       
//        
//        guard !query.isEmpty else {
//            matches.removeAll(keepingCapacity: true)
//            currentMatchIndex = 0
//            collectionView.reloadData()
//            updateSearchNavigator()
//            return
//        }
//        
//        // Take a snapshot so the background thread doesn't access
//        // the mutable `lines` array while the UI is changing it.
//        let snapshot = lines
//        
//        let workItem = DispatchWorkItem { [weak self] in
//            guard let self else { return }
//            var result: [SearchMatch] = []
//            
//            result.reserveCapacity( min(snapshot.count, 512))
//            for line in snapshot {
//                // Don't use workItem.isCancelled here.
//                // The work item cannot safely reference itself.
//                //
//                // Generation is used to reject stale results.
//                
//                let searchableText = line.searchableText
//                guard !searchableText.isEmpty else { continue }
//                print("LINE:", searchableText)
//                print("LINE UTF8:", Array(searchableText.utf8))
//                var searchStart = searchableText.startIndex
//                var occurrenceIndex = 0
//                while searchStart < searchableText.endIndex {
//                    guard let range = searchableText.range( of: query, range: searchStart..<searchableText.endIndex) else { break }
//                    result.append(SearchMatch(lineId: line.id,occurrenceIndex: occurrenceIndex))
//                    occurrenceIndex += 1
//                    
//                    // Prevent an infinite loop.
//                    if range.upperBound == searchableText.endIndex { break }
//                    searchStart = range.upperBound
//                }
//            }
//            
//            DispatchQueue.main.async { [weak self] in
//                guard let self else { return }
//                // Ignore results from an older search.
//                guard currentGeneration == self.generation else { return }
//                
//                // Ignore results if the search text changed.
//                let currentQuery = normalizedSearchText(self.searchText).trimmingCharacters( in: .whitespacesAndNewlines ).lowercased()
//                guard currentQuery == query else { return }
//                self.matches = result
//                self.currentMatchIndex = 0
//                self.collectionView.reloadData()
//                self.updateSearchNavigator()
//                if !result.isEmpty {
//                    self.scrollToCurrentMatch()
//                }
//            }
//        }
//        
//        searchWorkItem = workItem
//        
//        DispatchQueue.global(
//            qos: .userInitiated
//        ).async(
//            execute: workItem
//        )
//    }
//    // MARK: Search Navigation
//    /// Advances the active match index to the next search occurrence and scrolls to bring it into view.
//    func nextSearchMatch() {
//        guard !matches.isEmpty else { return}
//        if currentMatchIndex < matches.count - 1 {
//            currentMatchIndex += 1
//        } else {
//            currentMatchIndex = 0
//        }
//        scrollToCurrentMatch()
//    }
//    
//    /// Moves the active match index to the previous search occurrence and scrolls to bring it into view.
//    func previousSearchMatch() {
//        guard !matches.isEmpty else {return}
//        if currentMatchIndex > 0 {
//            currentMatchIndex -= 1
//        } else {
//            currentMatchIndex = matches.count - 1
//        }
//        scrollToCurrentMatch()
//    }
//    /// Smoothly adjusts horizontal scroll offset so that a highlighted occurrence is comfortably visible.
//    private func scrollHorizontallyToMatch(in line: JSONLine, occurrenceIndex: Int) {
//        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//        guard !query.isEmpty else { return }
//        
//        // Find the character offset of the occurrenceIndex-th match within this line.
//        let lowerText = line.searchableText
//        var searchStart = lowerText.startIndex
//        var currentOccurrence = 0
//        var matchStartCharOffset: Int?
//        
//        while searchStart < lowerText.endIndex {
//            guard let range = lowerText.range(of: query, range: searchStart..<lowerText.endIndex) else {
//                break
//            }
//            
//            if currentOccurrence == occurrenceIndex {
//                matchStartCharOffset = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
//                break
//            }
//            
//            currentOccurrence += 1
//            searchStart = range.upperBound
//            
//            if searchStart >= lowerText.endIndex { break }
//        }
//        
//        guard let charOffset = matchStartCharOffset else { return }
//        
//        // Estimate horizontal pixel position, same character-width assumption
//        // used elsewhere for the monospaced font.
//        let characterWidth: CGFloat = 7.8
//        var leadingOffset: CGFloat = horizontalPadding
//        
//        if line.imageURL != nil {
//            leadingOffset += imageSize + 8 // thumbnail width + stack spacing
//        }
//        
//        let matchStartX = leadingOffset + CGFloat(charOffset) * characterWidth
//        let matchWidth = CGFloat(query.count) * characterWidth
//        let matchEndX = matchStartX + matchWidth
//        
//        let visibleWidth = bodyScrollView.bounds.width
//        guard visibleWidth > 0 else { return }
//        
//        let currentOffsetX = bodyScrollView.contentOffset.x
//        let margin: CGFloat = 40
//        
//        var targetOffsetX = currentOffsetX
//        
//        // Only scroll if the match isn't already comfortably visible.
//        if matchStartX < currentOffsetX + margin {
//            targetOffsetX = max(0, matchStartX - margin)
//        } else if matchEndX > currentOffsetX + visibleWidth - margin {
//            targetOffsetX = matchEndX - visibleWidth + margin
//        }
//        
//        let maxOffsetX = max(0, bodyContentWidth - visibleWidth)
//        targetOffsetX = min(max(0, targetOffsetX), maxOffsetX)
//        
//        bodyScrollView.setContentOffset(
//            CGPoint(x: targetOffsetX, y: bodyScrollView.contentOffset.y),
//            animated: true
//        )
//    }
//    
//    /// Centers the current search match vertically and scrolls horizontally to bring the match into view.
//    private func scrollToCurrentMatch() {
//        
//        guard matches.indices.contains(currentMatchIndex) else { return }
//        let match = matches[currentMatchIndex]
//        guard let index = lines.firstIndex( where: { $0.id == match.lineId }) else {
//            return
//        }
//        
//        let indexPath = IndexPath(item: index,section: 0)
//        
//        collectionView.scrollToItem( at: indexPath, at: .centeredVertically, animated: false )
//        collectionView.reloadItems(at: [indexPath])
//        scrollHorizontallyToMatch(in: lines[index], occurrenceIndex: match.occurrenceIndex)
//        
//    }
//    
//    /// Starts a recurring timer to perform repetitive navigation when holding down a search step button.
//    private func startRepeatingNavigation(_ action: @escaping () -> Void) {
//        navigationRepeatTimer?.invalidate()
//        
//        action()
//        
//        navigationRepeatTimer = Timer.scheduledTimer(
//            //            withTimeInterval: 0.15,
//            withTimeInterval: 0.01,
//            repeats: true
//        ) { _ in
//            action()
//        }
//    }
//    
//    /// Cancels and flushes the repeating navigation timer.
//    private func stopRepeatingNavigation() {
//        navigationRepeatTimer?.invalidate()
//        navigationRepeatTimer = nil
//    }
//    
//    /// Updates the text label and visibility of the search match counter pill.
//    private func updateSearchNavigator() {
//        if matches.isEmpty  {
//            searchNavigator.isHidden = true
//            return
//        }
//        searchNavigator.isHidden = false
//        matchCountLabel.text = "\(currentMatchIndex + 1) of \(matches.count)"
//    }
//    
//    /// Navigates to the previous search match with animated highlight transition.
//    @objc func previousMatch() {
//        guard !matches.isEmpty else {
//            return
//        }
//        
//        let oldMatch = matches[currentMatchIndex]
//        
//        if currentMatchIndex > 0 {
//            currentMatchIndex -= 1
//        } else {
//            currentMatchIndex = matches.count - 1
//        }
//        
//        let newMatch = matches[currentMatchIndex]
//        
//        updateSearchNavigator()
//        
//        reloadMatchCells(
//            oldMatch: oldMatch,
//            newMatch: newMatch
//        )
//        
//        scrollToCurrentMatch()
//    }
//    
//    /// Reloads cells affected by match transitions to swap orange and yellow highlight states.
//    private func reloadMatchCells(oldMatch: SearchMatch, newMatch: SearchMatch) {
//        var indexPaths: [IndexPath] = []
//        
//        if oldMatch.lineId >= 0 && oldMatch.lineId < lines.count {
//            indexPaths.append(IndexPath( item: oldMatch.lineId,section: 0))
//        }
//        
//        if newMatch.lineId >= 0 && newMatch.lineId < lines.count {
//            let newIndexPath = IndexPath( item: newMatch.lineId, section: 0)
//            if !indexPaths.contains(newIndexPath) {
//                indexPaths.append(newIndexPath)
//            }
//        }
//        collectionView.reloadItems( at: indexPaths)
//    }
//    
//    /// Navigates to the next search match with animated highlight transition.
//    @objc func nextMatch() {
//        guard !matches.isEmpty else {
//            return
//        }
//        let oldMatch = matches[currentMatchIndex]
//        if currentMatchIndex < matches.count - 1 {
//            currentMatchIndex += 1
//        } else {
//            currentMatchIndex = 0
//        }
//        let newMatch = matches[currentMatchIndex]
//        updateSearchNavigator()
//        reloadMatchCells( oldMatch: oldMatch,  newMatch: newMatch)
//        scrollToCurrentMatch()
//    }
//    
//    // MARK: UICollectionView
//    /// Returns single section for all JSON lines.
//    func numberOfSections( in collectionView: UICollectionView) -> Int {
//        1
//    }
//    /// Returns the total number of parsed JSON lines.
//    func collectionView( _ collectionView: UICollectionView, numberOfItemsInSection section: Int ) -> Int {
//        lines.count
//    }
//    
//    /// Dequeues and configures a JSONLineCell for rendering a single line of syntax-highlighted JSON.
//    func collectionView( _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        
//        guard let cell = collectionView.dequeueReusableCell( withReuseIdentifier: JSONLineCell.reuseIdentifier, for: indexPath) as? JSONLineCell else {
//            return UICollectionViewCell()
//        }
//        
//        guard lines.indices.contains(indexPath.item) else {
//            return cell
//        }
//        
//        let line = lines[indexPath.item]
//        let activeOccurrence: Int?
//        
//        if matches.indices.contains(currentMatchIndex),
//           matches[currentMatchIndex].lineId == line.id {
//            activeOccurrence = matches[currentMatchIndex].occurrenceIndex
//        } else {
//            activeOccurrence = nil
//        }
//        
//        cell.configure(
//            line: line,
//            searchText: searchText,
//            activeOccurrenceIndex: activeOccurrence,
//            colorScheme: currentColorScheme,
//            imageSize: imageSize
//        ) { [weak self] url in
//            self?.showImagePreview(url)
//        }
//        
//        return cell
//    }
//    
//    // MARK: Layout=
//    /// Calculates the row dimensions for collection view cells.
//    func collectionView( _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath ) -> CGSize {
//        CGSize(width: collectionView.bounds.width,height: rowHeight)
//    }
//    
//    // MARK: Selection
//    /// Handles tapping a line to copy its text to the clipboard and display a confirmation checkmark.
//    func collectionView( _ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        guard lines.indices.contains(indexPath.item) else { return }
//        let line = lines[indexPath.item]
//        
//        // Copy line
//        UIPasteboard.general.string = line.text.trimmingCharacters( in: .whitespacesAndNewlines )
//        // Haptic feedback
//        UINotificationFeedbackGenerator().notificationOccurred(.success)
//        // Show checkmark on the tapped cell
//        guard let cell = collectionView.cellForItem( at: indexPath ) as? JSONLineCell else { return }
//        cell.showCopyIndicator()
//    }
//    
//    /// Measures the widest line in the document to set up horizontal scroll width constraints.
//    private func updateBodyContentWidth() {
//        guard !lines.isEmpty else { return }
//         
//        let characterWidth: CGFloat = 7.8
//        let padding: CGFloat = 32
//        
//        var maximumCharacters = 0
//        for line in lines {
//            maximumCharacters = max( maximumCharacters, line.text.count)
//        }
//        
//        let calculatedWidth = CGFloat(maximumCharacters) * characterWidth + padding
//        
//        // Prevent absurdly large content sizes for pathological
//        // single-line JSON.
//        let maximumWidth: CGFloat = 16_000
//        let minimumWidth = view.bounds.width
//        
//        bodyContentWidth = max( minimumWidth, min(calculatedWidth, maximumWidth))
//        bodyContentWidthConstraint.constant = bodyContentWidth
//        bodyScrollView.layoutIfNeeded()
//        collectionView.collectionViewLayout.invalidateLayout()
//    }
//    // MARK: Image Preview
//    /// Displays a modal sheet previewing the image at the given URL inside a UINavigationController with a Close button.
//    private func showImagePreview( _ url: URL) {
//        selectedImageURL = url
//        let controller = ImagePreviewViewController(url: url)
//        let navController = UINavigationController(rootViewController: controller)
//        navController.modalPresentationStyle = .pageSheet
//        present( navController, animated: true)
//    }
//}
//
//// MARK: - Search Match
//struct SearchMatch: Equatable, Sendable {
//    let lineId: Int
//    let occurrenceIndex: Int
//}
//
//// MARK: - JSON Line
//struct JSONLine: Identifiable {
//    let id: Int
//    let text: String
//    /// Lowercase version used by search.
//    let searchableText: String
//    /// Pre-tokenized syntax highlighting.
//    let tokens: [JSONToken]
//    /// Image URL detected during parsing.
//    let imageURL: URL?
//}
//
//// MARK: - Token
//struct JSONToken {
//    let text: String
//    let type: JSONTokenType
//}
//
//// MARK: - Token Type
//enum JSONTokenType {
//    case key
//    case string
//    case number
//    case keyword
//    case punctuation
//    case whitespace
//    case unknown
//}
//
//// MARK: - Parser
//final class JSONViewerParser {
//    static let shared = JSONViewerParser()
//    private init() {}
//    private static let detector:
//    NSDataDetector? = { try? NSDataDetector( types: NSTextCheckingResult.CheckingType.link.rawValue)}()
//    /// Pretty-prints a raw JSON string and converts each line into a tokenized JSONLine object.
//    func parse(_ jsonString: String) -> [JSONLine] {
//        let prettyString: String
//        if let data = jsonString.data(using: .utf8),
//           let object = try? JSONSerialization.jsonObject(with: data, options: []),
//           let prettyData = try? JSONSerialization.data( withJSONObject: object,options: [.prettyPrinted,.withoutEscapingSlashes]),
//           let result = String(data: prettyData,encoding: .utf8){
//            prettyString = result
//        } else {
//            prettyString = jsonString
//        }
//        
//        let rawLines = prettyString.split( separator: "\n", omittingEmptySubsequences: false)
//        
//        var result: [JSONLine] = []
//        result.reserveCapacity(rawLines.count)
//        
//        for (index, substring) in rawLines.enumerated() {
//            let text = String(substring)
//            let tokens = tokenize(text)
//            let searchableText = text.lowercased()
//            
//            let imageURL = detectImageURL(from: text )
//            
//            result.append(JSONLine(id: index, text: text,searchableText: searchableText, tokens: tokens, imageURL: imageURL))
//        }
//        return result
//    }
//    
//    // MARK: Tokenizer
//    /// Breaks a single line of text into typed JSONToken segments using regular expressions.
//    private func tokenize( _ line: String) -> [JSONToken] {
//        var tokens: [JSONToken] = []
//        let nsString = line as NSString
//        let range = NSRange( location: 0, length: nsString.length )
//        let matches = JSONLexerConstants.tokenRegex.matches(in: line, options: [],range: range)
//        var lastIndex = 0
//        
//        for match in matches {
//            if match.range.location > lastIndex {
//                let gap = nsString.substring(with: NSRange(location: lastIndex,length: match.range.location - lastIndex))
//                tokens.append(JSONToken(text: gap, type: .unknown ))
//            }
//            
//            let end = match.range.location + match.range.length
//            lastIndex = end
//            
//            if let stringRange = optionalRange(match,name: "string"){
//                let string = nsString.substring(with: stringRange)
//                let suffixRange = NSRange(location: end,length: max(0,nsString.length - end))
//                let suffix = nsString.substring(with: suffixRange)
//                let isKey = suffix.trimmingCharacters( in: .whitespaces).hasPrefix(":")
//                tokens.append(JSONToken(text: string, type: isKey ? .key : .string ))
//            } else if let numberRange = optionalRange(match, name: "number"){
//                tokens.append(JSONToken(text: nsString.substring( with: numberRange),type: .number))
//            } else if let keywordRange = optionalRange(match, name: "keyword"){
//                tokens.append(JSONToken(text: nsString.substring(with: keywordRange),type: .keyword))
//            } else if let punctuationRange = optionalRange(match, name: "punct"){
//                tokens.append(JSONToken(text: nsString.substring(with: punctuationRange),type: .punctuation))
//            } else if let whitespaceRange = optionalRange(match, name: "ws"){
//                tokens.append(JSONToken(text: nsString.substring(with: whitespaceRange),type: .whitespace))
//            }
//        }
//        
//        if lastIndex < nsString.length {
//            let gap = nsString.substring(with: NSRange(location: lastIndex, length: nsString.length - lastIndex))
//            tokens.append(JSONToken(text: gap, type: .unknown))
//        }
//        
//        return tokens
//    }
//    
//    /// Safely extracts the NSRange of a named capture group from a regex match result.
//    private func optionalRange(_ match: NSTextCheckingResult, name: String) -> NSRange? {
//        let range = match.range(withName: name)
//        guard range.location != NSNotFound, range.length > 0 else {
//            return nil
//        }
//        return range
//    }
//    
//    // MARK: Image URL Detection
//    /// Scans a text line for HTTP/HTTPS image links or relative image paths (e.g. TMDB).
//    private func detectImageURL( from text: String ) -> URL? {
//        guard let detector = Self.detector else {
//            return nil
//        }
//        let range = NSRange(location: 0, length: text.utf16.count)
//        let matches = detector.matches(in: text,options: [], range: range)
//        for match in matches {
//            guard let url = match.url, let scheme = url.scheme else {
//                continue
//            }
//            
//            guard scheme.lowercased() == "http" || scheme.lowercased() == "https" else {
//                continue
//            }
//            if isImageURL(url) {
//                return url
//            }
//        }
//        
//        // TMDB-style relative path.
//        let quotedParts = text.components(separatedBy: "\"")
//        for component in quotedParts {
//            guard component.hasPrefix("/") else {
//                continue
//            }
//            let lower = component.lowercased()
//            guard lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") else {
//                continue
//            }
//            if component.count > 10 {
//                return URL(string: "https://image.tmdb.org/t/p/w500" + component)
//            }
//        }
//        
//        return nil
//    }
//    
//    /// Checks whether a given URL points to a supported image file format based on extension.
//    private func isImageURL(_ url: URL) -> Bool {
//        let path = url.path.lowercased()
//        let extensions = [".jpg",".jpeg",".png",".gif",".webp"]
//        if extensions.contains(where: {path.hasSuffix($0)}) {
//            return true
//        }
//        
//        let absolute = url.absoluteString.lowercased()
//        return extensions.contains( where: {absolute.contains($0)})
//    }
//}
//
//// MARK: - Lexer Constants
//private enum JSONLexerConstants {
//    static let tokenPattern = #"(?<string>"(?:\\.|[^"])*")|(?<number>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?<keyword>\b(?:true|false|null)\b)|(?<punct>[\[\]\{\}:,])|(?<ws>\s+)"#
//    static let tokenRegex = try! NSRegularExpression(pattern: tokenPattern, options: [])
//}
//
//// MARK: - JSON Cell
//final class JSONLineCell: UICollectionViewCell {
//    private let copyIndicator: UIImageView = {
//        let imageView = UIImageView(
//            image: UIImage(systemName: "checkmark")
//        )
//        
//        imageView.tintColor = .systemGreen
//        imageView.contentMode = .scaleAspectFit
//        imageView.isHidden = true
//        
//        return imageView
//    }()
//    static let reuseIdentifier = "JSONLineCell"
//    private var lineText = ""
//    private let lineLabel = UILabel()
//    private let imageView = UIImageView()
//    private let stackView = UIStackView()
//    private var representedImageURL: URL?
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setup()
//    }
//    required init?( coder: NSCoder) {
//        super.init(coder: coder)
//        setup()
//    }
//    /// Clears cell state, images, and text before being reused by the collection view.
//    override func prepareForReuse() {
//        super.prepareForReuse()
//        lineLabel.attributedText = nil
//        imageView.image = nil
//        imageView.isHidden = true
//        representedImageURL = nil
//        copyIndicator.isHidden = true
//    }
//    /// Temporarily displays a green checkmark indicating the line content was copied.
//    func showCopyIndicator() {
//        copyIndicator.isHidden = false
//        copyIndicator.alpha = 1
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
//            guard let self else { return }
//            self.copyIndicator.isHidden = true
//        }
//    }
//    
//    /// Builds subviews, layout constraints, fonts, and stack view containers for the cell.
//    private func setup() {
//        contentView.backgroundColor = .clear
//        lineLabel.numberOfLines = 1
//        lineLabel.font = .monospacedSystemFont(
//            ofSize: 13,
//            weight: .regular
//        )
//        lineLabel.lineBreakMode = .byClipping
//        imageView.contentMode = .scaleAspectFill
//        imageView.clipsToBounds = true
//        imageView.layer.cornerRadius = 2
//        imageView.isHidden = true
//        copyIndicator.image = UIImage(systemName: "checkmark")
//        copyIndicator.tintColor = .systemGreen
//        copyIndicator.contentMode = .scaleAspectFit
//        copyIndicator.isHidden = true
//        copyIndicator.setContentHuggingPriority(
//            .required,
//            for: .horizontal
//        )
//        stackView.axis = .horizontal
//        stackView.alignment = .center
//        stackView.spacing = 8
//        contentView.addSubview(stackView)
//        contentView.addSubview(copyIndicator)
//        stackView.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
//            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor,constant: -16),
//            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
//            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
//            
//            imageView.widthAnchor.constraint(equalToConstant: 18),
//            imageView.heightAnchor.constraint(equalToConstant: 18),
//            copyIndicator.widthAnchor.constraint(equalToConstant: 14),
//            copyIndicator.heightAnchor.constraint(equalToConstant: 16)
//        ])
//        stackView.addArrangedSubview(copyIndicator)
//        stackView.addArrangedSubview(imageView)
//        stackView.addArrangedSubview(lineLabel)
//    }
//    /// Binds a JSONLine model, applies search highlights, loads image thumbnail, and attaches tap gestures.
//    func configure(
//        line: JSONLine,
//        searchText: String,
//        activeOccurrenceIndex: Int?,
//        colorScheme: UIUserInterfaceStyle,
//        imageSize: CGFloat,
//        onImageTap: @escaping (URL) -> Void
//    ) {
//        
//        let attributed = JSONAttributedStringBuilder.build(
//            tokens: line.tokens,
//            query: searchText,
//            activeOccurrenceIndex: activeOccurrenceIndex,
//            colorScheme: colorScheme
//        )
////        let attributed = JSONAttributedStringBuilder.build(
////            line: line,
////            query: searchText,
////            activeOccurrenceIndex: activeOccurrenceIndex,
////            colorScheme: colorScheme
////        )
//        
//        lineLabel.attributedText = attributed
//        if let imageURL = line.imageURL {
//            imageView.isHidden = false
//            representedImageURL = imageURL
//            JSONImageLoader.shared.load(imageURL) { [weak self] image in
//                guard let self else { return }
//                guard self.representedImageURL == imageURL else {
//                    return
//                }
//                DispatchQueue.main.async {
//                    if let image {
//                        self.imageView.image = image
//                        let tap = UITapGestureRecognizer(target: self, action: #selector( self.imageTapped))
//                        self.imageView
//                            .gestureRecognizers?
//                            .forEach { self.imageView.removeGestureRecognizer( $0 ) }
//                        self.imageView.isUserInteractionEnabled = true
//                        self.imageView.addGestureRecognizer( tap )
//                        self.imageTapHandler = onImageTap
//                    } else {
//                        self.imageView.image = UIImage( systemName: "photo" )
//                        self.imageView.tintColor = .secondaryLabel
//                    }
//                }
//            }
//        } else {
//            imageView.isHidden = true
//            imageView.image = nil
//        }
//    }
//    
//    private var imageTapHandler: ((URL) -> Void)?
//    /// Responds to tapping the image thumbnail by triggering the image preview handler.
//    @objc private func imageTapped() {
//        guard let url = representedImageURL else { return }
//        imageTapHandler?(url)
//    }
//}
//
//// MARK: - Attributed String Builder
//private enum JSONAttributedStringBuilder {
//    static func build(tokens: [JSONToken], query: String, activeOccurrenceIndex: Int?, colorScheme:  UIUserInterfaceStyle ) -> NSAttributedString {
//        let result = NSMutableAttributedString()
//        let normalizedQuery = query.lowercased()
//        var occurrenceIndex = 0
//        
//        for token in tokens {
//            let baseColor = color(for: token.type, style: colorScheme)
//            guard !normalizedQuery.isEmpty, token.text.range( of: normalizedQuery, options: .caseInsensitive) != nil
//            else {
//                result.append( NSAttributedString( string: token.text,attributes: [.foregroundColor: baseColor]))
//                continue
//            }
//            
//            appendHighlightedToken(token.text, baseColor: baseColor, query: normalizedQuery,
//                                   activeOccurrenceIndex: activeOccurrenceIndex,
//                                   occurrenceIndex: &occurrenceIndex,
//                                   result: result
//            )
//        }
//        
//        return result
//    }
//    
//    private static func appendHighlightedToken(
//        _ text: String,
//        baseColor: UIColor,
//        query: String,
//        activeOccurrenceIndex: Int?,
//        occurrenceIndex: inout Int,
//        result: NSMutableAttributedString
//    ) {
//        guard !text.isEmpty else {
//            return
//        }
//        
//        guard !query.isEmpty else {
//            result.append(NSAttributedString(string: text, attributes: [.foregroundColor: baseColor]))
//            return
//        }
//        let lowerText = text.lowercased()
//        let lowerQuery = query.lowercased()
//        var searchStart = lowerText.startIndex
//        var originalSearchStart = text.startIndex
//        
//        while searchStart < lowerText.endIndex {
//            guard let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) else {
//                break
//            }
//            
//            /*
//             Convert the UTF-16 offsets instead of trying to directly
//             convert String.Index between two different Strings.
//             */
//            let lowerStartOffset = lowerText.utf16.distance(
//                from: lowerText.utf16.startIndex,
//                to: range.lowerBound
//            )
//            
//            let lowerEndOffset = lowerText.utf16.distance(
//                from: lowerText.utf16.startIndex,
//                to: range.upperBound
//            )
//            
//            let textUTF16Start = text.utf16.index(
//                text.utf16.startIndex,
//                offsetBy: lowerStartOffset,
//                limitedBy: text.utf16.endIndex
//            )
//            
//            let textUTF16End = text.utf16.index(
//                text.utf16.startIndex,
//                offsetBy: lowerEndOffset,
//                limitedBy: text.utf16.endIndex
//            )
//            
//            guard
//                let textStartUTF16 = textUTF16Start,
//                let textEndUTF16 = textUTF16End,
//                let textStart = String.Index(textStartUTF16, within: text),
//                let textEnd = String.Index(textEndUTF16,within: text)
//            else {
//                break
//            }
//            
//            // Add text before the match.
//            if originalSearchStart < textStart {
//                let prefix = String(text[originalSearchStart..<textStart])
//                if !prefix.isEmpty {
//                    result.append(NSAttributedString(string: prefix,attributes: [.foregroundColor: baseColor]))
//                }
//            }
//            
//            // Add the matched text.
//            let match = String(text[textStart..<textEnd])
//            let isActive = activeOccurrenceIndex == occurrenceIndex
//            
//            result.append(NSAttributedString(string: match, attributes: [.foregroundColor: UIColor.black, .backgroundColor: isActive ? UIColor.orange : UIColor.yellow ]))
//            
//            occurrenceIndex += 1
//            
//            // Move forward.
//            searchStart = range.upperBound
//            originalSearchStart = textEnd
//            
//            // Safety against an infinite loop.
//            if searchStart >= lowerText.endIndex {
//                break
//            }
//        }
//        
//        // Append anything remaining after the last match.
//        if originalSearchStart < text.endIndex {
//            let remaining = String(
//                text[originalSearchStart..<text.endIndex]
//            )
//            
//            if !remaining.isEmpty {
//                result.append(NSAttributedString(string: remaining, attributes: [.foregroundColor: baseColor]))
//            }
//        }
//    }
//    
//    private static func color(for type: JSONTokenType, style: UIUserInterfaceStyle) -> UIColor {
//        let dark = style == .dark
//        switch type {
//        case .key:
//            return dark ? UIColor(red: 0.61, green: 0.86, blue: 0.99, alpha: 1)
//            : UIColor(red: 0.02, green: 0.32, blue: 0.65, alpha: 1)
//        case .string:
//            return dark ? UIColor(red: 0.81, green: 0.57, blue: 0.47, alpha: 1)
//            : UIColor(red: 0.64, green: 0.08, blue: 0.08, alpha: 1)
//        case .number:
//            return dark ? UIColor(red: 0.71, green: 0.81, blue: 0.66,alpha: 1)
//            : UIColor(red: 0.04, green: 0.53, blue: 0.35,alpha: 1)
//        case .keyword:
//            return dark ? UIColor(red: 0.34, green: 0.61, blue: 0.84, alpha: 1)
//            : UIColor.blue
//        case .punctuation:
//            return .secondaryLabel
//        case .whitespace:
//            return .label
//        case .unknown:
//            return .label
//        }
//    }
//}
//
///// Formatter creating syntax-highlighted and search-highlighted NSAttributedStrings for JSON tokens.
////private enum JSONAttributedStringBuilder {
////    /// Generates a styled NSAttributedString from tokens with highlighted search query substrings.
////    static func build(
////        line: JSONLine,
////        query: String,
////        activeOccurrenceIndex: Int?,
////        colorScheme: UIUserInterfaceStyle
////    ) -> NSAttributedString {
////
////        let result = NSMutableAttributedString()
////
////        // --------------------------------------------------
////        // 1. Build the normal syntax-highlighted JSON
////        // --------------------------------------------------
////
////        for token in line.tokens {
////
////            let baseColor = color(
////                for: token.type,
////                style: colorScheme
////            )
////
////            result.append(
////                NSAttributedString(
////                    string: token.text,
////                    attributes: [
////                        .foregroundColor: baseColor
////                    ]
////                )
////            )
////        }
////
////        // --------------------------------------------------
////        // 2. No search query
////        // --------------------------------------------------
////
////        guard !query.isEmpty else {
////            return result
////        }
////
////        // --------------------------------------------------
////        // 3. Find matches in the COMPLETE line
////        // --------------------------------------------------
////
////        let lowerText = line.text.lowercased()
////        let lowerQuery = query.lowercased()
////
////        var searchStart = lowerText.startIndex
////        var occurrenceIndex = 0
////
////        while searchStart < lowerText.endIndex {
////
////            guard let range = lowerText.range(
////                of: lowerQuery,
////                range: searchStart..<lowerText.endIndex
////            ) else {
////                break
////            }
////
////            // Convert String.Index → NSRange
////            let nsRange = NSRange(
////                range,
////                in: line.text
////            )
////
////            let isActive =
////                activeOccurrenceIndex == occurrenceIndex
////
////            result.addAttributes(
////                [
////                    .foregroundColor: UIColor.black,
////                    .backgroundColor: isActive
////                        ? UIColor.orange
////                        : UIColor.yellow
////                ],
////                range: nsRange
////            )
////
////            occurrenceIndex += 1
////
////            if range.upperBound == lowerText.endIndex {
////                break
////            }
////
////            searchStart = range.upperBound
////        }
////
////        return result
////    }
////        /// Maps a JSONTokenType to a theme-appropriate foreground UIColor for light and dark interface styles.
////        private static func color(
////        for type: JSONTokenType,
////        style: UIUserInterfaceStyle
////    ) -> UIColor {
////
////        let dark = style == .dark
////
////        switch type {
////
////        case .key:
////            return dark
////                ? UIColor(
////                    red: 0.61,
////                    green: 0.86,
////                    blue: 0.99,
////                    alpha: 1
////                )
////                : UIColor(
////                    red: 0.02,
////                    green: 0.32,
////                    blue: 0.65,
////                    alpha: 1
////                )
////
////        case .string:
////            return dark
////                ? UIColor(
////                    red: 0.81,
////                    green: 0.57,
////                    blue: 0.47,
////                    alpha: 1
////                )
////                : UIColor(
////                    red: 0.64,
////                    green: 0.08,
////                    blue: 0.08,
////                    alpha: 1
////                )
////
////        case .number:
////            return dark
////                ? UIColor(
////                    red: 0.71,
////                    green: 0.81,
////                    blue: 0.66,
////                    alpha: 1
////                )
////                : UIColor(
////                    red: 0.04,
////                    green: 0.53,
////                    blue: 0.35,
////                    alpha: 1
////                )
////
////        case .keyword:
////            return dark
////                ? UIColor(
////                    red: 0.34,
////                    green: 0.61,
////                    blue: 0.84,
////                    alpha: 1
////                )
////                : UIColor.blue
////
////        case .punctuation:
////            return .secondaryLabel
////
////        case .whitespace:
////            return .label
////
////        case .unknown:
////            return .label
////        }
////    }
////}
//
//// MARK: - Image Loader
///// Memory-cached image loader using an in-memory NSCache and ephemeral URLSession.
//final class JSONImageLoader {
//    static let shared = JSONImageLoader()
//    private let cache = NSCache<NSURL, UIImage>()
//    private let session: URLSession
//    private init() {
//        let configuration = URLSessionConfiguration.ephemeral
//        configuration.requestCachePolicy = .returnCacheDataElseLoad
//        configuration.timeoutIntervalForRequest = 15
//        configuration.timeoutIntervalForResource = 30
//        session = URLSession( configuration: configuration)
//        cache.countLimit = 100
//    }
//    
//    /// Asynchronously fetches an image from URL or returns cached instance if available.
//    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
//        if let cached = cache.object(forKey: url as NSURL) {
//            completion(cached)
//            return
//        }
//        session.dataTask( with: url) { [weak self] data, _, _ in
//            guard let data, let image = UIImage(data: data) else {
//                completion(nil)
//                return
//            }
//            self?.cache.setObject( image, forKey: url as NSURL )
//            completion(image)
//        }.resume()
//    }
//}
//
//// MARK: - Image Preview
//final class ImagePreviewViewController: UIViewController {
//    private let url: URL
//    private let imageView = UIImageView()
//    private let activityIndicator = UIActivityIndicatorView( style: .large )
//    
//    init(url: URL) {
//        self.url = url
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    /// Sets up navigation bar, close button, image view, and triggers image loading.
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        print("🔥 JSONViewerController viewDidLoad")
//        view.backgroundColor = .systemBackground
//        title = "Preview"
//        navigationItem.rightBarButtonItem = UIBarButtonItem(
//            title: "Close",
//            style: .plain,
//            target: self,
//            action: #selector(dismissPreview)
//        )
//        setupImageView()
//        loadImage()
//    }
//    
//    /// Configures aspect-fit image view and centers the loading activity indicator.
//    private func setupImageView() {
//        imageView.contentMode = .scaleAspectFit
//        imageView.clipsToBounds = true
//        view.addSubview( imageView )
//        imageView.translatesAutoresizingMaskIntoConstraints = false
//        
//        NSLayoutConstraint.activate([
//            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16 ),
//            imageView.leadingAnchor.constraint( equalTo: view.leadingAnchor,constant: 16),
//            imageView.trailingAnchor.constraint( equalTo: view.trailingAnchor, constant: -16),
//            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16 )
//        ])
//        
//        view.addSubview(activityIndicator)
//        
//        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
//        
//        NSLayoutConstraint.activate([
//            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor )
//        ])
//    }
//    
//    /// Fetches image from cache/network and displays it in the image view.
//    private func loadImage() {
//        activityIndicator.startAnimating()
//        JSONImageLoader.shared.load(
//            url
//        ) { [weak self] image in
//            DispatchQueue.main.async {
//                guard let self else { return }
//                self.activityIndicator
//                    .stopAnimating()
//                if let image {
//                    self.imageView.image = image
//                } else {
//                    self.imageView.image = UIImage(systemName:"photo")
//                }
//            }
//        }
//    }
//    
//    /// Dismisses the modal preview sheet.
//    @objc
//    private func dismissPreview() {
//        dismiss(animated: true)
//    }
//}
//
//// MARK: - Search Command
//public enum JSONSearchCommand: Equatable, Sendable {
//    case next
//    case previous
//}
//
//// MARK: - SwiftUI Wrapper
///// SwiftUI representable wrapper integrating JSONViewerController into SwiftUI layouts.
//struct JSONViewer<Header: View>: UIViewControllerRepresentable {
//    typealias UIViewControllerType = JSONViewerController
//    
//    let jsonString: String
//    var searchText: String = ""
//    @Binding var searchCommand: JSONSearchCommand?
//    var onFindRequested: (() -> Void)?
//    let header: Header
//    
//    /// Initializes the SwiftUI wrapper with raw JSON, search query, search stepping binding, and custom header.
//
//    init(
//        jsonString: String,
//        searchText: String = "",
//        searchCommand: Binding<JSONSearchCommand?> = .constant(nil),
//        onFindRequested: (() -> Void)? = nil,
//        @ViewBuilder header: () -> Header
//    ) {
//        self.jsonString = jsonString
//        self.searchText = searchText
//        self._searchCommand = searchCommand
//        self.onFindRequested = onFindRequested
//        self.header = header()
//    }
//    
//    /// Creates and configures the underlying JSONViewerController instance.
//    func makeUIViewController( context: Context) -> JSONViewerController {
//        let headerController = UIHostingController( rootView: header)
//        headerController.view.backgroundColor = .clear
//        let controller = JSONViewerController(jsonString: jsonString, headerView: headerController.view)
//        controller.onFindRequested = onFindRequested
//        return controller
//    }
//    
//    /// Updates search query and executes next/previous search stepping commands from SwiftUI state.
//    func updateUIViewController( _ uiViewController: JSONViewerController, context: Context) {
//        uiViewController.onFindRequested = onFindRequested
//        uiViewController.updateSearchText(searchText)
//        if let command = searchCommand {
//            switch command {
//            case .next:
//                uiViewController.nextMatch()
//            case .previous:
//                uiViewController.previousMatch()
//            }
//            DispatchQueue.main.async {
//                self.searchCommand = nil
//            }
//        }
//    }
//}
//
//// MARK: - Empty Header Convenience
//extension JSONViewer
///// Convenience initializer when no custom header view is required.
//where Header == EmptyView {
//    init(
//        jsonString: String,
//        searchText: String = "",
//        searchCommand: Binding<JSONSearchCommand?> = .constant(nil),
//        onFindRequested: (() -> Void)? = nil
//    ) {
//        self.init(
//            jsonString: jsonString,
//            searchText: searchText,
//            searchCommand: searchCommand,
//            onFindRequested: onFindRequested
//        ) {
//            EmptyView()
//        }
//    }
//}




import UIKit
import SwiftUI

// MARK: - JSON Viewer

/// High-performance JSON viewer.
///
/// Architecture:
/// JSON String
///     ↓
/// Background JSON parsing
///     ↓
/// Flattened JSONLine models
///     ↓
/// UICollectionView
///     ↓
/// Reusable cells
///
/// Expensive work is performed before rendering:
/// - JSON parsing
/// - syntax tokenization
/// - searchable text generation
/// - image URL detection
///
/// The collection view only renders visible rows.
///
///

final class LeftIndicatorCollectionView: UICollectionView {

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let verticalIndicator = subviews.first(where: {
            $0.frame.width <= 4 &&
            $0.frame.height > $0.frame.width
        }) else {
            return
        }

        var frame = verticalIndicator.frame
        frame.origin.x = 2

        verticalIndicator.frame = frame
    }
}

final class JSONViewerController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
// MARK: Input

private let jsonString: String
private let headerView: UIView
private let searchNavigator = UIView()
private let matchCountLabel = UILabel()
private let previousButton = UIButton(type: .system)
private let nextButton = UIButton(type: .system)
// MARK: UI


private var collectionView: UICollectionView!

private let bodyScrollView = UIScrollView()
private let bodyContentView = UIView()

private var bodyContentWidthConstraint: NSLayoutConstraint!
private var bodyContentWidth: CGFloat = 0

// MARK: Data

private var lines: [JSONLine] = []

// MARK: Search

private(set) var searchText: String = ""

private var matches: [SearchMatch] = []
private var currentMatchIndex: Int = 0
private var navigationRepeatTimer: Timer?

/// Invalidates older parsing/search operations.
private var generation: UInt64 = 0
private var parserGeneration = 0
private var searchGeneration = 0

// MARK: Tasks

private var parserWorkItem: DispatchWorkItem?
private var searchWorkItem: DispatchWorkItem?

// MARK: Image

private var selectedImageURL: URL?

// MARK: Appearance

private var currentColorScheme: UIUserInterfaceStyle {
    traitCollection.userInterfaceStyle
}

// MARK: Configuration

private let rowHeight: CGFloat = 22
private let horizontalPadding: CGFloat = 16
private let imageSize: CGFloat = 18

// MARK: Init

var onFindRequested: (() -> Void)?

override var canBecomeFirstResponder: Bool {
    true
}

override var keyCommands: [UIKeyCommand]? {
    [
        UIKeyCommand(
            title: "Find in JSON",
            action: #selector(handleCmdF),
            input: "f",
            modifierFlags: .command
        ),
        UIKeyCommand(
            title: "Next Match",
            action: #selector(nextMatch),
            input: "\r"
        ),
        UIKeyCommand(
            title: "Previous Match",
            action: #selector(previousMatch),
            input: "\r",
            modifierFlags: .shift
        )
    ]
}

@objc private func handleCmdF() {
    onFindRequested?()
}

init(
    jsonString: String,
    headerView: UIView
) {
    self.jsonString = jsonString
    self.headerView = headerView

    super.init(nibName: nil, bundle: nil)
}

required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
}

deinit {
    parserWorkItem?.cancel()
    searchWorkItem?.cancel()
    navigationRepeatTimer?.invalidate()
}

// MARK: Lifecycle

override func viewDidLoad() {
    super.viewDidLoad()
    setupCollectionView()
    setupHeader()
    parseJSON()
    setupSearchNavigator()
}

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
//        headerView.frame.size.width = view.bounds.width
    let width = view.bounds.width

        guard width > 0 else {
            return
        }

        if bodyContentWidth < width {
            bodyContentWidth = width
            bodyContentWidthConstraint.constant = width
        }
}

// MARK: Setup
private func setupSearchNavigator() {
    searchNavigator.translatesAutoresizingMaskIntoConstraints = false
    searchNavigator.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)

    searchNavigator.layer.cornerRadius = 25
    searchNavigator.layer.shadowColor = UIColor.black.cgColor
    searchNavigator.layer.shadowOpacity = 0.15
    searchNavigator.layer.shadowRadius = 10
    searchNavigator.layer.shadowOffset = CGSize(width: 0, height: 5)

    view.addSubview(searchNavigator)

    NSLayoutConstraint.activate([
        searchNavigator.trailingAnchor.constraint(equalTo: view.trailingAnchor,constant: -16),
        searchNavigator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,constant: -66),
        searchNavigator.heightAnchor.constraint(equalToConstant: 50)
    ])

    // MARK: Count

    matchCountLabel.translatesAutoresizingMaskIntoConstraints = false
    matchCountLabel.font = .systemFont(ofSize: 13, weight: .bold)
    matchCountLabel.textColor = .label

    // MARK: Previous
    previousButton.translatesAutoresizingMaskIntoConstraints = false
    previousButton.setImage(UIImage(systemName: "chevron.up"),for: .normal)
    previousButton.tintColor = .label
    previousButton.addTarget(self,action: #selector(previousMatch),for: .touchUpInside)
    let previousLongPress = UILongPressGestureRecognizer(
        target: self,
        action: #selector(handlePreviousLongPress(_:))
    )

    previousButton.addGestureRecognizer(previousLongPress)

    // MARK: Next

    nextButton.translatesAutoresizingMaskIntoConstraints = false
    nextButton.setImage(UIImage(systemName: "chevron.down"),for: .normal)
    nextButton.tintColor = .label
    nextButton.addTarget(self,action: #selector(nextMatch),for: .touchUpInside)
    let nextLongPress = UILongPressGestureRecognizer(
        target: self,
        action: #selector(handleNextLongPress(_:))
    )

    nextButton.addGestureRecognizer(nextLongPress)

    searchNavigator.addSubview(matchCountLabel)
    searchNavigator.addSubview(previousButton)
    searchNavigator.addSubview(nextButton)

    NSLayoutConstraint.activate([
        matchCountLabel.leadingAnchor.constraint(equalTo: searchNavigator.leadingAnchor, constant: 16),
        matchCountLabel.centerYAnchor.constraint(equalTo: searchNavigator.centerYAnchor),
        
        previousButton.leadingAnchor.constraint(equalTo: matchCountLabel.trailingAnchor, constant: 12),
        previousButton.centerYAnchor.constraint(equalTo: searchNavigator.centerYAnchor),
        previousButton.widthAnchor.constraint(equalToConstant: 32),
        previousButton.heightAnchor.constraint(equalToConstant: 32),
        
        nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 4),
        nextButton.trailingAnchor.constraint(equalTo: searchNavigator.trailingAnchor, constant: -8),
        nextButton.centerYAnchor.constraint(equalTo: searchNavigator.centerYAnchor),
        nextButton.widthAnchor.constraint(equalToConstant: 32),
        nextButton.heightAnchor.constraint(equalToConstant: 32)
    ])

    searchNavigator.isHidden = true
}
    @objc
    private func handlePreviousLongPress(
        _ gesture: UILongPressGestureRecognizer
    ) {
        switch gesture.state {
        case .began:
            startRepeatingNavigation { [weak self] in
                self?.previousMatch()
            }

        case .ended, .cancelled, .failed:
            stopRepeatingNavigation()

        default:
            break
        }
    }
    @objc
    private func handleNextLongPress(
        _ gesture: UILongPressGestureRecognizer
    ) {
        switch gesture.state {
        case .began:
            startRepeatingNavigation { [weak self] in
                self?.nextMatch()
            }

        case .ended, .cancelled, .failed:
            stopRepeatingNavigation()

        default:
            break
        }
    }
private func setupCollectionView() {
    let layout = UICollectionViewFlowLayout()

    layout.scrollDirection = .vertical
    layout.minimumLineSpacing = 0
    layout.minimumInteritemSpacing = 0
    layout.sectionInset = .zero

    collectionView = LeftIndicatorCollectionView(frame: .zero,collectionViewLayout: layout)
    collectionView.backgroundColor = .systemBackground

    // Vertical scrolling remains owned by UICollectionView.
    collectionView.alwaysBounceVertical = true
    collectionView.showsVerticalScrollIndicator = true
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.register(JSONLineCell.self, forCellWithReuseIdentifier: JSONLineCell.reuseIdentifier)

    // MARK: Horizontal body container

    bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
    bodyScrollView.backgroundColor = .systemBackground

    bodyScrollView.alwaysBounceHorizontal = true
    bodyScrollView.alwaysBounceVertical = false

    bodyScrollView.showsHorizontalScrollIndicator = true
    bodyScrollView.showsVerticalScrollIndicator = false

    bodyScrollView.isDirectionalLockEnabled = true
    bodyScrollView.bounces = true

    bodyContentView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(bodyScrollView)
    bodyScrollView.addSubview(bodyContentView)
    bodyContentView.addSubview(collectionView)

    bodyContentWidth = view.bounds.width

    bodyContentWidthConstraint = bodyContentView.widthAnchor.constraint(equalToConstant: max(bodyContentWidth, 1))

    NSLayoutConstraint.activate([
        // Scroll view
        bodyScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        bodyScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        bodyScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

        // Content
        bodyContentView.leadingAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.leadingAnchor),
        bodyContentView.trailingAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.trailingAnchor),
        bodyContentView.topAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.topAnchor),
        bodyContentView.bottomAnchor.constraint(equalTo: bodyScrollView.contentLayoutGuide.bottomAnchor),
        bodyContentWidthConstraint,

        // Collection view fills the horizontally-scrollable content.
        collectionView.leadingAnchor.constraint(equalTo: bodyContentView.leadingAnchor),
        collectionView.trailingAnchor.constraint(equalTo: bodyContentView.trailingAnchor),
        collectionView.topAnchor.constraint(equalTo: bodyContentView.topAnchor),
        collectionView.bottomAnchor.constraint(equalTo: bodyContentView.bottomAnchor),

        // Keep vertical scrolling owned by UICollectionView.
        collectionView.heightAnchor.constraint(equalTo: bodyScrollView.frameLayoutGuide.heightAnchor)
    ])
}

private func setupHeader() {
    headerView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(headerView)

    NSLayoutConstraint.activate([
        headerView.topAnchor.constraint(equalTo: view.topAnchor),
        headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1),

        // Body starts immediately below the header.
        bodyScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor)
    ])
}

// MARK: Parsing

private func parseJSON() {
    print("🔥 parseJSON CALLED")
    parserWorkItem?.cancel()

    parserGeneration &+= 1
    let currentGeneration = parserGeneration

    let input = jsonString

    let workItem = DispatchWorkItem { [weak self] in

        guard let self else { return }
        print("🔥 parser work started")

        let parsedLines = JSONViewerParser.shared.parse(input)

        print("🔥 parsed lines:",parsedLines.count)

        guard !Thread.current.isCancelled else {
            print("🔥 parser cancelled")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            print("🔥 MAIN: assigning lines:", parsedLines.count)
            guard currentGeneration == self.parserGeneration else {
                print("🔥 parser generation mismatch")
                return
            }
            self.lines = parsedLines
            self.updateBodyContentWidth()
            print("🔥 lines assigned:",self.lines.count)
            self.collectionView.reloadData()
            print("🔥 reloadData called")
            self.scheduleSearch( self.searchText)
        }
    }

    parserWorkItem = workItem

    DispatchQueue.global(
        qos: .userInitiated
    ).async(
        execute: workItem
    )
}

// MARK: Search

func updateSearchText( _ text: String) {
    searchText = text
    scheduleSearch(text)
}

private func scheduleSearch(_ text: String) {
    searchWorkItem?.cancel()
    generation &+= 1
    let currentGeneration = generation
    let query = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    guard !query.isEmpty else {
        matches.removeAll(keepingCapacity: true)
        currentMatchIndex = 0
        collectionView.reloadData()
        updateSearchNavigator()
        return
    }

    // Take a snapshot so the background thread doesn't access
    // the mutable `lines` array while the UI is changing it.
    let snapshot = lines

    let workItem = DispatchWorkItem { [weak self] in
        guard let self else { return }
        var result: [SearchMatch] = []

        result.reserveCapacity( min(snapshot.count, 512))
        for line in snapshot {
            // Don't use workItem.isCancelled here.
            // The work item cannot safely reference itself.
            //
            // Generation is used to reject stale results.

            let searchableText = line.searchableText
            guard !searchableText.isEmpty else { continue }

            var searchStart = searchableText.startIndex
            var occurrenceIndex = 0
            while searchStart < searchableText.endIndex {
                guard let range = searchableText.range( of: query, range: searchStart..<searchableText.endIndex) else { break }
                result.append(SearchMatch(lineId: line.id,occurrenceIndex: occurrenceIndex))
                occurrenceIndex += 1
                
                // Prevent an infinite loop.
                if range.upperBound == searchableText.endIndex { break }
                searchStart = range.upperBound
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Ignore results from an older search.
            guard currentGeneration == self.generation else { return }

            // Ignore results if the search text changed.
            let currentQuery = self.searchText.trimmingCharacters( in: .whitespacesAndNewlines ).lowercased()
            guard currentQuery == query else { return }
            self.matches = result
            self.currentMatchIndex = 0
            self.collectionView.reloadData()
            self.updateSearchNavigator()
            if !result.isEmpty {
                self.scrollToCurrentMatch()
            }
        }
    }

    searchWorkItem = workItem

    DispatchQueue.global(
        qos: .userInitiated
    ).async(
        execute: workItem
    )
}
// MARK: Search Navigation

func nextSearchMatch() {
    guard !matches.isEmpty else { return}
    if currentMatchIndex < matches.count - 1 {
        currentMatchIndex += 1
    } else {
        currentMatchIndex = 0
    }
    scrollToCurrentMatch()
}

func previousSearchMatch() {
    guard !matches.isEmpty else {return}
    if currentMatchIndex > 0 {
        currentMatchIndex -= 1
    } else {
        currentMatchIndex = matches.count - 1
    }
    scrollToCurrentMatch()
}

private func scrollHorizontallyToMatch(in line: JSONLine, occurrenceIndex: Int) {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return }

    // Find the character offset of the occurrenceIndex-th match within this line.
    let lowerText = line.searchableText
    var searchStart = lowerText.startIndex
    var currentOccurrence = 0
    var matchStartCharOffset: Int?

    while searchStart < lowerText.endIndex {
        guard let range = lowerText.range(of: query, range: searchStart..<lowerText.endIndex) else {
            break
        }

        if currentOccurrence == occurrenceIndex {
            matchStartCharOffset = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
            break
        }

        currentOccurrence += 1
        searchStart = range.upperBound

        if searchStart >= lowerText.endIndex { break }
    }

    guard let charOffset = matchStartCharOffset else { return }

    // Estimate horizontal pixel position, same character-width assumption
    // used elsewhere for the monospaced font.
    let characterWidth: CGFloat = 7.8
    var leadingOffset: CGFloat = horizontalPadding

    if line.imageURL != nil {
        leadingOffset += imageSize + 8 // thumbnail width + stack spacing
    }

    let matchStartX = leadingOffset + CGFloat(charOffset) * characterWidth
    let matchWidth = CGFloat(query.count) * characterWidth
    let matchEndX = matchStartX + matchWidth

    let visibleWidth = bodyScrollView.bounds.width
    guard visibleWidth > 0 else { return }

    let currentOffsetX = bodyScrollView.contentOffset.x
    let margin: CGFloat = 40

    var targetOffsetX = currentOffsetX

    // Only scroll if the match isn't already comfortably visible.
    if matchStartX < currentOffsetX + margin {
        targetOffsetX = max(0, matchStartX - margin)
    } else if matchEndX > currentOffsetX + visibleWidth - margin {
        targetOffsetX = matchEndX - visibleWidth + margin
    }

    let maxOffsetX = max(0, bodyContentWidth - visibleWidth)
    targetOffsetX = min(max(0, targetOffsetX), maxOffsetX)

    bodyScrollView.setContentOffset(
        CGPoint(x: targetOffsetX, y: bodyScrollView.contentOffset.y),
        animated: true
    )
}

private func scrollToCurrentMatch() {

    guard matches.indices.contains(currentMatchIndex) else { return }
    let match = matches[currentMatchIndex]
    guard let index = lines.firstIndex( where: { $0.id == match.lineId }) else {
        return
    }

    let indexPath = IndexPath(item: index,section: 0)

    collectionView.scrollToItem( at: indexPath, at: .centeredVertically, animated: false )
    collectionView.reloadItems(at: [indexPath])
    scrollHorizontallyToMatch(in: lines[index], occurrenceIndex: match.occurrenceIndex)

}

    private func startRepeatingNavigation(_ action: @escaping () -> Void) {
        navigationRepeatTimer?.invalidate()

        action()

        navigationRepeatTimer = Timer.scheduledTimer(
//            withTimeInterval: 0.15,
            withTimeInterval: 0.01,
            repeats: true
        ) { _ in
            action()
        }
    }

    private func stopRepeatingNavigation() {
        navigationRepeatTimer?.invalidate()
        navigationRepeatTimer = nil
    }
private func updateSearchNavigator() {
    if matches.isEmpty  {
        searchNavigator.isHidden = true
        return
    }
    searchNavigator.isHidden = false
    matchCountLabel.text = "\(currentMatchIndex + 1) of \(matches.count)"
}
    

@objc func previousMatch() {
    guard !matches.isEmpty else {
        return
    }

    let oldMatch = matches[currentMatchIndex]

    if currentMatchIndex > 0 {
        currentMatchIndex -= 1
    } else {
        currentMatchIndex = matches.count - 1
    }

    let newMatch = matches[currentMatchIndex]

    updateSearchNavigator()

    reloadMatchCells(
        oldMatch: oldMatch,
        newMatch: newMatch
    )

    scrollToCurrentMatch()
}

private func reloadMatchCells(oldMatch: SearchMatch, newMatch: SearchMatch) {
    var indexPaths: [IndexPath] = []

    if oldMatch.lineId >= 0 && oldMatch.lineId < lines.count {
        indexPaths.append(IndexPath( item: oldMatch.lineId,section: 0))
    }

    if newMatch.lineId >= 0 && newMatch.lineId < lines.count {
        let newIndexPath = IndexPath( item: newMatch.lineId, section: 0)
        if !indexPaths.contains(newIndexPath) {
            indexPaths.append(newIndexPath)
        }
    }
    collectionView.reloadItems( at: indexPaths)
}

@objc func nextMatch() {
    guard !matches.isEmpty else {
        return
    }
    let oldMatch = matches[currentMatchIndex]
    if currentMatchIndex < matches.count - 1 {
        currentMatchIndex += 1
    } else {
        currentMatchIndex = 0
    }
    let newMatch = matches[currentMatchIndex]
    updateSearchNavigator()
    reloadMatchCells( oldMatch: oldMatch,  newMatch: newMatch)
    scrollToCurrentMatch()
}
    
// MARK: UICollectionView
func numberOfSections( in collectionView: UICollectionView) -> Int {
    1
}

func collectionView( _ collectionView: UICollectionView, numberOfItemsInSection section: Int ) -> Int {
    lines.count
}

func collectionView( _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    guard let cell = collectionView.dequeueReusableCell( withReuseIdentifier: JSONLineCell.reuseIdentifier, for: indexPath) as? JSONLineCell else {
        return UICollectionViewCell()
    }
    
    guard lines.indices.contains(indexPath.item) else {
        return cell
    }

    let line = lines[indexPath.item]
    let activeOccurrence: Int?

    if matches.indices.contains(currentMatchIndex),
        matches[currentMatchIndex].lineId == line.id {
        activeOccurrence = matches[currentMatchIndex].occurrenceIndex
    } else {
        activeOccurrence = nil
    }

    cell.configure(
        line: line,
        searchText: searchText,
        activeOccurrenceIndex: activeOccurrence,
        colorScheme: currentColorScheme,
        imageSize: imageSize
    ) { [weak self] url in
        self?.showImagePreview(url)
    }

    return cell
}

// MARK: Layout=
func collectionView( _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath ) -> CGSize {
    CGSize(width: collectionView.bounds.width,height: rowHeight)
}

// MARK: Selection
func collectionView( _ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard lines.indices.contains(indexPath.item) else { return }
    let line = lines[indexPath.item]
    
    // Copy line
    UIPasteboard.general.string = line.text.trimmingCharacters( in: .whitespacesAndNewlines )
    // Haptic feedback
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    // Show checkmark on the tapped cell
    guard let cell = collectionView.cellForItem( at: indexPath ) as? JSONLineCell else { return }
    cell.showCopyIndicator()
}

private func updateBodyContentWidth() {
    guard !lines.isEmpty else { return }
    
    let characterWidth: CGFloat = 7.8
    let padding: CGFloat = 32

    var maximumCharacters = 0
    for line in lines {
        maximumCharacters = max( maximumCharacters, line.text.count)
    }

    let calculatedWidth = CGFloat(maximumCharacters) * characterWidth + padding

    // Prevent absurdly large content sizes for pathological
    // single-line JSON.
    let maximumWidth: CGFloat = 16_000
    let minimumWidth = view.bounds.width

    bodyContentWidth = max( minimumWidth, min(calculatedWidth, maximumWidth))
    bodyContentWidthConstraint.constant = bodyContentWidth
    bodyScrollView.layoutIfNeeded()
    collectionView.collectionViewLayout.invalidateLayout()
}
// MARK: Image Preview

private func showImagePreview( _ url: URL) {
    selectedImageURL = url
    let controller = ImagePreviewViewController(url: url)
    let navController = UINavigationController(rootViewController: controller)
    navController.modalPresentationStyle = .pageSheet
    present( navController, animated: true)
}
}

// MARK: - Search Match
struct SearchMatch: Equatable, Sendable {
    let lineId: Int
    let occurrenceIndex: Int
}

// MARK: - JSON Line
struct JSONLine: Identifiable {
    let id: Int
    let text: String
    /// Lowercase version used by search.
    let searchableText: String
    /// Pre-tokenized syntax highlighting.
    let tokens: [JSONToken]
    /// Image URL detected during parsing.
    let imageURL: URL?
}

// MARK: - Token
struct JSONToken {
    let text: String
    let type: JSONTokenType
}

// MARK: - Token Type
enum JSONTokenType {
    case key
    case string
    case number
    case keyword
    case punctuation
    case whitespace
    case unknown
}

// MARK: - Parser
final class JSONViewerParser {
    static let shared = JSONViewerParser()
    private init() {}
    private static let detector:
        NSDataDetector? = { try? NSDataDetector( types: NSTextCheckingResult.CheckingType.link.rawValue)}()

    func parse(_ jsonString: String) -> [JSONLine] {
        let prettyString: String
        if let data = jsonString.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data, options: []),
        let prettyData = try? JSONSerialization.data( withJSONObject: object,options: [.prettyPrinted,.withoutEscapingSlashes]),
        let result = String(data: prettyData,encoding: .utf8){
            prettyString = result
            } else {
            prettyString = jsonString
            }

        let rawLines = prettyString.split( separator: "\n", omittingEmptySubsequences: false)

        var result: [JSONLine] = []
        result.reserveCapacity(rawLines.count)
        
        for (index, substring) in rawLines.enumerated() {
            let text = String(substring)
            let tokens = tokenize(text)
            let searchableText = text.lowercased()

            let imageURL = detectImageURL(from: text )

            result.append(JSONLine(id: index, text: text,searchableText: searchableText, tokens: tokens, imageURL: imageURL))
        }
        return result
    }

    // MARK: Tokenizer

    private func tokenize( _ line: String) -> [JSONToken] {
        var tokens: [JSONToken] = []
        let nsString = line as NSString
        let range = NSRange( location: 0, length: nsString.length )
        let matches = JSONLexerConstants.tokenRegex.matches(in: line, options: [],range: range)
        var lastIndex = 0

        for match in matches {
            if match.range.location > lastIndex {
            let gap = nsString.substring(with: NSRange(location: lastIndex,length: match.range.location - lastIndex))
            tokens.append(JSONToken(text: gap, type: .unknown ))
            }

            let end = match.range.location + match.range.length
            lastIndex = end

            if let stringRange = optionalRange(match,name: "string"){
                let string = nsString.substring(with: stringRange)
                let suffixRange = NSRange(location: end,length: max(0,nsString.length - end))
                let suffix = nsString.substring(with: suffixRange)
                let isKey = suffix.trimmingCharacters( in: .whitespaces).hasPrefix(":")
                tokens.append(JSONToken(text: string, type: isKey ? .key : .string ))
            } else if let numberRange = optionalRange(match, name: "number"){
                    tokens.append(JSONToken(text: nsString.substring( with: numberRange),type: .number))
            } else if let keywordRange = optionalRange(match, name: "keyword"){
                tokens.append(JSONToken(text: nsString.substring(with: keywordRange),type: .keyword))
            } else if let punctuationRange = optionalRange(match, name: "punct"){
                tokens.append(JSONToken(text: nsString.substring(with: punctuationRange),type: .punctuation))
            } else if let whitespaceRange = optionalRange(match, name: "ws"){
                tokens.append(JSONToken(text: nsString.substring(with: whitespaceRange),type: .whitespace))
            }
        }

        if lastIndex < nsString.length {
            let gap = nsString.substring(with: NSRange(location: lastIndex, length: nsString.length - lastIndex))
            tokens.append(JSONToken(text: gap, type: .unknown))
        }

        return tokens
    }

    private func optionalRange(_ match: NSTextCheckingResult, name: String) -> NSRange? {
        let range = match.range(withName: name)
        guard range.location != NSNotFound, range.length > 0 else {
            return nil
        }
        return range
    }

    // MARK: Image URL Detection

    private func detectImageURL( from text: String ) -> URL? {
        guard let detector = Self.detector else {
            return nil
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector.matches(in: text,options: [], range: range)
        for match in matches {
            guard let url = match.url, let scheme = url.scheme else {
                continue
            }

            guard scheme.lowercased() == "http" || scheme.lowercased() == "https" else {
                continue
            }
            if isImageURL(url) {
                return url
            }
        }

        // TMDB-style relative path.
        let quotedParts = text.components(separatedBy: "\"")
        for component in quotedParts {
            guard component.hasPrefix("/") else {
                continue
            }
            let lower = component.lowercased()
            guard lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") else {
                continue
            }
            if component.count > 10 {
                return URL(string: "https://image.tmdb.org/t/p/w500" + component)
            }
        }

        return nil
    }

    private func isImageURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        let extensions = [".jpg",".jpeg",".png",".gif",".webp"]
        if extensions.contains(where: {path.hasSuffix($0)}) {
            return true
        }

        let absolute = url.absoluteString.lowercased()
        return extensions.contains( where: {absolute.contains($0)})
    }
}

// MARK: - Lexer Constants
private enum JSONLexerConstants {
    static let tokenPattern = #"(?<string>"(?:\\.|[^"])*")|(?<number>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?<keyword>\b(?:true|false|null)\b)|(?<punct>[\[\]\{\}:,])|(?<ws>\s+)"#
    static let tokenRegex = try! NSRegularExpression(pattern: tokenPattern, options: [])
}

// MARK: - JSON Cell
final class JSONLineCell: UICollectionViewCell {
    private let copyIndicator: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(systemName: "checkmark")
        )

        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true

        return imageView
    }()
    static let reuseIdentifier = "JSONLineCell"
    private var lineText = ""
    private let lineLabel = UILabel()
    private let imageView = UIImageView()
    private let stackView = UIStackView()
    private var representedImageURL: URL?
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?( coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        lineLabel.attributedText = nil
        imageView.image = nil
        imageView.isHidden = true
        representedImageURL = nil
        copyIndicator.isHidden = true
    }
    
    func showCopyIndicator() {
        copyIndicator.isHidden = false
        copyIndicator.alpha = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.copyIndicator.isHidden = true
        }
    }
    
    private func setup() {
        contentView.backgroundColor = .clear
        lineLabel.numberOfLines = 1
        lineLabel.font = .monospacedSystemFont(
            ofSize: 13,
            weight: .regular
        )
        lineLabel.lineBreakMode = .byClipping
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 2
        imageView.isHidden = true
        copyIndicator.image = UIImage(systemName: "checkmark")
        copyIndicator.tintColor = .systemGreen
        copyIndicator.contentMode = .scaleAspectFit
        copyIndicator.isHidden = true
        copyIndicator.setContentHuggingPriority(
            .required,
            for: .horizontal
        )
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        contentView.addSubview(stackView)
        contentView.addSubview(copyIndicator)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor,constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18),
            copyIndicator.widthAnchor.constraint(equalToConstant: 14),
            copyIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
        stackView.addArrangedSubview(copyIndicator)
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(lineLabel)
    }

    func configure(
        line: JSONLine,
        searchText: String,
        activeOccurrenceIndex: Int?,
        colorScheme: UIUserInterfaceStyle,
        imageSize: CGFloat,
        onImageTap: @escaping (URL) -> Void
    ) {
        
//        let attributed = JSONAttributedStringBuilder.build(
//            tokens: line.tokens,
//            query: searchText,
//            activeOccurrenceIndex: activeOccurrenceIndex,
//            colorScheme: colorScheme
//        )
        
        let attributed = JSONAttributedStringBuilder.build(
                    line: line,
                    query: searchText,
                    activeOccurrenceIndex: activeOccurrenceIndex,
                    colorScheme: colorScheme
                )
        
        
        lineLabel.attributedText = attributed
        if let imageURL = line.imageURL {
            imageView.isHidden = false
            representedImageURL = imageURL
            JSONImageLoader.shared.load(imageURL) { [weak self] image in
                guard let self else { return }
                guard self.representedImageURL == imageURL else {
                    return
                }
                DispatchQueue.main.async {
                    if let image {
                        self.imageView.image = image
                        let tap = UITapGestureRecognizer(target: self, action: #selector( self.imageTapped))
                        self.imageView
                            .gestureRecognizers?
                            .forEach { self.imageView.removeGestureRecognizer( $0 ) }
                        self.imageView.isUserInteractionEnabled = true
                        self.imageView.addGestureRecognizer( tap )
                        self.imageTapHandler = onImageTap
                    } else {
                        self.imageView.image = UIImage( systemName: "photo" )
                        self.imageView.tintColor = .secondaryLabel
                    }
                }
            }
        } else {
            imageView.isHidden = true
            imageView.image = nil
        }
    }

    private var imageTapHandler: ((URL) -> Void)?

    @objc private func imageTapped() {
        guard let url = representedImageURL else { return }
        imageTapHandler?(url)
    }
}

// MARK: - Attributed String Builder
//private enum JSONAttributedStringBuilder {
//    static func build(tokens: [JSONToken], query: String, activeOccurrenceIndex: Int?, colorScheme:  UIUserInterfaceStyle ) -> NSAttributedString {
//        let result = NSMutableAttributedString()
//        let normalizedQuery = query.lowercased()
//        var occurrenceIndex = 0
//
//        for token in tokens {
//            let baseColor = color(for: token.type, style: colorScheme)
//            guard !normalizedQuery.isEmpty, token.text.range( of: normalizedQuery, options: .caseInsensitive) != nil
//            else {
//                result.append( NSAttributedString( string: token.text,attributes: [.foregroundColor: baseColor]))
//                continue
//            }
//
//            appendHighlightedToken(token.text, baseColor: baseColor, query: normalizedQuery,
//                activeOccurrenceIndex: activeOccurrenceIndex,
//                occurrenceIndex: &occurrenceIndex,
//                result: result
//            )
//        }
//
//        return result
//    }
//
//    private static func appendHighlightedToken(
//        _ text: String,
//        baseColor: UIColor,
//        query: String,
//        activeOccurrenceIndex: Int?,
//        occurrenceIndex: inout Int,
//        result: NSMutableAttributedString
//    ) {
//        guard !text.isEmpty else {
//            return
//        }
//
//        guard !query.isEmpty else {
//            result.append(NSAttributedString(string: text, attributes: [.foregroundColor: baseColor]))
//            return
//        }
//        let lowerText = text.lowercased()
//        let lowerQuery = query.lowercased()
//        var searchStart = lowerText.startIndex
//        var originalSearchStart = text.startIndex
//
//        while searchStart < lowerText.endIndex {
//            guard let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) else {
//                break
//            }
//
//            /*
//             Convert the UTF-16 offsets instead of trying to directly
//             convert String.Index between two different Strings.
//             */
//            let lowerStartOffset = lowerText.utf16.distance(
//                from: lowerText.utf16.startIndex,
//                to: range.lowerBound
//            )
//
//            let lowerEndOffset = lowerText.utf16.distance(
//                from: lowerText.utf16.startIndex,
//                to: range.upperBound
//            )
//
//            let textUTF16Start = text.utf16.index(
//                text.utf16.startIndex,
//                offsetBy: lowerStartOffset,
//                limitedBy: text.utf16.endIndex
//            )
//
//            let textUTF16End = text.utf16.index(
//                text.utf16.startIndex,
//                offsetBy: lowerEndOffset,
//                limitedBy: text.utf16.endIndex
//            )
//
//            guard
//                let textStartUTF16 = textUTF16Start,
//                let textEndUTF16 = textUTF16End,
//                let textStart = String.Index(textStartUTF16, within: text),
//                let textEnd = String.Index(textEndUTF16,within: text)
//            else {
//                break
//            }
//
//            // Add text before the match.
//            if originalSearchStart < textStart {
//                let prefix = String(text[originalSearchStart..<textStart])
//                if !prefix.isEmpty {
//                    result.append(NSAttributedString(string: prefix,attributes: [.foregroundColor: baseColor]))
//                }
//            }
//
//            // Add the matched text.
//            let match = String(text[textStart..<textEnd])
//            let isActive = activeOccurrenceIndex == occurrenceIndex
//
//            result.append(NSAttributedString(string: match, attributes: [.foregroundColor: UIColor.black, .backgroundColor: isActive ? UIColor.orange : UIColor.yellow ]))
//            
//            occurrenceIndex += 1
//
//            // Move forward.
//            searchStart = range.upperBound
//            originalSearchStart = textEnd
//
//            // Safety against an infinite loop.
//            if searchStart >= lowerText.endIndex {
//                break
//            }
//        }
//
//        // Append anything remaining after the last match.
//        if originalSearchStart < text.endIndex {
//            let remaining = String(
//                text[originalSearchStart..<text.endIndex]
//            )
//
//            if !remaining.isEmpty {
//                result.append(NSAttributedString(string: remaining, attributes: [.foregroundColor: baseColor]))
//            }
//        }
//    }
//    
//    private static func color(for type: JSONTokenType, style: UIUserInterfaceStyle) -> UIColor {
//        let dark = style == .dark
//        switch type {
//        case .key:
//            return dark ? UIColor(red: 0.61, green: 0.86, blue: 0.99, alpha: 1)
//                : UIColor(red: 0.02, green: 0.32, blue: 0.65, alpha: 1)
//        case .string:
//            return dark ? UIColor(red: 0.81, green: 0.57, blue: 0.47, alpha: 1)
//                : UIColor(red: 0.64, green: 0.08, blue: 0.08, alpha: 1)
//        case .number:
//            return dark ? UIColor(red: 0.71, green: 0.81, blue: 0.66,alpha: 1)
//                : UIColor(red: 0.04, green: 0.53, blue: 0.35,alpha: 1)
//        case .keyword:
//            return dark ? UIColor(red: 0.34, green: 0.61, blue: 0.84, alpha: 1)
//                : UIColor.blue
//        case .punctuation:
//            return .secondaryLabel
//        case .whitespace:
//            return .label
//        case .unknown:
//            return .label
//        }
//    }
//}

/// Formatter creating syntax-highlighted and search-highlighted NSAttributedStrings for JSON tokens.
private enum JSONAttributedStringBuilder {
    /// Generates a styled NSAttributedString from tokens with highlighted search query substrings.
    static func build(
        line: JSONLine,
        query: String,
        activeOccurrenceIndex: Int?,
        colorScheme: UIUserInterfaceStyle
    ) -> NSAttributedString {

        let result = NSMutableAttributedString()

        // --------------------------------------------------
        // 1. Build the normal syntax-highlighted JSON
        // --------------------------------------------------

        for token in line.tokens {

            let baseColor = color(
                for: token.type,
                style: colorScheme
            )

            result.append(
                NSAttributedString(
                    string: token.text,
                    attributes: [
                        .foregroundColor: baseColor
                    ]
                )
            )
        }

        // --------------------------------------------------
        // 2. No search query
        // --------------------------------------------------

        guard !query.isEmpty else {
            return result
        }

        // --------------------------------------------------
        // 3. Find matches in the COMPLETE line
        // --------------------------------------------------

        let lowerText = line.text.lowercased()
        let lowerQuery = query.lowercased()

        var searchStart = lowerText.startIndex
        var occurrenceIndex = 0

        while searchStart < lowerText.endIndex {

            guard let range = lowerText.range(
                of: lowerQuery,
                range: searchStart..<lowerText.endIndex
            ) else {
                break
            }

            // Convert String.Index → NSRange
            let nsRange = NSRange(
                range,
                in: line.text
            )

            let isActive =
                activeOccurrenceIndex == occurrenceIndex

            result.addAttributes(
                [
                    .foregroundColor: UIColor.black,
                    .backgroundColor: isActive
                        ? UIColor.orange
                        : UIColor.yellow
                ],
                range: nsRange
            )

            occurrenceIndex += 1

            if range.upperBound == lowerText.endIndex {
                break
            }

            searchStart = range.upperBound
        }

        return result
    }
        /// Maps a JSONTokenType to a theme-appropriate foreground UIColor for light and dark interface styles.
        private static func color(
        for type: JSONTokenType,
        style: UIUserInterfaceStyle
    ) -> UIColor {

        let dark = style == .dark

        switch type {

        case .key:
            return dark
                ? UIColor(
                    red: 0.61,
                    green: 0.86,
                    blue: 0.99,
                    alpha: 1
                )
                : UIColor(
                    red: 0.02,
                    green: 0.32,
                    blue: 0.65,
                    alpha: 1
                )

        case .string:
            return dark
                ? UIColor(
                    red: 0.81,
                    green: 0.57,
                    blue: 0.47,
                    alpha: 1
                )
                : UIColor(
                    red: 0.64,
                    green: 0.08,
                    blue: 0.08,
                    alpha: 1
                )

        case .number:
            return dark
                ? UIColor(
                    red: 0.71,
                    green: 0.81,
                    blue: 0.66,
                    alpha: 1
                )
                : UIColor(
                    red: 0.04,
                    green: 0.53,
                    blue: 0.35,
                    alpha: 1
                )

        case .keyword:
            return dark
                ? UIColor(
                    red: 0.34,
                    green: 0.61,
                    blue: 0.84,
                    alpha: 1
                )
                : UIColor.blue

        case .punctuation:
            return .secondaryLabel

        case .whitespace:
            return .label

        case .unknown:
            return .label
        }
    }
}


// MARK: - Image Loader
final class JSONImageLoader {
    static let shared = JSONImageLoader()
    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession( configuration: configuration)
        cache.countLimit = 100
    }

    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        session.dataTask( with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            self?.cache.setObject( image, forKey: url as NSURL )
            completion(image)
        }.resume()
    }
}

// MARK: - Image Preview
final class ImagePreviewViewController: UIViewController {
    private let url: URL
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView( style: .large )

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔥 JSONViewerController viewDidLoad")
        view.backgroundColor = .systemBackground
        title = "Preview"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(dismissPreview)
        )
        setupImageView()
        loadImage()
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        view.addSubview( imageView )
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16 ),
            imageView.leadingAnchor.constraint( equalTo: view.leadingAnchor,constant: 16),
            imageView.trailingAnchor.constraint( equalTo: view.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16 )
        ])

        view.addSubview(activityIndicator)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor )
        ])
    }

    private func loadImage() {
        activityIndicator.startAnimating()
        JSONImageLoader.shared.load(
            url
        ) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                self.activityIndicator
                    .stopAnimating()
                if let image {
                    self.imageView.image = image
                } else {
                    self.imageView.image = UIImage(systemName:"photo")
                }
            }
        }
    }

    @objc
    private func dismissPreview() {
        dismiss(animated: true)
    }
}

// MARK: - Search Command
public enum JSONSearchCommand: Equatable, Sendable {
    case next
    case previous
}

// MARK: - SwiftUI Wrapper
struct JSONViewer<Header: View>: UIViewControllerRepresentable {
    typealias UIViewControllerType = JSONViewerController

    let jsonString: String
    var searchText: String = ""
    @Binding var searchCommand: JSONSearchCommand?
    var onFindRequested: (() -> Void)?
    let header: Header

    init(
        jsonString: String,
        searchText: String = "",
        searchCommand: Binding<JSONSearchCommand?> = .constant(nil),
        onFindRequested: (() -> Void)? = nil,
        @ViewBuilder header: () -> Header
    ) {
        self.jsonString = jsonString
        self.searchText = searchText
        self._searchCommand = searchCommand
        self.onFindRequested = onFindRequested
        self.header = header()
    }
    
    func makeUIViewController( context: Context) -> JSONViewerController {
        let headerController = UIHostingController( rootView: header)
        headerController.view.backgroundColor = .clear
        let controller = JSONViewerController(jsonString: jsonString, headerView: headerController.view)
        controller.onFindRequested = onFindRequested
        return controller
    }
    private func normalizedSearchText(_ text: String) -> String {
           text
               .replacingOccurrences(of: "“", with: "\"")
               .replacingOccurrences(of: "”", with: "\"")
               .replacingOccurrences(of: "‘", with: "'")
               .replacingOccurrences(of: "’", with: "'")
               .lowercased()
       }
    func updateUIViewController( _ uiViewController: JSONViewerController, context: Context) {
        uiViewController.onFindRequested = onFindRequested
        uiViewController.updateSearchText(normalizedSearchText(searchText))
        if let command = searchCommand {
            switch command {
            case .next:
                uiViewController.nextMatch()
            case .previous:
                uiViewController.previousMatch()
            }
            DispatchQueue.main.async {
                self.searchCommand = nil
            }
        }
    }
}

// MARK: - Empty Header Convenience
extension JSONViewer
where Header == EmptyView {
    init(
        jsonString: String,
        searchText: String = "",
        searchCommand: Binding<JSONSearchCommand?> = .constant(nil),
        onFindRequested: (() -> Void)? = nil
    ) {
        self.init(
            jsonString: jsonString,
            searchText: searchText,
            searchCommand: searchCommand,
            onFindRequested: onFindRequested
        ) {
            EmptyView()
        }
    }
}
