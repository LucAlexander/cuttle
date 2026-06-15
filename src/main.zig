const std = @import("std");
const Buffer = std.ArrayList;
const Map = std.StringHashMap;

const debug = true;

const ERROR_MAX = 128;
const ERROR_LINES = 5;

const TOKEN = u64;

const QUOTE = '\'';
const UNQUOTE = ',';
const ADD = '+';
const SUB = '-';
const MUL = '*';
const DIV = '/';
const MOD = '%';
const AND = '&';
const OR = '|';
const XOR = '^';
const LT = '<';
const GT = '>';
const OPEN = '(';
const CLOSE = ')';
const CASE = 0;
const COMP = 1;
const UNIVERSE = 2;
const STR = 3;
const HEAD = 4;
const PROG = 5;
const VAR = 6;
const IDEN = 7;
const FLOAT = 8;
const TAIL = 9;
const LET = 10;
const SET = 11;
const LAMBDA = 12;
const INT = 13;
const NAT = 14;
const ERROR = 19;
const RECORD = 20;
const CONS = 21;

const Token = struct{
	text: []const u8,
	tag: TOKEN,
	pos: u64,
	value: ?union(enum){
		float: f64,
		nat: u64,
		int: i64
	}
};

const Error = struct {
	pos: u64,
	message: []u8
};

const ErrorLog = struct {
	mem: *const std.mem.Allocator,
	log: Buffer(Error),
	
	pub fn init(mem: *const std.mem.Allocator) ErrorLog {
		return ErrorLog{
			.mem = mem,
			.log = Buffer(Error).init(mem.*)
		};
	}

	pub fn append(self: *ErrorLog, index:u64, comptime fmt: []const u8, args: anytype) void {
		var err = Error{
			.pos = index,
			.message = self.mem.alloc(u8, ERROR_MAX) catch unreachable
		};
		const result = std.fmt.bufPrint(err.message, fmt, args) catch unreachable;
		err.message.len = result.len;
		self.log.append(err) catch unreachable;
	}

	pub fn handle(self: *ErrorLog, text: []const u8) void {
		for (self.log.items) |er| {
			tokenize_error_report(er, text);
		}
	}
};

pub fn is_symbol(c: u8) bool {
	if (c == '!' or c == '#' or c == '$' or c == '%' or
		c == '^' or c == '`' or c == '*' or c == '+' or
		c == '-' or c == '/' or c == '?' or c == ':' or
		c == ';' or c == '.' or c == '~' or c == '<' or
		c == '>' or c == '{' or c == '}' or c == '[' or
		c == ']' or c == '=' or c == ','){
		return true;
	}
	return false;
}

pub fn tokenize_error_report(er: Error, text: []const u8) void {
	var i: u64 = 0;
	var line: u64 = 0;
	var line_count: u64 = 1;
	var token_count: u64 = 0;
	while (i < text.len){
		if (token_count == er.pos){
			break;
		}
		const c = text[i];
		switch(c){
			'\n' => {
				line = i;
				line_count += 1;
				i += 1;
				continue;
			},
			' ', '\t', '\r' => {
				i += 1;
				continue;
			},
			'"' => {
				i += 1;
				while (text[i] != '"' and i < text.len){
					i += 1;
				}
				i += 1;
				continue;
			},
			QUOTE, UNQUOTE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, LT, GT, OPEN, CLOSE => {
				token_count += 1;
				i += 1;
				continue;
			},
			else => {
				var k: u64 = i;
				while ((std.ascii.isAlphanumeric(text[k]) or is_symbol(text[k])) and (k < text.len)){
					k += 1;
				}
				i = k;
				token_count += 1;
				continue;
			}
		}
	}
	i = line;
	std.debug.print("[ERROR] Line {}: {s}\n| ", .{line_count, er.message});
	line_count = 0;
	while (i < text.len and line_count < ERROR_LINES){
		const c = text[i];
		i += 1;
		std.debug.print("{c}", .{c});
		if (c == '\n'){
			std.debug.print("| ", .{});
			line_count += 1;
		}
	}
	std.debug.print("\n", .{});
}

pub fn tokenize(mem: *const std.mem.Allocator, text: []const u8) Buffer(Token) {
	var tokens = Buffer(Token).init(mem.*);
	var i: u64 = 0;
	var tokmap = Map(TOKEN).init(mem.*);
	tokmap.put("case", CASE) catch unreachable;
	tokmap.put("comp", COMP) catch unreachable;
	tokmap.put("universe", UNIVERSE ) catch unreachable;
	tokmap.put("head", HEAD ) catch unreachable;
	tokmap.put("prog", PROG ) catch unreachable;
	tokmap.put("tail", TAIL ) catch unreachable;
	tokmap.put("let", LET ) catch unreachable;
	tokmap.put("var", VAR ) catch unreachable;
	tokmap.put("set", SET ) catch unreachable;
	tokmap.put("lambda", LAMBDA ) catch unreachable;
	tokmap.put("error", ERROR) catch unreachable;
	tokmap.put("record", RECORD) catch unreachable;
	tokmap.put("cons", CONS) catch unreachable;
	while (i < text.len){
		const c = text[i];
		switch(c){
			' ', '\n', '\t', '\r' => {
				i += 1;
				continue;
			},
			'"' => {
				const start = i;
				i += 1;
				while (text[i] != '"' and i < text.len){
					i += 1;
				}
				i += 1;
				tokens.append(Token{
					.text = text[start .. i],
					.tag = STR,
					.pos = tokens.items.len,
					.value = null
				}) catch unreachable;
				continue;
			},
			QUOTE, UNQUOTE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, LT, GT, OPEN, CLOSE => {
				tokens.append(Token{
					.text = text[i..i+1],
					.tag = c,
					.pos = tokens.items.len,
					.value = null
				}) catch unreachable;
				i += 1;
				continue;
			},
			else => {
				var k: u64 = i;
				while ((std.ascii.isAlphanumeric(text[k]) or is_symbol(text[k])) and (k < text.len)){
					k += 1;
				}
				if (tokmap.get(text[i..k])) |tok| {
					tokens.append(Token{
						.text = text[i..k],
						.tag = tok,
						.pos = tokens.items.len,
						.value = null
					}) catch unreachable;
					i = k;
					continue;
				}
				const z = std.fmt.parseInt(i64, text[i..k], 10) catch {
					const n = std.fmt.parseInt(u64, text[i..k], 10) catch {
						const f = std.fmt.parseFloat(f64, text[i..k]) catch {
							tokens.append(Token{
								.text = text[i..k],
								.tag = IDEN,
								.pos = tokens.items.len,
								.value = null
							}) catch unreachable;
							i = k;
							continue;
						};
						tokens.append(Token{
							.text = text[i..k],
							.tag = FLOAT ,
							.pos = tokens.items.len,
							.value = .{
								.float = f
							}
						}) catch unreachable;
						i = k;
						continue;
					};
					tokens.append(Token{
						.text = text[i..k],
						.tag = NAT,
						.pos = tokens.items.len,
						.value = .{
							.nat = n
						}
					}) catch unreachable;
					i = k;
					continue;
				};
				tokens.append(Token{
					.text = text[i..k],
					.tag = INT,
					.pos = tokens.items.len,
					.value = .{
						.int = z
					}
				}) catch unreachable;
				i = k;
				continue;
			}
		}
	}
	return tokens;
}

