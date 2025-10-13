import Foundation
import SwiftSyntax
import SwiftParser

public struct Program: Codable {
    public let chunks: [Chunk]
    public let functions: [FunctionRef]
}

public final class SwiftScriptCompiler {
    public init() {}

    public func compile(source: String) throws -> Program {
        let file = Parser.parse(source: source)
        let programAST = try buildAST(file: file)
        let emitter = BytecodeEmitter()
        return emitter.emit(program: programAST)
    }

    private func buildAST(file: SourceFileSyntax) throws -> ScriptProgram {
        var funcs: [ScriptFunction] = []
        for item in file.statements {
            guard let decl = item.item.as(FunctionDeclSyntax.self) else { continue }
            let name = decl.name.text
            let params: [String] = decl.signature.parameterClause.parameters.map { $0.firstName?.text ?? "_" }
            let bodyStmts = try buildBlock(decl.body)
            funcs.append(ScriptFunction(name: name, params: params, body: bodyStmts))
        }
        return ScriptProgram(functions: funcs)
    }

    private func buildBlock(_ body: CodeBlockSyntax?) throws -> [Stmt] {
        guard let body else { return [] }
        var out: [Stmt] = []
        for stmt in body.statements { out.append(try buildStmt(stmt)) }
        return out
    }

    private func buildStmt(_ stmt: CodeBlockItemSyntax) throws -> Stmt {
        let converter = SourceLocationConverter(fileName: "script", tree: stmt.root)
        let line = stmt.positionAfterSkippingLeadingTrivia.line(using: converter)
        if let v = stmt.item.as(VariableDeclSyntax.self) {
            guard v.bindingSpecifier.keywordKind == .let else {
                throw SRKError.compile(message: "Only 'let' is supported", at: SourceLocation(line: line))
            }
            guard let binding = v.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let initExpr = binding.initializer?.value else {
                throw SRKError.compile(message: "Invalid let declaration", at: SourceLocation(line: line))
            }
            return .letDecl(name: pattern.identifier.text, expr: try buildExpr(initExpr), line: line)
        }
        if let ret = stmt.item.as(ReturnStmtSyntax.self) {
            let ex = try ret.expression.map { try buildExpr($0) }
            return .return(ex, line: line)
        }
        if let ifs = stmt.item.as(IfExprSyntax.self) {
            guard let condExpr = ifs.conditions.first?.condition.as(ExprSyntax.self) else {
                throw SRKError.compile(message: "Invalid if condition", at: SourceLocation(line: line))
            }
            let thenBody = try buildBlock(ifs.body)
            var elseBody: [Stmt]? = nil
            if let eb = ifs.elseBody {
                switch eb {
                case .codeBlock(let b): elseBody = try buildBlock(b)
                case .if(let nested): elseBody = try buildBlock(nested.body)
                }
            }
            return .ifStmt(cond: try buildExpr(condExpr), thenBody: thenBody, elseBody: elseBody, line: line)
        }
        if let e = stmt.item.as(ExprSyntax.self) { return .expr(try buildExpr(e), line: line) }
        throw SRKError.compile(message: "Unsupported statement", at: SourceLocation(line: line))
    }

    private func buildExpr(_ e: ExprSyntax) throws -> Expr {
        if let s = e.as(StringLiteralExprSyntax.self) {
            let segments = s.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }
            return .string(segments.joined())
        }
        if let i = e.as(IntegerLiteralExprSyntax.self) { return .int(Int(i.literal.text) ?? 0) }
        if let b = e.as(BooleanLiteralExprSyntax.self) { return .bool(b.literal.keywordKind == .true) }
        if let id = e.as(IdentifierExprSyntax.self) { return .ident(id.identifier.text) }
        if let call = e.as(FunctionCallExprSyntax.self) {
            let name = call.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let args: [Expr] = call.arguments.map { try! buildExpr($0.expression) }
            return .call(name: name, args: args)
        }
        if let bin = e.as(InfixOperatorExprSyntax.self) {
            let lhs = try buildExpr(bin.leftOperand)
            let rhs = try buildExpr(bin.rightOperand)
            let opText = bin.operatorOperand.description.trimmingCharacters(in: .whitespaces)
            switch opText {
            case "+": return .binary(lhs: lhs, op: .add, rhs: rhs)
            case "==": return .binary(lhs: lhs, op: .eq, rhs: rhs)
            default: throw SRKError.compile(message: "Operator \(opText) not supported", at: nil)
            }
        }
        throw SRKError.compile(message: "Unsupported expression", at: nil)
    }
}

// MARK: - BytecodeEmitter with source maps
final class BytecodeEmitter {
    private var chunks: [Chunk] = []
    private var functions: [FunctionRef] = []
    private var localsStack: [[String: Int]] = []
    private var functionIndexByName: [String: Int] = [:]

