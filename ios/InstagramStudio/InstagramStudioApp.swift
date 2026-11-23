import SwiftUI

@main struct InstagramStudioApp: App {
    var body: some Scene { WindowGroup { WorkspaceView().preferredColorScheme(.dark) } }
}

struct WorkspaceView: View {
    @StateObject private var store = AccountStore()
    @StateObject private var browser = BrowserModel()
    @State private var showAccounts = false
    @State private var postLink = ""
    private var selected: StudioAccount? { store.records.accounts.first { $0.id == browser.accountID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "camera.aperture").foregroundStyle(.pink)
                    Text(selected?.name ?? "Instagram Studio").font(.headline).lineLimit(1)
                    Spacer()
                    Button { showAccounts = true } label: {
                        Label("Accounts (\(store.records.accounts.count))", systemImage: "person.crop.rectangle.stack")
                    }.font(.caption)
                }.padding(.horizontal).padding(.vertical, 12)
                HStack(spacing: 8) {
                    TextField("Paste post or Reel link", text: $postLink)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder).onSubmit { browser.openPost(postLink) }
                    Button("Open") { browser.openPost(postLink) }.buttonStyle(.borderedProminent).tint(.purple)
                        .disabled(browser.webView == nil)
                }.padding(.horizontal).padding(.bottom, 10)
                if browser.loading { ProgressView().progressViewStyle(.linear).tint(.pink) }
                if let view = browser.webView {
                    EmbeddedBrowser(view: view).id(browser.accountID)
                } else {
                    ContentUnavailableView {
                        Label("All your profiles, on your iPhone", systemImage: "person.crop.rectangle.stack")
                    } description: {
                        Text("Add an account, then sign in directly inside this app. Your PC can stay off.")
                    } actions: {
                        Button("Add or choose account") { showAccounts = true }.buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                HStack {
                    Button { browser.webView?.goBack() } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Back")
                    Spacer()
                    Button { browser.webView?.reload() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Reload")
                    Spacer()
                    Button { browser.navigate("https://www.instagram.com/") } label: { Image(systemName: "house") }.accessibilityLabel("Instagram home")
                    Spacer()
                    Button { browser.navigate("https://www.instagram.com/reels/") } label: { Image(systemName: "play.rectangle") }.accessibilityLabel("Reels")
                    Spacer()
                    Button { browser.navigate("https://www.instagram.com/direct/inbox/") } label: { Image(systemName: "paperplane") }.accessibilityLabel("Messages")
                }.font(.title3).padding().disabled(browser.webView == nil)
            }
            .background(Color(red: 0.04, green: 0.06, blue: 0.09))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAccounts) {
                AccountPicker(store: store) { account in
                    store.select(account); browser.open(account); showAccounts = false
                }
            }
            .sheet(isPresented: Binding(get: { browser.popup != nil }, set: { if !$0 { browser.closePopup() } })) {
                NavigationStack {
                    if let popup = browser.popup {
                        EmbeddedBrowser(view: popup).navigationTitle("Account login")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { browser.closePopup() } } }
                    }
                }
            }
            .alert("Instagram Studio", isPresented: Binding(get: { browser.message != nil || store.error != nil }, set: { if !$0 { browser.message = nil; store.error = nil } })) {
                Button("OK") { browser.message = nil; store.error = nil }
            } message: { Text(browser.message ?? store.error ?? "") }
        }
    }
}

struct AccountPicker: View {
    @ObservedObject var store: AccountStore
    let choose: (StudioAccount) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var newName = ""
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.records.accounts.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { account in
                        Button { choose(account) } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.fill").foregroundStyle(.pink)
                                Text(account.name).foregroundStyle(.primary)
                                Spacer()
                                if account.id == store.records.selectedID { Image(systemName: "checkmark").foregroundStyle(.pink) }
                            }.padding(.vertical, 8)
                        }
                    }
                } footer: {
                    Text("\(store.records.accounts.count) accounts. Separate sessions are stored on this iPhone. Instagram may request login again. Keep this app installed to retain its data.")
                }
                Section { Button("Add Instagram account", systemImage: "plus") { adding = true } }
            }
            .navigationTitle("Your accounts")
            .searchable(text: $search)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Add account", isPresented: $adding) {
                TextField("Account name", text: $newName)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Add") {
                    if let account = store.add(newName) { newName = ""; choose(account) }
                }
            } message: { Text("Give this profile a name, then sign in to Instagram inside the app.") }
        }
    }
}
