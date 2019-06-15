# See TestClassDef.swift

class MyParentClass
    def value
        22
    end

    def other_value
        44
    end
end

# Swift:
# module MyOuterModule
#   module MyInnerModule
#     class MyClass < MyParentClass
#       def value
#         100
#       end
#     end
#   end
# end

def test_swiftclass
  inst = MyOuterModule::MyInnerModule::MyClass.new
  val = inst.value
  raise "Bad val #{val}" unless val == 100

  valo = inst.other_value
  raise "Bad other_val #{valo}" unless valo == 44
end

module InjectableModule
    def value1
        22
    end

    def value2
        29
    end
end

class InjecteeClass1
    def value1
        50
    end
end

class InjecteeClass2
    def value1
        30
    end
end

# Swift:
# class InjecteeClass1
#     include InjectableModule
# end
#
# class InjecteeClass2
#     prepend InjectableModule
# end

def test_inject1
    o1 = InjecteeClass1.new
    v1 = o1.value1
    raise "Bad v1 #{v1}" unless v1 == 50
    v2 = o1.value2
    raise "Bad v2 #{v2}" unless v2 == 29

    o2 = InjecteeClass2.new
    v3 = o2.value1
    raise "Bad v3 #{v3}" unless v3 == 22
    v4 = o2.value2
    raise "Bad v4 #{v4}" unless v4 == 29
end

# Swift:
# class InjecteeClass1
#     extend InjectableModule
# end

def test_inject2
    v1 = InjecteeClass1.value1
    raise "Bad 2.v1 #{v1}" unless v1 == 22
end

# Swift:
# class PeerMethods
#   def fingerprint
#    "FINGERPRINT"
#   end
# end

def test_bound1
  i1 = PeerMethods.new
  v1 = i1.fingerprint
  raise "Bad fingerprint" unless v1 == "FINGERPRINT"
end

# Swift:
# class Invader
#   def initialize(name)
#   end
#
#   def fire
#   end
#
#   def name
#   end
# end

def test_invader
  inv1 = Invader.new("fred")
  n = inv1.name
  raise "Bad name" unless n == "fred"
  stats = inv1.list_stats
  inv1.list_stats do |s_name, s_count|
    stats.delete_if { |s| s == s_name }
    stats.delete_if { |s| s == s_count }
  end
  raise "Bad stats? #{stats}" unless stats.empty?
  r = inv1.fire
  raise "Bad fire rc #{r}" unless r == inv1
  true
end
