const std = @import("std");
const Buffer = std.ArrayList;
const Map = std.StringHashMap;

const debug = true;

const ERROR_MAX = 128;
const ERROR_LINES = 5;

const TOKEN = u64;

const HOLE = '_';
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
const DEFINE = 0;
const MACRO = 1;
const UNIVERSE = 2;
const STR = 3;
const HEAD = 4;
const PROG = 5;
const IF = 6;
const IDEN = 7;
const FLOAT = 8;
const TAIL = 9;
const LET = 10;
const SET = 11;
const LAMBDA = 12;
const INT = 13;
const NAT = 14;
const LE = 15;
const GE = 16;
const EQ = 17;
const NE = 18;

const Token = struct{
	text: []const u8,
	tag: TOKEN,
	pos: u64
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
			HOLE, QUOTE, UNQUOTE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, LT, GT, OPEN, CLOSE => {
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
	tokmap.put("define", DEFINE ) catch unreachable;
	tokmap.put("macro", MACRO ) catch unreachable;
	tokmap.put("universe", UNIVERSE ) catch unreachable;
	tokmap.put("head", HEAD ) catch unreachable;
	tokmap.put("prog", PROG ) catch unreachable;
	tokmap.put("if", IF ) catch unreachable;
	tokmap.put("tail", TAIL ) catch unreachable;
	tokmap.put("let", LET ) catch unreachable;
	tokmap.put("set", SET ) catch unreachable;
	tokmap.put("lambda", LAMBDA ) catch unreachable;
	tokmap.put("<=", LE ) catch unreachable;
	tokmap.put(">=", GE ) catch unreachable;
	tokmap.put("==", EQ ) catch unreachable;
	tokmap.put("!=", NE ) catch unreachable;
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
					.pos = tokens.items.len
				}) catch unreachable;
				continue;
			},
			HOLE, QUOTE, UNQUOTE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, LT, GT, OPEN, CLOSE => {
				tokens.append(Token{
					.text = text[i..i+1],
					.tag = c,
					.pos = tokens.items.len
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
						.pos = tokens.items.len
					}) catch unreachable;
					i = k;
					continue;
				}
				_ = std.fmt.parseInt(i64, text[i..k], 10) catch {
					_ = std.fmt.parseInt(u64, text[i..k], 10) catch {
						_ = std.fmt.parseFloat(f64, text[i..k]) catch {
							tokens.append(Token{
								.text = text[i..k],
								.tag = IDEN,
								.pos = tokens.items.len
							}) catch unreachable;
							i = k;
							continue;
						};
						tokens.append(Token{
							.text = text[i..k],
							.tag = FLOAT ,
							.pos = tokens.items.len
						}) catch unreachable;
						i = k;
						continue;
					};
					tokens.append(Token{
						.text = text[i..k],
						.tag = NAT,
						.pos = tokens.items.len
					}) catch unreachable;
					i = k;
					continue;
				};
				tokens.append(Token{
					.text = text[i..k],
					.tag = INT,
					.pos = tokens.items.len
				}) catch unreachable;
				i = k;
				continue;
			}
		}
	}
	return tokens;
}

const AST = struct {
	mem: *const std.mem.Allocator,
	let: Map(Expr),
	defs: Map(Definition),
	macros: Map(Macro),
	universes: Map(Map(Definition)),
	env: Map(Map(Expr)),

	pub fn show(self: *AST) void {
		var it = self.let.iterator();
		while (it.next()) |entry| {
			std.debug.print("let {s} ", .{entry.key_ptr.*});
			entry.value_ptr.show();
			std.debug.print("\n", .{});
		}
		var dit = self.defs.iterator();
		while (dit.next()) |entry| {
			entry.value_ptr.show();
			std.debug.print("\n", .{});
		}
		var macit = self.macros.iterator();
		while (macit.next()) |entry| {
			entry.value_ptr.show();
			std.debug.print("\n", .{});
		}
		var mit = self.universes.iterator();
		while (mit.next()) |entry| {
			std.debug.print("universe {s}\n", .{entry.key_ptr.*});
			var subit = entry.value_ptr.iterator();
			while (subit.next()) |subentry| {
				std.debug.print("{s} ", .{entry.key_ptr.*});
				subentry.value_ptr.show();
				std.debug.print("\n", .{});
			}
			std.debug.print("\n", .{});
		}
	}
};

