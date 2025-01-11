<!--
RubyGateway
README.md
Distributed under the MIT license, see LICENSE.
-->

# RubyGateway

[![CI](https://travis-ci.org/johnfairh/RubyGateway.svg?branch=master)](https://travis-ci.org/johnfairh/RubyGateway)
[![codecov](https://codecov.io/gh/johnfairh/RubyGateway/branch/master/graph/badge.svg)](https://codecov.io/gh/johnfairh/RubyGateway)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20linux-lightgrey.svg)
![License](https://cocoapod-badges.herokuapp.com/l/RubyGateway/badge.png)

Embed Ruby in Swift: load Gems, run Ruby scripts, invoke APIs seamlessly in
both directions.

RubyGateway is a framework built on the Ruby C API that lets Swift programs
running on macOS or Linux painlessly and safely run and interact with Ruby
programs.  It's easy to pass Swift values into Ruby and turn Ruby objects
back into Swift types.

RubyGateway lets you call any Ruby method from Swift, including passing Swift
closures as blocks.  It lets you define Ruby classes and methods that are
implemented in Swift.

See [CRuby](https://github.com/johnfairh/CRuby) if you are looking for a
low-level Ruby C API wrapper.

* [Examples](#examples)
* [Documentation](#documentation)
* [Requirements](#requirements)
* [Installation](#installation)
* [Contributions](#contributions)
* [License](#license)

## Examples

### Services

[Rouge](https://github.com/jneen/rouge) is a code highlighter.  In Ruby:
```ruby
require 'rouge'
html = Rouge.highlight("let a = 3", "swift", "html")
puts(html)
```

In Swift:
```swift
import RubyGateway

try Ruby.require(filename: "rouge")
let html = try Ruby.get("Rouge").call("highlight", args: ["let a = 3", "swift", "html"])
print(html)
```

### Calling Ruby

```swift
// Create an object.  Use keyword arguments with initializer
let student = RbObject(ofClass: "Academy::Student", kwArgs: ["name": "barney"])!

// Acess an attribute
print("Name is \(student.get("name"))")

// Fix their name by poking an ivar
try! student.setInstanceVar("@name", newValue: "Barney")

// Get a Swift version of `:reading`
let readingSubject = RbSymbol("reading")

// Call a method with mixed Swift data types
try! student.call("add_score", args: [readingSubject, 30])
try! student.call("add_score", args: [readingSubject, 35])

// Get a result as floating point
let avgScoreObj = try! student.call("mean_score_for_subject", args: [readingSubject])
let avgScore = Double(avgScoreObj)!
print("Mean score is \(avgScore)")

// Pass Swift code as a block
let scores = student.all_scores!
scores.call("each") { args in
    print("Subject: \(args[0]) Score: \(args[1])")
    return .nilObject
}

// Convert to a Swift array
let subjects = Array<String>(student.all_subjects!)
subjectsPopularityDb.submit(subjects: subjects)
```

## Calling Swift

Bound class definition:
```swift
class Cell {
    init() {
    }

    func setup(m: RbMethod) throws {
        ...
    }
    
    func getContent(m: RbMethod) throws -> String {
        ...
    }
}

let cellClass = try Ruby.defineClass("Cell", initializer: Cell.init)

try cellClass.defineMethod("initialize",
        argsSpec: RbMethodArgsSpec(mandatoryKeywords: ["width", "height"])
        method: Cell.setup)

try cellClass.defineMethod("content",
        argsSpec: RbMethodArgsSpec(requiresBlock: true),
        method: Cell.getContent)
```
Called from Ruby:
```ruby
cell = Cell.new(width: 200, height: 100)
cell.content { |c| prettyprint(c) }
```

Global variables:
```swift
// epochStore.current: Int

Ruby.defineGlobalVar("$epoch",
        get: { epochStore.current },
        set: { epochStore.current = newEpoch })
```

Global functions:
```swift
let logArgsSpec = RbMethodArgsSpec(leadingMandatoryCount: 1,
                                   optionalKeywordValues: ["priority" : 0])
try Ruby.defineGlobalFunction("log",
                              argsSpec: logArgsSpec) { _, method in
    Logger.log(message: String(method.args.mandatory[0]),
               priority: Int(method.args.keyword["priority"]!))
    return .nilObject
}
```
Calls from Ruby:
```ruby
log(object_to_log)
log(object2_to_log, priority: 2)
```

## Documentation

* [User guide](https://johnfairh.github.io/RubyGateway/guides/user-guide.html)
* [API documentation](https://johnfairh.github.io/RubyGateway)
* [Docset for Dash](https://johnfairh.github.io/RubyGateway/docsets/RubyGateway.tgz)

## Requirements

* Swift 6.0 or later, from swift.org or Xcode 16+
* macOS (tested on 14.1) or Linux (tested on Ubuntu Jammy)
* Ruby 2.6 or later including development files:
  * For macOS, these come with Xcode.
  * For Linux you may need to install a -dev package depending on how your Ruby
    is installed.
  * RubyGateway requires 'original' MRI/CRuby Ruby - no JRuby/Rubinius/etc.

## Installation

For macOS, if you are happy to use the system Ruby then you just need to include
the RubyGateway framework as a dependency.  If you are building on Linux or want
to use a different Ruby then you also need to configure CRuby.

## Linux

As of Swift 6, Apple have broken Swift PM such that you must pass "-Xcc -fmodules" to build the project.  Check the CI invocation for an example.

### Getting the framework

Carthage for macOS:
```
github "johnfairh/RubyGateway"
```

Swift package manager for macOS or Linux:
```
.package(url: "https://github.com/johnfairh/RubyGateway", from: "6.1.0")
```

### Configuring CRuby

CRuby is the glue between RubyGateway and your Ruby installation.  It is a
[separate github project](https://github.com/johnfairh/CRuby) but RubyGateway
includes it as submodule so you do not install or require it separately.

By default it points to the macOS system Ruby.  Follow the [CRuby usage
instructions](https://github.com/johnfairh/CRuby#usage) to change
this.  For example on Ubuntu 18 using `rbenv` Ruby 3:
```shell
mkdir MyProject && cd MyProject
swift package init --type executable
vi Package.swift
# add RubyGateway as a package dependency (NOT CRuby)
# add RubyGateway as a target dependency
echo "import RubyGateway; print(Ruby.versionDescription)" > Sources/MyProject/main.swift
swift package update
swift package edit CRuby
Packages/CRuby/cfg-cruby --mode rbenv --name 3.0.0
PKG_CONFIG_PATH=$(pwd)/Packages/CRuby:$PKG_CONFIG_PATH swift run -Xcc -fmodules
```

## Contributions

Welcome: open an issue / johnfairh@gmail.com / @johnfairh@mastodon.social

## License

Distributed under the MIT license.
