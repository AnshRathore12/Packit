//
//  MyURLProtocol.swift
//  NetworkInspector
//

@preconcurrency import Foundation

final class MyURLProtocol: URLProtocol,
                           URLSessionDataDelegate,
                           URLSessionTaskDelegate {

    // MARK: - Constants

    private static let handledKey = "MyURLProtocolHandledKey"

    // Prevent huge request/response bodies from causing memory pressure.
    private static let maxRequestBodySize = 1 * 1024 * 1024      // 1 MB
    private static let maxResponseBodySize = 2 * 1024 * 1024     // 2 MB

    // MARK: - Properties

    private var dataTask: URLSessionDataTask?

    private var transactionId: UUID?

    private var responseData = Data()

    private var response: URLResponse?

    private var responseError: Error?

    private var isResponseTruncated = false

    // Keep the forwarding session alive while the task is running.
    private var session: URLSession?

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {

        // Prevent infinite interception.
        if URLProtocol.property(
            forKey: handledKey,
            in: request
        ) != nil {
            return false
        }

        guard let scheme = request.url?.scheme?.lowercased() else {
            return false
        }

        // Only intercept HTTP/HTTPS.
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    // MARK: - Start Loading

    override func startLoading() {
        // Work on a mutable copy of the original request
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }

        // Prevent this request from being intercepted again
        URLProtocol.setProperty(
            true,
            forKey: Self.handledKey,
            in: mutableRequest
        )

        // If request uses a stream, convert it to Data
        if mutableRequest.httpBody == nil,
           let bodyStream = mutableRequest.httpBodyStream {
            if let body = Self.readBody(
                from: bodyStream,
                maxSize: Self.maxRequestBodySize
            ) {
                mutableRequest.httpBody = body
            }
        }

        let finalRequest = mutableRequest as URLRequest

        let transaction = NetworkTransaction(
            request: finalRequest,
            startTime: Date()
        )

        transactionId = transaction.id
        NetworkStore.shared.addTransaction(transaction)

        let configuration = URLSessionConfiguration.default

        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )

        self.session = session

        let task = session.dataTask(with: finalRequest)
        self.dataTask = task
        task.resume()
    }

    // MARK: - Stop Loading

    override func stopLoading() {

        dataTask?.cancel()

        dataTask = nil

        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (
            URLSession.ResponseDisposition
        ) -> Void
    ) {

        self.response = response

        // Forward response to original URLProtocol client.
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )

        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {

        // Capture only a limited amount of response data.
        if responseData.count < Self.maxResponseBodySize {

            let remaining =
                Self.maxResponseBodySize - responseData.count

            if data.count <= remaining {
                responseData.append(data)
            } else {
                responseData.append(
                    data.prefix(remaining)
                )

                isResponseTruncated = true
            }
        } else {
            isResponseTruncated = true
        }

        // IMPORTANT:
        // Always forward the ORIGINAL data to the app.
        client?.urlProtocol(
            self,
            didLoad: data
        )
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {

        responseError = error

        let transactionId = self.transactionId

        // Capture values before cleanup.
        let capturedResponse = response
        let capturedData = responseData
        let capturedTruncated = isResponseTruncated

        // Update NetworkStore.
        if let transactionId {

            NetworkStore.shared.updateTransaction(
                id: transactionId,
                with: capturedResponse,
                data: capturedData,
                error: error,
                isResponseTruncated: capturedTruncated
            )
        }

        // Notify original URLProtocol client.
        if let error {

            client?.urlProtocol(
                self,
                didFailWithError: error
            )

        } else {

            client?.urlProtocolDidFinishLoading(self)
        }

        // Cleanup.
        dataTask = nil
        self.response = nil
        self.responseError = nil
        self.responseData.removeAll(keepingCapacity: false)
        self.transactionId = nil

        session.finishTasksAndInvalidate()
        self.session = nil
    }

    // MARK: - Metrics

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {

        guard let transactionId else {
            return
        }

        guard let metric = metrics.transactionMetrics.last else {
            return
        }

        let dnsDuration: TimeInterval?

        if let start = metric.domainLookupStartDate,
           let end = metric.domainLookupEndDate {

            dnsDuration = end.timeIntervalSince(start)

        } else {
            dnsDuration = nil
        }

        let connectDuration: TimeInterval?

        if let start = metric.connectStartDate,
           let end = metric.connectEndDate {

            connectDuration = end.timeIntervalSince(start)

        } else {
            connectDuration = nil
        }

        let tlsDuration: TimeInterval?

        if let start = metric.secureConnectionStartDate,
           let end = metric.secureConnectionEndDate {

            tlsDuration = end.timeIntervalSince(start)

        } else {
            tlsDuration = nil
        }

        let ttfbDuration: TimeInterval?

        if let start = metric.requestStartDate,
           let end = metric.responseStartDate {

            ttfbDuration = end.timeIntervalSince(start)

        } else {
            ttfbDuration = nil
        }

        let downloadDuration: TimeInterval?

        if let start = metric.responseStartDate,
           let end = metric.responseEndDate {

            downloadDuration = end.timeIntervalSince(start)

        } else {
            downloadDuration = nil
        }

        let isCacheHit =
            metric.resourceFetchType == .localCache

        // Don't perform unnecessary work on the main thread.
        NetworkStore.shared.updateMetrics(
            transactionId: transactionId,
            dnsDuration: dnsDuration,
            connectDuration: connectDuration,
            tlsDuration: tlsDuration,
            ttfbDuration: ttfbDuration,
            downloadDuration: downloadDuration,
            isCacheHit: isCacheHit
        )
    }

    // MARK: - Request Body

    private static func readBody(
        from stream: InputStream,
        maxSize: Int
    ) -> Data? {

        stream.open()

        defer {
            stream.close()
        }

        var data = Data()

        let bufferSize = 16 * 1024

        let buffer = UnsafeMutablePointer<UInt8>.allocate(
            capacity: bufferSize
        )

        defer {
            buffer.deallocate()
        }

        while stream.hasBytesAvailable {

            let read = stream.read(
                buffer,
                maxLength: min(bufferSize, maxSize - data.count)
            )

            if read <= 0 {
                break
            }

            data.append(
                buffer,
                count: read
            )

            if data.count >= maxSize {
                break
            }
        }

        return data
    }
}
