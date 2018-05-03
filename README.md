<!--
RubyGateway
README.md
Distributed under the MIT license, see LICENSE.
-->

# RubyGateway

[![CI](https://travis-ci.org/johnfairh/RubyGateway.svg?branch=master)](https://travis-ci.org/johnfairh/RubyGateway)
[![codecov](https://codecov.io/gh/johnfairh/RubyGateway/branch/master/graph/badge.svg)](https://codecov.io/gh/johnfairh/RubyGateway)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
![Pod](https://cocoapod-badges.herokuapp.com/v/RubyGateway/badge.png)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20linux-lightgrey.svg)
![License](https://cocoapod-badges.herokuapp.com/l/RubyGateway/badge.png)

Embed Ruby in Swift: load Gems, run Ruby scripts, get results.

RubyGateway is a framework built on the Ruby C API that lets Swift programs
running on macOS or Linux painlessly and safely run and interact with Ruby
programs.  It's easy to pass Swift datatypes into Ruby and turn Ruby objects
back into Swift types.

This project is [young](https://johnfairh.github.io/RubyGateway/todo.html).
Eventually plan to allow implementation of Ruby classes in Swift, enabling Ruby as
a DSL/scripting language for Swift applications.

See [CRuby](https://github.com/johnfairh/CRuby) if you are looking for a
low-level Ruby C API wrapper.

* [Examples](#examples)
* [Documentation](#documentation)
* [Requirements](#requirement)
* [Installation](#installation)
* [Contributions](#contributions)
* [License](#license)

## Examples

A couple of examples:

### Services

[Rouge](https://github.com/jneen/rouge) is a code highlighter.  In Ruby:
```ruby
require 'rouge'
html = Rouge.highlight("let a = 3", "swift", "html")
puts(html)
```

In Swift 4.1 with similar [lack of] error checking:
```swift
import RubyGateway

try! Ruby.require(filename: "rouge")
let html = try! Ruby.get("Rouge").call("highlight", args: ["let a = 3", "swift", "html"])
print(html)
```

In future Swift, maybe:
```swift
import RubyGateway

try! Ruby.require(filename: "rouge")
let html = try! Ruby.Rouge!.highlight("let a = 3", "swift", "html")
print(html)
```

### Objects

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
let scores = try! student.get("all_scores")
scores.call("each") { args in
    print("Subject: \(args[0]) Score: \(args[1])")
    return .nilObject
}

// Convert to a Swift array
let subjects = Array<String>(try! student.get("all_subjects"))
subjectsPopularityDb.submit(subjects: subjects)
```

## Documentation

* [User guide](https://johnfairh.github.io/RubyGateway/user-guide.html).
* [API documentation](https://johnfairh.github.io/RubyGateway).
* [Docset for Dash](https://johnfairh.github.io/RubyGateway/docsets/RubyGateway.tgz).

## Requirements

* Swift 4.1 or later, from swift.org or Xcode 9.3+.
* macOS (tested on 10.13.3) or Linux (tested on Ubuntu Xenial/16.04 on x86_64) with Clang 6+.
* Ruby 2.2 or later including development files:
  * For macOS, these come with Xcode.
  * For Linux you may need to install a -dev package depending on how your Ruby
    is installed.
  * RubyGateway requires 'original' MRI/CRuby Ruby - no JRuby/Rubinius/etc.

## Installation

For macOS, if you are happy to use the system Ruby then you just need to include
the RubyGateway framework as a dependency.  If you are building on Linux or want
to use a different Ruby then you also need to configure CRuby.

### Getting the framework

Carthage for macOS:
```
github "johnfairh/RubyGateway"
```

Swift package manager for macOS or Linux:
```
.package(url: "https://github.com/johnfairh/RubyGateway", from: "0.4.0")
```

CocoaPods for macOS:
```
pod 'RubyGateway'
```

### Configuring CRuby

CRuby is the glue between RubyGateway and your Ruby installation.  It is a
[separate github project](https://github.com/johnfairh/CRuby) but RubyGateway
includes it as submodule so you do not install or require it separately.

By default it points to the macOS system Ruby.  Follow the [CRuby usage
instructions](https://github.com/johnfairh/CRuby#usage) to change
this.  For example on Linux using [Brightbox Ruby](https://www.brightbox.com/docs/ruby/ubuntu/)
2.5:
```shell
sudo apt-get install ruby2.5 ruby2.5-dev pkg-config
mkdir MyProject
swift package init --type executable
vi Package.swift
# add RubyGateway as a package dependency (NOT CRuby)
# add RubyGateway as a target dependency
echo "import RubyGateway; print(Ruby.versionDescription)" > Sources/MyProject/main.swift
swift package update
swift package edit CRuby
Packages/CRuby/cfg-cruby --mode pkg-config --name ruby-2.5
PKG_CONFIG_PATH=$(pwd)/Packages/CRuby:$PKG_CONFIG_PATH swift run
```

## Contributions

Welcome: open an issue / johnfairh@gmail.com 

## License

Distributed under the MIT license.
