# Using RubyGateway

This document contains notes on using RubyGateway.  For installation tips
see [the README](index.html).
* [How to use the framework](#general-usage)
* [How to do various Ruby tasks](#how-to)
* [Error handling approach](#error-handling)
* [Concurrency and multi-threading](#concurrency)
* [Health warning](#caveats-and-gotchas)
* [Using the libruby API](#using-the-cruby-api)
* [Garbage collection notes](#garbage-collection)

## General Usage

The Ruby VM is initialized when you first try to use it and shut down when the
process ends.  Load Ruby code using `RbGateway.load(filename:wrap:)` or
`RbGateway.require(filename:)`.  Or just run some Ruby code and get the result
using `RbGateway.eval(ruby:)`.  There already is a global instance of `RbGateway`
called `Ruby` so the code looks like:

```swift
import RubyGateway

do {
    let result = try Ruby.eval(ruby: "'a' * 4")
    print(result)
} catch {
}
```

Create objects using `RbObject.init(ofClass:args:kwArgs:)`.  Pass Swift types
or `RbObject`s to the `args` parameter.

Use `RbObjectAccess.call(_:args:kwArgs:)` to call methods on the object.  See
`RbObjectAccess` for more object operations and variations on `call` including
passing Swift code as a block.  Again pass Swift types or `RbObject`s in the
`args` parameter.

Use optional initializers to convert from `RbObject`s back to Swift types, or
implicitly/explicitly access `RbObject.description` if you just want `String`.

```swift
import RubyGateway

do {
    try Ruby.require(filename: "academy")
    let student = try RbObject(ofClass: "Academy::Student",
                               kwArgs: ["name": "Betty"])
    if let bettyGpa = try Double(student.get("gpa")) {
        processScore(gpa: bettyGpa)
    }
} catch {
}
```

Define new modules with `RbGateway.defineModule(_:under:)` and new classes with
`RbGateway.defineClass(_:parent:under:)`.  Define methods on new or existing
classes or modules with `RbObject.defineMethod(_:argsSpec:body:)` and
`RbObject.defineSingletonMethod(_:argsSpec:body:)`.

Defining a module with a static API:
```swift
let myModule = try Ruby.defineModule("Bakery")

try myModule.defineSingletonMethod("reserve_cakes", .basic(1)) { _, method in
    if let cakeCount = Int(method.args.mandatory[0]) {
        Cakes.reserve(cakeCount)
    }
    return .nilObject
}
```
...called from Ruby:
```ruby
def daily_routine
  Bakery.reserve_cakes(4)
end
```

Define new classes bound directly to Swift classes with
`RbGateway.defineClass(_:under:initializer:)` and define methods on them bound
directly to Swift methods with `RbObject.defineMethod(_:argsSpec:method:)`.
See [below](#define-new-classes-in-swift) for more on this.

```swift
let cellClass = try Ruby.defineClass("Cell", initializer: Cell.init)

try cellClass.defineMethod("initialize",
        argsSpec: RbMethodArgsSpec(mandatoryKeywords: ["width", "height"])
        method: Cell.setup)

try cellClass.defineMethod("content",
        argsSpec: RbMethodArgsSpec(requiresBlock: true),
        method: Cell.getContent)
```

...called from Ruby:
```ruby
cell = Cell.new(width: 200, height: 100)
cell.content { |c| prettyprint(c) }
```

## How to ...

A few Ruby-ish tasks.  Lots of these are more long-winded in Swift.  The idea
here though is not to let you write Ruby using Swift: use Ruby to do that!  But
rather to provide a layer that lets you bridge between Ruby and Swift code,
which will sometimes require driving the Ruby code in these ways.

### Exchange Swift types

RubyGateway provides extensions to most Swift types so you can initialize
`RbObject`s with them and vice versa, or use them directly as arguments to
`RbObjectAccess.call(...)` and friends.  Supported types are:
* `Bool`
* `String`
* Floating point - `Float` and `Double`
* Unsigned integer - `UInt`, `UInt64`, `UInt32`, `UInt16`, `UInt8`
* Signed integer - `Int`, `Int64`, `Int32`, `Int16`, `Int8`
* `Array` or `ArraySlice` with supported element type
* `Dictionary` with supported key and value types
* `Set` with supported element type
* Range types with supported bound types - `Range`, `ClosedRange`

See `RbObject.convert(to:)` as a throwing alternative to optional initializers.

### Exchange `nil` with Ruby

The static `RbObject.nilObject` represents Ruby `nil` and can be passed to Ruby
methods as a parameter or used in data structures.  As a short-hand you can use
literal Swift `nil` with APIs like `RbObjectAccess.call(_:args:kwArgs:)`.

When Ruby returns `nil` to Swift it always comes through as an `RbObject`.  You
can compare this directly to `RbObject.nilObject` or use `RbObject.isNil` to
test it.

If you want to include Ruby `nil` in a heterogenous array use this kind of
syntax:
```swift
let arr: RbObject = [1, 2.0, "three", .nilObject]
```

### Deal with Ruby arrays

There are a few approaches to make use of Ruby arrays depending on your goal.
1. Convert the whole array to Swift using an initializer.  This eagerly converts
   all the elements to Swift too and gives you an independent Swift array.
2. Use Ruby Array methods via `RbObjectAccess.call(...)`.  Doing more work in
   the Ruby domain can reduce the number of elements that need to be converted
   to Swift types.
3. Use Swift collection methods via `RbObject.collection`.  This gives access
   to the Swift collection APIs.  It's more efficient that approach #1 if you
   can avoid converting all the array elements and looks prettier if you are
   aiming to mutate the array because the mutations happen in-place.

### Pass a symbol as an argument

Use `RbSymbol`.  Ruby:
```ruby
res = obj.meth(:value)
```
RubyGateway:
```swift
let res = try obj.call("meth", args: [RbSymbol("value")])
```

### Pass a method as a block

Use `RbProc` and `RbSymbol`.  Ruby:
```ruby
res = arr.each(&:downcase)
```
RubyGateway:
```swift
let res = try arr.call("each", block: RbProc(object: RbSymbol("downcase")))
```

### Pass Swift code as a block

Use an `RbObjectAccess.call(...)` variant with a `blockCall` trailing-closure
argument.  Ruby:
```ruby
obj.meth { |x| puts(x) }
```
RubyGateway:
```swift
try obj.call("meth") { args in
    print(args[0])
    return .nilObject
}
```
If the method causes the Ruby object to capture the block as a proc then you
have to tell RubyGateway:
```swift
try obj.call("meth", blockRetention: .self) { args in
    print(args[0])
    return .nilObject
}
```

### Use 'break' in a Swift block

Throw an `RbBreak`.  Ruby:
```ruby
result = array.each do |item|
   break item if f(item)
end
```
RubyGateway:
```swift
result = try array.call("each") { args in
    if f(args[0]) {
        throw RbBreak(with: args[0])
    }
    return .nilObject
}
```

### Use 'return' in a Swift block

Can't do it - missing from the Ruby API.  Would probably have just been
confusing anyway.

### Create a Proc with Swift code

Use `RbObject.init(blockCall:)`.  Ruby:
```ruby
myProc = proc { |a, b| a + b }
```
RubyGateway:
```swift
myProc = RbObject() { args in
    return args[0] + args[1]
}
```
You must not let the `RbObject` expire while Ruby is holding on to the proc
object or the program will crash.  For example if you pass `myProc` to a
method of a Ruby object that captures the proc for later use, then you must
not let that Swift value go out of scope until the Ruby object has died or
otherwise guarantees never to invoke the proc.

You can't write a Proc that accepts arguments more sophisticated than purely
positional: this is your author's fault and may be addressed in future.

### Create a lambda with Swift code

You can't: there's not much value and the API doesn't provide the argument
policing.

Previous versions of this document suggested this workaround:
```swift
let myLambda = try Ruby.call("lambda", blockRetention: .returned) { args in
                   print("I got \(args.count) args!")
                   return .nilObject
               }
```

...but this was wrong-headed, never returned an actual lambda, and does not
work at all from Ruby 3.3.  See [Ruby #19777](https://bugs.ruby-lang.org/issues/19777).

### Access class variables

Use `RbObjectAccess.getClassVar(_:)` **on the class**: RubyGateway goes like the
Ruby API not Ruby as written.  Ruby:
```ruby
class MyClass
  @@count = 0
  def initialize
    @@count += 1
  end
end
```
RubyGateway:
```swift
let myClass = try Ruby.getClass("MyClass")
let count = try myClass.getClassVar("@@count")
```

### Implement Ruby global variables in Swift

See `RbGateway.defineGlobalVar(_:get:set:)`.  For example:
```swift
var currentEpoch: Int

Ruby.defineGlobalVar("$epoch",
                     get: { currentEpoch },
                     set: { notifyNewEpoch($0)})
```

### Define and implement methods in Swift

Global functions are defined using
`RbGateway.defineGlobalFunction(_:argsSpec:body:)`; methods are defined
using `RbObject.defineMethod(_:argsSpec:body:)`; and singleton methods are
defined using `RbObject.defineSingletonMethod(_:argsSpec:body:)`.  These
all follow the same pattern.

The `RbMethodArgsSpec` is how you set the signature for the function: how many
arguments of what kinds, which ones have default values, which have keywords,
and so on.  For example, this defines a function to Ruby called `log` that
requires one argument and passes its string representation onwards;
```swift
let logArgsSpec = RbMethodArgsSpec(leadingMandatoryCount: 1)
try Ruby.defineGlobalFunction("log",
                              argsSpec: logArgsSpec) { _, method in
    Logger.log(message: String(method.args.mandatory[0]))
    return .nilObject
}
```
Call from Ruby:
```ruby
log(object_to_log)
```

A more complicated version taking keyword parameters including an optional
priority:
```swift
let log2ArgsSpec = RbMethodArgsSpec(mandatoryKeywords: ["message"],
                                    optionalKeywordValues: ["priority" : 0 ])
try Ruby.defineGlobalFunction("log2",
                              argsSpec: log2ArgsSpec) { _, method in
    Logger.log(message: String(method.args.keyword["message"]!),
               priority: Int(method.args.keyword["priority"]!))
    return .nilObject
}
```
RubyGateway validates arguments and fills defaults before invoking the Swift
callback so guarantees all keywords have values.

Call from Ruby:
```ruby
log2(message: object_to_log)
log2(message: object_to_log, priority: 2)
```

### Use blocks from Swift methods

The `RbMethod` passed to your method callback provides access to the method's
block.  The best way to invoke it is with an unguarded `try`, and let any
thrown errors propagate back to Swift.  This ensures that the control flow will
work properly should Ruby do `return` or `next` inside the block.

For example:
```swift
let log3ArgsSpec = RbMethodArgsSpec(requiresBlock: true)
try Ruby.defineGlobalFunction("log3",
                              argsSpec: log3ArgsSpec) { _, method in
    let logContent = try method.yieldBlock()
    Logger.log(message: logContent)
    return .nilObject
}
```

If you need to handle exceptions from the `yield`, perhaps to do your own
cleanup or take some kind of special action, then pay attention to whether the
error is `RbError.rubyJump(_:)` or `RbError.rubyException(_:)`: for the former,
you can do your own cleanup but must rethrow the error and must not call into
Ruby as part of the cleanup.

### Define new modules in Swift

Use `RbGateway.defineModule(_:under:)` to define a new module.

For example:
```swift
let outerModule = try Ruby.defineModule("MySystem")
let innerModule = try Ruby.defineModule("SubsystemA", under: outerModule)

try innerModule.defineSingletonMethod("activate") { ... }
```
...is equivalent to, in Ruby:
```ruby
module MySystem
  module SubsystemA
    def self.activate
      ...
    end
  end
end
```

### Define new classes in Swift

There are two different ways of doing this.  The first way is with
`RbGateway.defineClass(_:parent:under:)` which works just like the module
example above, except it also supports `RbObject.defineMethod(_:argsSpec:body:)`
to define methods.

The other way is to bind a Swift class to the Ruby class.  A new instance
of the Swift class is associated with each instance of the Ruby class, and
Ruby methods are implemented by methods of the bound Swift class.

These classes are created with `RbGateway.defineClass(_:under:initializer:)`
and have methods defined with `RbObject.defineMethod(_:argsSpec:method:)`.

RubyGateway holds a strong reference to the object returned by the `initializer`
parameter throughout the life of the Ruby object, releasing it only when the
Ruby object is garbage-collected.

For example:
```swift
// Must be a class, cannot be a struct.
class Invader {
    private var name = ""

    // Called during Ruby object allocation
    init() {
    }

    // Explicitly bound `initialize` called during Ruby `new`.
    func initialize(rbMethod: RbMethod) throws {
        name = try rbMethod.args.mandatory[0].convert()
    }

    // Bound methods can return any type conforming to `RbObjectConvertible`
    func name(rbMethod: RbMethod) throws -> String {
        return name
    }

    // Bound methods can return `RbObject` to return various
    // Ruby types.  They also support blocks and any other variations
    // of Ruby argument passing.
    func listStats(rbMethod: RbMethod) throws -> RbObject {
        if rbMethod.isBlockGiven {
            try rbMethod.yieldBlock(args: ["Health", 100])
            try rbMethod.yieldBlock(args: ["Shield", 25])
            return .nilObject
        } else {
            return ["Health", 100, "Shield", 25]
        }
    }

    // Bound methods can be 'Void' in Swift; RubyGateway inserts
    // the equivalent of 'return self' to Ruby.
    func fire(rbMethod: RbMethod) throws {
        ...
    }
}

let invaderClass = try Ruby.defineClass("Invader", initializer: Invader.init)
try invaderClass.defineMethod("initialize",
                              argsSpec: .basic(1),
                              method: Invader.initialize)
try invaderClass.defineMethod("name", method: Invader.name)
try invaderClass.defineMethod("list_stats", method: Invader.listStats)
try invaderClass.defineMethod("fire, method: Invader.fire)
```
Use from Ruby:
```ruby
invader = Invader.new("Miles")
invader.list_stats do |name, score| in
  ...
end
invader.fire
```

### Run finalizers before process exit

If you want to stop using Ruby and get on with something else, and
never come back to Ruby in the process, use `RbGateway.cleanup()`.

### Work with Ruby complex numbers

See `RbComplex` for a thin wrapper to Ruby's `Complex` type.

### Work with Ruby rational numbers

See `RbRational` for a thin wrapper to Ruby's `Rational` type.

## Error Handling

RubyGateway is very explicit about failure points.  Any Ruby method call can
raise an exception instead of terminating normally and this is reflected in the
throwable nature of most of the interesting RubyGateway methods.

Normally when writing Ruby scripts one doesn't care about this and just lets
the program crash, which happens very rarely after the debugging phase.  If you
are using RubyGateway though, there is presumably a lot more happening for you
and your users than the Ruby stuff -- otherwise you'd be writing Ruby, not
Swift.  I feel it does not make sense for a subsystem like this to decide how to
handle errors, so RubyGateway propagates all errors ([except when it doesn't]
(#caveats-and-gotchas)).

And `try!` is always available for quick don't-care-about-errors environments.

### Errors + Exceptions

All errors thrown are `RbError` which is an enum of various interface errors
detected by RubyGateway and one case `RbError.rubyException(_:)` that covers all
Ruby exceptions.

RubyGateway remembers the last few `RbError`s that were generated and stores
them in the publicly available `RbError.history`.

### `nil` failures

Converting Ruby values to Swift types works differently: it happens using
failable initializers such as `String.init(_:)`.  These can fail for a variety
of reasons.  When they do, RubyGateway still internally generates an `RbError`
and stores a copy in `RbError.history` even though it is not thrown.  This
means you can diagnose why a conversion failed:

```swift
guard let score = Float(scoreObj) else {
    print("Failed to get score back from Ruby: \(RbError.history.mostRecent)")
    return
}
```

### Failable Adapter

`RbFailableAccess` is a non-throwing adapter for `RbObject` and `RbGateway` that
returns `nil` when there is an error.  All it does is `try?` the
corresponding throwing method, meaning that the details of the failure are
available in `RbError.history`.

This is a steal of rough approach (the name is my fault) from the Python DML
sandbox with an eye to adding direct member lookup/callable to RubyGateway --
Swift subscripts can't throw.

I'm not sure this is better than just writing `try?` which at least makes it
very difficult for readers to ignore the possibility of errors.

## Concurrency

RubyGateway inherits Ruby's threading model.  This means you can only use
RubyGateway APIs on the first thread from which you use a RubyGateway API, and
then any other threads created by Ruby.

Outside of the very first time, it's not possible to call Ruby on a random
thread created either directly by your program or by the Swift concurrency /
Dispatch runtime.

The simplest pattern is to call some Ruby method during system startup on
the Swift `MainActor` and then treat Ruby calls as requiring isolation to
that actor.

Depending on the Ruby you're using, this may end up blocking your UI and so on.
To avoid this, create a dedicated thread for Ruby and be sure to call Ruby only
on that thread.  The easiest way to do this with Swift concurrency is to associate
an executor with a thread and then your Ruby-calling actors with that executor.
There's a sample of this pattern in the `Sources/RubyThreadSample` target.

If you take calls _from_ Ruby on Ruby-created threads, and servicing these requires
access to your Swift concurrency executors, then you have to start a `Task` to do
this, blocking & then resuming the (Ruby) thread while that work happens.  You have
to be really careful with the GVL here to avoid deadlocks or worse.

`RbThread` provides some static helpers for creating further Ruby threads and
relinquishing the GVL: consult the internet for further guidance.

## Caveats and Gotchas

### Crashiness

Certain `RbObject` methods forward to Ruby calls and crash (`fatalError()`)
if Ruby fails / the object doesn't support the method.  It's up to you to be
sure the Ruby objects you're dealing with are of the right type.  See
`RbObject` for more information on which these methods are.

### Swift closure retention

If you pass a Swift closure to a method as a block/proc/lambda that is used
by Ruby after that method finishes -- ie. *not* the normal `#each`-type use --
then you need to understand `RbBlockRetention`.

The reason for all this is that calling Swift code from Ruby requires an
intermediate Swift object, and RubyGateway needs to tie the lifetime of that
Swift object to something else in the Swift world.

### Block arity

The Ruby runtime cannot tell the arity (number of expected arguments) of
blocks created by the Ruby C API / RubyGateway -- `Proc#arity` always comes
out as -1.  This means that any Ruby code that tries to be clever by inspecting
the arity of its block will not work as expected.

Ruby's `Hash#each` suffers from this: instead of getting the key and value
passed separately you get one parameter, a two-element array of key and value.

### Ruby code safety

RubyGateway puts no restriction on what Ruby code can do: it can access the
filesystem, exit the process, and has complete access to the process's memory.

Ruby has historically had a `$SAFE` feature that did some amount of sandboxing.
This was gradually deprecated over the years and removed entirely in Ruby 3.0.

Dealing with actively hostile Ruby code is best done with a separate process
or container; several examples on github.

## Using the CRuby API

The [CRuby](https://github.com/johnfairh/CRuby) package provides access to as
much of the `libruby` API as makes it through the importer.  You can use this
in conjunction with RubyGateway to access more of the API than RubyGateway itself
provides.

Each `RbObject` wraps one `VALUE` keeping it safe from garbage collection.  You
can access that `VALUE` using `RbObject.withRubyValue(call:)`.

RubyGateway caches intern'ed Ruby strings - you can access the cache using
`RbGateway.getID(for:)`.

Note that when you call the Ruby API and Ruby raises an exception, the process
immediately crashes unless you are running inside `rb_protect()` or equivalent.

## Swift Concurrency

Sendable annotations and checking are thought to be complete.

That said it's probably possible to defeat these checks with enough effort
because of the way Swift types are lost and reapplied either side of the C
layer.

### Garbage collection

The main risk using the `libruby` API is that GC happens too early on objects
you are trying to work with.

Ruby uses a mark and sweep GC.  This means the GC must be able to find the root
objects while they are live.  Two relevant techniques for this are:
1. A list of known root objects;
2. Stack snooping.

`RbObject` holds one `VALUE` and stores it on the known list while the Swift
object is alive.  So if you solely use `RbObject`s then everything should be
fine. The only risk is that the Swift object dies before you expect it to;
the standard library includes `withExtendedLifetime(_:_:)` to help reason about
this.

Ruby GC scans the stack of each Ruby thread searching for `VALUE`s.  In very
old Ruby, the position of the stack was found from the address of a local
variable in an init function.  In modern Ruby, at least on Darwin & Linux,
various pthread APIs are used instead which means there are no unwritten
rules about where the init function is called.

See `TestRbObject.testStackGc()` for a demo of this working in Swift.

This relies on the compiler actually placing `VALUE`s on the stack, which it is
not obliged to do.  In C the `RB_GC_GUARD()` macro forces its hand -- a similar
thing should work in Swift but I haven't managed to find a situation where the
Swift compiler does *not* put it on the stack so can't test it.

### References

* [Ruby C API Guide](http://silverhammermba.github.io/emberb/) - great guide to
  the API.
* [Ruby Hacking Guide](http://ruby-hacking-guide.github.io) - in-depth on how
  Ruby (an old version of) works.
* [Incremental GC in Ruby](https://blog.heroku.com/incremental-gc) - very
  interesting overview of GC pre + @ 2.2.
