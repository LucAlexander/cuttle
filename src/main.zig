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
const ERROR = 19;
const RECORD = 20;

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
// the loop
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
	tokmap.put("error", ERROR) catch unreachable;
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
			HOLE, QUOTE, UNQUOTE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, LT, GT, OPEN, CLOSE => {
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

const Universe = struct {
	name: Token,
	equality: Expr,
	int: Expr,
	nat: Expr,
	float: Expr,
	str: Expr,
	lam: Expr,
	all: Expr
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

const AST = struct {
	mem: *const std.mem.Allocator,
	tmp: *const std.mem.Allocator,
	let: Map(Expr),
	defs: Map(Definition),
	macros: Map(Macro),
	universe_declarations: Map(Universe),
	universes: Map(Map(Definition)),
	env: Map(Map(Expr)),
	records: Map(Record),

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

const Record = struct {
	name: Token,
	fields: Buffer(Token)
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

pub fn parse(mem: *const std.mem.Allocator, tmp: *const std.mem.Allocator, tokens: []Token, err: *ErrorLog) ParseError!AST {
	var ast = AST{
		.mem = mem,
		.tmp = tmp,
		.let = Map(Expr).init(mem.*),
		.defs = Map(Definition).init(mem.*),
		.macros = Map(Macro).init(mem.*),
		.universe_declarations = Map(Universe).init(mem.*),
		.universes = Map(Map(Definition)).init(mem.*),
		.env = Map(Map(Expr)).init(mem.*),
		.records = Map(Record).init(mem.*)
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
		else if (tokens[i].tag == RECORD){
			try parse_record(&ast, &i, tokens, err);
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

pub fn parse_record(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i.*].tag != IDEN){
		err.append(i.*, "Expected identifier for record name, found {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.records.get(tokens[i.*].text)) |_| {
		err.append(i.*, "Duplicate identifier for name of record, found {s}\n", .{tokens[i.*].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i.*];
	i.* += 1;
	const fields = try parse_expression(ast, i, tokens, err);
	if (fields == .atom){
		var rec = Record{
			.name = name,
			.fields = Buffer(Token).init(ast.mem.*)
		};
		rec.fields.append(fields.atom) catch unreachable;
		ast.records.put(name.text, rec) catch unreachable;
		return;
	}
	var rec = Record{
		.name = name,
		.fields = Buffer(Token).init(ast.mem.*)
	};
	for (fields.expr.items) |item| {
		if (item.* == .expr){
			err.append(i.*, "Expected atom for field in record {s}\n", .{name.text});
			return ParseError.UnexpectedToken;
		}
		rec.fields.append(item.atom) catch unreachable;
	}
	ast.records.put(name.text, rec) catch unreachable;
	return;
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
	ast.universe_declarations.put(tokens[i.*].text, Universe{
		.name = tokens[i.*],
		.equality = try parse_expression(ast, i, tokens, err),
		.int = try parse_expression(ast, i, tokens, err),
		.nat = try parse_expression(ast, i, tokens, err),
		.float = try parse_expression(ast, i, tokens, err),
		.str = try parse_expression(ast, i, tokens, err),
		.lam = try parse_expression(ast, i, tokens, err),
		.all = try parse_expression(ast, i, tokens, err)
	}) catch unreachable;
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
			return try parse_sub_expression_arity(ast, i, tokens, err, 8);
		},
		ERROR => {
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
			ERROR => {
				return try parse_sub_expression_arity(ast, i, tokens, err, 1);
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
			ERROR => {
				return try parse_sub_expression_arity(ast, i, tokens, err, 1);
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

pub fn static_interpret(ast: *AST, err: *ErrorLog) ParseError!*Expr{
	var it = ast.defs.iterator();
	while (it.next()) |entry| {
		if (std.mem.eql(u8, "main", entry.key_ptr.*) == false){
			_ = try walk_def(ast, entry.value_ptr, err, false);
		}
	}
	if (ast.defs.getPtr("main")) |def| {
		return try walk_def(ast, def, err, true);
	}
	err.append(0, "No entry point for outer kernel\n", .{});
	return ParseError.UnexpectedToken;
}

pub fn walk_def(ast: *AST, def: *Definition, err: *ErrorLog, run: bool) ParseError!*Expr{
	if (def.args.depth() > 2){
		err.append(def.name.pos, "Cannot destructure definition args\n", .{});
		return ParseError.UnexpectedToken;
	}
	if (def.expression) |*expr| {
		const inner = try walk_expr(ast, expr, err, run, null, def.name);
		def.expression = inner.*;
		return inner;
	}
	else{
		err.append(def.name.pos, "Cannot find expression for definition\n", .{});
		return ParseError.UnexpectedToken;
	}
}

pub fn macro_argmap(ast: *AST, structure: *Expr, args: []*Expr, err: *ErrorLog) ParseError!Map(*Expr) {
	var map = Map(*Expr).init(ast.mem.*);
	if (structure.* == .atom){
		const argexpr = ast.mem.create(Expr) catch unreachable;
		argexpr.* = Expr{
			.expr = Buffer(*Expr).init(ast.mem.*)
		};
		argexpr.expr.appendSlice(args) catch unreachable;
		map.put(structure.atom.text, argexpr) catch unreachable;
	}
	else if (structure.* == .quote){
		if (nearest_token(structure)) |pos| {
			err.append(pos.pos, "Cannot quote arguments\n", .{});
		}
		else{
			err.append(0, "Cannot quote arguments\n", .{});
		}
		return ParseError.UnexpectedToken;
	}
	for (args, structure.expr.items) |arg, candidate| {
		try argmap_descend(&map, arg, candidate, err);
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
				try argmap_descend(argmap, l, r, err);
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

pub fn walk_expr(ast: *AST, expr: *Expr, err: *ErrorLog, run: bool, macro: ?Token, calling_token: Token) ParseError!*Expr {
	var processed: *Expr = expr;
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
						if (ast.macros.getPtr(expr.expr.items[i].atom.text)) |def| {
							if (def.args == .atom){
								var argmap = try macro_argmap(ast, &def.args, expr.expr.items[i..expr.expr.items.len], err);
								if (def.expression)|*expression|{
									const replaced = distribute_argmap(ast, &argmap, expression);
									const interpreted = try walk_expr(ast, replaced, err, true, def.env, calling_token);
									new_expr.expr.append(interpreted) catch unreachable;
								}
							}
							else if (def.args == .expr){
								if (def.args.expr.items.len <= expr.expr.items.len-i){
									var argmap = try macro_argmap(ast, &def.args, expr.expr.items[i..i+def.args.expr.items.len], err);
									if (def.expression)|*expression|{
										const replaced = distribute_argmap(ast, &argmap, expression);
										const interpreted = try walk_expr(ast, replaced, err, true, def.env, calling_token);
										new_expr.expr.append(interpreted) catch unreachable;
									}
								}
							}
							else{
								err.append(def.name.pos, "Quote args not allowed\n", .{});
								return ParseError.UnexpectedToken;
							}
						}
						new_expr.expr.append(expr.expr.items[i]) catch unreachable;
						i += 1;
						continue;
					}
					const new = try walk_expr(ast, expr.expr.items[i], err, run, null, calling_token);
					new_expr.expr.append(new) catch unreachable;
					i += 1;
				}
			}
			processed = new_expr;
		},
		.atom => {
			if (ast.macros.getPtr(expr.atom.text)) |def| {
				if (def.args == .atom){
					const empty = ast.mem.create(Expr) catch unreachable;
					empty.* = Expr{
						.expr = Buffer(*Expr).init(ast.mem.*)
					};
					var argmap = try macro_argmap(ast, &def.args, empty.expr.items[0..0], err);
					if (def.expression)|*expression|{
						const replaced = distribute_argmap(ast, &argmap, expression);
						const interpreted = try walk_expr(ast, replaced, err, true, def.env, calling_token);
						processed = interpreted;
					}
				}
				else if  (def.args == .expr){
					if (def.args.expr.items.len == 0){
						if (def.expression) |*expression|{
							const interpreted = try walk_expr(ast, expression, err, true, def.env, calling_token);
							processed = interpreted;
						}
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
	if (run){
		var scope = Buffer(Let).init(ast.mem.*);
		var trace = Buffer(Token).init(ast.mem.*);
		trace.append(calling_token) catch unreachable;
		var it = ast.universes.iterator();
		while (it.next()) |entry| {
			ast.defs = entry.value_ptr.*;
			if (ast.universe_declarations.get(entry.key_ptr.*)) |uni| {
				_ = try interpret(ast, &scope, processed, err, macro, uni, entry.value_ptr, &trace);
				scope.clearRetainingCapacity();
			}
		}
		var ret = try interpret(ast, &scope, processed, err, macro, null, null, &trace);
		while (ret == .tail){
			if (std.mem.eql(u8, ret.tail.call.text, calling_token.text)){
				ret = try interpret(ast, &scope, processed, err, macro, null, null, &trace);
			}
			else {
				break;
			}
		}
	}
	return processed;
}

pub fn distribute_argmap(ast: *AST, argmap: *Map(*Expr), expr: *Expr) *Expr {
	const new = ast.mem.create(Expr) catch unreachable;
	switch (expr.*){
		.expr => {
			new.* = Expr{
				.expr = Buffer(*Expr).init(ast.mem.*)
			};
			for (expr.expr.items) |sub| {
				new.expr.append(distribute_argmap(ast, argmap, sub)) catch unreachable;
			}
		},
		.atom => {
			if (argmap.get(expr.atom.text)) |replacement| {
				return replacement;
			}
			new.* = Expr{
				.atom = expr.atom
			};
		},
		.quote => {
			new.* = Expr{
				.quote = distribute_argmap(ast, argmap, expr.quote)
			};
		}
	}
	return new;
}

pub fn interpret(ast: *AST, scope: *Buffer(Let), expr: *Expr, err: *ErrorLog, top_level_macro: ?Token, universe: ?Universe, universe_defs: ?*Map(Definition), calling_token: ?*Buffer(Token)) ParseError!ExprTail {
	switch (expr.*) {
		.expr => {
			if (expr.expr.items.len == 1){
				return try interpret(ast, scope, expr.expr.items[0], err, null, universe, universe_defs, calling_token);
			}
			if (expr.expr.items.len != 0){
				var head = expr.expr.items[0];
				if (head.* == .atom){
					switch (head.atom.tag){
						PROG => {
							if (expr.expr.items.len > 1){
								var i: u64 = 1;
								var last: ?ExprTail = null;
								while (i < expr.expr.items.len){
									if (i == expr.expr.items.len-1){
										last = try interpret(ast, scope, expr.expr.items[i], err, null, universe, universe_defs, calling_token);
									}
									else{
										last = try interpret(ast, scope, expr.expr.items[i], err, null, universe, universe_defs, null);
									}
									i += 1;
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
							const b = try interpret(ast, scope, cond, err, null, universe, universe_defs, null);
							if (b == .tail){
								return b;
							}
							if (b.expr.* == .atom){
								if (b.expr.atom.value) |val| {
									if (val == .float){
										if (val.float == 0){
											return try interpret(ast, scope, alt, err, null, universe, universe_defs, calling_token);
										}
									}
									if (val == .nat){
										if (val.nat == 0){
											return try interpret(ast, scope, alt, err, null, universe, universe_defs, calling_token);
										}
									}
									if (val == .int){
										if (val.int == 0){
											return try interpret(ast, scope, alt, err, null, universe, universe_defs, calling_token);
										}
									}
								}
							}
							return try interpret(ast, scope, cons, err, null, universe, universe_defs, calling_token);
						},
						LET => {
							const name = expr.expr.items[1];
							const val = expr.expr.items[2];
							if (top_level_macro) |env| {
								if (ast.env.getPtr(env.text)) |lets| {
									const eval = try interpret(ast, scope, val, err, null, universe, universe_defs, null);
									if (eval == .tail){
										return eval;
									}
									lets.put(name.atom.text, eval.expr.*) catch unreachable;
								}
								else{
									var map = Map(Expr).init(ast.mem.*);
									const eval = try interpret(ast, scope, val, err, null, universe, universe_defs, null);
									if (eval == .tail){
										return eval;
									}
									map.put(name.atom.text, eval.expr.*) catch unreachable;
									ast.env.put(env.text, map) catch unreachable;
								}
								return ExprTail{.expr=expr};
							}
							else{
								const eval = try interpret(ast, scope, val, err, null, universe, universe_defs, null);
								if (eval == .tail){
									return eval;
								}
								scope.append(Let{
									.name = name.atom,
									.value = eval.expr
								}) catch unreachable;
								return ExprTail{.expr=expr};
							}
						},
						SET => {
							const name = expr.expr.items[1];
							const val = expr.expr.items[2];
							if (top_level_macro) |env| {
								if (ast.env.getPtr(env.text)) |lets| {
									const eval = try interpret(ast, scope, val, err, null, universe, universe_defs, null);
									if (eval == .tail){
										return eval;
									}
									lets.put(name.atom.text, eval.expr.*) catch unreachable;
									return ExprTail{.expr=expr};
								}
								err.append(name.atom.pos, "No value with name {s} in environment\n", .{name.atom.text});
								return ParseError.UnexpectedToken;
							}
							else{
								for (scope.items) |*let| {
									if (std.mem.eql(u8, let.name.text, name.atom.text)){
										const eval = try interpret(ast, scope, val, err, null, universe, universe_defs, null);
										if (eval == .tail){
											return eval;
										}
										let.value = eval.expr;
										return ExprTail{.expr=expr};
									}
								}
								if (ast.let.get(name.atom.text)) |_| {
									const eval = try interpret(ast, scope, val, err, null, universe, universe_defs, null);
									if (eval == .tail){
										return eval;
									}
									ast.let.put(name.atom.text, eval.expr.*) catch unreachable;
									return ExprTail{.expr=expr};
								}
								err.append(name.atom.pos, "No value with name {s} in scope\n", .{name.atom.text});
								return ParseError.UnexpectedToken;
							}
						},
						LAMBDA => {
							return ExprTail{.expr=expr};
						},
						LE, LT, GE, GT, EQ, NE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR => {
							const left = try interpret(ast, scope, expr.expr.items[1], err, null, universe, universe_defs, null);
							const right = try interpret(ast, scope, expr.expr.items[1], err, null, universe, universe_defs, null);
							if (left.expr.* != .atom){
								err.append(0, "Expected atom for left side of binary expression\n", .{});
								return ParseError.UnexpectedToken;
							}
							if (right.expr.* != .atom){
								err.append(0, "Expected atom for right side of binary expression\n", .{});
								return ParseError.UnexpectedToken;
							}
							return ExprTail{.expr=try binop(ast, head.atom.tag, left.expr, right.expr)};
						},
						UNQUOTE => {
							const expression = expr.expr.items[1];
							return try interpret(ast, scope, expression, err, null, universe, universe_defs, calling_token);
						},
						DEFINE => {
							if (expr.expr.items.len != 4){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[1].* != .atom){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[1].atom.tag != IDEN){
								return ExprTail{.expr=expr};
							}
							const name = expr.expr.items[1].atom;
							const args = expr.expr.items[2];
							const expression = expr.expr.items[3];
							ast.defs.put(name.text, Definition{
								.name = name,
								.args = args.*,
								.expression = expression.*
							}) catch unreachable;
							const empty = ast.mem.create(Expr) catch unreachable;
							empty.* = Expr{
								.expr = Buffer(*Expr).init(ast.mem.*)
							};
							return ExprTail{.expr=empty};
						},
						MACRO => {
							if (expr.expr.items.len != 5){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[1].* != .atom){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[1].atom.tag != IDEN){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[2].* != .atom){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[2].atom.tag != IDEN){
								return ExprTail{.expr=expr};
							}
							const name = expr.expr.items[1].atom;
							const env = expr.expr.items[1].atom;
							const args = expr.expr.items[2];
							const expression = expr.expr.items[3];
							ast.macros.put(name.text, Macro{
								.name = name,
								.env = env,
								.args = args.*,
								.expression = expression.*
							}) catch unreachable;
							const empty = ast.mem.create(Expr) catch unreachable;
							empty.* = Expr{
								.expr = Buffer(*Expr).init(ast.mem.*)
							};
							return ExprTail{.expr=empty};
						},
						UNIVERSE => {
							if (expr.expr.items.len != 9){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[1].* != .atom){
								return ExprTail{.expr=expr};
							}
							if (expr.expr.items[1].atom.tag != IDEN){
								return ExprTail{.expr=expr};
							}
							ast.universe_declarations.put(expr.expr.items[1].atom.text, Universe{
								.name = expr.expr.items[1].atom,
								.equality = expr.expr.items[2].*,
								.int = expr.expr.items[3].*,
								.nat = expr.expr.items[4].*,
								.float = expr.expr.items[5].*,
								.str = expr.expr.items[6].*,
								.lam = expr.expr.items[7].*,
								.all = expr.expr.items[8].*
							}) catch unreachable;
							ast.universes.put(expr.expr.items[1].atom.text, Map(Definition).init(ast.mem.*)) catch unreachable;
							const empty = ast.mem.create(Expr) catch unreachable;
							empty.* = Expr{
								.expr = Buffer(*Expr).init(ast.mem.*)
							};
							return ExprTail{.expr=empty};
						},
						ERROR => {
							const string = try interpret(ast, scope, expr.expr.items[1], err, null, null, null, calling_token);
							if (string == .tail){
								return string;
							}
							if (string.expr.* != .atom){
								if (nearest_token(string.expr)) |tok| {
									err.append(tok.pos, "Expected error to be string atom\n", .{});
								}
								else{
									err.append(0, "Expected error to be string atom\n", .{});
								}
								return ParseError.UnexpectedToken;
							}
							if (string.expr.atom.tag != STR){
								err.append(string.expr.atom.pos, "Expected error to be string\n", .{});
								return ParseError.UnexpectedToken;
							}
							err.append(string.expr.atom.pos, "{s}\n", .{string.expr.atom.text});
							return ParseError.UnexpectedToken;
						},
						else => {}
					}
					var i: u64 = 0;
					while (i < expr.expr.items.len){
						const save = scope.items.len;
						const eval = try interpret(ast, scope, expr.expr.items[i], err, null, universe, universe_defs, null);
						expr.expr.items[i] = eval.expr;
						scope.items.len = save;
						i += 1;
					}
					head = expr.expr.items[0];
					if (head.* == .atom){
						if (ast.defs.getPtr(head.atom.text)) |def| {
							const ret = try argapply_defs(ast, scope, def, expr, err, universe, universe_defs, calling_token);
							if (ret == .tail){
								return ret;
							}
							return check(ast, scope, head.atom.text, ret.expr, err, universe, universe_defs, calling_token);
						}
						else if (ast.universes.getPtr(head.atom.text)) |uni| {
							return ExprTail{.expr=try list_parse_universe_def(ast, uni, expr)};
						}
					}
					else if (head.* == .expr){
						return try lambda(ast, scope, head, expr, err, universe, universe_defs);
					}
				}
				else if (head.* == .expr){
					return try lambda(ast, scope, head, expr, err, universe, universe_defs);
				}
			}
		},
		.atom => {
			if (universe) |uni| {
				if (universe_defs.?.get(expr.atom.text)) |uni_term| {
					const wrapped = ast.mem.create(Expr) catch unreachable;
					wrapped.* = uni_term.expression.?;
					return ExprTail{.expr=wrapped};
				}
				switch (expr.atom.tag){
					INT => {
						const wrapped = ast.mem.create(Expr) catch unreachable;
						wrapped.* = uni.int;
						return ExprTail{.expr=wrapped};
					},
					NAT => {
						const wrapped = ast.mem.create(Expr) catch unreachable;
						wrapped.* = uni.nat;
						return ExprTail{.expr=wrapped};
					},
					STR => {
						const wrapped = ast.mem.create(Expr) catch unreachable;
						wrapped.* = uni.str;
						return ExprTail{.expr=wrapped};
					},
					LAMBDA => {
						const wrapped = ast.mem.create(Expr) catch unreachable;
						wrapped.* = uni.lam;
						return ExprTail{.expr=wrapped};
					},
					FLOAT => {
						const wrapped = ast.mem.create(Expr) catch unreachable;
						wrapped.* = uni.float;
						return ExprTail{.expr=wrapped};
					},
					else => {}
				}
				const wrapped = ast.mem.create(Expr) catch unreachable;
				wrapped.* = uni.all;
				return ExprTail{.expr=wrapped};
			}
			for (scope.items) |let| {
				if (std.mem.eql(u8, expr.atom.text, let.name.text)){
					const save = scope.items.len;
					const new = try interpret(ast, scope, let.value, err, null, universe, universe_defs, calling_token);
					scope.items.len = save;
					return new;
				}
			}
			if (ast.defs.getPtr(expr.atom.text)) |def| {
				const ret = try argapply_defs(ast, scope, def, expr, err, universe, universe_defs, calling_token);
				return ret;
			}
			return ExprTail{.expr=expr};
		},
		.quote => {
			return ExprTail{.expr=expr};
		}
	}
	return ExprTail{.expr=expr};
}

pub fn check(ast: *AST, scope: *Buffer(Let), head: []const u8, expr: *Expr, err: *ErrorLog, universe: ?Universe, universe_defs: ?*Map(Definition), calling_token: ?*Buffer(Token)) ParseError!ExprTail {
	if (universe) |uni| {
		if (universe_defs.?.getPtr(head)) |reference| {
			var checker = ast.mem.create(Expr) catch unreachable;
			checker.* = Expr{
				.expr = Buffer(*Expr).init(ast.mem.*)
			};
			const wrapper = ast.mem.create(Expr) catch unreachable;
			wrapper.* = uni.equality;
			checker.expr.append(wrapper) catch unreachable;
			checker.expr.append(expr) catch unreachable;
			checker.expr.append(&reference.expression.?) catch unreachable;
			return try interpret(ast, scope, checker, err, null, null, null, calling_token);
		}
	}
	return ExprTail{.expr=expr};
}

pub fn lambda(ast: *AST, scope: *Buffer(Let), head: *Expr, expr: *Expr, err: *ErrorLog, universe: ?Universe, universe_defs: ?*Map(Definition)) ParseError!ExprTail {
	if (head.expr.items.len > 0){
		const islambda = head.expr.items[0];
		if (islambda.* == .atom){
			if (islambda.atom.tag == LAMBDA){
				if (expr.expr.items.len > 1){
					const save = scope.items.len;
					if (head.expr.items[1].expr.items.len > expr.expr.items.len-1){
						err.append(head.expr.items[0].atom.pos, "not enough arguments for lambda\n", .{});
						return ParseError.UnexpectedToken;
					}
					for (head.expr.items[1].expr.items, 0..) |argname, i| {
						if (argname.* != .atom){
							err.append(head.expr.items[0].atom.pos, "lambda arggs must be atoms\n", .{});
							return ParseError.UnexpectedToken;
						}
						const eval = try interpret(ast, scope, expr.expr.items[i+1], err, null, universe, universe_defs, null);
						scope.append(Let{
							.name = argname.atom,
							.value = eval.expr
						}) catch unreachable;
					}
					const new = try interpret(ast, scope, head.expr.items[2], err, null, universe, universe_defs, null);
					scope.items.len = save;
					if (expr.expr.items.len > head.expr.items[1].expr.items.len){
						const rest = ast.mem.create(Expr) catch unreachable;
						rest.* = Expr{
							.expr = Buffer(*Expr).init(ast.mem.*)
						};
						rest.expr.append(new.expr) catch unreachable;
						rest.expr.appendSlice(expr.expr.items[head.expr.items[1].expr.items.len+1..]) catch unreachable;
						return try interpret(ast, scope, rest, err, null, universe, universe_defs, null);
					}
					return new;
				}
			}
		}
	}
	return ExprTail{.expr=expr};
}

pub fn list_parse_universe_def(ast: *AST, universe: *Map(Definition), expr: *Expr) ParseError!*Expr {
	if (expr.expr.items.len != 4){
		return expr;
	}
	if (expr.expr.items[1].* != .atom){
		return expr;
	}
	if (expr.expr.items[1].atom.tag != IDEN){
		return expr;
	}
	const name = expr.expr.items[1].atom;
	const args = expr.expr.items[2];
	const expression = expr.expr.items[3];
	universe.put(name.text, Definition{
		.name = name,
		.args = args.*,
		.expression = expression.*
	}) catch unreachable;
	const empty = ast.mem.create(Expr) catch unreachable;
	empty.* = Expr{
		.expr = Buffer(*Expr).init(ast.mem.*)
	};
	return empty;
}

pub fn binop_type(comptime T: type, op: TOKEN, l: T, r: T) T {
	var v:T = 0;
	switch (op){
		LE => {
			if (l <= r){
				v = 1;
			}
			else {
				v = 0;
			}
		},
		LT => {
			if (l < r){
				v = 1;
			}
			else {
				v = 0;
			}
		},
		GE => {
			if (l >= r){
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

pub fn binop(ast: *AST, op: TOKEN, left: *Expr, right: *Expr) ParseError!*Expr {
	if (op == EQ){
		if (structural_eq(left, right)){
			const ret = ast.mem.create(Expr) catch unreachable;
			const buf = ast.mem.alloc(u8, 20) catch unreachable;
			const s = std.fmt.bufPrint(buf, "{}", .{1}) catch unreachable;
			ret.* = Expr{
				.atom = Token{
					.tag = NAT,
					.text = s,
					.value = .{
						.nat = 1
					},
					.pos = 0
				}
			};
			return ret;
		}
		const ret = ast.mem.create(Expr) catch unreachable;
		const buf = ast.mem.alloc(u8, 20) catch unreachable;
		const s = std.fmt.bufPrint(buf, "{}", .{0}) catch unreachable;
		ret.* = Expr{
			.atom = Token{
				.tag = NAT,
				.text = s,
				.value = .{
					.nat = 0
				},
				.pos = 0
			}
		};
		return ret;
	}
	else if (op == NE){
		if (!structural_eq(left, right)){
			const ret = ast.mem.create(Expr) catch unreachable;
			const buf = ast.mem.alloc(u8, 20) catch unreachable;
			const s = std.fmt.bufPrint(buf, "{}", .{1}) catch unreachable;
			ret.* = Expr{
				.atom = Token{
					.tag = NAT,
					.text = s,
					.value = .{
						.nat = 1
					},
					.pos = 0
				}
			};
			return ret;
		}
		const ret = ast.mem.create(Expr) catch unreachable;
		const buf = ast.mem.alloc(u8, 20) catch unreachable;
		const s = std.fmt.bufPrint(buf, "{}", .{0}) catch unreachable;
		ret.* = Expr{
			.atom = Token{
				.tag = NAT,
				.text = s,
				.value = .{
					.nat = 0
				},
				.pos = 0
			}
		};
		return ret;
	}
	if (left.atom.tag == FLOAT or right.atom.tag == FLOAT){
		const l: f64 = left.atom.value.?.float;
		const r: f64 = right.atom.value.?.float;
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
		const r: i64 = right.atom.value.?.int;
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
	const r: u64 = right.atom.value.?.nat;
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

const ExprTail = union(enum){
	expr: *Expr,
	tail: struct {
		expr: *Expr,
		call: Token
	}
};

pub fn argapply_defs(ast: *AST, scope: *Buffer(Let), def: *Definition, expr: *Expr, err: *ErrorLog, universe: ?Universe, universe_defs: ?*Map(Definition), calling_token: ?*Buffer(Token)) ParseError!ExprTail {
	const save = scope.items.len;
	if (def.args == .atom){
		scope.append(Let{
			.name = def.args.atom,
			.value = expr
		}) catch unreachable;
	}
	else if (def.args == .expr){
		if (expr.* == .expr){
			if (def.args.expr.items.len <= expr.expr.items.len-1){
				for (def.args.expr.items, expr.expr.items[1..]) |arg, exp| {
					if (arg.* == .atom){
						scope.append(Let{
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
			else{
				return ExprTail{.expr=expr};
			}
		}
		else if (def.args.expr.items.len > 0){
			return ExprTail{.expr = expr};
		}
	}
	else if (def.args == .quote){
		err.append(def.name.pos, "cannot quote args\n", .{});
		return ParseError.UnexpectedToken;
	}
	if (def.expression) |*expression| {
		var scope_copy = scope.*;
		var calling_copy: ?Buffer(Token) = null;
		const alloc_ptr = checkpoint_from_allocator(ast.mem);
		scope.* = deep_copy_buffer(Let, ast.mem, scope);
		if (calling_token) |calling| {
			calling_copy = calling.*;
			calling.* = deep_copy_buffer(Token, ast.mem, calling);
		}
		var ret: ?ExprTail = null;
		if (expr.* == .expr){
			if (def.args.expr.items.len < expr.expr.items.len-1){
				ret = try interpret(ast, scope, expression, err, null, universe, universe_defs, null);
				const tmp_copy = deep_copy(ast.tmp, ret.?.expr);
				restore_from_allocator(ast.mem, alloc_ptr);
				ret.?.expr = deep_copy(ast.mem, tmp_copy);
				reset_from_allocator(ast.tmp);
				scope.* = scope_copy;
				if (calling_token) |calling| {
					calling.* = calling_copy.?;
				}
			}
			else {
				if (calling_token) |calling| {
					for (calling.items) |call| {
						if (std.mem.eql(u8, def.name.text, call.text)){
							return ExprTail{
								.tail=.{
									.call = call,
									.expr = expr
								}
							};
						}
					}
					calling.append(def.name) catch unreachable;
					ret = try interpret(ast, scope, expression, err, null, universe, universe_defs, calling_token);
					while (ret.? == .tail){
						const tmp_copy = deep_copy(ast.tmp, ret.?.tail.expr);
						restore_from_allocator(ast.mem, alloc_ptr);
						ret.?.tail.expr = deep_copy(ast.mem, tmp_copy);
						reset_from_allocator(ast.tmp);
						scope.* = deep_copy_buffer(Let, ast.mem, &scope_copy);
						calling.* = deep_copy_buffer(Token, ast.mem, &calling_copy.?);
						if (std.mem.eql(u8, ret.?.tail.call.text, def.name.text)) {
							calling.append(def.name) catch unreachable;
							ret = try interpret(ast, scope, ret.?.tail.expr, err, null, universe, universe_defs, calling_token);
						}
						else{
							break;
						}
					}
					const tmp_copy = deep_copy(ast.tmp, ret.?.expr);
					restore_from_allocator(ast.mem, alloc_ptr);
					ret.?.tail.expr = deep_copy(ast.mem, tmp_copy);
					reset_from_allocator(ast.tmp);
					scope.* = scope_copy;
					calling.* = calling_copy.?;
				}
				else{
					ret = try interpret(ast, scope, expression, err, null, universe, universe_defs, null);
					const tmp_copy = deep_copy(ast.tmp, ret.?.expr);
					restore_from_allocator(ast.mem, alloc_ptr);
					ret.?.expr = deep_copy(ast.mem, tmp_copy);
					reset_from_allocator(ast.tmp);
					scope.* = scope_copy;
					if (calling_token) |calling| {
						calling.* = calling_copy.?;
					}
				}
			}
		}
		else{
			if (calling_token) |calling| {
				for (calling.items) |call| {
					if (std.mem.eql(u8, def.name.text, call.text)){
						return ExprTail{
							.tail=.{
								.call = call,
								.expr = expr
							}
						};
					}
				}
				calling.append(def.name) catch unreachable;
				ret = try interpret(ast, scope, expression, err, null, universe, universe_defs, calling_token);
				while (ret.? == .tail){
					const tmp_copy = deep_copy(ast.tmp, ret.?.tail.expr);
					restore_from_allocator(ast.mem, alloc_ptr);
					ret.?.tail.expr = deep_copy(ast.mem, tmp_copy);
					reset_from_allocator(ast.tmp);
					scope.* = deep_copy_buffer(Let, ast.mem, &scope_copy);
					calling.* = deep_copy_buffer(Token, ast.mem, &calling_copy.?);
					if (std.mem.eql(u8, ret.?.tail.call.text, def.name.text)) {
						ret = try interpret(ast, scope, ret.?.tail.expr, err, null, universe, universe_defs, calling_token);
					}
					else{
						break;
					}
				}
				const tmp_copy = deep_copy(ast.tmp, ret.?.expr);
				restore_from_allocator(ast.mem, alloc_ptr);
				ret.?.expr = deep_copy(ast.mem, tmp_copy);
				reset_from_allocator(ast.tmp);
				scope.* = scope_copy;
				calling.* = calling_copy.?;
			}
			else{
				ret = try interpret(ast, scope, expression, err, null, universe, universe_defs, null);
			}
		}
		scope.items.len = save;
		if (ret) |r| {
			if (expr.* == .expr){
				if (def.args.expr.items.len < expr.expr.items.len-1){
					const checked = r;
					const new = ast.mem.create(Expr) catch unreachable;
					new.* = Expr{
						.expr = Buffer(*Expr).init(ast.mem.*)
					};
					new.expr.append(checked.expr) catch unreachable;
					new.expr.appendSlice(expr.expr.items[def.args.expr.items.len+2..]) catch unreachable;
					return try interpret(ast, scope, new, err, null, universe, universe_defs, calling_token);
				}
			}
			return r;
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
	var ast = parse(&main_mem, &temp_mem, tokens.items, &err) catch {
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
	const main_expr = static_interpret(&ast, &err) catch {
		err.handle(contents);
		return;
	};
	if (err.log.items.len != 0){
		err.handle(contents);
		return;
	}
	main_expr.show();
}

//TODO
// records
// canvas
// input registry
// list to string

