Hello,

This repository is a the kernel for an abstract interpreter. Every term in this little language may be given different interpretations in different algebra universes all within userspace. This may be used to define type systems, or other constrictions of the program space. Its primary purpose is as the internals of an interactive note tool for language, constraint, and provability research.
Based on the revised uploaded interpreter source, I’ve written this as language documentation rather than an implementation audit. 

# Language Documentation

## Overview

The language is a small expression oriented language with prefix syntax, global declarations, local mutable bindings, macros, records, lambdas, and semantic universes.

Programs are written as sequences of top level forms. Evaluation begins at a definition named `main`.

The language is mostly S expression based:

```text
(f x y)
(+ 1 2)
(if cond yes no)
```

Many fixed arity forms may also be written without wrapping parentheses when the parser can determine their arity:

```text
+ 1 2
if cond yes no
f x y
```

Parentheses are still the clearest and safest style for nested expressions.

## Lexical Structure

Whitespace separates tokens. Spaces, newlines, tabs, and carriage returns are ignored except as separators.

String literals are written with double quotes:

```text
"hello"
"some text"
```

The following single character tokens are recognized specially:

```text
_ ' , + - * / % & | ^ < > ( )
```

The language reserves the following words:

```text
define
macro
universe
head
tail
prog
if
let
set
lambda
error
record
```

The comparison operators are:

```text
< <= > >= == !=
```

Identifiers may contain alphanumeric characters and many symbol characters, including:

```text
! # $ % ^ ` * + - / ? : ; . ~ < > { } [ ] = ,
```

However, standalone operator characters such as `+`, `-`, `*`, and `/` are tokenized as operators.

## Primitive Values

The language has the following primitive atom categories:

```text
integer
natural number
float
string
identifier
```

Examples:

```text
-12
0
42
3.14
"hello"
foo
```

Numbers are parsed into integer, natural, or floating point atoms. Strings remain string atoms, including their surrounding quote text.

## Expressions

The AST has three expression categories:

```text
atom
list
quote
```

An atom is a single token:

```text
x
42
"hello"
```

A list is a parenthesized sequence of expressions:

```text
(a b c)
(+ 1 2)
(f x y)
```

A quoted expression is written with `'`:

```text
'x
'(a b c)
```

Quoted expressions are treated as data and are not evaluated normally.

Unquote is written with `,`:

```text
,x
,(+ 1 2)
```

Unquote evaluates the expression that follows it.

## Top Level Program Structure

A file is a sequence of top level declarations.

Accepted top level forms are:

```text
let
define
macro
universe
record
<universe-name>
```

A minimal program defines `main`:

```text
define main () 42
```

The interpreter evaluates the definition named `main` as the entry point.

## Global Bindings

A global binding is declared with `let`:

```text
let name expr
```

Example:

```text
let answer 42

define main () answer
```

Global lets bind names to expressions. These names can be referenced later during evaluation.

## Definitions

Functions are declared with `define`:

```text
define name args body
```

Example:

```text
define id (x) x

define main () (id 10)
```

The argument list is usually a parenthesized list of names:

```text
define add (x y) (+ x y)
```

A zero argument definition uses an empty argument list:

```text
define main () 123
```

A definition may also use a single atom as its argument structure. In that case, the call expression is bound as a whole.

Definitions are applied by writing the function name followed by its arguments:

```text
(add 1 2)
```

or, in fixed arity contexts:

```text
add 1 2
```

If more arguments are supplied than a function consumes, the result of the first application is applied to the remaining arguments. This supports higher order and curried programming styles.

## Sequential Evaluation with `prog`

`prog` evaluates expressions in order and returns the final expression’s value.

```text
(prog
  expr1
  expr2
  expr3)
```

Example:

```text
define main ()
  (prog
    let x 10
    set x 20
    x)
```

`prog` is the main form for sequencing side effecting expressions such as `let`, `set`, `define`, `macro`, and `universe`.

## Conditionals

Conditionals use `if`:

```text
if condition consequent alternative
```

or:

```text
(if condition consequent alternative)
```

The condition is evaluated first.

Numeric zero is false:

```text
0
0.0
```

Any other value is treated as true.

Example:

```text
define main ()
  (if (< 1 2)
      "yes"
      "no")
```

## Local Bindings

A local binding is introduced with `let`:

```text
let name value
```

Example:

```text
define main ()
  (prog
    let x 1
    x)
```

