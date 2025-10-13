import Foundation

public struct ScriptProgram {
    public var functions: [ScriptFunction]
    public init(functions: [ScriptFunction]) { self.functions = functions }
}

public struct ScriptFunction {
    public let name: String
    public let params: [String]
    public let body: [Stmt]
    public init(name: String, params: [String], body: [Stmt]) {
        self.name = name; self.params = params; self.body = body
    }
}

public enum Stmt {
    case letDecl(name: String, expr: Expr, line: Int)
    case expr(Expr, line: Int)
    case `return`(Expr?, line: Int)
    case ifStmt(cond: Expr, thenBody: [Stmt], elseBody: [Stmt]?, line: Int)
}

public enum BinaryOp { case add, eq }

public enum Expr {
    case string(String)
    case int(Int)
    case bool(Bool)
    case ident(String)
    case call(name: String, args: [Expr])
    case binary(lhs: Expr, op: BinaryOp, rhs: Expr)
}
