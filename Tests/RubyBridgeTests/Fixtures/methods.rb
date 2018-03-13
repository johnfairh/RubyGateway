class MethodsTest
    attr_accessor :property

    def initialize
        self.property = "Default"

        @@property = "ClassDefault"

        @doubleMethod = :double
    end

    def noArgsMethod
        # Don't return anything either
    end

    def threeArgsMethod(aString, aInt, aFloat)
        unless aString.class == String
            raise "Not a string: #{aString.class}"
        end
        unless aInt.class == Fixnum
            raise "Not a fixnum integer: #{aInt.class}"
        end
        unless aFloat.class == Float
            raise "Not a float: #{aFloat.class}"
        end
        "OK"
    end

    def self.classMethod
        true
    end

    def kwArgsMethod(aFirst, aSecond:, aThird: 1)
        aFirst + aSecond * aThird
    end

    def double(x)
        return x * 2
    end

    def yielder
        raise "No block given" unless block_given?
        yield(22, "fish")
    end
end
