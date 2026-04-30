import Foundation

enum State: String, Comparable {
    case idle, working, attention

    private var rank: Int {
        switch self {
        case .idle:      return 0
        case .working:   return 1
        case .attention: return 2
        }
    }

    static func < (a: State, b: State) -> Bool { a.rank < b.rank }
}