const Scope = struct {
	mem: *const std.mem.Allocator,
	lets: Buffer(Map(*Expr)),
	stored_capacity: u64,
	
	pub fn init(mem: *const std.mem.Allocator) Scope {
		return Scope{
			.mem = mem,
			.lets = Buffer(Map(*Expr)).init(mem.*),
			.stored_capacity = 0
		};
	}

	pub fn contains(scope: *Scope, key: []const u8) ?*Expr {
		for (scope.lets.items) |map| {
			if (map.get(key)) |val| {
				return val;
			}
		}
		return null;
	}

	pub fn push_frame(scope: *Scope) u64 { 
		const current_frame = scope.lets.items.len;
		if (scope.lets.items.len < scope.stored_capacity){
			scope.lets.items.len += 1;
			scope.lets.items[current_frame].clearRetainingCapacity();
			return current_frame;
		}
		scope.lets.append(Map(*Expr).init(scope.mem.*)) catch unreachable;
		scope.stored_capacity = scope.lets.items.len;
		return current_frame;
	}

	pub fn pop_frame(scope: *Scope, frame: u64) void {
		for (frame+1 .. scope.lets.items.len) |i| {
			scope.lets.items[i].clearRetainingCapacity();
		}
		scope.lets.items.len = frame;
	}

	pub fn push(scope: *Scope, key: [] const u8, value: *Expr) void {
		scope.lets.items[scope.lets.items.len-1].put(key, value) catch unreachable;
	}
};

const Universe = struct {
	name: Token,
	equality: Expr,
	int: Expr,
	nat: Expr,
	float: Expr,
	str: Expr,
	lam: Expr,
	all: Expr,
	lets: Map(*Expr)
};

pub fn checkpoint_from_allocator(allocator: *const std.mem.Allocator) usize {
    const fba: *std.heap.FixedBufferAllocator = @ptrCast(@alignCast(allocator.ptr));
    return fba.end_index;
}

pub fn restore_from_allocator(allocator: *const std.mem.Allocator, checkpoint: usize) void {
    const fba: *std.heap.FixedBufferAllocator = @ptrCast(@alignCast(allocator.ptr));
    fba.end_index = checkpoint;
}

pub fn reset_from_allocator(allocator: *const std.mem.Allocator) void {
	const fba: *std.heap.FixedBufferAllocator = @ptrCast(@alignCast(allocator.ptr));
	fba.reset();
}

const Env = struct {
	let: Scope,
	vars: Scope,
	universes: Map(Universe),
	records: Map(Record),
};

const AST = struct {
	mem: *const std.mem.Allocator,
	tmp: *const std.mem.Allocator,
	env: Map(Env),
	values: Buffer(*Expr),

	pub fn show(ast: *AST) void {
		for (ast.values.items) |value| {
			value.show();
			std.debug.print("\n\n", .{});
		}
	}
};

const Record = struct {
	name: Token,
	fields: Buffer(Token),

	pub fn show(self: *Record) void {
		for (self.fields.items) |f| {
			std.debug.print("{s} ", .{f.text});
		}
	}
};

const Expr = union(enum){
	expr: Buffer(*Expr),
	atom: Token,
	quote: *Expr,

	pub fn depth(self: *Expr) u64  {
		switch (self.*){
			.expr => {
				var max_depth:u64 = 0;
				for (self.expr.items) |inner| {
					const inner_depth = inner.depth();
					if (inner_depth > max_depth){
						max_depth = inner_depth;
					}
				}
				return max_depth+1;
			},
			.atom => {
				return 1;
			},
			.quote => {
				return 1+self.quote.depth();
			}
		}
		return 0;
	}

	pub fn show(self: *Expr) void {
		switch (self.*){
			.expr => {
				std.debug.print("(", .{});
				for (self.expr.items) |s| {
					s.show();
				}
				std.debug.print(") ", .{});
			},
			.atom => {
				std.debug.print("{s} ", .{self.atom.text});
			},
			.quote => {
				std.debug.print("'", .{});
				self.quote.show();
			}
		}
	}
};

const ParseError = error {
	UnexpectedToken
};

pub fn parse(mem: *const std.mem.Allocator, tmp: *const std.mem.Allocator, tokens: []Token, err: *ErrorLog) ParseError!AST {
	var ast = AST{
		.mem = mem,
		.tmp = tmp,
		.env = Map(Env).init(mem.*),
		.values = Buffer(*Expr).init(mem.*)
	};
	const default = Env{
		.let = Scope.init(mem),
		.vars = Scope.init(mem),
		.universes = Map(Universe).init(mem.*),
		.records = Map(Record).init(mem.*),
	};
	ast.env.put("_", default) catch unreachable;
	if (ast.env.getPtr("_")) |env| {
		var i: u64 = 0;
		const frame = env.let.push_frame();
		const vframe = env.vars.push_frame();
		while (i<tokens.len){
			const top_level = ast.mem.create(Expr) catch unreachable;
			top_level.* = try parse_expression(&ast, &i, tokens, err, env);
			const digested = try metabolize(&ast, top_level, err, env, null);
			ast.values.append(digested) catch unreachable;
		}
		env.let.pop_frame(frame);
		env.vars.pop_frame(vframe);
	}
	return ast;
}

