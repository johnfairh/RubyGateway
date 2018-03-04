module RubyBridge
    class EndToEnd
        attr_accessor :name
        attr_reader :version

        def initialize(version, name:)
            @version = version
            @name = name
        end

        def to_s
            "#{name} (version #{version})"
        end
    end
end
