require 'rails_helper'

describe UserMatchHistoryUpdater do
  let(:user) {
    build(
      :user,
      uid: 1008518012,
      last_time_parse: Time.current - 1.day,
      created_at: Time.current - 1.hour
    )
  }
  let(:sample_response) { file_fixture('sample_account.json').read }
  let(:sample_match) { file_fixture('sample_match.json').read }

  let(:match) { MatchesRepository.new.find(5079685150).player_by_slot(130) }
  let(:wrong_match) { double(match_id: 1111111, match: double(match_id: 1111111, type_id: 3, starts_at: 1.week.ago)) }


  let(:subject) { described_class.new(user) }

  before do
    stub_request(:get, 'http://35.227.237.124/api/v2/account-matches/1008518012').
      to_return(body: sample_response)
    allow(subject).to receive(:user).and_return(user)
    allow(subject).to receive(:recent_match_ids).and_return([])
    allow(subject).to receive(:freshest_match_ids).and_return([])
    allow(Dota.api).to receive(:matches).with(player_id: user.uid) { [] }
  end

  context 'there are no new matches' do
    before :each do
      allow(subject).to receive(:new_match_ids).and_return([])
    end

    it 'does not save any matches' do
      expect(MatchSaver).not_to receive(:new)
      subject.perform
    end
  end

  context 'one new match' do
    before :each do
      allow(subject).to receive(:new_match_ids)
        .and_return([6])
      allow(subject).to receive(:unstuck_matches)
    end

    it 'saves one match' do
      expect(MatchSaver).to receive_message_chain(:new, :perform)
      subject.perform
    end
  end

  context 'filtering out invalid matches' do
    xit 'does not select match with wrong type' do
      allow_any_instance_of(MatchesRepository).to receive(:by_account)
        .with(id: user.uid, page: 1, per: 50) { [match, wrong_match] }
      user.created_at = 2.weeks.ago
      expect(subject.send(:match_ids_from_api)).to eq [match.match_id]
    end

    it 'does not select match if match started before user was created' do
      user.created_at = Time.current + 1.week
      allow(Dota.api).to receive(:matches)
        .with(player_id: user.uid) { [match] }

      expect(subject.send(:match_ids_from_api)).to eq []
    end
  end
end
