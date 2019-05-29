
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

class IdentifiedClass < Object
  attr_accessor :uniqueId

  def initialize(newId)
    self.uniqueId = newId
  end
end

class BaseClass < Object
end

class DerivedClass < BaseClass
end

class OverriddenClass < Object
  def getValue
    33
  end
end

# swift:
#
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
#
# class IdentifiedClass
#   def doubleId
#     uniqueId * 2
#   end
# end
#
# class BaseClass
#   def getValue
#     22
#   end
# end
#
# class OverriddenClass
#   def getValue
#     22
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

def test_self_access
  o1 = IdentifiedClass.new(13)
  o2 = IdentifiedClass.new(29)
  v1 = o1.doubleId
  raise "Wrong answer 1 #{v1}" unless v1 == 26
  v2 = o2.doubleId
  raise "Wrong answer 2 #{v2}" unless v2 == 58
end

def test_inherited
  o1 = BaseClass.new
  o2 = DerivedClass.new
  v1 = o1.getValue
  raise "Wrong answer base #{v1}" unless v1 == 22
  v2 = o2.getValue
  raise "Wrong answer derived #{v2}" unless v2 == 22
end

def test_overridden
  o1 = OverriddenClass.new
  v1 = o1.getValue
  raise "Wrong answer 1 #{v1}" unless v1 == 22
end
