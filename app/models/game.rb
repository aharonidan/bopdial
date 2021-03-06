class Game < ApplicationRecord
  belongs_to :team_a, class_name: 'Team'
  belongs_to :team_b, class_name: 'Team'

  after_update { User.calculate_points }

  def not_editable?(account: nil)
    # adjusting to Israel time
    (Time.now + 3.hours) > deadline || self.not_editable
  end

  def bets
    @bets ||= Bet.where(game_id: id)
  end

  def editable?(account: nil)
    not not_editable?(account: account)
  end

  def place_holder?
    team_a.group == 'place_holder'
  end

  def self.horses_editable?(account: nil)
    first.editable?(account: account)
  end

  def self.horses_not_editable?(account: nil)
    first.not_editable?(account: account)
  end

  def self.black_horse_announced?
    Setting.where(name: 'black_horse').any?
  end

  def self.grey_horse_announced?
    Setting.where(name: 'grey_horse').any?
  end

  def self.top_scorer_announced?
    Setting.where(name: 'top_scorer').any?
  end

  def self.champion_announced?
    Setting.where(name: 'champion').any?
  end

  def played?
    score_a.present? and score_b.present?
  end

  def team_a_wins?
    score_a > score_b
  end

  def team_b_wins?
    score_a < score_b
  end

  def draw?
    score_a == score_b
  end

  def playoff?
    is_playoff
  end

  def self.no_games_today
    where(match_time: Date.today.beginning_of_day..Date.today.end_of_day).empty?
  end
end