pub fn metabolize(ast: *AST, expr: *Expr, err: *ErrorLog, env: *Env, universe: ?*Universe) ParseError!*Expr{
	var it = env.universes.iterator();
	while (it.next()) |entry| {
		_ = try metabolize(ast, expr, err, env, entry.value_ptr);
	}
	switch (expr.*){
		.expr => {
			if (expr.expr.items.len == 0){
				return expr;
			}
			if (expr.expr.items.len == 1){
				return try metabolize(ast, expr.expr.items[0], err, env, universe);
			}
			if (expr.expr.items[0].* == .atom){
				switch (expr.expr.items[0].atom.tag){
					LET => {
						if (expr.expr.items.len != 3){
							err.append(expr.expr.items[0].atom.pos, "Malformed let\n", .{});
							return ParseError.UnexpectedToken;
						}
						if (expr.expr.items[1].* != .atom){
							err.append(expr.expr.items[0].atom.pos, "Expected name for let\n", .{});
							return ParseError.UnexpectedToken;
						}
						for (env.let.lets.items) |frame| {
							if (frame.getPtr(expr.expr.items[1].atom.text)) |_| {
								err.append(expr.expr.items[0].atom.pos, "Symbol already in scope\n", .{});
								return ParseError.UnexpectedToken;
							}
						}
						for (env.vars.lets.items) |frame| {
							if (frame.getPtr(expr.expr.items[1].atom.text)) |_| {
								err.append(expr.expr.items[0].atom.pos, "Symbol already in scope\n", .{});
								return ParseError.UnexpectedToken;
							}
						}
						const value = try metabolize(ast, expr.expr.items[2], err, env, universe);
						expr.expr.items[2] = value;
						env.let.push(
							expr.expr.items[1].atom.text,
							value
						);
						return expr;
					},
					VAR => {
						if (expr.expr.items.len != 3){
							err.append(expr.expr.items[0].atom.pos, "Malformed var\n", .{});
							return ParseError.UnexpectedToken;
						}
						if (expr.expr.items[1].* != .atom){
							err.append(expr.expr.items[0].atom.pos, "Expected name for var\n", .{});
							return ParseError.UnexpectedToken;
						}
						for (env.let.lets.items) |frame| {
							if (frame.getPtr(expr.expr.items[1].atom.text)) |_| {
								err.append(expr.expr.items[0].atom.pos, "Symbol already in scope\n", .{});
								return ParseError.UnexpectedToken;
							}
						}
						for (env.vars.lets.items) |frame| {
							if (frame.getPtr(expr.expr.items[1].atom.text)) |_| {
								err.append(expr.expr.items[0].atom.pos, "Symbol already in scope\n", .{});
								return ParseError.UnexpectedToken;
							}
						}
						const value = try metabolize(ast, expr.expr.items[2], err, env, universe);
						expr.expr.items[2] = value;
						env.vars.push(
							expr.expr.items[1].atom.text,
							try metabolize(ast, value, err, env, universe)
						);
						return expr;
					},
					SET => {
						if (expr.expr.items.len != 3){
							err.append(expr.expr.items[0].atom.pos, "Malformed set\n", .{});
							return ParseError.UnexpectedToken;
						}
						if (expr.expr.items[1].* != .atom){
							err.append(expr.expr.items[0].atom.pos, "Expected name for set\n", .{});
							return ParseError.UnexpectedToken;
						}
						for (env.vars.lets.items) |*frame| {
							if (frame.getPtr(expr.expr.items[1].atom.text)) |_| {
								frame.put(
									expr.expr.items[1].atom.text,
									try metabolize(ast, expr.expr.items[2], err, env, universe)
								) catch unreachable;
								return expr;
							}
						}
						err.append(expr.expr.items[1].atom.pos, "Binding {s} not found in scope\n", .{expr.expr.items[1].atom.text});
						return ParseError.UnexpectedToken;
					},
					UNIVERSE => {
						if (expr.expr.items.len != 9){
							err.append(expr.expr.items[1].atom.pos, "Malformed universe definition\n", .{});
							return ParseError.UnexpectedToken;
						}
						const name = try metabolize(ast, expr.expr.items[1], err, env, universe);
						if (name.* != .atom){
							err.append(expr.expr.items[1].atom.pos, "Expected atom for universe name\n", .{});
							return ParseError.UnexpectedToken;
						}
						const uni = Universe{
							.name = name.atom,
							.equality = expr.expr.items[2].*,
							.int = expr.expr.items[3].*,
							.nat = expr.expr.items[4].*,
							.float = expr.expr.items[5].*,
							.str= expr.expr.items[6].*,
							.lam = expr.expr.items[7].*,
							.all = expr.expr.items[8].*,
							.lets = Map(*Expr).init(ast.mem.*)
						};
						env.universes.put(name.atom.text, uni) catch unreachable;
						return expr;
					},
					RECORD => {
						if (expr.expr.items.len < 3){
							err.append(expr.expr.items[0].atom.pos, "Malformed record\n", .{});
							return ParseError.UnexpectedToken;
						}
						const name = try metabolize(ast, expr.expr.items[1], err, env, universe);
						if (name.* != .atom){
							err.append(expr.expr.items[0].atom.pos, "Expected atom for record name", .{});
							return ParseError.UnexpectedToken;
						}
						var record = Record{
							.name = name.atom,
							.fields = Buffer(Token).init(ast.mem.*)
						};
						const fields = try metabolize(ast, expr.expr.items[2], err, env, universe);
						if (fields.* != .expr){
							err.append(expr.expr.items[1].atom.pos, "Record definition expected to be list of atoms\n", .{});
							return ParseError.UnexpectedToken;
						}
						for (fields.expr.items) |field| {
							if (field.* != .atom){
								err.append(expr.expr.items[1].atom.pos, "Record definition expected to be list of atoms\n", .{});
								return ParseError.UnexpectedToken;
							}
							record.fields.append(field.atom) catch unreachable;
						}
						env.records.put(name.atom.text, record) catch unreachable;
						return expr;
					},
					PROG => {
						var i: u64 = 0;
						const frame = env.let.push_frame();
						const vframe = env.let.push_frame();
						while (i < expr.expr.items.len){
							const line = try metabolize(ast, expr.expr.items[i], err, env, universe);
							expr.expr.items[i] = line;
							i += 1;
						}
						env.let.pop_frame(frame);
						env.vars.pop_frame(vframe);
						return expr.expr.items[expr.expr.items.len-1];
					},
					CASE => {
						if (expr.expr.items.len < 2){
							err.append(expr.expr.items[0].atom.pos, "Malformed case\n", .{});
							return ParseError.UnexpectedToken;
						}
						const arg = try metabolize(ast, expr.expr.items[1], err, env, universe);
						var i: u64 = 1;
						while (i < expr.expr.items.len){
							const map = try metabolize(ast, expr.expr.items[i], err, env, universe);
							expr.expr.items[i] = map;
							if (map.* != .expr){
								err.append(expr.expr.items[0].atom.pos, "malformed case mapping\n", .{});
								return ParseError.UnexpectedToken;
							}
							if (structural_eq(map.expr.items[0], arg)){
								return try metabolize(ast, map.expr.items[1], err, env, universe);
							}
							i += 1;
						}
						err.append(expr.expr.items[0].atom.pos, "partial case\n", .{});
						return ParseError.UnexpectedToken;
					},
					COMP => {
						if (expr.expr.items.len != 3){
							err.append(expr.expr.items[0].atom.pos, "Malformed comp\n", .{});
							return ParseError.UnexpectedToken;
						}
						const environment = try metabolize(ast, expr.expr.items[1], err, env, universe);
						if (environment.* != .atom){
							err.append(expr.expr.items[0].atom.pos, "Expected atom for environment\n", .{});
							return ParseError.UnexpectedToken;
						}
						if (expr.expr.items[2].* != .expr){
							err.append(expr.expr.items[0].atom.pos, "Expected program for computation\n", .{});
							return ParseError.UnexpectedToken;
						}
						if (ast.env.getPtr(environment.atom.text)) |_| { }
						else{
							ast.env.put(environment.atom.text, Env{
								.let = Scope.init(ast.mem),
								.vars = Scope.init(ast.mem),
								.universes = Map(Universe).init(ast.mem.*),
								.records = Map(Record).init(ast.mem.*),
							}) catch unreachable;
						}
						if (ast.env.getPtr(environment.atom.text)) |exists| {
							var i: u64 = 0;
							const frame = exists.let.push_frame();
							const vframe = exists.vars.push_frame();
							while (i < expr.expr.items.len){
								expr.expr.items[i] = try metabolize(ast, expr.expr.items[i], err, env, null);
								i += 1;
							}
							exists.let.pop_frame(frame);
							exists.vars.pop_frame(vframe);
							return expr.expr.items[expr.expr.items.len-1];
						}
						unreachable;
					},
					HEAD => {
						if (expr.expr.items.len != 2){
							err.append(expr.expr.items[0].atom.pos, "malformed head\n", .{});
							return ParseError.UnexpectedToken;
						}
						const arg = try metabolize(ast, expr.expr.items[1], err, env, universe);
						if (arg.* != .expr){
							return arg;
						}
						if (arg.expr.items.len == 0){
							return arg;
						}
						return arg.expr.items[0];
					},
					TAIL => {
						if (expr.expr.items.len != 2){
							err.append(expr.expr.items[0].atom.pos, "malformed head\n", .{});
							return ParseError.UnexpectedToken;
						}
						const arg = try metabolize(ast, expr.expr.items[1], err, env, universe);
						const tail = ast.mem.create(Expr) catch unreachable;
						tail.* = Expr{
							.expr = Buffer(*Expr).init(ast.mem.*)
						};
						if (arg.* != .expr){
							return tail;
						}
						if (arg.expr.items.len == 0){
							return tail;
						}
						tail.expr.appendSlice(arg.expr.items[1..]) catch unreachable;
						return tail;
					},
					UNQUOTE => {
						const quoted = try metabolize(ast, expr.expr.items[1], err, env, universe);
						if (quoted.* == .quote){
							return quoted.quote;
						}
						err.append(expr.expr.items[0].atom.pos, "Expected quoted data\n", .{});
						return ParseError.UnexpectedToken;
					},
					CONS => {
						if (expr.expr.items.len != 3){
							err.append(expr.expr.items[0].atom.pos, "Malformed cons\n", .{});
							return ParseError.UnexpectedToken;
						}
						const tail = ast.mem.create(Expr) catch unreachable;
						tail.* = Expr{
							.expr = Buffer(*Expr).init(ast.mem.*)
						};
						var node = expr;
						while(node.expr.items[0].atom.tag != CONS){
							tail.expr.append(expr.expr.items[1]) catch unreachable;
							node = expr.expr.items[2];
							if (node.* != .expr){
								break;
							}
							if (node.expr.items.len != 3){
								break;
							}
							if (node.expr.items[0].* != .atom){
								break;
							}
						}
						tail.expr.append(node) catch unreachable;
						return tail;
					},
					ERROR => {
						if (expr.expr.items.len != 2){
							err.append(expr.expr.items[0].atom.pos, "Malformed error\n", .{});
							return ParseError.UnexpectedToken;
						}
						err.append(expr.expr.items[0].atom.pos, "{s}\n", .{expr.expr.items[1].atom.text});
						return ParseError.UnexpectedToken;
					},
					LAMBDA => {
						return expr;
					},
					ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, LT, GT => {
						if (expr.expr.items.len != 3){
							err.append(expr.expr.items[0].atom.pos, "Expected 2 args for binary operand\n", .{});
							return ParseError.UnexpectedToken;
						}
						return binop(ast, expr.expr.items[0].atom.tag, expr.expr.items[1], expr.expr.items[2]);
					},
					else => {
						if (env.universes.getPtr(expr.expr.items[0].atom.text)) |interpretation| {
							if (expr.expr.items.len != 3){
								err.append(expr.expr.items[0].atom.pos, "Malformed {s}\n", .{expr.expr.items[0].atom.text});
								return ParseError.UnexpectedToken;
							}
							if (expr.expr.items[1].* != .atom){
								err.append(expr.expr.items[0].atom.pos, "Expected name for {s}\n", .{expr.expr.items[0].atom.text});
								return ParseError.UnexpectedToken;
							}
							interpretation.lets.put(
								expr.expr.items[1].atom.text,
								try metabolize(ast, expr.expr.items[2], err, env, universe)
							) catch unreachable;
							return expr;
						}
						const term = try metabolize(ast, expr.expr.items[0], err, env, universe);
						expr.expr.items[0] = term;
						if (term.* != .expr){
							return expr;
						}
						if (term.expr.items[0].* != .atom){
							return expr;
						}
						if (env.records.getPtr(term.expr.items[0].atom.text)) |record| {
							const right = try metabolize(ast, expr.expr.items[1], err, env, universe);
							if (right.* == .atom){
								return try record_access(ast, record, term, right, expr, err, env, universe);
							}
						}
						if (term.expr.items.len != 3){
							return expr;
						}
						if (term.expr.items[0].atom.tag != LAMBDA){
							return expr;
						}
						if (term.expr.items[1].* == .expr){
							if (term.expr.items[1].expr.items.len > expr.expr.items.len-1){
								return expr;
							}
						}
						return try metabolize_lambda(ast, expr, err, env, universe);
					}
				}
			}
			else if (expr.expr.items[0].* == .expr){
				expr.expr.items[0] = try metabolize(ast, expr.expr.items[0], err, env, universe);
				if (expr.expr.items[0].* == .atom){
					return try metabolize(ast, expr, err, env, universe);
				}
				const term = expr.expr.items[0];
				if (term.* != .expr){
					return expr;
				}
				if (term.expr.items[0].* != .atom){
					return expr;
				}
				if (env.records.getPtr(term.expr.items[0].atom.text)) |record| {
					const right = try metabolize(ast, expr.expr.items[1], err, env, universe);
					if (right.* == .atom){
						return try record_access(ast, record, term, right, expr, err, env, universe);
					}
				}
				if (term.expr.items.len != 3){
					return expr;
				}
				if (term.expr.items[0].atom.tag != LAMBDA){
					return expr;
				}
				if (term.expr.items[1].* == .expr){
					if (term.expr.items[1].expr.items.len > expr.expr.items.len-1){
						return expr;
					}
				}
				return try metabolize_lambda(ast, expr, err, env, universe);
			}
			else{
				return expr;
			}
		},
		.atom => {
			if (universe) |interpretation| {
				if (interpretation.lets.get(expr.atom.text)) |def| {
					return try metabolize(ast, def, err, env, null);
				}
			}
			if (env.let.contains(expr.atom.text)) |def| {
				return try metabolize(ast, def, err, env, universe);
			}
			return expr;
		},
		.quote => {
			return expr;
		}
	}
	return expr;
}

