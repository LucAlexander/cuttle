# Cuttle

A small homoiconic language for **programmable semantic overlays**.

A program in Cuttle has an ordinary runtime meaning, but it may also be evaluated inside any number of independently defined **universes**. A universe can interpret the same program as a type, cost, proof, security classification, material property, effect, resource bound, or any other semantic domain.

Universes are executable programs rather than fixed compiler plugins. Each universe has its own environment, default meanings, named summaries, and satisfaction relation.

> The concrete evaluator answers: “What does this program do?”
>
> A universe answers: “What does this program mean in this semantic world?”


## Core model

The language is built around four ideas:

1. **Code is data.** Programs are represented directly as atoms, lists, and quoted expressions.
2. **Functions are open code.** Lambda parameters are substituted hygienically, while other free names are resolved in the environment where the code eventually runs.
3. **Environments are explicit semantic contexts.** The same open program can be evaluated in the concrete environment, a named computation environment, or a universe.
4. **Universes define judgments.** A universe may assign expected meanings to named functions and check those meanings when the functions are called.

A universe judgment can be read informally as:

```text
U ⊢ expression ⇓ meaning
```

A declared expectation creates an obligation:

```text
U ⊢ implementation(name) satisfies expectation(name)
```

The engine does not privilege types. A type system is one possible universe among many.


## Syntax

Programs use prefix, Lisp like syntax.

```lisp
(function argument-1 argument-2)
```

Parentheses are strongly recommended in source examples. Some fixed arity forms can be parsed without an outer wrapper, but variable arity forms such as `prog` and `case` require grouping.

### Atoms

The tokenizer recognizes:

```lisp
42
-12
3.14
"hello"
identifier
```

Numbers are divided into three runtime categories:

- non negative integral literals are naturals;
- negative integral literals are integers;
- decimal literals are floats.

Strings currently have no documented escape syntax.

### Application

```lisp
(f x y)
```

The head expression is evaluated first. If it resolves to a lambda with enough arguments, the arguments are substituted into the lambda body.

Extra arguments are reapplied to the result:

```lisp
((lambda (x) (lambda (y) (+ x y))) 10 5)
```

is evaluated as if the first application produced a function and the remaining argument were then applied to it.

## Evaluation semantics

### Lazy function arguments

Ordinary lambda arguments are substituted into the body without first being evaluated.

```lisp
((lambda (x) 1)
  (error "this argument is unused"))
```

The unused argument does not need to be evaluated by the lambda itself.

Built in arithmetic and comparison operators evaluate their operands before performing the primitive operation.

### Hygienic substitution

Lambda parameters are renamed to fresh internal names before use. This prevents an argument from accidentally capturing a binder with the same source level spelling.

For example, nested lambdas do not confuse their parameters merely because both were written as `x`.

### Open code and late bound names

Lambdas do not automatically capture surrounding `let` or `var` bindings in closure environments.

A free name is resolved in the environment where the resulting code is executed.

```lisp
(let add-current-x
  (lambda (y)
    (+ x y)))

(prog
  (let x 10)
  (add-current-x 5))
```

Here, `x` is supplied by the environment in which `add-current-x` is called.

This is intentional. Lambdas are portable open code whose unresolved names may acquire meaning from a later host environment.

Values can still be incorporated structurally through substitution:

```lisp
(let make-adder
  (lambda (x)
    (lambda (y)
      (+ x y))))

(let add-ten (make-adder 10))

(add-ten 5)
```

Applying `make-adder` substitutes `10` into the returned lambda, producing code that no longer depends on an ambient `x`.

A continuation style `let-in` can be defined in this style rather than requiring implicit lexical closure capture.
```

(let let-in
    (lambda (x y cont)
        ((lambda (x) cont) y))A)

```

## Bindings and state

### `let`

```lisp
(let name value)
```

Creates an immutable binding in the current environment.

```lisp
(let answer 42)
answer
```

The name is placed into scope before its value is fully evaluated, allowing recursive definitions.

A visible name cannot currently be shadowed by another `let` or `var` of the same spelling.

`let` is an ambient binding. It is not automatically captured by lambdas created later.

### `var`

```lisp
(var name value)
```

Creates a mutable binding.

```lisp
(var count 0)
```

Like `let`, the name enters scope before its initializer is fully evaluated.

### `set`

```lisp
(set name value)
```

Updates an existing mutable binding.

```lisp
(prog
  (var count 0)
  (set count (+ count 1))
  count)
```

`set` fails when the target is not a visible `var`.

### `prog`

```lisp
(prog
  expression-1
  expression-2
  ...
  expression-n)
```

Evaluates expressions sequentially in fresh `let` and `var` frames and returns the final result.

```lisp
(prog
  (let x 10)
  (var y 20)
  (set y (+ x y))
  y)
```

Bindings created inside the program are removed when the program finishes, although open code executed during the program can resolve them while they remain active.

## Functions

### Fixed arity lambda

```lisp
(lambda (x y) body)
```

Example:

```lisp
(let add
  (lambda (x y)
    (+ x y)))

(add 2 3)
```

A fixed arity lambda does not reduce until enough arguments are available.

### Variadic lambda

When the parameter position is a single atom rather than a list, the lambda receives the remaining arguments as one expression list:

```lisp
(lambda args
  (head args))
```

This form is useful for writing syntax processing functions and small derived forms.

## Quotation

### Quote

```lisp
'expression
```

Quote returns an expression as data without evaluating it.

```lisp
'(+ 1 2)
```

Lambda substitution does not descend normally into quoted syntax.

