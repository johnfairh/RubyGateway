# demonstrator
module Academy
  class Student

    class SubjectScores
      attr_reader :count, :total

      def initialize(count, total)
        @count = count
        @total = total
      end

      def add(score)
        @count += 1
        @total += score
      end

      def mean
        Float(total)/Float(count)
      end

      def to_s
        "#{count} scores, mean #{mean}"
      end
    end

    attr_reader :name, :scores

    def add_score(subject, score)
      current = scores[subject]
      if current
        current.add(score)
      else
        scores[subject] = SubjectScores.new(1, score)
      end
    end

    def score_for_subject(subject)
      scores[subject] or nil
    end

    def mean_score_for_subject(subject)
      s = score_for_subject(subject)
      return nil unless s
      s.mean
    end

    def initialize(name:)
      @name = name
      @scores = Hash.new
    end

    def to_s
      "#{name}: #{scores.to_s}"
    end
  end

  class YearGroup
    attr_reader :students, :subjects

    def initialize(subjects = [:reading, :riting, :rithmetic])
      @students = []
      @subjects = subjects
    end

    def add_student(student)
      students.push(student) #Student.new(name: name))
    end

    def run_test(subject)
      raise "Bad subject #{subject}" unless @subjects.include?(subject)
      raise "need block" unless block_given?

      students.each do |student|
        score = yield(student.name, subject)
        student.add_score(subject, score)
      end
    end

    def report
      puts("#{students.count} students:")
      students.each do |student|
        puts("  #{student.to_s}")
      end
    end
  end
end