pub fn binop_type(comptime T: type, op: TOKEN, l: T, r: T) T {
	var v:T = 0;
	switch (op){
		LT => {
			if (l < r){
				v = 1;
			}
			else {
				v = 0;
			}
		},
		GT => {
			if (l > r){
				v = 1;
			}
			else {
				v = 0;
			}
		},
		ADD => {
			v = l + r;
		},
		SUB => {
			v = l - r;
		},
		MUL => {
			v = l * r;
		},
		DIV => {
			if (r == 0){
				unreachable;
			}
			v = @divExact(l, r);
		},
		MOD => {
			if (r == 0){
				unreachable;
			}
			v = @mod(l, r);
		},
		AND => {
			if ((l != 0) and (r != 0)){
				return 1;
			}
			return 0;
		},
		OR => {
			if ((l != 0) or (r != 0)) {
				return 1;
			}
			return 0;
		},
		XOR => {
			if ((l != 0 and r == 0) or (l == 0 and r != 0)){
				return 1;
			}
			return 0;
		},
		else => {
			unreachable;
		}
	}
	return v;
}

pub fn binop(ast: *AST, op: TOKEN, left: *Expr, right: *Expr) ParseError!*Expr {
	if (left.atom.tag == FLOAT or right.atom.tag == FLOAT){
		const l: f64 = left.atom.value.?.float;
		var r: f64 = 0;
		if (right.atom.value.? == .int){
			r = @floatFromInt(right.atom.value.?.int);
		}
		else if (right.atom.value.? == .nat){
			r = @floatFromInt(right.atom.value.?.nat);
		}
		else{
			r = right.atom.value.?.float;
		}
		const v = binop_type(f64, op, l, r);
		const ret = ast.mem.create(Expr) catch unreachable;
		const buf = ast.mem.alloc(u8, 20) catch unreachable;
		const s = std.fmt.bufPrint(buf, "{}", .{v}) catch unreachable;
		ret.* = Expr{
			.atom = Token{
				.tag = FLOAT,
				.text = s,
				.value = .{
					.float = v
				},
				.pos = 0
			}
		};
		return ret;
	}
	else if (left.atom.tag == INT or right.atom.tag == INT){
		const l: i64 = left.atom.value.?.int;
		var r: i64 = 0;
		if (right.atom.value.? == .int){
			r = right.atom.value.?.int;
		}
		else if (right.atom.value.? == .nat){
			r = @intCast(right.atom.value.?.nat);
		}
		else{
			r = @intFromFloat(right.atom.value.?.float);
		}
		const v = binop_type(i64, op, l, r);
		const ret = ast.mem.create(Expr) catch unreachable;
		const buf = ast.mem.alloc(u8, 20) catch unreachable;
		const s = std.fmt.bufPrint(buf, "{}", .{v}) catch unreachable;
		ret.* = Expr{
			.atom = Token{
				.tag = INT,
				.text = s,
				.value = .{
					.int = v
				},
				.pos = 0
			}
		};
		return ret;
	}
	const l: u64 = left.atom.value.?.nat;
	var r: u64 = 0;
	if (right.atom.value.? == .int){
		r = @intCast(right.atom.value.?.int);
	}
	else if (right.atom.value.? == .nat){
		r = right.atom.value.?.nat;
	}
	else{
		r = @intFromFloat(right.atom.value.?.float);
	}
	const v = binop_type(u64, op, l, r);
	const ret = ast.mem.create(Expr) catch unreachable;
	const buf = ast.mem.alloc(u8, 20) catch unreachable;
	const s = std.fmt.bufPrint(buf, "{}", .{v}) catch unreachable;
	ret.* = Expr{
		.atom = Token{
			.tag = NAT,
			.text = s,
			.value = .{
				.nat = v
			},
			.pos = 0
		}
	};
	return ret;
}

