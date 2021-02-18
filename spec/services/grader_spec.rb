require 'rails_helper'

describe Grader do
  let(:replay) { Opendota::Replay.test_replay }

  subject { Grader.new(replay) }

  describe '#call' do
    it 'returns grade b' do
      expect(subject.call).to eq Grade.find_by(name: 'B')
    end

    it 'returns grade s' do
      subject = Grader.new(Opendota::Replay.test_replay(2))
      expect(subject.call).to eq Grade.find_by(name: 'C')
    end

    it 'returns grade b' do
      subject = Grader.new(Opendota::Replay.test_replay(3))
      expect(subject.call).to eq Grade.find_by(name: 'B')
    end

    it 'returns grade a' do
      subject = Grader.new(Opendota::Replay.test_replay(4))
      expect(subject.call).to eq Grade.find_by(name: 'B')
    end

    it 'returns grade a' do
      subject = Grader.new(Opendota::Replay.test_replay(128))
      expect(subject.call).to eq Grade.find_by(name: 'B')
    end

    it 'returns grade b' do
      subject = Grader.new(Opendota::Replay.test_replay(129))
      expect(subject.call).to eq Grade.find_by(name: 'B')
    end

    it 'returns grade a' do
      subject = Grader.new(Opendota::Replay.test_replay(130))
      expect(subject.call).to eq Grade.find_by(name: 'C')
    end

    it 'returns grade c' do
      subject = Grader.new(Opendota::Replay.test_replay(131))
      expect(subject.call).to eq Grade.find_by(name: 'C')
    end

    it 'returns grade b' do
      subject = Grader.new(Opendota::Replay.test_replay(132))
      expect(subject.call).to eq Grade.find_by(name: 'A')
    end

    context 'missing benchmarks' do
      it 'returns fake benchmark' do
        replay = Opendota::Replay.test_replay(132)
        replay.player_info[:benchmarks][:gold_per_min][:pct] = nil
        replay.player_info[:benchmarks][:xp_per_min][:pct] = nil
        replay.player_info[:benchmarks][:kills_per_min][:pct] = nil
        replay.player_info[:benchmarks][:last_hits_per_min][:pct] = nil
        replay.player_info[:benchmarks][:hero_damage_per_min][:pct] = nil
        replay.player_info[:benchmarks][:hero_healing_per_min][:pct] = nil
        replay.player_info[:benchmarks][:tower_damage][:pct] = nil
        subject = Grader.new(replay)
        expect(subject.call).to eq Grade.find_by(name: 'S')
      end
    end
  end
end
