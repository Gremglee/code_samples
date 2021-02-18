require 'rails_helper'

RSpec.describe UserMatch, type: :model do
  let!(:match) { create(:match, match_id: 5079685150) }
  let!(:quest) { create(:quest) }
  let!(:user) { create(:user) }
  let!(:quest_result) { create(:quest_result, match: match) }
  let!(:user_quest) { create(:user_quest, user: user, quest: quest, quest_results: [quest_result]) }
  subject(:user_match) { create(:user_match, user: user, match: match, side: match.radiant) }

  describe '#successful_quests' do
    it 'return a successful quest' do
      expect(subject.successful_quests.to_a).to eq [user_quest]
    end

    it 'does not return an unsuccessful quest attempt' do
      quest_result.update(stars: 0)

      expect(subject.successful_quests.count).to eq 0
    end
  end

  describe '#update_player_information' do
    let(:replay) { Opendota::Replay.test_replay }

    it 'updated player info' do
      subject.update_player_information(replay)
      expect(subject.position).to eq 1
      expect(subject.lane).to eq 1
    end

    it 'saves backpack items' do
      subject.update_player_information(replay)
      expect(subject.backpack_item_ids).to eq [0, 0, 0]
    end
  end

  describe '#items' do
    it 'returns snippets' do
      allow(subject).to receive(:item_ids) { [1, 2, 3, 4, 5, 6] }
      expect(subject.items).to eq [
        ":item_blink_dagger:", ":item_blades_of_attack:",
        ":item_broadsword:", ":item_chainmail:",
        ":item_claymore:", ":item_helm_of_iron_will:"
      ]
    end
  end

  describe '#items_with_timings' do
    let(:replay) { Opendota::Replay.test_replay }

    it 'returns right timings' do
      allow(subject).to receive(:item_ids) { [37, 0, 42, 20, 41, 16] }

      expect(subject.items_with_timings.map(&:inspect)).to eq [
        { formatted_timing: "-00:51", item: ":item_circlet:", timing: -51 },
        { formatted_timing: "02:26", item: ":item_iron_branch:", timing: 146 },
        { formatted_timing: "-", item: ":item_ghost_scepter:", timing: 999999 },
        { formatted_timing: "-", item: ":item_observer_ward:", timing: 999999 },
        { formatted_timing: "-", item: ":item_bottle:", timing: 999999 }
      ]
    end
  end

  describe '#starting_build_cost' do
    let(:replay) { Opendota::Replay.test_replay }
    let(:sample_match) { file_fixture('sample_match.json').read }

    before do
      stub_request(:get, "http://35.227.237.124/api/v2/match/4000000001").
        to_return(body: sample_match)
    end

    it 'returns costs sum' do
      expect(subject.player_data.starting_build_cost).to eq 740
    end
  end

  describe '#grade' do
    it 'returns not graded' do
      expect(subject.grade).to eq nil
    end
  end

  context 'many mistakes' do
    let!(:mistake1) { create(:mistake, type: Mistakes::NotMetaHero) }
    let!(:mistake2) { create(:mistake, type: Mistakes::RandomPick) }
    let!(:mistake3) { create(:mistake, type: Mistakes::LowLastHitLaning) }
    let!(:mistake4) { create(:mistake, type: Mistakes::NoQuellingBlade) }
    let!(:mistake5) { create(:mistake, type: Mistakes::SuboptimalRole) }

    subject(:user_match) { create(:user_match, user: user, match: match, side: match.radiant,
                                  mistakes: [mistake1, mistake2, mistake3, mistake4, mistake5])
    }

    describe '#free_mistakes' do
      it 'returns 3 mistakes max' do
        expect(subject.free_mistakes.count).to eq 1
      end
    end

    describe '#paid_mistakes' do
      it 'returns 2 mistakes' do
        expect(subject.paid_mistakes.count).to eq 4
      end
    end
  end
end
