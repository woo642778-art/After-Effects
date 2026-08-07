struct PublicationGate: Equatable, Sendable {
    private(set) var latestToken = 0

    mutating func begin() -> Int {
        latestToken += 1
        return latestToken
    }

    func accepts(_ token: Int) -> Bool {
        token == latestToken
    }
}
