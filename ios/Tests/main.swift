import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let file = directory.appendingPathComponent("accounts.json")
defer { try? FileManager.default.removeItem(at: directory) }
var records = try AccountRecords.load(from: file)
for index in 1...100 { _ = try records.add(name: "Account \(index)") }
records.selectedID = records.accounts[37].id
try records.save(to: file)
let restored = try AccountRecords.load(from: file)
require(restored.accounts == records.accounts, "Account identifiers must survive restart")
require(Set(restored.accounts.map(\.id)).count == 100, "Each account must use its own persistent store")
require(restored.selectedID == records.selectedID, "Selection must survive restart")
let canonical = try InstagramLink.post("https://instagram.com/reels/ABC/?tracking=1")
require(canonical.absoluteString == "https://www.instagram.com/reel/ABC/", "Normalize links")
require(InstagramLink.startURL(hasSession: false).absoluteString == "https://www.instagram.com/accounts/login/", "New accounts must start at the web login form")
require(InstagramLink.startURL(hasSession: true) == InstagramLink.home, "Saved sessions can open home")
for invalid in ["http://instagram.com/p/ABC/", "https://evil.com/reel/ABC/", "https://instagram.com@evil.com/p/ABC/", "https://instagram.com:443/p/ABC/", "instagram://reel/ABC", "https://instagram.com/accounts/login/"] {
    do { _ = try InstagramLink.post(invalid); fatalError("Invalid link accepted") } catch { }
}
try Data("corrupted".utf8).write(to: file)
do { _ = try AccountRecords.load(from: file); fatalError("Corrupt data accepted") } catch { }
let unchanged = try String(contentsOf: file, encoding: .utf8)
require(unchanged == "corrupted", "Corrupt data must not be overwritten")
print("PASS: 100 isolated account identifiers, persisted names and selection, restricted link URLs, corrupt file preserved.")