### Unquote

```lisp
,expression
```

Unquote removes one quotation layer. Within quoted code, unquoted regions remain visible to lambda substitution.

This permits templates containing both literal syntax and substituted program fragments.

## Structural data

### `head`

```lisp
(head expression)
```

If the value is a non empty expression list, returns its first element.

For a non list atom, `head` returns the atom itself.

### `tail`

```lisp
(tail expression)
```

Returns a list containing every element except the first.

For an atom or empty list, it returns an empty expression.

### `cons`

```lisp
(cons head tail)
```

Constructs an expression list. Nested `cons` chains are flattened into the resulting list.

### `case`

```lisp
(case value
  (pattern-1 result-1)
  (pattern-2 result-2)
  ...)
```

Evaluates `value`, then compares it with each pattern using structural equality.

```lisp
(case 2
  (1 "one")
  (2 "two")
  (3 "three"))
```

`case` is partial. Evaluation fails when no branch matches.

Patterns are expressions rather than a separate pattern language.

## Records

### Declaration

```lisp
(record RecordName (field-1 field-2 ...))
```

Example:

```lisp
(record Point (x y))
```

A record value is a tagged positional expression:

```lisp
(Point 10 20)
```

The tag identifies the field layout.

### Field access

A record value may be applied to a field name:

```lisp
(let point (Point 10 20))

(point x)
(point y)
```

Field access may forward additional arguments to the selected field value. This allows record fields to contain callable values.

Records are currently structural runtime data; record construction does not enforce field count.

## Primitive operations

Binary operators use prefix syntax:

```lisp
(+ left right)
(- left right)
(* left right)
(/ left right)
(% left right)

(< left right)
(> left right)

(& left right)
(| left right)
(^ left right)
```

`<` and `>` return numeric `1` or `0`.

`&`, `|`, and `^` treat zero as false and non zero as true, and return `1` or `0`.

Division is exact in the current implementation. Division or modulo by zero is not handled as a recoverable language error.

Within universes, built in operators retain their concrete numeric semantics.

## Errors

```lisp
(error "message")
```

Stops evaluation and records an error at the source token.

Errors are used both for ordinary runtime failure and for universe satisfaction checks.

## Named computation environments

### `comp`

```lisp
(comp environment-name program)
```

Evaluates a program in an environment separate from the caller.

```lisp
(comp sandbox
  (prog
    (let x 10)
    (+ x 2)))
```

A named computation environment has separate:

- immutable bindings;
- mutable bindings;
- universes;
- record declarations.

Free names in open code are resolved against the selected computation environment.

Bindings created during a `comp` invocation are scoped to that invocation.

`comp` is the ordinary language counterpart of universe evaluation: both allow the same code to be rehosted in a different semantic context.

## Universes

A universe is an independently programmed semantic environment.

It defines:

1. a satisfaction procedure;
2. default meanings for primitive atom categories;
3. named expectations or semantic summaries;
4. an isolated environment used during universe evaluation.

### Declaring a universe

```lisp
(universe
  UniverseName
  satisfaction
  integer-default
  natural-default
  float-default
  string-default
  lambda-default
  all-default)
```

The fields are:

| `UniverseName` Name used to declare expectations and inspect expressions
| `satisfaction` A two argument function receiving expected and actual meanings
| `integer-default` Meaning assigned to integer atoms
| `natural-default` Meaning assigned to natural number atoms
| `float-default` Meaning assigned to float atoms
| `string-default` Meaning assigned to string atoms
| `lambda-default` Meaning assigned to lambda expressions
| `all-default` Fallback meaning for otherwise uninterpreted atoms

The satisfaction procedure is called like:

```lisp
(satisfaction expected actual)
```

It may implement structural equality, implication, subtyping, containment, a resource bound, proof checking, or any other relation. It should fail with `error` when the judgment is not satisfied.


### Declaring a universe expectation

After a universe exists, its name becomes a declaration form:

```lisp
(UniverseName function-name expected-meaning)
```

Example:

```lisp
(Kind identity Nat)
```

The declaration serves two related purposes:

- it is the expected universe result for calls to `identity`;
- it is available as a semantic summary of `identity` while interpreting other programs in the universe.

### Automatic checking

When a named concrete function is called, the interpreter checks every universe that declares an expectation for that name.

Conceptually:

```text
concrete call: f arguments

for each universe U containing an expectation for f:
    expected = U[f]
    actual   = evaluate the resolved application inside U
    evaluate U.satisfaction(expected, actual)

evaluate the application concretely
```

Only named applications with explicit universe entries are checked.

This creates an assume guarantee model:

- universe entries may be assumed as summaries at internal call sites;
- concrete function applications must satisfy their declared universe result.

Checks currently occur at function application time. An annotated function that is never called is not automatically verified by a whole program pass.

### Isolated universe environments

A universe does not implicitly inherit the concrete environment.

If a universe needs a meaning for a dependency, that meaning should be supplied in the universe itself.

Unknown atoms fall back to the universe's `all` value. A universe may use that value as top, unknown, unconstrained, or another domain specific fallback.

### Inspecting a universe result

```lisp
(inspect UniverseName expression)
```

Evaluates `expression` directly inside the selected universe and returns the inferred universe value.

```lisp
(inspect Kind 10)
```

If the natural number default of `Kind` is `Nat`, this evaluates to `Nat`.

`inspect` is useful for:

- debugging a universe;
- showing inferred meanings;
- testing semantic definitions;
- using a universe as an alternate evaluator without declaring an expectation.
