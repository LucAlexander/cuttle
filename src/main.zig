const std = @import("std");
const Buffer = std.ArrayList;
const Map = std.StringHashMap;

const ERROR_MAX = 128;

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
const DEFINE = 0;
const MACRO = 1;
const UNIVERSE = 2;
const CUT = 3;
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
	tag: TOKEN
};

const Error = struct {
	pos: u64,
	message: []u8
};

const ErrorLog = struct {
	mem: *const std.mem.Allocator,
	log: Buffer(Error)
	
	pub fn init(mem: *const std.mem.Allocator) ErrorLog {
		return ErrorLog{
			.mem = mem,
			.log = Buffer(Error).init(mem.*)
		};
	}

	pub fn append(self: *ErrorLog, index:u64, comptime fmt: []const u8, args: anytype) void {
		var err = Error{
			.post = index,
			.message = self.mem.alloc(u8, ERROR_MAX) catch unreachable;
		};
		const result = std.fmt.bufPrint(err.message, fmt, args) catch unreachable;
		err.message.len = result.len;
		log.append(err) catch unreachable;
	}

	pub fn handle(self: *ErrorLog) void {
		//TODO
	}
};

pub fn tokenize(mem: *const std.mem.Allocator, text: []const u8) Buffer(Token) {
	var tokens = Buffer(Token).init(mem.*);
	var i: u64 = 0;
	var tokmap = Map(TOKEN).init(mem.*);
	tokmap.put("define", DEFINE ) catch unreachable;
	tokmap.put("macro", MACRO ) catch unreachable;
	tokmap.put("universe", UNIVERSE ) catch unreachable;
	tokmap.put("cut", CUT ) catch unreachable;
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
	while (i < tokens.len){
		const c = tokens[i];
		switch(c){
			' ', '\n', '\t', '\r' => {
				i += 1;
				continue;
			},
			HOLE, QUOTE, UNQUOTE, ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, LT, GT => {
				tokens.append(Token{
					.text = text[i..i+1],
					.tag = c
				}) catch unreachable;
				i += 1;
				continue;
			}
			else => {
				const k = i;
				while ((std.ascii.isAlphanumeric(text[k]) or is_symbol(text[k])) and (k < tokens.len)){
					k += 1;
				}
				if (tokmap.get(text[i..k])) |tok| {
					tokens.append(Token{
						.text = text[i..k],
						.tag = tok
					}) catch unreachable;
					i = k;
					continue;
				}
				_ = std.fmt.parseInt(i64, text[i..k], 10) catch {
					_ = std.fmt.parseInt(u64, text[i..k], 10) catch {
						_ = std.fmt.parseFloat(f64, text[i..k], 10) catch {
							tokens.append(Token{
								.text = text[i..k],
								.tag = IDEN
							}) catch unreachable;
							i = k;
							continue;
						}
						tokens.append(Token{
							.text = text[i..k],
							.tag = FLOAT 
						}) catch unreachable;
						i = k;
						continue;
					};
					tokens.append(Token{
						.text = text[i..k],
						.tag = NAT
					}) catch unreachable;
					i = k;
					continue;
				};
				tokens.append(Token{
					.text = text[i..k],
					.tag = INT
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
	macros: Map(Definition),
	universes: Map(Map(Definition))
};

const Definition = struct {
	name: Token,
	args: Expr,
	expression: Expr
};

const Expr = union(enum){
	expr: Buffer(*Expr),
	atom: Token,
	quote: *Expr
};

const ParseError = error {
	UnexpectedToken
}

pub fn parse(mem: *const std.mem.Allocator, tokens: []Token, err: *ErrorLog) ParseError!AST {
	var ast = AST{
		.mem = mem,
		.let = Map(Expr).init(mem.*),
		.defs = Map(Definition).init(mem.*),
		.macros = Map(Definition).init(mem.*),
		.universes = Map(Map(Definition)).init(mem.*)
	};
	var i: u64 = 0;
	while (i<tokens.len){
		if (tokens[i].tag == LET){
			try parse_let(&ast, &i, tokens, err);
		}
		else if (tokens[i].tag == DEF){
			try parse_def(&ast, &i, tokens, err);
		}
		else if (tokens[i].tag == MACRO){
			try parse_macro(&ast, &i, tokens, err);
		}
		else if (tokens[i].tag == UNIVERSE){
			try parse_universe(&ast, &i, tokens, err);
		}
		else {
			if (ast.universes.getPtr(tokens[i].tag)) |universe| {
				try parse_universe_def(&ast, &i, tokens, tokens[i], universe, err);
			}
		}
		else {
			err.append(i, "Unexpected token at top level {s}\n", .{tokens[i].text});
		}
	}
	return ast;
}

pub fn parse_let(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i].tag != IDEN){
		err.append(i.*, "Expected identifier for name of universe, found {s}\n", .{tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.let.get(tokens[i].text)) |_| {
		err.append(i.*, "Duplicate global let definition {s}\n", .{tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i];
	i.* += 1;
	const expr = try parse_expr(ast, i, tokens, err);
	ast.let.put(name.text, expr) catch unreachable;
}

pub fn parse_def(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i].tag != IDEN){
		err.append(i.*, "Expected identifier for name of definition, found {s}\n", .{tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.def.get(tokens[i].text)) |_| {
		err.append(i.*, "Duplicate definition {s}\n", .{tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i];
	i.* += 1;
	const args = try parse_expr(ast, i, tokens, err);
	const expression = try parse_expr(ast, i, token, err);
	ast.defs.put(Definition{
		.name = name,
		.args = args,
		.expression = expression
	}) catch unreachable;
}

pub fn parse_macro(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i].tag != IDEN){
		err.append(i.*, "Expected identifier for name of macro, found {s}\n", .{tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.macros.get(tokens[i].text)) |_| {
		err.append(i.*, "Duplicate macro {s}\n", .{tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i];
	i.* += 1;
	const args = try parse_expr(ast, i, tokens, err);
	const expression = try parse_expr(ast, i, token, err);
	ast.macros.put(Definition{
		.name = name,
		.args = args,
		.expression = expression
	}) catch unreachable;
}

pub fn parse_universe(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i].tag != IDEN){
		err.append(i.*, "Expected identifier for name of universe, found {s}\n", .{tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	if (ast.universes.get(tokens[i].text)) |_| {
		err.append(i.*, "Duplicate universe definition {s}\n", .{tokens[i].text})
		return ParseError.UnexpectedToken;
	}
	ast.universes.put(tokens[i].text, Map(Definition).init(ast.mem.*)) catch unreachable;
	i.* += 1;
}

pub fn parse_universe_def(ast: *AST, i: *u64, tokens: []Token, name: Token, universe: *Map(Definition), err: *ErrorLog) ParseError!void {
	i.* += 1;
	if (tokens[i].tag != IDEN){
		err.append(i.*, "Expected identifier for name of {s}, found {s}\n", .{name.text, tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	if (universe.get(tokens[i].text)) |_| {
		err.append(i.*, "Duplicate {s} {s}\n", .{name.text, tokens[i].text});
		return ParseError.UnexpectedToken;
	}
	const name = tokens[i];
	i.* += 1;
	const args = try parse_expr(ast, i, tokens, err);
	const expression = try parse_expr(ast, i, token, err);
	universe.put(Definition{
		.name = name,
		.args = args,
		.expression = expression
	}) catch unreachable;
}

pub fn parse_expression(ast: *AST, i: *u64, tokens: []Token, err: *ErrorLog) ParseError!Expr {
	//TODO
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
		std.debug.print("   [infile name] [outfile name]: compile file\n", .{});
		return;
	}
	if (args.len < 3){
		std.debug.print("-h for help\n", .{});
		return;
	}
	const filename = args[1];
	const outfile = args[2];
	const contents = try get_contents(&main_mem, filename);
	const tokens = tokenize(&main_mem, contents);
	var err = ErrorLog.init(&main_mem);
	var ast = parse(&main_mem, tokens.items, &err) catch {
		err.handle();
	};
}