pub fn record_access(ast: *AST, record: *Record, host: *Expr, right: *Expr, outer: *Expr, err: *ErrorLog, env: *Env, universe: ?*Universe) ParseError!*Expr {
	const name = right.atom.text;
	for (record.fields.items, 1..) |item, i| {
		if (std.mem.eql(u8, item.text, name)){
			const new = ast.mem.create(Expr) catch unreachable;
			new.* = Expr{
				.expr = Buffer(*Expr).init(ast.mem.*)
			};
			new.expr.append(host.expr.items[i]) catch unreachable;
			new.expr.appendSlice(outer.expr.items[2..]) catch unreachable;
			return try metabolize(ast, new, err, env, universe);
		}
	}
	err.append(right.atom.pos, "No field {s} in record {s}", .{name, host.expr.items[0].atom.text});
	return ParseError.UnexpectedToken;
}

pub fn metabolize_lambda(ast: *AST, expr: *Expr, err: *ErrorLog, env: *Env, universe: ?*Universe) ParseError!*Expr{
	var argmap = Map(*Expr).init(ast.mem.*);
	if (expr.expr.items[0].expr.items[1].* == .atom){
		const rest = ast.mem.create(Expr) catch unreachable;
		rest.* = Expr{
			.expr = Buffer(*Expr).init(ast.mem.*)
		};
		rest.expr.appendSlice(expr.expr.items[1..]) catch unreachable;
		argmap.put(expr.expr.items[0].expr.items[1].atom.text, rest) catch unreachable;
		return try distribute_args(ast, argmap, expr.expr.items[0].expr.items[2]);
	}
	for (expr.expr.items[0].expr.items[1].expr.items, expr.expr.items[1..expr.expr.items[0].expr.items[1].expr.items.len+1]) |name, arg| {
		if (name.* == .atom){
			argmap.put(name.atom.text, arg) catch unreachable;
		}
		else{
			err.append(expr.expr.items[0].expr.items[0].atom.pos, "Expected lambda arg to be atom\n", .{});
			return ParseError.UnexpectedToken;
		}
	}
	const section = try distribute_args(ast, argmap, expr.expr.items[0].expr.items[2]);
	if (expr.expr.items[0].expr.items[1].expr.items.len < expr.expr.items.len-1){
		const new = ast.mem.create(Expr) catch unreachable;
		new.* = Expr{
			.expr = Buffer(*Expr).init(ast.mem.*)
		};
		new.expr.append(section) catch unreachable;
		new.expr.appendSlice(expr.expr.items[expr.expr.items[0].expr.items[1].expr.items.len+1..]) catch unreachable;
		return try metabolize(ast, new, err, env, universe);
	}
	return section;
}

pub fn distribute_args(ast: *AST, argmap: Map(*Expr), expr: *Expr) ParseError!*Expr {
	switch (expr.*){
		.expr => {
			const new = ast.mem.create(Expr) catch unreachable;
			new.* = Expr{
				.expr = Buffer(*Expr).init(ast.mem.*)
			};
			for (expr.expr.items) |item| {
				new.expr.append(try distribute_args(ast, argmap, item)) catch unreachable;
			}
			return new;
		},
		.atom => {
			if (argmap.get(expr.atom.text)) |new| {
				return new;
			}
			return expr;
		},
		.quote => {
			return expr;
		}
	}
}

pub fn parse_expression(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog, env: *Env) ParseError!Expr {
	var head = tokens[i.*];
	if (head.tag == QUOTE){
		i.* += 1;
		head = tokens[i.*];
		if (head.tag == OPEN){
			i.* += 1;
			const inner = try parse_sub_expression_until(ast, i, tokens, err, env);
			const outer = Expr{
				.quote = ast.mem.create(Expr) catch unreachable
			};
			outer.quote.* = inner;
			return outer;
		}
		const inner = Expr{
			.atom = head
		};
		const outer = Expr{
			.quote = ast.mem.create(Expr) catch unreachable
		};
		outer.quote.* = inner;
		i.* += 1;
		return outer;
	}
	if (head.tag == OPEN){
		i.* += 1;
		return try parse_sub_expression_until(ast, i, tokens, err, env);
	}
	switch (head.tag){
		PROG => {
			err.append(i.*, "Cannot parse arbitrary arity of prog without wrapper\n", .{});
			return ParseError.UnexpectedToken;
		},
		CASE => {
			err.append(i.*, "Cannot parse arbitrary arity of case without wrapper\n", .{});
			return ParseError.UnexpectedToken;
		},
		LET => {
			const let = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
			if (let.expr.items[1].* != .atom){
				err.append(i.*, "let expression requires a single name", .{});
				return ParseError.UnexpectedToken;
			}
			if (let.expr.items[1].atom.tag != IDEN){
				err.append(i.*, "let expression requires an identifier for a name", .{});
				return ParseError.UnexpectedToken;
			}
			return let;
		},
		VAR => {
			const let = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
			if (let.expr.items[1].* != .atom){
				err.append(i.*, "var expression requires a single name", .{});
				return ParseError.UnexpectedToken;
			}
			if (let.expr.items[1].atom.tag != IDEN){
				err.append(i.*, "var expression requires an identifier for a name", .{});
				return ParseError.UnexpectedToken;
			}
			return let;
		},
		SET => {
			const let = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
			if (let.expr.items[1].* != .atom){
				err.append(i.*, "set expression requires a single name", .{});
				return ParseError.UnexpectedToken;
			}
			if (let.expr.items[1].atom.tag != IDEN){
				err.append(i.*, "set expression requires an identifier for a name", .{});
				return ParseError.UnexpectedToken;
			}
			return let;
		},
		HEAD, TAIL => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 1, env);
		},
		CONS, COMP, LAMBDA, LT, GT, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
		},
		UNQUOTE => {
			const let_name = head;
			i.* += 1;
			const left = ast.mem.create(Expr) catch unreachable;
			left.* = try parse_expression(ast, i, tokens, err, env);
			var let = Expr{
				.expr = Buffer(*Expr).init(ast.mem.*)
			};
			const outer = ast.mem.create(Expr) catch unreachable;
			outer.* = Expr{
				.atom = let_name
			};
			let.expr.append(outer) catch unreachable;
			let.expr.append(left) catch unreachable;
			return let;
		},
		UNIVERSE => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 9, env);
		},
		ERROR => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 1, env);
		},
		else => {}
	}
	var it = env.universes.iterator();
	while (it.next()) |entry| {
		if (std.mem.eql(u8, head.text, entry.key_ptr.*)){
			const let = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
			if (let.expr.items[1].* != .atom){
				err.append(i.*, "interpretation term for {s} expression requires a single name", .{head.text});
				return ParseError.UnexpectedToken;
			}
			if (let.expr.items[1].atom.tag != IDEN){
				err.append(i.*, "interpretation term for {s} expression requires an identifier for a name", .{head.text});
				return ParseError.UnexpectedToken;
			}
			return let;
		}
	}
	const arity = resolve_to_arity(ast, head, env);
	if (arity != 0){
		 const call = try parse_sub_expression_arity(ast, i, tokens, err, arity, env);
		 return call;
	}
	if (head.tag != IDEN and head.tag != INT and head.tag != NAT and head.tag != FLOAT and head.tag != STR){
		err.append(i.*, "Unknown token, expected expression, found {s}\n", .{head.text});
		return ParseError.UnexpectedToken;
	}
	i.* += 1;
	return Expr{
		.atom = head
	};
}

