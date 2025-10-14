import Foundation
import SwiftUI
import SwiftSyntax
import SwiftParser

@MainActor
public final class SwiftRuntimeKit: ObservableObject {
    public static let shared = SwiftRuntimeKit()

    @Published private var liveViews: [String: AnyView] = [:]
    private var sources: [String: String] = [:]

    // Editor bindings
    @Published public var showEditor: Bool = false
    @Published public var currentEditingSource: String = ""
    public private(set) var currentEditingID: String? = nil

    private init() {}

    public func view(for id: String) -> AnyView? {
        liveViews[id]
    }

    /// Load source (initial) and compile
    public func load(source: String, id: String) {
        sources[id] = source
        if let any = compileView(from: source) {
            liveViews[id] = any
        } else {
            liveViews[id] = AnyView(
                VStack {
                    Text("Compile error — see console").foregroundColor(.red)
                    Text(source).font(.system(.caption, design: .monospaced)).lineLimit(6)
                }.padding()
            )
        }
    }

    public func openEditor(for id: String) {
        currentEditingID = id
        currentEditingSource = sources[id] ?? ""
        showEditor = true
    }

    public func applyEdit(_ newSource: String) {
        guard let id = currentEditingID else { return }
        sources[id] = newSource
        currentEditingSource = newSource
        if let any = compileView(from: newSource) {
            liveViews[id] = any
        } else {
            print("[SwiftRuntimeKit] compile failed for id=\(id)")
        }
        showEditor = false
    }

    // MARK: - Compiler: SwiftSyntax + interpreter to AnyView

    /// Parse source and produce an AnyView if source is a single View-expression or `var body` style.
    /// Acceptable formats:
    ///  - A single expression: `VStack { Text("Hi") }`
    ///  - A `var body: some View { ... }` block (the builder extracts the top expression)
    public func compileView(from source: String) -> AnyView? {
        do {
            let parsed = Parser.parse(source: source)
            if let expr = findPrimaryViewExpression(in: parsed) {
                let builder = DynamicViewBuilder()
                if let dyn = try builder.build(from: expr) {
                    return dyn.toAnyView()
                } else {
                    return nil
                }
            } else {
                print("[SwiftRuntimeKit] No top-level view expression found.")
                return nil
            }
        } catch {
            print("[SwiftRuntimeKit] parse error:", error)
            return nil
        }
    }

    private func findPrimaryViewExpression(in file: SourceFileSyntax) -> ExprSyntax? {
        // 1) If file contains a single expression statement, return it
        for stmt in file.statements {
            if let item = stmt.item.as(ExprSyntax.self) {
                return item
            }
            // 2) variable decl with initializer expression
            if let v = stmt.item.as(VariableDeclSyntax.self) {
                for binding in v.bindings {
                    if let initExpr = binding.initializer?.value {
                        if let e = initExpr.as(ClosureExprSyntax.self) {
                            // closure: take first expression in closure body
                            if let first = e.statements.first?.item.as(ExprSyntax.self) {
                                return first
                            }
                        } else if let e = initExpr.as(ExprSyntax.self) {
                            return e
                        }
                    }
                }
            }
            // 3) function decl body (e.g. func body could contain the view)
            if let f = stmt.item.as(FunctionDeclSyntax.self) {
                if let body = f.body {
                    for item in body.statements.reversed() {
                        if let e = item.item.as(ExprSyntax.self) {
                            return e
                        }
                    }
                }
            }
        }
        return nil
    }
}
