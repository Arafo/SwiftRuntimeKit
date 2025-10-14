import SwiftUI
import SwiftRuntimeKit

@main
struct DemoApp: App {
    @ObservedObject var runtime = SwiftRuntimeKit.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                LiveRuntimeView(
                    source: """
                    VStack(spacing: 12) {
                        Text("Hello runtime!").font(.largeTitle).foregroundColor(.blue)
                        Text("Tap ✏️ to edit me live.").font(.subheadline).foregroundColor(.gray)
                        Button("Press me") { }
                    }
                    """,
                    id: "mainView"
                )
                .padding()

                if runtime.showEditor {
                    // Editor is presented via sheet in LiveRuntimeView; this is a fallback overlay
                    Color.black.opacity(0.2).edgesIgnoringSafeArea(.all)
                }
            }
        }
    }
}
