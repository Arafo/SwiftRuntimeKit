import SwiftUI

public struct RuntimeEditorView: View {
    @ObservedObject private var runtime = SwiftRuntimeKit.shared
    @State private var editedSource: String = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            TextEditor(text: $editedSource)
                .font(.system(.body, design: .monospaced))
                .padding()
                .navigationTitle("Edit View")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            runtime.applyEdit(editedSource)
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            runtime.showEditor = false
                        }
                    }
                }
                .onAppear {
                    editedSource = runtime.currentEditingSource
                }
        }
    }
}
