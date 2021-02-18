require 'rails_helper'

RSpec.describe Match, type: :model do
  subject(:match) { build(:match) }

  it 'creates match with initial state' do
    expect(subject).to be_created
  end

  it 'logs state change' do
    subject.start_checking
    expect(subject.match_state_changes.last)
      .to have_attributes(from: 'created', to: 'checking')
  end

  context 'states' do
    describe '#successful_check' do
      let(:match) { build(:match, state: 'retrying') }

      specify do
        expect {
          match.successful_check!
        }.to change { match.state }.from('retrying').to('checked')
      end
    end
  end

  context 'unlocks' do
    let(:user) { build(:user, current_match_unlocks: 2) }
    it 'should decrease unlocks count for user' do
      subject.unlock_for!(user)
      expect(user.current_match_unlocks).to eq 1
      expect(user.unlocks.count).to eq 1
      expect(subject.unlocked_for?(user)).to be_truthy
    end

    it 'should not unlock when no unlocks available' do
      user.update(current_match_unlocks: 0)
      subject.unlock_for!(user)
      expect(user.current_match_unlocks).to eq 0
      expect(user.unlocks.count).to eq 0
      expect(subject.unlocked_for?(user)).to be_falsey
    end
  end
end