Local bindings are scoped dynamically during the evaluation of the current expression. They are most useful inside `prog`.

## Assignment

Existing bindings are updated with `set`:

```text
set name value
```

Example:

```text
define main ()
  (prog
    let x 1
    set x (+ x 1)
    x)
```

`set` updates a local binding when one is available. It can also update a global binding.

## Lambdas

Anonymous functions are written with `lambda`:

```text
lambda (arg1 arg2 ...) body
```

A lambda evaluates to itself until applied.

Example:

```text
define main ()
  ((lambda (x) x) 10)
```

Multiple arguments are supported:

```text
define main ()
  ((lambda (x y) (+ x y)) 2 3)
```

Lambdas can return lambdas:

```text
define main ()
  (((lambda (x)
      (lambda (y)
        (+ x y)))
    2)
   3)
```

## Arithmetic and Logical Operators

Binary operators are prefix forms:

```text
(+ left right)
(- left right)
(* left right)
(/ left right)
(% left right)
(& left right)
(| left right)
(^ left right)
```

They may also be written without parentheses in fixed arity positions:

```text
+ 1 2
* 3 4
```

Arithmetic operators:

```text
+   addition
-   subtraction
*   multiplication
/   exact division
%   modulo
```

Logical numeric operators:

```text
&   returns 1 when both operands are nonzero, else 0
|   returns 1 when either operand is nonzero, else 0
^   returns 1 when exactly one operand is nonzero, else 0
```

The result type is selected from the operand types. Floating point operands produce floating point results; integer operands produce integer results; otherwise natural number arithmetic is used.

## Comparisons

Comparison operators are binary prefix forms:

```text
(< left right)
(<= left right)
(> left right)
(>= left right)
```

They return `1` for true and `0` for false.

Examples:

```text
(< 1 2)
(>= 10 10)
```

## Structural Equality

Equality and inequality compare expressions structurally:

```text
(== left right)
(!= left right)
```

Examples:

```text
(== 1 1)
(!= '(a b) '(a c))
(== '(x y) '(x y))
```

Structural equality compares atoms by token text, lists by length and recursive element equality, and quoted expressions by their quoted contents.

## Quotation

Quote turns an expression into data:

```text
'x
'(a b c)
```

A quoted expression is returned directly by the evaluator.

This is useful for symbolic programming:

```text
define main () '(hello world)
```

Unquote evaluates the expression after the comma:

```text
,(+ 1 2)
```

## Records

Records declare named tuple layouts.

Declaration:

```text
record Name fields
```

Fields may be a single atom:

```text
record Box value
```

or a parenthesized list:

```text
record Pair (left right)
record Vec2 (x y)
```

A record value is represented as a list whose first element is the record name:

```text
(Pair 10 20)
(Vec2 3 4)
```

Fields are accessed by applying the record value to a field name:

```text
((Pair 10 20) left)
((Pair 10 20) right)
```

Example:

```text
record Pair (left right)

define main ()
  ((Pair 10 20) left)
```

Field access may be followed by additional application. If the selected field is callable, the remaining arguments are applied to it.

## Macros

Macros are declared with `macro`:

```text
macro name env args body
```

Example shape:

```text
macro when _ (cond body)
  (if cond body '())
```

A macro receives unevaluated expression structure, builds an argument map, substitutes arguments into its body, and then walks/evaluates the expanded body.

The `env` field names the macro environment. `_` may be used when no named environment is required.

Macro arguments may be a flat or structured expression pattern:

```text
macro first _ (x y) x
macro pair-left _ ((x y)) x
```

Macro substitution replaces occurrences of argument names inside the macro body with the matched input expressions.

Example:

```text
macro unless _ (cond body)
  (if cond '() body)

define main ()
  (unless 0 "runs")
```

## Runtime Declarations

Declarations can also appear inside evaluated code when written as expressions.

Runtime definition:

```text
(define name args body)
```

Runtime macro declaration:

```text
(macro name env args body)
```

Runtime universe declaration:

```text
(universe name equality int nat float str lam all)
```

These forms are useful inside `prog` for constructing or extending the current environment during evaluation.

## Error Form

The `error` form evaluates its argument and reports it as an error message.

```text
error "message"
```

Example:

```text
define main ()
  (error "bad state")
```

The argument should evaluate to a string.

## Semantic Universes

A universe is a named semantic overlay. It gives alternate meanings to expressions when the program is interpreted inside that universe.

A universe declaration has this shape:

