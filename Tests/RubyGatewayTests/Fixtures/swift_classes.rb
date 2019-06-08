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