const Macro = struct {
	name: Token,
	env: Token,
	args: Expr,
	expression: ?Expr,

	pub fn show(self: *Macro) void {
		std.debug.print("macro (in {s}) {s} ", .{self.env.text, self.name.text});
		self.args.show();
		if (self.expression) |*expr| {
			expr.show();
		}
	}
};

const Definition = struct {
	name: Token,
	args: Expr,
	expression: ?Expr,

	pub fn show(self: *Definition) void {
		std.debug.print("define {s} ", .{self.name.text});
		self.args.show();
		if (self.expression) |*expr| {
			expr.show();
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
			},
		}
	}
};

const ParseError = error {
	UnexpectedToken
};

pub fn parse(mem: *const std.mem.Allocator, tokens: []Token, err: *ErrorLog) ParseError!AST {
	var ast = AST{
		.mem = mem,
		.let = Map(Expr).init(mem.*),
		.defs = Map(Definition).init(mem.*),
		.macros = Map(Macro).init(mem.*),
		.universes = Map(Map(Definition)).init(mem.*),
		.env = Map(Map(Expr)).init(mem.*)
	};
	var i: u64 = 0;
	while (i<tokens.len){
		if (tokens[i].tag == LET){
			try parse_let(&ast, &i, tokens, err);
		}
		else if (tokens[i].tag == DEFINE){
			try parse_def(&ast, &i, tokens, err);
		}
		else if (tokens[i].tag == MACRO){
			try parse_macro(&ast, &i, tokens, err);
		}
		else if (tokens[i].tag == UNIVERSE){
			try parse_universe(&ast, &i, tokens, err);
		}
		else if (ast.universes.getPtr(tokens[i].text)) |universe| {
			try parse_universe_def(&ast, &i, tokens, tokens[i], universe, err);
		}
		else{
			err.append(i, "Unexpected token at top level {s}\n", .{tokens[i].text});
			i += 1;
		}
	}
	return ast;
}