pub fn resolve_to_arity(ast: *AST, name: Token, env: *Env) u8 {
	switch (name.tag){
		CASE, PROG => {
			return 0;
		},
		ERROR, UNQUOTE, HEAD, TAIL => {
			return 1;
		},
		VAR, SET, LET, COMP, LAMBDA, LT, GT, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
			return 2;
		},
		UNIVERSE => {
			return 9;
		},
		else => {}
	}
	if (env.let.contains(name.text)) |target| {
		if (target.* == .atom){
			return resolve_to_arity(ast, target.atom, env);
		}
		if (target.* == .expr){
			if (target.expr.items.len != 0){
				if (target.expr.items[0].* == .atom){
					if (target.expr.items[0].atom.tag == LAMBDA){
						if (target.expr.items.len == 3){
							if (target.expr.items[1].* == .atom){
								return 0;
							}
							else if (target.expr.items[1].* == .expr){
								return @truncate(target.expr.items[1].expr.items.len);
							}
							return 0;
						}
					}
				}
			}
		}
	}
	var it = env.universes.iterator();
	while (it.next()) |entry| {
		if (std.mem.eql(u8, name.text, entry.key_ptr.*)){
			return 3;
		}
		var subit = entry.value_ptr.lets.iterator();
		while (subit.next()) |subentry| {
			if (std.mem.eql(u8, name.text, subentry.key_ptr.*)){
				const target = subentry.value_ptr.*;
				if (target.* == .atom){
					return resolve_to_arity(ast, target.atom, env);
				}
				if (target.* == .expr){
					if (target.expr.items.len != 0){
						if (target.expr.items[0].* == .atom){
							if (target.expr.items[0].atom.tag == LAMBDA){
								if (target.expr.items.len == 3){
									if (target.expr.items[1].* == .atom){
										return 0;
									}
									else if (target.expr.items[1].* == .expr){
										return @truncate(target.expr.items[1].expr.items.len);
									}
									return 0;
								}
							}
						}
					}
				}
			}
		}
	}
	return 0;
}

pub fn parse_sub_expression_arity(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog, arity: u64, env: *Env) ParseError!Expr {
	var expr = Expr{
		.expr = Buffer(*Expr).init(ast.mem.*)
	};
	const first = ast.mem.create(Expr) catch unreachable;
	first.* = Expr{
		.atom = tokens[i.*]
	};
	expr.expr.append(first) catch unreachable;
	i.* += 1;
	while (expr.expr.items.len < arity+1){
		if (i.* == tokens.len){
			err.append(i.*-1, "Unexpected end of file\n", .{});
			return ParseError.UnexpectedToken;
		}
		var head = tokens[i.*];
		if (head.tag == QUOTE){
			i.* += 1;
			head = tokens[i.*];
			if (head.tag == OPEN){
				i.* += 1;
				const inner = try parse_sub_expression_until(ast, i, tokens, err, env);
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = Expr{
					.quote = ast.mem.create(Expr) catch unreachable
				};
				outer.quote.* = inner;
				expr.expr.append(outer) catch unreachable;
				continue;
			}
			const inner = Expr{
				.atom = head
			};
			const outer = ast.mem.create(Expr) catch unreachable;
			outer.* = Expr{
				.quote = ast.mem.create(Expr) catch unreachable
			};
			outer.quote.* = inner;
			expr.expr.append(outer) catch unreachable;
			i.* += 1;
			continue;
		}
		if (head.tag == OPEN){
			i.* += 1;
			const outer = ast.mem.create(Expr) catch unreachable;
			outer.* = try parse_sub_expression_until(ast, i, tokens, err, env);
			expr.expr.append(outer) catch unreachable;
			continue;
		}
		else if (head.tag == CLOSE){
			err.append(i.*, "Unexpected close to open expression\n", .{});
			return ParseError.UnexpectedToken;
		}
		switch (head.tag){
			PROG => {
				err.append(i.*, "Cannot parse arbitrary arity of prog without wrapper\n", .{});
				return ParseError.UnexpectedToken;
			},
			CASE => {
				err.append(i.*, "Cannot parse arbitrary arity of case without wrapper\n", .{});
				return ParseError.UnexpectedToken;
			},
			LET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "let expression requires a single name", .{});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "let expression requires an identifier for a name", .{});
					return ParseError.UnexpectedToken;
				}
				expr.expr.append(let) catch unreachable;
				continue;
			},
			VAR => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "var expression requires a single name", .{});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "var expression requires an identifier for a name", .{});
					return ParseError.UnexpectedToken;
				}
				expr.expr.append(let) catch unreachable;
				continue;
			},
			SET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "set expression requires a single name", .{});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "set expression requires an identifier for a name", .{});
					return ParseError.UnexpectedToken;
				}
				expr.expr.append(let) catch unreachable;
				continue;
			},
			HEAD, TAIL => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 1, env);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			CONS, COMP, LAMBDA, LT, GT, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			UNQUOTE => {
				const let_name = head;
				i.* += 1;
				const left = ast.mem.create(Expr) catch unreachable;
				left.* = try parse_expression(ast, i, tokens, err, env);
				var let = ast.mem.create(Expr) catch unreachable;
				let.* = Expr{
					.expr = Buffer(*Expr).init(ast.mem.*)
				};
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = Expr{
					.atom = let_name
				};
				let.expr.append(outer) catch unreachable;
				let.expr.append(left) catch unreachable;
				expr.expr.append(let) catch unreachable;
				continue;
			},
			UNIVERSE => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 8, env);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			ERROR => {
				return try parse_sub_expression_arity(ast, i, tokens, err, 1, env);
			},
			else => {}
		}
		var it = env.universes.iterator();
		while (it.next()) |entry| {
			if (std.mem.eql(u8, head.text, entry.key_ptr.*)){
				const let = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "interpretation term for {s} expression requires a single name", .{head.text});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "interpretation term for {s} expression requires an identifier for a name", .{head.text});
					return ParseError.UnexpectedToken;
				}
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = let;
				expr.expr.append(outer) catch unreachable;
				continue;
			}
		}
		const ar = resolve_to_arity(ast, head, env);
		if (ar != 0){
			const call = try parse_sub_expression_arity(ast, i, tokens, err, ar, env);
			const outer = ast.mem.create(Expr) catch unreachable;
			outer.* = call;
			expr.expr.append(outer) catch unreachable;
			continue;
		}
		if (head.tag != IDEN and head.tag != INT and head.tag != NAT and head.tag != FLOAT and head.tag != STR){
			err.append(i.*, "Unknown token, expected expression, found {s}\n", .{head.text});
			return ParseError.UnexpectedToken;
		}
		const def = Expr{
			.atom = head
		};
		const outer = ast.mem.create(Expr) catch unreachable;
		outer.* = def;
		expr.expr.append(outer) catch unreachable;
		i.* += 1;
	}
	return expr;
}

