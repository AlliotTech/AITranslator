import Foundation

final class Debouncer {
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem?
    private let interval: TimeInterval

    init(intervalMs: Int, queue: DispatchQueue = .main) {
        self.interval = TimeInterval(intervalMs) / 1000.0
        self.queue = queue
    }

    func schedule(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: block)
        workItem = item
        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
