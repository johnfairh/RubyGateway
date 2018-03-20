module RubyGateway
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

        def give_name
            yield self.name
        end

        def always_raise
            raise "Always raising"
        end
    end
end
