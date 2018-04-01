# class without to_*
class Nonconvert < BasicObject
end

# class without to_str
class JustToS
    def to_s
        "to_s"
    end
end

# class with to_str and to_s
class BothToSAndToStr
    def to_s
        "to_s"
    end

    def to_str
        "to_str"
    end
end

# class with trap to_a
class NotArrayable
    def to_a
        1
    end
end