    func emit(program: ScriptProgram) -> Program {
        for (idx, f) in program.functions.enumerated() {
            functionIndexByName[f.name] = idx
            functions.append(FunctionRef(name: f.name, arity: f.params.count, chunkIndex: idx, locals: 32))
            chunks.append(Chunk())
        }
        for (idx, f) in program.functions.enumerated() {
            withChunk(index: idx) {
                beginFunction(params: f.params)
                for stmt in f.body { emit(stmt) }
                pushConst(.null, line: lastLineOr1())
                currentChunk.code.append(.return); currentChunk.debugLines.append(lastLineOr1())
                endFunction()
            }
        }
        return Program(chunks: chunks, functions: functions)
    }

    private var currentChunkIndex: Int = 0
    private var currentChunk: Chunk {
        get { chunks[currentChunkIndex] }
        set { chunks[currentChunkIndex] = newValue }
    }

    private func withChunk(index: Int, _ body: () -> Void) {
        let prev = currentChunkIndex; currentChunkIndex = index; body(); currentChunkIndex = prev
    }

    private func beginFunction(params: [String]) {
        localsStack.append([:])
        var scope = localsStack.removeLast()
        for (i, name) in params.enumerated() { scope[name] = i }
        localsStack.append(scope)
    }

    private func endFunction() { _ = localsStack.popLast() }

    private var lastLine: Int = 1
    private func lastLineOr1() -> Int { max(1, lastLine) }

    private func emit(_ s: Stmt) {
        switch s {
        case .letDecl(let name, let expr, let line):
            lastLine = line
            emit(expr, line: line)
            currentChunk.code.append(.storeLocal(slotIndex(name))); currentChunk.debugLines.append(line)
        case .expr(let e, let line):
            lastLine = line
            emit(e, line: line); currentChunk.code.append(.pop); currentChunk.debugLines.append(line)
        case .return(let e, let line):
            lastLine = line
            if let ex = e { emit(ex, line: line) } else { pushConst(.null, line: line) }
            currentChunk.code.append(.return); currentChunk.debugLines.append(line)
        case .ifStmt(let cond, let thenBody, let elseBody, let line):
            lastLine = line
            emit(cond, line: line)
            let jf = append(.jumpIfFalse(offset: 0), line: line)
            for st in thenBody { emit(st) }
            let j = append(.jump(offset: 0), line: line)
            let elseStart = currentChunk.code.count
            patch(jf, to: elseStart - jf - 1)
            if let elseBody {
                for st in elseBody { emit(st) }
            }
            let end = currentChunk.code.count
            patch(j, to: end - j - 1)
        }
    }

    private func emit(_ e: Expr, line: Int) {
        switch e {
        case .string(let s): pushConst(.string(s), line: line)
        case .int(let i): pushConst(.int(i), line: line)
        case .bool(let b): pushConst(.bool(b), line: line)
        case .ident(let name):
            currentChunk.code.append(.loadLocal(slotIndex(name))); currentChunk.debugLines.append(line)
        case .call(let name, let args):
            for a in args { emit(a, line: line) }
            if let fi = functionIndexByName[name] {
                currentChunk.code.append(.callFunc(funcIndex: fi, argc: args.count))
            } else {
                let idx = addConst(.name(name))
                currentChunk.code.append(.callNative(nameIndex: idx, argc: args.count))
            }
            currentChunk.debugLines.append(line)
        case .binary(let lhs, let op, let rhs):
            emit(lhs, line: line); emit(rhs, line: line)
            switch op { case .add: currentChunk.code.append(.add); case .eq: currentChunk.code.append(.eq) }
            currentChunk.debugLines.append(line)
        }
    }

    @discardableResult
    private func append(_ i: Instruction, line: Int) -> Int {
        currentChunk.code.append(i); currentChunk.debugLines.append(line)
        return currentChunk.code.count - 1
    }

    private func patch(_ index: Int, to offset: Int) {
        let line = currentChunk.debugLines[index]
        switch currentChunk.code[index] {
        case .jumpIfFalse: currentChunk.code[index] = .jumpIfFalse(offset: offset); currentChunk.debugLines[index] = line
        case .jump: currentChunk.code[index] = .jump(offset: offset); currentChunk.debugLines[index] = line
        default: break
        }
    }

    private func pushConst(_ c: Constant, line: Int) {
        let idx = addConst(c)
        currentChunk.code.append(.pushConst(idx)); currentChunk.debugLines.append(line)
    }

    private func slotIndex(_ name: String) -> Int {
        guard var scope = localsStack.last else { fatalError("scope missing") }
        if let slot = scope[name] { return slot }
        let slot = scope.count; scope[name] = slot; localsStack[localsStack.count-1] = scope
        return slot
    }

    @discardableResult
    private func addConst(_ c: Constant) -> Int {
        var ch = currentChunk
        ch.constants.append(c)
        let idx = ch.constants.count - 1
        currentChunk = ch
        return idx
    }
}
