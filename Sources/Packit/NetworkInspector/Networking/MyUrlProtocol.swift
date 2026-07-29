@preconcurrency import Foundation

 final class MyURLProtocol: URLProtocol, URLSessionDataDelegate,  URLSessionTaskDelegate {
    private static let handledKey = "MyURLProtocolHandledKey"
    private var dataTask: URLSessionDataTask?
    private var transactionId: UUID?
    private var responseData = Data()
    private var response: URLResponse?
    private var responseError: Error?

    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        guard let url = request.url, let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let request = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return }
        URLProtocol.setProperty(true, forKey: MyURLProtocol.handledKey, in: request)
        
        // If the request uses a stream (like Alamofire POSTs), extract it into httpBody
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            
            while true {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break // EOF or Error
                }
            }
            buffer.deallocate()
            stream.close()
            
            request.httpBody = data
        }
        
        let transaction = NetworkTransaction(request: request as URLRequest, startTime: Date())
        self.transactionId = transaction.id
        NetworkStore.shared.addTransaction(transaction)
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: request as URLRequest)
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.responseData.append(data)
        self.client?.urlProtocol(self, didLoad: data)
    }
    
    // MARK: - URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.responseError = error
        
        if let id = self.transactionId {
            NetworkStore.shared.updateTransaction(id: id, with: self.response, data: self.responseData, error: error)
        }
        
        if let error = error {
            self.client?.urlProtocol(self, didFailWithError: error)
        } else {
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let id = self.transactionId else { return }
        guard let transactionMetrics = metrics.transactionMetrics.last else { return }
        
        DispatchQueue.main.async {
            if let index = NetworkStore.shared.transactions.firstIndex(where: { $0.id == id }) {
                var tx = NetworkStore.shared.transactions[index]
                
                if let fetchStart = transactionMetrics.fetchStartDate,
                   let domainStart = transactionMetrics.domainLookupStartDate,
                   let domainEnd = transactionMetrics.domainLookupEndDate,
                   let connectStart = transactionMetrics.connectStartDate,
                   let secureStart = transactionMetrics.secureConnectionStartDate,
                   let connectEnd = transactionMetrics.connectEndDate,
                   let requestStart = transactionMetrics.requestStartDate,
                   let responseStart = transactionMetrics.responseStartDate,
                   let responseEnd = transactionMetrics.responseEndDate {
                    
                    tx.dnsDuration = domainEnd.timeIntervalSince(domainStart)
                    tx.connectDuration = connectEnd.timeIntervalSince(connectStart)
                    tx.tlsDuration = connectEnd.timeIntervalSince(secureStart)
                    tx.ttfbDuration = responseStart.timeIntervalSince(requestStart)
                    tx.downloadDuration = responseEnd.timeIntervalSince(responseStart)
                }
                
                tx.isCacheHit = transactionMetrics.resourceFetchType == .localCache
                
                NetworkStore.shared.transactions[index] = tx
            }
        }
    }
}
