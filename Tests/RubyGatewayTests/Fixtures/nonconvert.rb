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

# class without to_h + to_hash
class NotHashable
end

# class without to_hash
class JustToH
    def to_h
        { 1 => 2}
    end
end

# class with both
class BothToHAndToHash
    def to_hash
        { 1 => 2 }
    end

    def to_h
        { :bad => "news" }
    end
end

# class with trap to_hash
class TrapToHash
    def to_hash
        "Not remotely a hash"
    end
end