pub fn parse_sub_expression_until(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog, env: *Env) ParseError!Expr {
	var expr = Expr{
		.expr = Buffer(*Expr).init(ast.mem.*)
	};
	while (tokens[i.*].tag != CLOSE){
		var head = tokens[i.*];
		if (head.tag == QUOTE){
			i.* += 1;
			head = tokens[i.*];
			if (head.tag == OPEN){
				i.* += 1;
				const inner = try parse_sub_expression_until(ast, i, tokens, err, env);
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = Expr{
					.quote = ast.mem.create(Expr) catch unreachable
				};
				outer.quote.* = inner;
				expr.expr.append(outer) catch unreachable;
				continue;
			}
			const inner = Expr{
				.atom = head
			};
			const outer = ast.mem.create(Expr) catch unreachable;
			outer.* = Expr{
				.quote = ast.mem.create(Expr) catch unreachable
			};
			outer.quote.* = inner;
			expr.expr.append(outer) catch unreachable;
			i.* += 1;
			continue;
		}
		if (head.tag == OPEN){
			i.* += 1;
			const outer = ast.mem.create(Expr) catch unreachable;
			outer.* = try parse_sub_expression_until(ast, i, tokens, err, env);
			expr.expr.append(outer) catch unreachable;
			continue;
		}
		switch (head.tag){
			PROG => {
				if (expr.expr.items.len == 0){
					const outer = ast.mem.create(Expr) catch unreachable;
					outer.* = Expr{
						.atom = head
					};
					i.* += 1;
					const continued = try parse_sub_expression_until(ast, i, tokens, err, env);
					expr.expr.append(outer) catch unreachable;
					expr.expr.appendSlice(continued.expr.items) catch unreachable;
					return expr;
				}
				err.append(i.*, "Cannot parse arbitrary arity of prog without wrapper\n", .{});
				return ParseError.UnexpectedToken;
			},
			CASE => {
				if (expr.expr.items.len == 0){
					const outer = ast.mem.create(Expr) catch unreachable;
					outer.* = Expr{
						.atom = head
					};
					i.* += 1;
					const continued = try parse_sub_expression_until(ast, i, tokens, err, env);
					expr.expr.append(outer) catch unreachable;
					expr.expr.appendSlice(continued.expr.items) catch unreachable;
					return expr;
				}
				err.append(i.*, "Cannot parse arbitrary arity of cons without wrapper\n", .{});
				return ParseError.UnexpectedToken;
			},
			LET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "let expression requires a single name", .{});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "let expression requires an identifier for a name", .{});
					return ParseError.UnexpectedToken;
				}
				expr.expr.append(let) catch unreachable;
				continue;
			},
			VAR => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "var expression requires a single name", .{});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "var expression requires an identifier for a name", .{});
					return ParseError.UnexpectedToken;
				}
				expr.expr.append(let) catch unreachable;
				continue;
			},
			SET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "set expression requires a single name", .{});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "set expression requires an identifier for a name", .{});
					return ParseError.UnexpectedToken;
				}
				expr.expr.append(let) catch unreachable;
				continue;
			},
			HEAD, TAIL => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 1, env);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			CONS, COMP, LAMBDA, LT, GT, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			UNQUOTE => {
				const let_name = head;
				i.* += 1;
				const left = ast.mem.create(Expr) catch unreachable;
				left.* = try parse_expression(ast, i, tokens, err, env);
				var let = ast.mem.create(Expr) catch unreachable;
				let.* = Expr{
					.expr = Buffer(*Expr).init(ast.mem.*)
				};
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = Expr{
					.atom = let_name
				};
				let.expr.append(outer) catch unreachable;
				let.expr.append(left) catch unreachable;
				expr.expr.append(let) catch unreachable;
				continue;
			},
			UNIVERSE => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 8, env);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			ERROR => {
				return try parse_sub_expression_arity(ast, i, tokens, err, 1, env);
			},
			else => {}
		}
		var it = env.universes.iterator();
		while (it.next()) |entry| {
			if (std.mem.eql(u8, head.text, entry.key_ptr.*)){
				const let = try parse_sub_expression_arity(ast, i, tokens, err, 2, env);
				if (let.expr.items[1].* != .atom){
					err.append(i.*, "interpretation term for {s} expression requires a single name", .{head.text});
					return ParseError.UnexpectedToken;
				}
				if (let.expr.items[1].atom.tag != IDEN){
					err.append(i.*, "interpretation term for {s} expression requires an identifier for a name", .{head.text});
					return ParseError.UnexpectedToken;
				}
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = let;
				expr.expr.append(outer) catch unreachable;
				continue;
			}
		}
		const arity = resolve_to_arity(ast, head, env);
		if (arity != 0){
			const call = try parse_sub_expression_arity(ast, i, tokens, err, arity, env);
			const outer = ast.mem.create(Expr) catch unreachable;
			outer.* = call;
			expr.expr.append(outer) catch unreachable;
			continue;
		}
		const def = Expr{
			.atom = head
		};
		const outer = ast.mem.create(Expr) catch unreachable;
		outer.* = def;
		expr.expr.append(outer) catch unreachable;
		i.* += 1;
	}
	i.* += 1;
	return expr;
}

pub fn nearest_token(expr: *Expr) ?Token {
	switch (expr.*){
		.expr => {
			if (expr.expr.items.len == 0){
				return null;
			}
			return nearest_token(expr.expr.items[0]);
		},
		.atom => {
			return expr.atom;
		},
		.quote => {
			return nearest_token(expr.quote);
		}
	}
	return null;
}

var internal_uid: []const u8 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

pub fn uid(mem: *const std.mem.Allocator) []u8 {
	var new = mem.alloc(u8, internal_uid.len)
		catch unreachable;
	var i: u64 = 0;
	var inc: bool = false;
	while (i < new.len){
		if (internal_uid[i] < 'Z'){
			new[i] = internal_uid[i] + 1;
			i += 1;
			break;
		}
		new[i] = 'A';
		inc = true;
		i += 1;
	}
	if (inc){
		new[i] = internal_uid[i]+1;
	}
	while (i < new.len){
		new[i] = internal_uid[i];
		i += 1;
	}
	internal_uid = new;
	return new;
}