```text
universe Name equality int nat float str lam all
```

The fields mean:

```text
equality   expression used to compare universe-level meanings
int        meaning assigned to integer atoms
nat        meaning assigned to natural-number atoms
float      meaning assigned to float atoms
str        meaning assigned to string atoms
lam        meaning assigned to lambda atoms
all        fallback meaning for other atoms
```

Example shape:

```text
universe Type eq Int Nat Float Str Function Unknown
```

Universe specific definitions are written by using the universe name as a top level form:

```text
Type add (x y) Nat
Type id  (x)   Unknown
```

A universe definition has this shape:

```text
UniverseName term args meaning
```

During universe interpretation, atoms are mapped through the universe:

```text
integer atom        -> universe int meaning
natural atom        -> universe nat meaning
float atom          -> universe float meaning
string atom         -> universe str meaning
lambda atom         -> universe lambda meaning
known universe term -> that term's universe-specific meaning
other atom          -> universe fallback meaning
```

When a defined term is interpreted inside a universe, the interpreter can compare the computed universe meaning against the universe specific declaration using the universe’s equality expression.

This allows the same source expression to be interpreted simultaneously as:

```text
runtime value
type meaning
cost meaning
proof meaning
constraint meaning
```

depending on the universes declared by the program.

## Evaluation Order

Program execution has two phases.

First, all definitions other than `main` are walked. This expands macros and prepares definition bodies.

Then the `main` definition is evaluated.

When `main` runs, expressions are interpreted in each declared universe and then interpreted normally.

The final result is printed using the expression printer.

## Function Application

Function application evaluates arguments by binding them to the function’s declared parameter names.

Example:

```text
define add (x y) (+ x y)

define main ()
  (add 2 3)
```

If a function has no required arguments, it can be used as a value producing term:

```text
define five () 5

define main () five
```

If a function receives fewer arguments than required, the expression remains available for later completion. If it receives more arguments than required, the result is applied to the remaining arguments.

## Recursion and Tail Calls

The evaluator tracks active calls and represents recursive tail position work explicitly. When a recursive call returns to the same function, the evaluator can continue interpretation using the carried expression.

This permits recursive definitions to be written directly:

```text
define loop (x)
  (loop x)
```

For useful terminating recursion, combine conditionals and arithmetic:

```text
define count-down (n)
  (if (== n 0)
      0
      (count-down (- n 1)))

define main ()
  (count-down 10)
```

## Lists and Expression Data

Parenthesized expressions serve both as calls and as symbolic list data, depending on context.

Quoted lists are data:

```text
'(a b c)
```

Unquoted lists are evaluated as expressions:

```text
(a b c)
```

The first element of an evaluated list is treated as the head position. If it resolves to a function, lambda, record constructor, record value, universe name, or special form, the corresponding semantics are applied.

## Style Guide

Prefer parenthesized calls for clarity:

```text
(add 1 2)
(if cond yes no)
```

Use `prog` for sequential code:

```text
(prog
  let x 1
  set x (+ x 1)
  x)
```

Use quoted forms for symbolic data:

```text
'(claim implies conclusion)
```

Use records for named product data:

```text
record Claim (premise conclusion)
((Claim A B) conclusion)
```

Use universes when a program should carry more than one interpretation:

```text
universe Type eq Int Nat Float Str Function Unknown

Type add (x y) Nat

define add (x y) (+ x y)

define main () (add 1 2)
```

## Minimal Examples

### Constant program

```text
define main () 42
```

### Arithmetic

```text
define main ()
  (+ 20 22)
```

### Function

```text
define square (x)
  (* x x)

define main ()
  (square 12)
```

### Local state

```text
define main ()
  (prog
    let x 10
    set x (+ x 5)
    x)
```

### Lambda

```text
define main ()
  ((lambda (x) (+ x 1)) 41)
```

### Record

```text
record Vec2 (x y)

define main ()
  ((Vec2 3 4) x)
```

### Quoted symbolic data

```text
define main ()
  '(proof goal theorem)
```

### Conditional

```text
define main ()
  (if (> 10 5)
      "larger"
      "smaller")
```

### Macro

```text
macro when _ (cond body)
  (if cond body '())

define main ()
  (when 1 "ran")
```

### Universe sketch

```text
universe Type eq Int Nat Float Str Function Unknown

Type add (x y) Nat

define add (x y)
  (+ x y)

define main ()
  (add 1 2)
```

