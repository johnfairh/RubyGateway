
# Testcases for defining methods in Swift.
#
# See TestObjMethods.swift
#

class EmptyClass < Object
end

# swift:
#
# class EmptyClass
#   def double(val)
#     val * 2
#   end
# end

def test_simple
  e = EmptyClass.new
  two = e.double(1)
  raise "Wrong answer: #{two}" unless two == 2
end

module EmptyModule
end

class ClassFromEmptyModule < Object
    include EmptyModule
end

# swift:
#
# module EmptyModule
#   def answer
#     "true"
#   end
# end

def test_module
  c = ClassFromEmptyModule.new
  tr = c.answer
  raise "Wrong answer: #{tr}" unless tr == "true"
end

class IdentifiedClass < Object
  attr_accessor :uniqueId

  def initialize(newId)
    self.uniqueId = newId
  end
end

# swift:
#
# class IdentifiedClass
#   def doubleId
#     uniqueId * 2
#   end
# end

def test_self_access
  o1 = IdentifiedClass.new(13)
  o2 = IdentifiedClass.new(29)
  v1 = o1.doubleId
  raise "Wrong answer 1 #{v1}" unless v1 == 26
  v2 = o2.doubleId
  raise "Wrong answer 2 #{v2}" unless v2 == 58
end

class BaseClass < Object
end

class DerivedClass < BaseClass
end

# swift:
#
# class BaseClass
#   def getValue
#     22
#   end
# end

def test_inherited
  o1 = BaseClass.new
  o2 = DerivedClass.new
  v1 = o1.getValue
  raise "Wrong answer base #{v1}" unless v1 == 22
  v2 = o2.getValue
  raise "Wrong answer derived #{v2}" unless v2 == 22
end

class OverriddenClass < Object
  def getValue
    33
  end
end

# swift:
#
# class OverriddenClass
#   def getValue
#     22
#   end
# end

def test_overridden
  o1 = OverriddenClass.new
  v1 = o1.getValue
  raise "Wrong answer 1 #{v1}" unless v1 == 22
end

class SingSimpleClass
  def answer
    22
  end
end

# test is entirely in Swift

class SingBase < Object
end

class SingDerived < SingBase
end

# swift:
#
# class SingBase
#   def self.value2
#     10
#   end
# end

def test_ston_overridden
  v1 = SingDerived.value2
  raise "Bad value #{v1}" unless v1 == 10
end
