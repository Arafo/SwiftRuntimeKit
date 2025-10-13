import Foundation
import SwiftSyntax
import SwiftParser

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
            let params: [String]
            if let clause = decl.signature.parameterClause {
                params = clause.parameters.map { $0.firstName?.text ?? "_" }
            } else {
                params = []
            }
            let bodyStmts = try buildBlock(decl.body)
            funcs.append(ScriptFunction(name: name, params: params, body: bodyStmts))
        }
        return ScriptProgram(functions: funcs)
    }

    private func buildBlock(_ body: CodeBlockSyntax?) throws -> [Stmt] {
        guard let body else { return [] }
        var out: [Stmt] = []
        for stmt in body.statements {
            out.append(try buildStmt(stmt))
        }
        return out
    }

    private func buildStmt(_ stmt: CodeBlockItemSyntax) throws -> Stmt {
        if let v = stmt.item.as(VariableDeclSyntax.self) {
            guard v.bindingSpecifier.keywordKind == .let else {
                throw CompilerError.unsupported("Only let supported")
            }
            guard let binding = v.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let initExpr = binding.initializer?.value else {
                throw CompilerError.invalidLet
            }
            return .letDecl(name: pattern.identifier.text, expr: try buildExpr(initExpr))
        }
        if let ret = stmt.item.as(ReturnStmtSyntax.self) {
            if let value = ret.expression { return .return(try buildExpr(value)) }
            return .return(nil)
        }
        if let ifs = stmt.item.as(IfExprSyntax.self) {
            return try buildIfExpr(ifs)
        }
        if let e = stmt.item.as(ExprSyntax.self) {
            return .expr(try buildExpr(e))
        }
        throw CompilerError.unsupported("Unsupported statement")
    }

    private func buildIfExpr(_ ifs: IfExprSyntax) throws -> Stmt {
        guard let condExpr = ifs.conditions.first?.condition.as(ExprSyntax.self) else {
            throw CompilerError.unsupported("Invalid if condition")
        }
        let thenBody = try buildBlock(ifs.body)
        var elseBody: [Stmt]? = nil
        if let eb = ifs.elseBody {
            switch eb {
            case .codeBlock(let b):
                elseBody = try buildBlock(b)
            case .if(let nested):
                elseBody = [try buildIfExpr(nested)]
            }
        }
        return .ifStmt(cond: try buildExpr(condExpr), thenBody: thenBody, elseBody: elseBody)
    }

    private func buildExpr(_ e: ExprSyntax) throws -> Expr {
        if let s = e.as(StringLiteralExprSyntax.self) {
            let segments = s.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }
            return .string(segments.joined())
        }
        if let i = e.as(IntegerLiteralExprSyntax.self) {
            return .int(Int(i.literal.text) ?? 0)
        }
        if let b = e.as(BooleanLiteralExprSyntax.self) {
            return .bool(b.literal.keywordKind == .true)
        }
        if let ref = e.as(DeclReferenceExprSyntax.self) {
            return .ident(ref.baseName.text)
        }
        if let call = e.as(FunctionCallExprSyntax.self) {
            let name = call.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let args: [Expr] = try call.arguments.map { try buildExpr($0.expression) }
            return .call(name: name, args: args)
        }
        if let bin = e.as(InfixOperatorExprSyntax.self) {
            let lhs = try buildExpr(bin.leftOperand)
            let rhs = try buildExpr(bin.rightOperand)
            let opText = bin.operatorOperand.description.trimmingCharacters(in: .whitespaces)
            switch opText {
            case "+": return .binary(lhs: lhs, op: .add, rhs: rhs)
            case "==": return .binary(lhs: lhs, op: .eq, rhs: rhs)
            default: throw CompilerError.unsupported("Operator \(opText) not supported")
            }
        }
        throw CompilerError.unsupported("Unsupported expression")
    }
}

public enum CompilerError: Error, CustomStringConvertible {
    case unsupported(String)
    case invalidLet

