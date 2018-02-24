class Uninspectable < BasicObject
end

class Inspectable
    attr_reader :attr1
    attr_accessor :attr2

    def initialize
        @attr1 = 23
        self.attr2 = ["one", "dozen", 3.4]
    end
end
