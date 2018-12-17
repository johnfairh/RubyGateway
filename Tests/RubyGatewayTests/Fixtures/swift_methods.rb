# Testcases for passing args and things to Swift.
#
# See TestMethods.swift
#

# Sticky situations caused by invoking blocks from Swift code.
#
# Swift defines, basically:
#
# def swift_calls_block
#    yield
#    return 100
# end
#
# def swift_returns_block
#    yield
# end

def ruby_should_return_100
    swift_calls_block { 42 }
end

def ruby_should_return_42
    swift_calls_block { break 42 }
end

def ruby_should_return_200
    swift_calls_block { break 42 }
    200
end

def ruby_should_return_44
    swift_calls_block { return 44 }
    200
end

def ruby_should_return_22
    swift_returns_block { 22 }
end

def ruby_should_return_24
    swift_returns_block do
        next 24
        22
    end
end

def ruby_should_return_4
   rv = 0
   swift_calls_block {
       rv += 1
       redo if rv < 4
   }
   rv
end

# Keyword args from Ruby to Swift
#
# Swift defines:
#
# def swift_kwargs(a:, b:, c: 2, d: 3)
#   a + b + c + d
# end

def ruby_kw_should_return_9
    swift_kwargs(a: 3, b: 1)
end

def ruby_kw_should_return_20
    swift_kwargs(a: 3, b: 1, c: 13)
end

def ruby_kw_should_return_14
    swift_kwargs(a: 3, b: 1, c: 7, d: 3)
end

def ruby_kw_should_return_100
    swift_kwargs
rescue
    100
end

def ruby_kw_should_return_200
    swift_kwargs(e: 14)
rescue
    200
end

# Swift defines:
# def log(msg);
# def log2(message:, priority: 1);
def ruby_test_logging_functions
    log("Log 1")
    log2(message: "Log 2")
    log2(message: "Log 3", priority: 2)
end
