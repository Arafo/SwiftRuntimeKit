import Foundation
import SwiftUI
import SwiftSyntax

// MARK: - Dynamic view representation

indirect enum DynamicView {
    case vstack(alignment: HorizontalAlignment?, spacing: CGFloat?, children: [DynamicView])
    case hstack(alignment: VerticalAlignment?, spacing: CGFloat?, children: [DynamicView])
    case zstack(alignment: Alignment?, children: [DynamicView])
    case text(String)
    case image(String)
    case spacer
    case color(String) // named color
    case rectangle
    case button(title: String?, children: [DynamicView])
    case modified(base: DynamicView, mods: [ViewModifierSpec])
    case any(AnyView)

    func toAnyView() -> AnyView {
        switch self {
        case .vstack(let alignment, let spacing, let children):
            return AnyView(VStack(alignment: alignment ?? .center, spacing: spacing) {
                ForEach(0..<children.count, id: \.self) { i in
                    children[i].toAnyView()
                }
            })
        case .hstack(let alignment, let spacing, let children):
            return AnyView(HStack(alignment: alignment ?? .center, spacing: spacing) {
                ForEach(0..<children.count, id: \.self) { i in
                    children[i].toAnyView()
                }
            })
        case .zstack(let alignment, let children):
            return AnyView(ZStack(alignment: alignment ?? .center) {
                ForEach(0..<children.count, id: \.self) { i in
                    children[i].toAnyView()
                }
            })
        case .text(let s):
            return AnyView(Text(s))
        case .image(let name):
            return AnyView(Image(name))
        case .spacer:
            return AnyView(Spacer())
        case .color(let ident):
            switch ident.lowercased() {
            case "red": return AnyView(Color.red)
            case "blue": return AnyView(Color.blue)
            case "green": return AnyView(Color.green)
            case "gray": return AnyView(Color.gray)
            case "black": return AnyView(Color.black)
            case "white": return AnyView(Color.white)
            default: return AnyView(Color.black)
            }
        case .rectangle:
            return AnyView(Rectangle())
        case .button(let title, let children):
            if children.isEmpty {
                return AnyView(Button(action: { print("[Runtime] Button '\(title ?? "button")' tapped") }) {
                    Text(title ?? "Button")
                })
            } else {
                return AnyView(Button(action: { print("[Runtime] Button '\(title ?? "button")' tapped") }) {
                    ForEach(0..<children.count, id: \.self) { i in
                        children[i].toAnyView()
                    }
                })
            }
        case .modified(let base, let mods):
            var v = base.toAnyView()
            for m in mods {
                switch m.name {
                case "padding":
                    if let val = m.doubleArgs.first { v = AnyView(v.padding(CGFloat(val))) }
                    else { v = AnyView(v.padding()) }
                case "foregroundColor":
                    if let first = m.args.first {
                        switch first {
                        case .identifier(let id):
                            if id.lowercased() == "red" { v = AnyView(v.foregroundColor(.red)) }
                            if id.lowercased() == "blue" { v = AnyView(v.foregroundColor(.blue)) }
                            if id.lowercased() == "green" { v = AnyView(v.foregroundColor(.green)) }
                            if id.lowercased() == "gray" { v = AnyView(v.foregroundColor(.gray)) }
                        default: break
                        }
                    }
                case "font":
                    if let a = m.args.first {
                        switch a {
                        case .identifier("title"): v = AnyView(v.font(.largeTitle))
                        case .identifier("headline"): v = AnyView(v.font(.headline))
                        case .identifier("body"): v = AnyView(v.font(.body))
                        case .identifier("caption"): v = AnyView(v.font(.caption))
                        default: break
                        }
                    }
                case "frame":
                    let w = m.doubleArgs[safe: 0]
                    let h = m.doubleArgs[safe: 1]
                    v = AnyView(v.frame(width: w.map(CGFloat.init), height: h.map(CGFloat.init)))
                default:
                    break
                }
            }
            return v
        case .any(let av):
            return av
        }
    }
}

// MARK: - View modifier descriptor

struct ViewModifierSpec {
    enum Arg { case identifier(String); case string(String); case number(Double) }
    let name: String
    let args: [Arg]
    let doubleArgs: [Double]
}

// MARK: - Builder: ExprSyntax -> DynamicView

final class DynamicViewBuilder {
    enum BuildError: Error {
        case unsupported(String)
    }

    func build(from expr: ExprSyntax) throws -> DynamicView? {
        return try parseExpr(expr)
    }

    private func parseExpr(_ e: ExprSyntax) throws -> DynamicView {
        // Function calls (e.g., VStack { ... }, Text("..."), Text("..".font(.title))
        if let call = e.as(FunctionCallExprSyntax.self) {
            return try parseFunctionCall(call)
        }

        // Member access + call: Text("Hi").padding()
        if let memberCall = e.as(FunctionCallExprSyntax.self) {
            return try parseFunctionCall(memberCall)
        }

        if let ident = e.as(IdentifierExprSyntax.self) {
            return try parseIdentifierOnly(ident)
        }

        if let lit = e.as(StringLiteralExprSyntax.self) {
            let parts = lit.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }
            return .text(parts.joined())
        }