    public var description: String {
        switch self {
        case .unsupported(let s): return "Unsupported: \(s)"
        case .invalidLet: return "Invalid let declaration"
        }
    }
}

final class BytecodeEmitter {
    private var chunks: [Chunk] = []
    private var functions: [FunctionRef] = []
    private var localsStack: [[String: Int]] = []
    private var functionIndexByName: [String: Int] = [:]
    private var currentChunkIndex: Int = 0

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
                currentChunk.code.append(.pushConst(addConst(.null)))
                currentChunk.code.append(.return)
                endFunction()
            }
        }
        return Program(chunks: chunks, functions: functions)
    }

    private var currentChunk: Chunk {
        get { chunks[currentChunkIndex] }
        set { chunks[currentChunkIndex] = newValue }
    }

    private func withChunk(index: Int, _ body: () -> Void) {
        let prev = currentChunkIndex
        currentChunkIndex = index
        body()
        currentChunkIndex = prev
    }

    private func beginFunction(params: [String]) {
        localsStack.append([:])
        var scope = localsStack.removeLast()
        for (i, name) in params.enumerated() { scope[name] = i }
        localsStack.append(scope)
    }

    private func endFunction() {
        _ = localsStack.popLast()
    }

    private func emit(_ s: Stmt) {
        switch s {
        case .letDecl(let name, let expr):
            emit(expr)
            storeLocal(name)
        case .expr(let e):
            emit(e)
            currentChunk.code.append(.pop)
        case .return(let e):
            if let e {
                emit(e)
            } else {
                currentChunk.code.append(.pushConst(addConst(.null)))
            }
            currentChunk.code.append(.return)
        case .ifStmt(let cond, let thenBody, let elseBody):
            emit(cond)
            let jf = currentChunk.code.count
            currentChunk.code.append(.jumpIfFalse(offset: 0))
            for st in thenBody { emit(st) }
            let j = currentChunk.code.count
            currentChunk.code.append(.jump(offset: 0))
            let elseStart = currentChunk.code.count
            currentChunk.code[jf] = .jumpIfFalse(offset: elseStart - jf - 1)
            if let elseBody {
                for st in elseBody { emit(st) }
            }
            let end = currentChunk.code.count
            currentChunk.code[j] = .jump(offset: end - j - 1)
        }
    }

    private func emit(_ e: Expr) {
        switch e {
        case .string(let s):
            currentChunk.code.append(.pushConst(addConst(.string(s))))
        case .int(let i):
            currentChunk.code.append(.pushConst(addConst(.int(i))))
        case .bool(let b):
            currentChunk.code.append(.pushConst(addConst(.bool(b))))
        case .ident(let name):
            loadLocal(name)
        case .call(let name, let args):
            for a in args { emit(a) }
            if let fi = functionIndexByName[name] {
                currentChunk.code.append(.callFunc(funcIndex: fi, argc: args.count))
            } else {
                let idx = addConst(.name(name))
                currentChunk.code.append(.callNative(nameIndex: idx, argc: args.count))
            }
        case .binary(let lhs, let op, let rhs):
            emit(lhs)
            emit(rhs)
            switch op {
            case .add: currentChunk.code.append(.add)
            case .eq: currentChunk.code.append(.eq)
            }
        }
    }

    private func loadLocal(_ name: String) {
        guard var scope = localsStack.last else { fatalError("scope missing") }
        if let slot = scope[name] {
            currentChunk.code.append(.loadLocal(slot))
        } else {
            let slot = scope.count
            scope[name] = slot
            localsStack[localsStack.count - 1] = scope
            currentChunk.code.append(.loadLocal(slot))
        }
    }

    private func storeLocal(_ name: String) {
        guard var scope = localsStack.last else { fatalError("scope missing") }
        let slot = scope[name] ?? scope.count
        scope[name] = slot
        localsStack[localsStack.count - 1] = scope
        currentChunk.code.append(.storeLocal(slot))
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