pub fn parse_let(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i.*].tag != IDEN){
		err.append(i.*, "Expected identifier for name of universe, found {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.let.get(tokens[i.*].text)) |_| {
		err.append(i.*, "Duplicate global let definition {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i.*];
	i.* += 1;
	const expr = try parse_expression(ast, i, tokens, err);
	ast.let.put(name.text, expr) catch unreachable;
}

pub fn parse_def(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i.*].tag != IDEN){
		err.append(i.*, "Expected identifier for name of definition, found {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.defs.get(tokens[i.*].text)) |_| {
		err.append(i.*, "Duplicate definition {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i.*];
	i.* += 1;
	const args = try parse_expression(ast, i, tokens, err);
	ast.defs.put(name.text, Definition{
		.name = name,
		.args = args,
		.expression = null
	}) catch unreachable;
	const expression = try parse_expression(ast, i, tokens, err);
	if (ast.defs.getPtr(name.text)) |def| {
		def.expression = expression;
	}
}

pub fn parse_macro(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i.*].tag != IDEN){
		err.append(i.*, "Expected identifier for name of macro, found {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.macros.get(tokens[i.*].text)) |_| {
		err.append(i.*, "Duplicate macro {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i.*];
	i.* += 1;
	const env = tokens[i.*];
	if (env.tag != IDEN and env.tag != HOLE){
		err.append(i.*, "Unknown environment {s}", .{env.text});
		return ParseError.UnexpectedToken;
	}
	i.* += 1;
	const args = try parse_expression(ast, i, tokens, err);
	ast.macros.put(name.text, Macro{
		.name = name,
		.env = env,
		.args = args,
		.expression = null 
	}) catch unreachable;
	const expression = try parse_expression(ast, i, tokens, err);
	if (ast.macros.getPtr(name.text)) |mac| {
		mac.expression = expression;
	}
}

pub fn parse_universe(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i.*].tag != IDEN){
		err.append(i.*, "Expected identifier for name of universe, found {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.universes.get(tokens[i.*].text)) |_| {
		err.append(i.*, "Duplicate universe definition {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	ast.universes.put(tokens[i.*].text, Map(Definition).init(ast.mem.*)) catch unreachable;
	i.* += 1;
}

pub fn parse_universe_def(ast: *AST, i: *u64, tokens: []Token, name: Token, universe: *Map(Definition), err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i.*].tag != IDEN){
		err.append(i.*, "Expected identifier for name of {s}, found {s}\n", .{name.text, tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	if (universe.get(tokens[i.*].text)) |_| {
		err.append(i.*, "Duplicate {s} {s}\n", .{name.text, tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	const n = tokens[i.*];
	i.* += 1;
	const args = try parse_expression(ast, i, tokens, err);
	const expression = try parse_expression(ast, i, tokens, err);
	universe.put(n.text, Definition{
		.name = n,
		.args = args,
		.expression = expression
	}) catch unreachable;
}

pub fn parse_expression(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!Expr {
	var head = tokens[i.*];
	if (head.tag == QUOTE){
		i.* += 1;
		head = tokens[i.*];
		if (head.tag == OPEN){
			i.* += 1;
			const inner = try parse_sub_expression_until(ast, i, tokens, err);
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
		return try parse_sub_expression_until(ast, i, tokens, err);
	}
	switch (head.tag){
		PROG => {
			err.append(i.*, "Cannot parse arbitrary arity of prog without wrapper\n", .{});
			return ParseError.UnexpectedToken;
		},
		IF => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 3);
		},
		LET => {
			const let = try parse_sub_expression_arity(ast, i, tokens, err, 2);
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
		SET => {
			const let = try parse_sub_expression_arity(ast, i, tokens, err, 2);
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
		LAMBDA, LE, LT, GE, GT, EQ, NE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 2);
		},
		UNQUOTE => {
			const let_name = head;
			i.* += 1;
			const left = ast.mem.create(Expr) catch unreachable;
			left.* = try parse_expression(ast, i, tokens, err);
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
		DEFINE => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 3);
		},
		MACRO => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 3);
		},
		UNIVERSE => {
			return try parse_sub_expression_arity(ast, i, tokens, err, 1);
		},
		else => {}
	}
	if (ast.defs.get(head.text)) |def| {
		if (def.args == .expr){
			const arity = def.args.expr.items.len;
			return try parse_sub_expression_arity(ast, i, tokens, err, arity);
		}
		err.append(i.*, "Cannot parse arbitrary arity of term {s}\n", .{head.text});
		return ParseError.UnexpectedToken;
	}
	else if (ast.macros.get(head.text)) |def| {
		if (def.args == .expr){
			const arity = def.args.expr.items.len;
			return try parse_sub_expression_arity(ast, i, tokens, err, arity);
		}
		err.append(i.*, "Cannot parse arbitrary arity of term {s}\n", .{head.text});
		return ParseError.UnexpectedToken;
	}
	else if (ast.let.get(head.text)) |_| {
		err.append(i.*, "Cannot parse arbitrary arity of term {s}\n", .{head.text});
		return ParseError.UnexpectedToken;
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

pub fn parse_sub_expression_arity(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog, arity: u64) ParseError!Expr {
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
		var head = tokens[i.*];
		if (head.tag == QUOTE){
			i.* += 1;
			head = tokens[i.*];
			if (head.tag == OPEN){
				i.* += 1;
				const inner = try parse_sub_expression_until(ast, i, tokens, err);
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
			outer.* = try parse_sub_expression_until(ast, i, tokens, err);
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
			IF => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 3);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			LET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2);
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
			SET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2);
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
			LAMBDA, LE, LT, GE, GT, EQ, NE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			UNQUOTE => {
				const let_name = head;
				i.* += 1;
				const left = ast.mem.create(Expr) catch unreachable;
				left.* = try parse_expression(ast, i, tokens, err);
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
			DEFINE => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 3);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			MACRO => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 3);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			UNIVERSE => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 1);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			else => {}
		}
		if (ast.defs.get(head.text)) |def| {
			if (def.args == .expr){
				const ar = def.args.expr.items.len;
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = try parse_sub_expression_arity(ast, i, tokens, err, ar);
				expr.expr.append(outer) catch unreachable;
				continue;
			}
			else {
				err.append(i.*, "Cannot parse arbitrary arity of term {s}\n", .{head.text});
				return ParseError.UnexpectedToken;
			}
		}
		else if (ast.macros.get(head.text)) |def| {
			if (def.args == .expr){
				const ar = def.args.expr.items.len;
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = try parse_sub_expression_arity(ast, i, tokens, err, ar);
				expr.expr.append(outer) catch unreachable;
				continue;
			}
			else{
				err.append(i.*, "Cannot parse arbitrary arity of term {s}\n", .{head.text});
				return ParseError.UnexpectedToken;
			}
		}
		const outer = ast.mem.create(Expr) catch unreachable;
		outer.* = Expr{
			.atom = head
		};
		expr.expr.append(outer) catch unreachable;
		i.* += 1;
	}
	return expr;
}

pub fn parse_sub_expression_until(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!Expr {
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
				const inner = try parse_sub_expression_until(ast, i, tokens, err);
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
			outer.* = try parse_sub_expression_until(ast, i, tokens, err);
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
					const continued = try parse_sub_expression_until(ast, i, tokens, err);
					expr.expr.append(outer) catch unreachable;
					expr.expr.appendSlice(continued.expr.items) catch unreachable;
					return expr;
				}
				err.append(i.*, "Cannot parse arbitrary arity of prog without wrapper\n", .{});
				return ParseError.UnexpectedToken;
			},
			IF => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 3);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			LET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2);
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
			SET => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2);
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
			LAMBDA, LE, LT, GE, GT, EQ, NE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
				const let = ast.mem.create(Expr) catch unreachable;
				let.* = try parse_sub_expression_arity(ast, i, tokens, err, 2);
				expr.expr.append(let) catch unreachable;
				continue;
			},
			UNQUOTE => {
				const let_name = head;
				i.* += 1;
				const left = ast.mem.create(Expr) catch unreachable;
				left.* = try parse_expression(ast, i, tokens, err);
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
			DEFINE => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 3);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			MACRO => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 3);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			UNIVERSE => {
				const definition = ast.mem.create(Expr) catch unreachable;
				definition.* = try parse_sub_expression_arity(ast, i, tokens, err, 1);
				expr.expr.append(definition) catch unreachable;
				continue;
			},
			else => {}
		}
		if (ast.defs.get(head.text)) |def| {
			if (def.args == .expr){
				const arity = def.args.expr.items.len;
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = try parse_sub_expression_arity(ast, i, tokens, err, arity);
				expr.expr.append(outer) catch unreachable;
				continue;
			}
			else{
				i.* += 1;
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = try parse_sub_expression_until(ast, i, tokens, err);
				expr.expr.append(outer) catch unreachable;
				return expr;
			}
		}
		else if (ast.macros.get(head.text)) |def| {
			if (def.args == .expr){
				const arity = def.args.expr.items.len;
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = try parse_sub_expression_arity(ast, i, tokens, err, arity);
				expr.expr.append(outer) catch unreachable;
				continue;
			}
			else{
				i.* += 1;
				const outer = ast.mem.create(Expr) catch unreachable;
				outer.* = try parse_sub_expression_until(ast, i, tokens, err);
				expr.expr.append(outer) catch unreachable;
				return expr;
			}
		}
		const outer = ast.mem.create(Expr) catch unreachable;
		outer.* = Expr{
			.atom = head
		};
		expr.expr.append(outer) catch unreachable;
		i.* += 1;
	}
	i.* += 1;
	return expr;
}

