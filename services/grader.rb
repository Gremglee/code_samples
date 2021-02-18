class Grader
  include SemanticLogger::Loggable

  attr_reader :replay

  def initialize(replay)
    @replay = replay
  end

  def call
    logger.measure_info("Assigning grade match_id=#{replay.match_id}", metric: 'player_perfomance/grades') do
      return fake_benchmark_score if use_fake_grade?

      case benchmark_score
      when 0...30
        Grade.find_by(name: 'C')
      when 30...60
        Grade.find_by(name: 'B')
      when 60...80
        Grade.find_by(name: 'A')
      when 80..100
        Grade.find_by(name: 'S')
      else
        raise Grader::GradeNotFound
      end
    end
  end

  private

  attr_reader :benchmarks

  def benchmark_score
    benchmarks.map do |benchmark_method|
      replay.send(benchmark_method)
    end.sum / benchmarks.count * 100
  end

  def use_fake_grade?
    benchmark_score.zero?
  end

  def fake_benchmark_score
    case replay.kda
    when 0...0.5
      Grade.find_by(name: 'C')
    when 0.5...1
      Grade.find_by(name: 'B')
    when 1...3
      Grade.find_by(name: 'A')
    when 3...1000
      Grade.find_by(name: 'S')
    end
  end

  def benchmarks
    @benchmarks ||= Heroes::Role.find(replay.lane || 5).valuable_benchmarks
  end

  class GradeNotFound < StandardError; end
end
