# Testcases for sticky situations caused by invoking blocks
# from Swift code.
#
# Swift defines, basically:
#
# def swift_calls_block
#    yield
#    return 100
# end
#
# don't forget to test `last`

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