const Let = struct{
	name: Token,
	value: *Expr
};

pub fn static_interpret(ast: *AST, err: *ErrorLog) ParseError!void {
	var it = ast.defs.iterator();
	while (it.next()) |entry| {
		if (std.mem.eql("main", entry.key_ptr.*) == false){
			try walk_def(ast, entry.value_ptr, err, false);
		}
	}
	if (ast.defs.getPtr("main")) |def| {
		try walk_def(ast, def, err, true);
	}
}

pub fn walk_def(ast: *AST, def: *Definition, err: *ErrorLog, run: bool) ParseError!void {
	if (def.args.depth() > 2){
		err.append(def.name.pos, "Cannot destructure definition args\n", .{});
		return ParseError.UnexpectedToken;
	}
	if (def.expression) |*expr| {
		def.expression = try walk_expr(ast, expr, err, run);
	}
	else{
		err.append(def.name.pos, "Cannot find expression for definition\n", .{});
		return ParseError.UnexpectedToken;
	}
}

pub fn macro_argmap(ast: *AST, structure: *Expr, args: []*Expr, err: *ErrorLog) ParseError!Map(*Expr) {
	const map = Map(*Expr).init(ast.mem.*);
	if (structure.* == .atom){
		const argexpr = ast.mem.create(Expr) catch unreachable;
		argexpr.* = Expr{
			.expr = Buffer(*Expr).init(ast.mem.*)
		};
		argexpr.expr.appendSlice(args) catch unreachable;
		map.put(structure.atom.text, argexpr) catch unreachable;
	}
	else if (structure.* == .QUOTE){
		if (nearest_token(structure)) |pos| {
			err.append(pos.pos, "Cannot quote arguments\n".{});
		}
		else{
			err.append(0, "Cannot quote arguments\n", .{});
		}
		return ParseError.UnexpectedToken;
	}
	for (args, structure.expr.items) |arg, candidate| {
		try argmap_descend(&argmap, arg, candidate, err);
	}
	return map;
}

