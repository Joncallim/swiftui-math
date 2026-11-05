import Foundation

/// Owned by DisplayProvider's existing serial lock. NSCache may evict values early;
/// an admission upper bound also enforces a hard ceiling without retaining a key registry.
final class BoundedRenderCache<Key: Hashable, Value> {
  private final class ValueBox {
    let value: Value
    init(_ value: Value) { self.value = value }
  }

  private let capacity: Int
  private let storage = NSCache<KeyBox<Key>, ValueBox>()
  private(set) var retainedEntryUpperBound = 0

  init(capacity: Int) {
    precondition(capacity > 0)
    self.capacity = capacity
  }

  func value(for key: Key) -> Value? { storage.object(forKey: KeyBox(key))?.value }

  func insert(_ value: Value, for key: Key) {
    let boxedKey = KeyBox(key)
    if storage.object(forKey: boxedKey) == nil {
      if retainedEntryUpperBound >= capacity {
        storage.removeAllObjects()
        retainedEntryUpperBound = 0
      }
      retainedEntryUpperBound += 1
    }
    storage.setObject(ValueBox(value), forKey: boxedKey)
  }
}
