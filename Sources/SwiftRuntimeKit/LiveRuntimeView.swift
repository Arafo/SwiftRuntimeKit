import SwiftUI

public struct LiveRuntimeView: View {
    @ObservedObject private var runtime = SwiftRuntimeKit.shared

    let source: String
    let id: String

    public init(source: String, id: String) {
        self.source = source
        self.id = id
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let view = runtime.view(for: id) {
                    view
                } else {
                    ProgressView("Compiling…")
                }
            }
            .onAppear {
                runtime.load(source: source, id: id)
            }

            Button {
                runtime.openEditor(for: id)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
            }
            .padding()
        }
        .sheet(isPresented: $runtime.showEditor) {
            RuntimeEditorView()
        }
    }
}