pub fn structural_eq(left: *Expr, right: *Expr) bool {
	switch (left.*){
		.expr => {
			if (right.* != .expr){
				return false;
			}
			if (left.expr.items.len != right.expr.items.len){
				return false;
			}
			for (left.expr.items, right.expr.items) |l, r| {
				if (!structural_eq(l, r)){
					return false;
				}
			}
			return true;
		},
		.atom => {
			if (right.* != .atom){
				return false;
			}
			if (!std.mem.eql(u8, left.atom.text, right.atom.text)){
				return false;
			}
			return true;
		},
		.quote => {
			if (right.* != .quote){
				return false;
			}
			return structural_eq(left.quote, right.quote);
		}
	}
	unreachable;
}

pub fn deep_copy_buffer(comptime T: type, mem: *const std.mem.Allocator, buf: *Buffer(T)) Buffer(T) {
	var new = Buffer(T).init(mem.*);
	for (buf.items) |old| {
		new.append(old) catch unreachable;
	}
	return new;
}

pub fn deep_copy(mem: *const std.mem.Allocator, expr: *Expr) *Expr {
	switch (expr.*){
		.expr => {
			const appl = mem.create(Expr) catch unreachable;
			appl.* = Expr{
				.expr = Buffer(*Expr).init(mem.*)
			};
			for (expr.expr.items) |item| {
				appl.expr.append(deep_copy(mem, item)) catch unreachable;
			}
			return appl;
		},
		.atom => {
			const atom = mem.create(Expr) catch unreachable;
			atom.* = Expr{
				.atom = expr.atom
			};
			return atom;
		},
		.quote => {
			const quote = mem.create(Expr) catch unreachable;
			quote.* = Expr{
				.quote = deep_copy(mem, expr.quote)
			};
			return quote;
		}
	}
	unreachable;
}

pub fn get_contents(mem: *const std.mem.Allocator, filename: []const u8) ![]u8 {
	var infile = std.fs.cwd().openFile(filename, .{}) catch |err| {
		std.debug.print("File not found: {s}\n", .{filename});
		return err;
	};
	defer infile.close();
	const stat = infile.stat() catch |err| {
		std.debug.print("Errored file stat: {s}\n", .{filename});
		return err;
	};
	const contents = infile.readToEndAlloc(mem.*, stat.size+1) catch |err| {
		std.debug.print("Error reading file: {s}\n", .{filename});
		return err;
	};
	return contents;
}

const PollStamp = struct {
    mtime: i128,
    size: u64,
};

pub fn get_stamp(path: []const u8) !PollStamp {
    const stat = try std.fs.cwd().statFile(path);
    return .{
        .mtime = stat.mtime,
        .size = stat.size,
    };
}

pub fn spawn_vim(allocator: std.mem.Allocator, argv: []const []const u8) !std.process.Child {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    return child;
}

pub fn stop_child(child: *std.process.Child) !void {
    const term = child.kill() catch |err| switch (err) {
        error.AlreadyTerminated => return,
        else => return err,
    };
    _ = term;
}

pub fn changed(a: PollStamp, b: PollStamp) bool {
    return a.mtime != b.mtime or a.size != b.size;
}

pub fn main() anyerror!void {
	const heap = std.heap.page_allocator;
	const main_buffer = heap.alloc(u8, 0x1000000) catch unreachable;
	var main_mem_fixed = std.heap.FixedBufferAllocator.init(main_buffer);
	var main_mem = main_mem_fixed.allocator();
	const temp_buffer = heap.alloc(u8, 0x100000) catch unreachable;
	var temp_mem_fixed = std.heap.FixedBufferAllocator.init(temp_buffer);
	var temp_mem = temp_mem_fixed.allocator();
	const args = try std.process.argsAlloc(main_mem);
	if (args.len == 1){
		std.debug.print("-h for help\n", .{});
		return;
	}
	if (std.mem.eql(u8, args[1], "-h")){
		std.debug.print("Help Menu\n", .{});
		std.debug.print("   -h : Show this message\n", .{});
		std.debug.print("   -i : Interactive mode\n", .{});
		std.debug.print("   [infile name] : interpret file\n", .{});
		return;
	}
	if (args.len < 2){
		std.debug.print("-h for help\n", .{});
		return;
	}
	if (args.len == 3){
		//if (std.mem.eql(u8, args[2], "-i") == false){
			//std.debug.print("-h for help\n", .{});
			//return;
		//}
		//const filename = args[1];
		//const contents = try get_contents(&main_mem, filename);
		//const tokens = tokenize(&main_mem, contents);
		//var err = ErrorLog.init(&main_mem);
		//var ast = parse(&main_mem, &temp_mem, tokens.items, &err) catch {
			//err.handle(contents);
			//return;
		//};
		//if (err.log.items.len != 0){
			//err.handle(contents);
			//return;
		//}
		//_ = static_interpret(&ast, &err) catch {
			//err.handle(contents);
			//return;
		//};
		//if (err.log.items.len != 0){
			//err.handle(contents);
			//return;
		//}
		//const buf = ast.mem.alloc(u8, 40) catch unreachable;
		//const s = std.fmt.bufPrint(buf, "{s}.live", .{filename}) catch unreachable;
		//var out = std.fs.cwd().createFile(s, .{.truncate=true}) catch {
			//std.debug.print("Error creating file: {s}\n", .{s});
		//};
		//ast.write(out);
		//out.close();
		//var vim_argv = [_][]const u8{ "vim", "-n", s};
		//var last_stamp = try get_stamp(s);
		//var child = try spawn_vim(main_mem, vim_argv[0..]);
		//defer stop_child(&child) catch {};
		//const poll_interval_ns = 250 * std.time.ns_per_ms;
		//while (true) {
			//std.time.sleep(poll_interval_ns);
			//const new_stamp = get_stamp(s) catch |e| switch (e) {
				//error.FileNotFound => continue,
				//else => return e,
			//};
			//if (changed(last_stamp, new_stamp)) {
				//last_stamp = new_stamp;
				//try stop_child(&child);
				//std.time.sleep(50 * std.time.ns_per_ms);
				//const recontents = try get_contents(&main_mem, s);
				//const retokens = tokenize(&main_mem, recontents);
				//ast = parse(&main_mem, &temp_mem, retokens.items, &err) catch {
					//err.handle(recontents);
					//return;
				//};
				//if (err.log.items.len != 0){
					//err.handle(recontents);
					//return;
				//}
				//_ = static_interpret(&ast, &err) catch {
					//err.handle(recontents);
					//return;
				//};
				//if (err.log.items.len != 0){
					//err.handle(recontents);
					//return;
				//}
				//out = std.fs.cwd().createFile(s, .{.truncate=true}) catch {
					//std.debug.print("Error creating file: {s}\n", .{s});
				//};
				//ast.write(out);
				//out.close();
				//child = try spawn_vim(main_mem, vim_argv[0..]);
			//}
		//}
		return;
	}
	const filename = args[1];
	const contents = try get_contents(&main_mem, filename);
	const tokens = tokenize(&main_mem, contents);
	var err = ErrorLog.init(&main_mem);
	var ast = parse(&main_mem, &temp_mem, tokens.items, &err) catch {
		err.handle(contents);
		return;
	};
	if (err.log.items.len != 0){
		err.handle(contents);
		return;
	}
	ast.show();
}

//TODO
// garbage collection again
// tail call optimiation again
// lambda arg realiasing again?

// canvas
// input registry
// general way to do syscalls I guess?
// interactive note environment with vim, let it be a formatter too, things evaluate on save. 
