class UserMatchHistoryUpdater
  include SemanticLogger::Loggable
  # Public Matchmaking, Tournament, Team Match, Solo Queue, Ranked, Battle Cup
  CORRECT_MATCH_TYPES = [0, 2, 5, 6, 7, 9]
  PRESTIGE_MATCH_TYPES = [2, 7, 9]
  PREFETCH_LAST_MATCHES_COUNT = 1

  def initialize(user, api=Dota.api)
    @user = user
    @api = api
  end

  def perform
    logger.info("Update match history for user_id=#{user.id}")
    return unless user.uid

    (prefetched_last_matches_ids + new_match_ids).each do |match_id|
      logger.measure_info('Match saver', metric: 'match_history/match_saver') do
        MatchSaver.new(match_id).perform
      end
    end


    logger.measure_info('Queue quest check', metric: 'match_history/queue_quest_check') do
      freshest_match_ids.each do |match_id|
        m = Match.find_by(match_id: match_id)
        MatchQuestChecker.new(m).check
      end
    end

    logger.measure_info('Mark old matches', metric: 'match_history/old_matches') do
      too_old_matches.each do |match|
        match.file_doesnt_exist
      end
    end

    update_health_status
    user.update(last_time_parse: Time.current)
  end

  private

  attr_accessor :user, :remote_matches


  def update_health_status
    Rails.cache.write('steam_api_health', 'ok', expires_in: 30.minutes)
  end

  def remote_matches
    matches ||= fetch_matches
  end

  def fetch_matches
    repo.by_account(id: user.uid, page: 1, per: 50)
  end

  def prefetched_last_matches_ids
    return [] if user.matches.any? || repo.by_account(id: user.uid) #@api.matches(player_id: user.uid)&.empty?

    remote_matches
      .select { |player| CORRECT_MATCH_TYPES.include? player.match.type_id }
      .sort_by { |player| player.match.starts_at }
      .map(&:match_id)
  end

  def unstuck_matches
    stuck_matches =
      user.matches.recent
        .joins('LEFT JOIN match_state_changes ON match_state_changes.match_id = matches.match_id')
        .where(matches: { state: :checking })
        .where(match_state_changes: { to: :checking })
        .where('match_state_changes.created_at < ?', Time.current - 15.minutes)
        .distinct

    stuck_matches.map{ |m| m.reset_state }
  end

  def freshest_match_ids
    user.matches.freshest.eligible_for_checking.order(match_id: :desc).pluck(:match_id)
  end

  def recent_match_ids
    user.matches.recent_but_not_freshest.eligible_for_checking.order(:match_id).pluck(:match_id)
  end

  def new_match_ids
    user_match_ids = user.matches.pluck(:match_id).map(&:to_i)
    (match_ids_from_api - user_match_ids).sort
  end

  def match_ids_from_api
    return [] if remote_matches.empty?

    remote_matches
      .select { |player| player.match.starts_at > user.created_at }
      .select { |player| CORRECT_MATCH_TYPES.include? player.match.type_id }
      .map(&:match_id)
  end

  def too_old_matches
    user.matches.eligible_for_checking.too_old
  end

  def repo
    @repo ||= MatchesRepository.new
  end
end
