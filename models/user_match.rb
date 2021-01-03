class UserMatch < ApplicationRecord
  include Decoratable

  FREE_MISTAKES_LIMIT = 1

  belongs_to :user, touch: true
  belongs_to :match
  belongs_to :grade
  belongs_to :hero
  belongs_to :side

  has_one :pro_similarity, dependent: :destroy

  has_many :user_quests, through: :match, dependent: :destroy
  has_many :mistakes, dependent: :destroy
  has_many :recommended_items, foreign_key: :player_id
  has_many :player_consumables_benchmarks, foreign_key: :player_id

  has_one :item_build, foreign_key: :player_id
  has_one :item_build_recommendation, foreign_key: :player_id

  validates :side, presence: true
  validates :user_id, uniqueness: { scope: :match_id }, if: :user_id
  validates :steam_id, uniqueness: { scope: :match_id }, if: :steam_id

  scope :with_mistakes, -> { joins(:mistakes).group(:id)
    .having("COUNT(mistakes.id) > 0") }
  scope :wins, -> { where(win: true) }
  scope :losses, -> { where(win: false) }

  def successful_quests
    user.user_quests
      .joins(:quest_results)
      .where(quest_results: { match: match })
      .where('quest_results.stars > quest_results.stars_before')
      .distinct
  end

  def mistake_analysis_result
    mistakes.sum(:percent_value)
  end

  def items_with_timings
    item_ids.select{ |item_id| item_id > 0 }
      .map{ |item_id| Dota.api.items(item_id).snippet_with_timing(item_timing(item_id)) }
      .sort_by{ |item| item.timing }
  end

  def recommended_items_with_timing
    recommended_items.map(&:snippet_with_timing).sort_by{ |item| item.timing }
  rescue
    []
  end

  def recommended_starting_items
    item_build_recommendation.starting_item_ids
      &.select{ |item_id| item_id > 0 }
      &.map{ |item_id| Dota.api.items(item_id).snippet_with_timing(0) }
  rescue
    []
  end

  def paid_mistakes
    mistakes.where.not(id: free_mistakes.ids)
  end

  def url
    hero.decorate.url
  end

  def name
    user&.nickname || nickname || 'Anonymous'
  end

  def position_name
    { '0' => 'unknown', '1' => 'carry', '2' => 'mid', '3' => 'offlane', '4' => 'support' }[position.to_i.to_s]
  end

  # 0, 1, 2, 3, 4 - radiant players, 128, 129, 130, 131, 132 - dire players
  def opendota_slot
    if side.radiant?
      slot - 1
    else
      127 + slot
    end
  end

  # 0, 1, 2, 3, 4 - radiant players, 5, 6, 7, 8, 9 - dire players
  def simple_slot
    if side.radiant?
      slot - 1
    else
      slot + 4
    end
  end

  def update_player_information(replay)
    update!(
      position: replay.role,
      lane: replay.lane,
      rank: replay.rank,
      backpack_item_ids: replay.backpack_item_ids
    )
  end

  private

  def item_timing(item_id)
    purchased_items.select{ |x| x.item_id == item_id }&.sort_by(&:timing)&.last&.timing
  end
end
