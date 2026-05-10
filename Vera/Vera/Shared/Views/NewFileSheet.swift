import SwiftUI

struct NewFileSheet: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    let onCreated: (URL) -> Void

    @State private var filename = ""
    @State private var selectedFolderURL: URL? = nil
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    private var targetFolder: URL? {
        selectedFolderURL ?? vm.rootURL
    }

    private var topLevelFolders: [(name: String, url: URL)] {
        vm.roots.compactMap {
            if case .folder(_, let name, _) = $0, let root = vm.rootURL {
                return (name, root.appendingPathComponent(name))
            }
            return nil
        }
    }

    var body: some View {
        #if os(iOS)
        NavigationStack { form.navigationTitle("New File").navigationBarTitleDisplayMode(.inline).toolbar { iOSToolbar } }
        #else
        form.padding(20).frame(width: 360)
        #endif
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("File name").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    TextField("untitled", text: $filename)
                        .textFieldStyle(.roundedBorder)
                        .focused($fieldFocused)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        #endif
                    Text(".md").foregroundStyle(.secondary)
                }
            }

            if !topLevelFolders.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Location", selection: $selectedFolderURL) {
                        Text("Root folder").tag(Optional<URL>.none)
                        ForEach(topLevelFolders, id: \.url) { folder in
                            Text(folder.name).tag(Optional(folder.url))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            #if os(macOS)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(filename.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            #endif
        }
        .onAppear { fieldFocused = true }
    }

    #if os(iOS)
    @ToolbarContentBuilder
    private var iOSToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Create") { create() }
                .disabled(filename.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
        }
    }
    #endif

    private func create() {
        let trimmed = filename.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let folder = targetFolder else { return }
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let url = try await vm.createFile(named: trimmed, in: folder)
                dismiss()
                onCreated(url)
            } catch CocoaError.fileWriteFileExists {
                errorMessage = "A file with that name already exists."
                isCreating = false
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}
