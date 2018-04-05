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

    def expectsNil(arg)
        raise "It's not nil: #{arg}" unless arg.nil?
    end

    def store_block(&block)
        @stored_block = block
    end

    def call_block
        @stored_block.call()
    end

    def yielder
        raise "No block given" unless block_given?
        yield(22, "fish")
    end

    def [](a, b)
        "#{a} #{b}"
    end

    def []=(a, b, new)
        @subscript_set = "#{a} #{b} = #{new}"
    end

    def get_num_array
        [1, 2, 3]
    end

    def sum_array(ary)
        sum = 0
        ary.each { |a| sum += a }
        sum
    end

    def get_sym_num_hash
        { a: 1, b: 2, c: 3}
    end

    def get_ambiguous_hash
        { 1 => "a", 1.0 => "b" }
    end

    def to_a
        [1, "two", 3.0]
    end
end