pub fn nearest_token(expr: *Expr) ?Token {
	switch (expr.*){
		.expr => {
			if (expr.expr.items.len == 0){
				return null;
			}
			return nearest_token(expr.expr.items[0]);
		}
		.atom => {
			return expr.atom;
		},
		.quote => {
			return nearest_token(expr.quote);
		}
	}
	return null;
}

pub fn argmap_descend(argmap: *Map(*Expr), left: *Expr, right: *Expr, err: *ErrorLog) ParseError!void {
	switch(left.*){
		.atom => {
			argmap.put(left.atom.text, right) catch unreachable;
		},
		.expr => {
			if (right.* != .expr){
				if (nearest_token(left)) |pos| {
					err.append(pos.pos, "argument structure does not match requested structure\n", .{});
				}
				else{
					err.append(0, "argument structure does not match requested structure\n", .{});
				}
				return ParseError.UnexpectedToken;
			}
			if (left.expr.items.len != right.expr.items.len){
				if (nearest_token(left)) |pos| {
					err.append(pos.pos, "argument structure does not match requested structure\n", .{});
				}
				else{
					err.append(0, "argument structure does not match requested structure\n", .{});
				}
				return ParseError.UnexpectedToken;
			}
			for (left.expr.items, right.expr.items) |l, r| {
				argmap_descend(argmap, l, r, err);
			}
		},
		.quote => {
			if (nearest_token(left)) |pos| {
				err.append(pos.pos, "Cannot quote arguments\n", .{});
			}
			else{
				err.append(0, "Cannot quote arguments\n", .{});
			}
			return ParseError.UnexpectedToken;
		}
	}
}

