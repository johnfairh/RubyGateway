
# Testcases for defining methods in Swift.
#
# See TestObjMethods.swift
#

class EmptyClass < Object
end

module EmptyModule
end

class ClassFromEmptyModule < Object
  include EmptyModule
end

# swift:
# class EmptyClass
#   def double(val)
#     val * 2
#   end
# end
#
# module EmptyModule
#   def answer
#     "true"
#   end
# end

def test_simple
  e = EmptyClass.new
  two = e.double(1)
  raise "Wrong answer: #{two}" unless two == 2
end

def test_module
  c = ClassFromEmptyModule.new
  tr = c.answer
  raise "Wrong answer: #{tr}" unless tr == "true"
end
