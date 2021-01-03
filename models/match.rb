class Match < ApplicationRecord
  include MatchDecorator
  include AASM
  include Unlockable

  has_one :radiant, ->{ where(radiant: true) }, primary_key: :match_id, class_name: 'Side', autosave: true
  has_one :dire, ->{ where(radiant: false) }, primary_key: :match_id, class_name: 'Side', autosave: true

  has_many :user_matches, dependent: :destroy
  has_many :users, through: :user_matches
  has_many :user_quests, primary_key: :match_id
  has_many :match_state_changes, primary_key: :match_id
  has_many :quest_results
  has_many :sides, primary_key: :match_id, dependent: :destroy, autosave: true
  has_many :players, through: :sides, dependent: :destroy

  belongs_to :league

  validates :match_id, :winner, :started_at, :state, presence: true
  validates :match_id, uniqueness: true
  validates :radiant, presence: true
  validates :dire, presence: true
  validates :players, length: { minimum: 1, maximum: 10 }

  scope :api_users, -> (api_user)     { joins(users: :api_user).where(api_users: { id: api_user.id }) }
  scope :for_steam_id, -> (steam_ids) { joins(:users).where(users: { uid: steam_ids }) if steam_ids }
  scope :freshest, -> { where('started_at > ?', Date.current - 4.days) }
  scope :recent, -> { where('started_at > ?', Date.current - 14.days) }
  scope :recent_but_not_freshest, -> { where('started_at > ?',
    Date.current - 14.days).where.not(id: freshest.ids) }
  scope :eligible_for_checking, -> { where(state: [:created, :failed]) }
  scope :too_old, -> { where('started_at < ?', Date.current - 14.days) }
  scope :from_time, -> (from) { where('started_at > ?', from)  if from }
  scope :till, -> (till) { where('started_at < ?', till)  if till }


  aasm column: 'state' do
    state :created, initial: true
    state :checking, :retrying, :checked, :damaged, :failed, :no_replay_file

    after_all_transitions :log_state_change

    event :start_checking do
      transitions from: [:checking, :created, :failed, :damaged, :checked, :retrying], to: :checking
    end

    event :successful_check do
      transitions from: [:created, :checking, :retrying], to: :checked
    end

    event :retry do
      transitions from: :checking, to: :retrying
    end

    # means known error
    event :mark_damaged do
      transitions to: :damaged
    end

    # means unknown error
    event :mark_failed do
      transitions from: [:created, :checking, :retrying], to: :failed
    end

    event :file_doesnt_exist do
      transitions to: :no_replay_file
    end

    event :reset_state do
      transitions to: :created
    end
  end

  def duration_in_seconds
    hours, min, sec = duration.split(':')
    hours.to_i * 3600 + min.to_i * 60 + sec.to_i
  end

  def match_data
    @match_data ||= get_match_data
  end

  def get_match_data
    repo = MatchesRepository.new
    repo.find(match_id)
  end

  # finds player by opendota slot [0, 1, 2, 3, 4, 128, 129, 130, 131, 132]
  def find_player(opendota_slot)
    opendota_slot = opendota_slot.to_i

    if opendota_slot > 4
      dire.players.find_by(slot: opendota_slot - 127)
    else
      radiant.players.find_by(slot: opendota_slot + 1)
    end
  end

  def opendota_link
    "https://www.opendota.com/matches/#{ match_id }"
  end

  private

  def log_state_change
    MatchStateChange.create(match_id: match_id, from: aasm.from_state, to: aasm.to_state)
  end
end
