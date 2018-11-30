# Testcases for sticky situations caused by invoking blocks
# from Swift code.
#
# See TestMethods.swift
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
