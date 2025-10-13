import Foundation

public struct Program {
    public let chunks: [Chunk]
    public let functions: [FunctionRef]
}

public final class MiniAssembler {
    private var chunk = Chunk()
    private var functions: [FunctionRef] = []
    private var localSlots: [String: Int] = [:]

    public init() {}

    public func compile(lines: [String]) -> Program {
        let mainRef = FunctionRef(name: "main", arity: 0, chunkIndex: 0, locals: 8)
        functions.append(mainRef)

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasPrefix("let ") {
                emitLet(line)
            } else {
                emitCall(line)
            }
        }
        // implicit return null
        chunk.code.append(.pushConst(addConst(.null)))
        chunk.code.append(.return)

        return Program(chunks: [chunk], functions: functions)
    }

    private func emitLet(_ line: String) {
        // let name = "Rafa"
        let rest = line.dropFirst(4)
        let comps = rest.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard comps.count == 2 else { return }
        let varName = comps[0]
        let expr = comps[1]
        let slot = slotIndex(for: varName)
        emitExpr(expr)
        chunk.code.append(.storeLocal(slot))
    }

    private func emitCall(_ line: String) {
        guard let open = line.firstIndex(of: "("), line.hasSuffix(")") else { return }
        let name = String(line[..<open]).trimmingCharacters(in: .whitespaces)
        let inside = String(line[line.index(after: open)..<line.index(before: line.endIndex)])
        let args = splitTopLevelArgs(inside)
        for arg in args {
            let expr = stripLabelIfPresent(arg)
            emitExpr(expr)
        }
        let nameIdx = addConst(.name(name))
        chunk.code.append(.callNative(nameIndex: nameIdx, argc: args.count))
        chunk.code.append(.pop)
    }

    private func emitExpr(_ exprRaw: String) {
        let expr = exprRaw.trimmingCharacters(in: .whitespaces)
        if let plus = topLevelPlusSplit(expr) {
            emitExpr(plus.lhs); emitExpr(plus.rhs); chunk.code.append(.add); return
        }
        if expr.hasPrefix("\"") && expr.hasSuffix("\"") && expr.count >= 2 {
            let s = String(expr.dropFirst().dropLast())
            chunk.code.append(.pushConst(addConst(.string(s)))); return
        }
        if let i = Int(expr) {
            chunk.code.append(.pushConst(addConst(.int(i)))); return
        }
        if let d = Double(expr) {
            chunk.code.append(.pushConst(addConst(.double(d)))); return
        }
        if expr == "true" || expr == "false" {
            chunk.code.append(.pushConst(addConst(.bool(expr == "true")))); return
        }
        if expr == "null" {
            chunk.code.append(.pushConst(addConst(.null))); return
        }
        // variable
        let slot = slotIndex(for: expr)
        chunk.code.append(.loadLocal(slot))
    }

    // MARK: - Helpers

    private func slotIndex(for name: String) -> Int {
        if let i = localSlots[name] { return i }
        let i = localSlots.count
        localSlots[name] = i
        return i
    }

    private func addConst(_ c: Constant) -> Int {
        chunk.constants.append(c)
        return chunk.constants.count - 1
    }

    private func splitTopLevelArgs(_ s: String) -> [String] {
        var res: [String] = []
        var current = ""
        var inString = false
        for ch in s {
            if ch == "\"" {
                inString.toggle()
                current.append(ch)
            } else if ch == "," && !inString {
                res.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty {
            res.append(current.trimmingCharacters(in: .whitespaces))
        }
        return res
    }

    private func stripLabelIfPresent(_ arg: String) -> String {
        if let idx = arg.firstIndex(of: ":") {
            return String(arg[arg.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        }
        return arg
    }

    private func topLevelPlusSplit(_ s: String) -> (lhs: String, rhs: String)? {
        var inString = false
        for (i, ch) in s.enumerated() {
            if ch == "\"" { inString.toggle() }
            if ch == "+" && !inString {
                let lhs = String(s.prefix(i)).trimmingCharacters(in: .whitespaces)
                let rhs = String(s.suffix(s.count - i - 1)).trimmingCharacters(in: .whitespaces)
                return (lhs, rhs)
            }
        }
        return nil
    }
}