        throw BuildError.unsupported("Unsupported expression: \(e.description.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    private func parseIdentifierOnly(_ ident: IdentifierExprSyntax) throws -> DynamicView {
        let name = ident.identifier.text
        switch name {
        case "Spacer": return .spacer
        case "Rectangle": return .rectangle
        default: throw BuildError.unsupported("Identifier \(name) not supported alone")
        }
    }

    private func parseFunctionCall(_ call: FunctionCallExprSyntax) throws -> DynamicView {
        let called = call.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle containers
        if called == "VStack" || called.hasSuffix(".VStack") {
            let children = try extractChildViews(from: call)
            return .vstack(alignment: nil, spacing: nil, children: children)
        }
        if called == "HStack" || called.hasSuffix(".HStack") {
            let children = try extractChildViews(from: call)
            return .hstack(alignment: nil, spacing: nil, children: children)
        }
        if called == "ZStack" || called.hasSuffix(".ZStack") {
            let children = try extractChildViews(from: call)
            return .zstack(alignment: nil, children: children)
        }

        // Text
        if called == "Text" || called.hasSuffix(".Text") {
            if let first = call.argumentList.first?.expression.as(StringLiteralExprSyntax.self) {
                let s = first.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
                var dv: DynamicView = .text(s)
                // If textual modifiers are chained, they appear as MemberAccessExpr + FunctionCall -> handled by upper-level parse
                return dv
            }
            throw BuildError.unsupported("Text requires string literal")
        }

        // Image
        if called == "Image" || called.hasSuffix(".Image") {
            if let first = call.argumentList.first?.expression.as(StringLiteralExprSyntax.self) {
                let s = first.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
                return .image(s)
            }
            throw BuildError.unsupported("Image requires string literal")
        }

        // Button
        if called == "Button" || called.hasSuffix(".Button") {
            // title variant or closure label
            var title: String? = nil
            if let first = call.argumentList.first?.expression.as(StringLiteralExprSyntax.self) {
                title = first.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
            }
            let children = try extractChildViews(from: call)
            return .button(title: title, children: children)
        }

        // Modifiers: when calledExpression is MemberAccessExprSyntax, parse base and apply modifier
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
            if let baseExpr = member.base?.as(ExprSyntax.self) {
                var baseDV = try parseExpr(baseExpr)
                // this call is the modifier call: member.name + args
                let modSpec = convertCallToModifier(call, memberName: member.name.text)
                baseDV = .modified(base: baseDV, mods: [modSpec])
                return baseDV
            }
        }

        // Member access without call: e.g., expression.method
        if let memberOnly = call.calledExpression.as(MemberAccessExprSyntax.self) {
            if let baseExpr = memberOnly.base?.as(ExprSyntax.self) {
                var baseDV = try parseExpr(baseExpr)
                // No args: treat as modifier with no args
                let modSpec = ViewModifierSpec(name: memberOnly.name.text, args: [], doubleArgs: [])
                baseDV = .modified(base: baseDV, mods: [modSpec])
                return baseDV
            }
        }

        // Fallback: try to parse description as literal text
        let desc = call.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return .text(desc)
    }

    private func extractChildViews(from call: FunctionCallExprSyntax) throws -> [DynamicView] {
        var children: [DynamicView] = []

        // Trailing closure children
        if let trailing = call.trailingClosure {
            for stmt in trailing.statements {
                if let expr = stmt.item.as(ExprSyntax.self) {
                    let child = try parseExpr(expr)
                    children.append(child)
                }
            }
            return children
        }

        // Look for closure arguments in argument list
        for arg in call.argumentList {
            if let closure = arg.expression.as(ClosureExprSyntax.self) {
                for stmt in closure.statements {
                    if let e = stmt.item.as(ExprSyntax.self) {
                        let child = try parseExpr(e)
                        children.append(child)
                    }
                }
            } else if let e = arg.expression.as(ExprSyntax.self) {
                // non-closure arg — could be a direct child expression (rare)
                // if it's a functioncall expression that returns a view, include it:
                if e.is(FunctionCallExprSyntax.self) || e.is(MemberAccessExprSyntax.self) || e.is(IdentifierExprSyntax.self) {
                    let child = try parseExpr(e)
                    children.append(child)
                }
            }
        }

        return children
    }

    private func convertCallToModifier(_ call: FunctionCallExprSyntax, memberName: String) -> ViewModifierSpec {
        var args: [ViewModifierSpec.Arg] = []
        var doubles: [Double] = []
        for arg in call.argumentList {
            let ex = arg.expression
            if let sl = ex.as(StringLiteralExprSyntax.self) {
                let s = sl.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
                args.append(.string(s))
            } else if let id = ex.as(IdentifierExprSyntax.self) {
                args.append(.identifier(id.identifier.text))
            } else if let intLit = ex.as(IntegerLiteralExprSyntax.self) {
                if let v = Double(intLit.digits.text) {
                    args.append(.number(v)); doubles.append(v)
                }
            } else if let floatLit = ex.as(FloatLiteralExprSyntax.self) {
                if let v = Double(floatLit.floatingDigits.text) {
                    args.append(.number(v)); doubles.append(v)
                }
            } else {
                // ignore complex args
            }
        }
        let name = memberName
        return ViewModifierSpec(name: name, args: args, doubleArgs: doubles)
    }
}

private extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