pub fn walk_expr(ast: *AST, expr: *Expr, err: *ErrorLog, run: bool) ParseError!*Expr {
	var processed: ?*Expr = null;
	switch (expr.*){
		.expr => {
			var new_expr = ast.mem.create(Expr) catch unreachable;
			new_expr.* = Expr{
				.expr = Buffer(*Expr).init(ast.mem.*)
			};
			if (expr.expr.items.len != 0){
				var i: u64 = 0;
				while (i < expr.expr.items.len){
					if (expr.expr.items[i].* == .atom){
						if (ast.macros.get(expr.atom.text)) |def| {
							if (def.args == .atom){
								const argmap = try macro_argmap(ast, def.args, expr.items[i..expr.expr.items.len], err);
								const replaced = distribute_argmap(ast, argmap, def.expression);
								const interpreted = try walk_expr(ast, replaced, err, run);
								new_expr.append(interpreted) catch unreachable;
							}
							else if (def.args == .expr){
								if (def.args.expr.items.len <= expr.expr.items.len-i){
									const argmap = try macro_argmap(ast, def.args, expr.expr.items[i..i+def.args.expr.items.len], err);
									const replaced = distribute_argmap(ast, argmap, def.expression);
									const interpreted = try walk_expr(ast, replaced, err, run);
									new_expr.append(interpreted) catch unreachable;
								}
							}
							else{
								err.append(def.name.pos, "Quote args not allowed\n", .{});
								return ParseError.UnexpectedToken;
							}
						}
						continue;
					}
					const new = try walk_expr(ast, expr.expr.items[i], err, run);
					new_expr.append(new) catch unreachable;
					i += 1;
				}
			}
			processed = new_expr;
		},
		.atom => {
			if (ast.macros.get(expr.atom.text)) |def| {
				if (def.args == .atom){
					const empty = ast.mem.create(Expr) catch unreachable;
					empty.* = Expr{
						.expr = Buffer(*Expr).init(ast.mem.*)
					};
					const argmap = try macro_argmap(ast, def.args, empty, err);
					const replaced = distribute_argmap(ast, argmap, def.expression);
					const interpreted = try walk_expr(ast, replaced, err, run);
					processed = interpreted;
				}
				else if  (def.args == .expr){
					if (def.args.expr.items.len == 0){
						const interpreted = try walk_expr(ast, replaced, err, run);
						processed = interpreted;
					}
				}
				else{
					err.append(def.name.pos, "Quote args not allowed\n", .{});
					return ParseError.UnexpectedToken;
				}
			}
		},
		.quote => {
			processed = expr;
		}
	}
	var scope = Buffer(Let).init(ast.mem.*);
	return try interpret(ast, &scope, processed, err);
}

pub fn interpret(ast: *AST, scope: *Buffer(Let), expr: *Expr, err: *ErrorLog) ParseError!*Expr {
	switch (expr.*) {
		.expr => {
			if (expr.expr.items.len != 0){
				const head = expr.expr.items[0];
				if (head.* == .atom){
					switch (head.atom.tag){
						PROG => {
							if (expr.expr.items.len > 1){
								var i: u64 = 1;
								var last: ?*Expr = null;
								while (i < expr.expr.items.len){
									i += 1;
									last = try interpret(ast, scope, expr, err);
								}
								if (last)|l|{
									return l;
								}
							}
						},
						IF => {
							const cond = expr.expr.items[1];
							const cons = expr.expr.items[2];
							const alt = expr.expr.items[3];
							const b = try interpret(ast, scope, cond, err);
							if (b == .atom){
								if (std.mem.eql(u8, b.atom.text, "0")){
									return try interpret(ast, scope, cons, err);
								}
							}
							return try interpret(ast, scope, alt, err);
						},
						LET => {
							const name = expr.expr.items[1];
							const val = expr.expr.items[2];
							scope.append(Let{
								.name = name.atom,
								.value = try interpret(ast, scope, val, err)
							}) catch unreachable;
							return expr;
						},
						SET => {
							const name = expr.expr.items[1];
							const val = expr.expr.items[2];
							for (scope.items) |*let| {
								if (std.mem.eql(u8, let.name.text, name.text)){
									let.value = try interpret(ast, scope, val, err);
									return expr;
								}
							}
						},
						LAMBDA => {
							return expr;
						},
						LE, LT, GE, GT, EQ, NE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
						},
						UNQUOTE => {
							const expression = expr.expr.items[1];
							return try interpret(ast, scope, val, err);
						},
						DEFINE => {
						},
						MACRO => {
						},
						UNIVERSE => {
						},
						else => {}
					}
					var i: u64 = 0;
					while (i < expr.expr.items.len){
						i += 1;
						const save = scope.items.len;
						expr.expr.items[i] = try interpret(ast, scope, expr.expr.items[i], err);
						scope.items.len = save;
					}
					if (ast.defs.get(head.atom.text)) |def| {
						const ret = try argapply_defs(ast, scope, def, expr, err);
						return ret;
					}
				}
				else if (head == .expr){
					if (head.expr.items.len > 0){
						const islambda = head.expr.items[0];
						if (islambda == .atom){
							if (islambda.atom.tag == LAMBDA){
								if (expr.items.len > 1){
									const save = scope.items.len;
									scope.append(Let{
										.name = head.expr.items[1],
										.value = try interpret(ast, scope, expr.expr.items[1], err)
									}) catch unreachable;
									const new = try interpret(ast, scope, head.expr.items[2], err);
									scope.items.len = save;
									if (expr.expr.items.len > 2){
										const rest = ast.mem.create(ast.mem.*) catch unreachable;
										rest.* = Expr{
											.expr = Buffer(*Expr).init(ast.mem.*)
										};
										rest.expr.append(new) catch unreachable;
										rest.expr.appendSlice(expr.expr.items[2..]) catch unreachable;
										return try interpret(ast, scope, rest, err);
									}
									return new;
								}
							}
						}
					}
				}
			}
		},
		.atom => {
			for (scope.items) |let| {
				if (std.mem.eql(u8, expr.atom.text, let.name.text)){
					const save = scope.items.len;
					const new = try interpret(ast, scope, let.value, err);
					scope.items.len = save;
					return new;
				}
			}
			if (ast.defs.get(expr.atom.text)) |def| {
				const ret = try argapply_defs(ast, scope, def, expr, err);
				return ret;
			}
		},
		.quote => {
			return expr;
		}
	}
	return expr;
}

