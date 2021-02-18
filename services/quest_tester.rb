class QuestTester
  include ActiveModel::Model

  attr_reader :result, :quest, :match_info, :match_id

  validate :match_info_present

  def initialize(match_id, quest)
    @match_id = match_id.gsub(/[^0-9,.]/, "")
    @quest = quest
    @result = {}
  end

  def check
    return unless valid?

    (1..10).to_a.each do |slot|
      replay = Opendota::Replay.new(match_info, slot)
      replay_check = QuestReplayCheck.new(replay, quest)
      check_quest_for_user(replay_check)
    end
  end

  private

  def match_info_present
    @match_info = Opendota::API.match_info(match_id, true)
  rescue Opendota::API::ReplayNotParsed
    self.errors.add(:base, 'Реплей еще не обработан. Повторите через 5-10 минут')
  rescue Opendota::API::MatchNotFound
    self.errors.add(:base, 'Неправильный ID матча')
  end

  def minimal_new_stars
    1
  end

  def check_quest_for_user(replay_check)
    @result[replay_check.replay.hero_name] = {}
    stars = 0
    (1..3).to_a.each do |star|
      replay_check_for_stars_result = replay_check.call(stars: star)
      @result[replay_check.replay.hero_name][:result] = replay_check_for_stars_result.to_hash
      if replay_check_for_stars_result.success?
        stars = star
        @result[replay_check.replay.hero_name][:stars] = stars
      else
        @result[replay_check.replay.hero_name][:stars] = stars
        break
      end
    end
  end
end
