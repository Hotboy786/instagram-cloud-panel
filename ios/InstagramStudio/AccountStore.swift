import Foundation
import Combine

@MainActor final class AccountStore: ObservableObject {
    @Published private(set) var records = AccountRecords()
    @Published var error: String?
    private let fileURL: URL
    private var available = true

    init() {
        fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProfileStudio/accounts.json")
        do { records = try AccountRecords.load(from: fileURL) }
        catch { available = false; self.error = "Account list could not be read. It has been kept untouched. \(error.localizedDescription)" }
    }

    func add(_ name: String) -> StudioAccount? {
        guard available else { error = "Account storage needs recovery before editing."; return nil }
        do {
            var next = records
            let account = try next.add(name: name)
            next.selectedID = account.id
            try next.save(to: fileURL)
            records = next
            return account
        } catch { self.error = error.localizedDescription; return nil }
    }

    func select(_ account: StudioAccount) {
        guard available else { return }
        do {
            var next = records; next.selectedID = account.id
            try next.save(to: fileURL); records = next
        } catch { self.error = error.localizedDescription }
    }
}