pub fn argapply_defs(ast: *AST, scope: *Buffer(Let), def: Definition, expr: *Expr, err: *ErrorLog) ParseError!*Expr {
	const save = scope.items.len;
	if (def.args == .atom){
		let.append(Let{
			.name = def.args,
			.value = expr
		}) catch unreachable;
	}
	else if (def.args == .expr){
		if (def.args.items.len < expr.expr.items.len-1)
		for (def.args.items, expr.expr.items[1..]) |arg, exp| {
			if (arg.* == .atom){
				let.append(Let{
					.name = arg.atom,
					.value = exp
				}) catch unreachable;
			}
			else{
				err.append(def.name.pos, "cannot structure definition args\n", .{});
				return ParseError.UnexpectedToken;
			}
		}
	}
	else if (def.args == .quote){
		err.append(def.name.pos, "cannot quote args\n", .{});
		return ParseError.UnexpectedToken;
	}
	const ret = try interpret(ast, scope, def.expression, err);
	scope.items.len = save;
	if (def.args.items.len < expr.expr.items.len-1){
		const new = ast.mem.create(Expr) catch unreachable;
		new.* = Expr{
			.expr = Buffer(*Expr).init(ast.mem.*)
		};
		new.expr.append(ret) catch unreachable;
		new.expr.appendSlice(expr.expr.items[def.args.items.len+2..]) catch unreachable;
		return try interpret(ast, scope, ret, err);
	}
	return ret;
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

pub fn main() anyerror!void {
	const heap = std.heap.page_allocator;
	const main_buffer = heap.alloc(u8, 0x1000000) catch unreachable;
	var main_mem_fixed = std.heap.FixedBufferAllocator.init(main_buffer);
	var main_mem = main_mem_fixed.allocator();
	const args = try std.process.argsAlloc(main_mem);
	if (args.len == 1){
		std.debug.print("-h for help\n", .{});
		return;
	}
	if (std.mem.eql(u8, args[1], "-h")){
		std.debug.print("Help Menu\n", .{});
		std.debug.print("   -h : Show this message\n", .{});
		std.debug.print("   [infile name] : compile file\n", .{});
		return;
	}
	if (args.len < 2){
		std.debug.print("-h for help\n", .{});
		return;
	}
	const filename = args[1];
	const contents = try get_contents(&main_mem, filename);
	const tokens = tokenize(&main_mem, contents);
	var err = ErrorLog.init(&main_mem);
	var ast = parse(&main_mem, tokens.items, &err) catch {
		err.handle(contents);
		return;
	};
	if (err.log.items.len != 0){
		err.handle(contents);
		return;
	}
	if (debug){
		ast.show();
	}
	static_interpret(&ast, &err) catch {
		err.handle(contents);
		return;
	};
	if (err.log.items.len != 0){
		err.handle(contents);
		return;
	}
}

//TODO
// the loop
	// list parse
	// list interpret
//macro environments
