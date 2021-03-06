class User < ApplicationRecord

  belongs_to :account
  belongs_to :black_horse, class_name: 'Team', optional: true
  belongs_to :grey_horse,  class_name: 'Team', optional: true
  belongs_to :champion,    class_name: 'Team', optional: true
  has_many :bets
  has_many :user_stats

  validate :horses_do_not_change_after_deadline, on: :update

  attr_accessor :remember_token
  attr_reader :account_name

	before_save do
    self.email = email.downcase
    self.top_scorer = top_scorer.parameterize(separator: '_') if top_scorer
  end

	validates :name,  presence: true, length: { maximum: 50 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 255 }, format: { with: VALID_EMAIL_REGEX }, uniqueness: { case_sensitive: false }
  has_secure_password

  def horses_do_not_change_after_deadline
    if Game.horses_not_editable?(account: account) and (black_horse_id_changed? or grey_horse_id_changed? or champion_id_changed? or top_scorer_changed? or after_army_trip_changed?)
      errors.add(:black_horse_id, "Change of horses after deadline not allowed!")
    end
  end

  # Returns the hash digest of the given string.
  def self.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                  BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  # Returns a random token.
  def self.new_token
    SecureRandom.urlsafe_base64
  end

  # Remembers a user in the database for use in persistent sessions.
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  # Forgets a user.
  def forget
    update_attribute(:remember_digest, nil)
  end

  # Returns true if the given token matches the digest.
  def authenticated?(remember_token)
  	return false if remember_digest.nil?
    BCrypt::Password.new(remember_digest).is_password?(remember_token)
  end

  def self.calculate_points
    User.all.each(&:calculate_points)
  end


  def calculate_points
    sum = 0
    for bet in bets_of_played_games
      sum += bet.points
    end

    sum += 8 if black_horse == Team.find_by(name: 'finland')
    sum += 8 if grey_horse and ['czech_republic', 'switzerland'].include?(grey_horse.name)
    sum += 8 if top_scorer == 'cristiano_ronaldo'
    sum += 8 if account.name == 'bop' and ['romelu_lukaku', 'harry_kane'].include?(top_scorer)
    sum += 9 if champion and champion.name == 'italy'
    update(points: sum)

  end

  def points
    super || 0
  end

  def daily_score
    today = bets.joins(:game).where.not(games: {score_a: nil}).where(games: {match_time: Date.today.beginning_of_day..Date.today.end_of_day})
    today.sum(:points)
  end

  def score_by_date date
    days_bets = bets.joins(:game).where.not(games: {score_a: nil}).where(games: {match_time: date.beginning_of_day..date.end_of_day})
    days_bets.sum(:points)
  end

  def best_day
    start_date = Game.first.match_time.to_date

    max = 0
    max_date = nil

    start_date.upto(Date.today) do |day|
      days_bets = bets.joins(:game).where.not(games: {score_a: nil}).where(games: {match_time: day.beginning_of_day..day.end_of_day})
      points = days_bets.sum(:points)
      if points > max
        max = points
        max_date = day
      end
    end
    {max: max, max_date: max_date}
  end

  def daily_king
    return if Game.no_games_today

    unplayed_games = Game.where(match_time: Date.today.beginning_of_day..Date.today.end_of_day, score_a: nil).any?
    return if unplayed_games

    scores = User.where(account: account).map(&:daily_score)
    daily_score == scores.max
  end

  def daily_loser
    return if Game.no_games_today
    unplayed_games = Game.where(match_time: Date.today.beginning_of_day..Date.today.end_of_day, score_a: nil).any?
    return if unplayed_games

    scores = User.where(account: account).map(&:daily_score)
    daily_score == scores.min
  end

  def black_horse_points
    return 8 if black_horse and Setting.where(name: 'black_horse', value: black_horse.name).any?
    return 0
  end

  def grey_horse_points
    return 8 if grey_horse and Setting.where(name: 'grey_horse', value: grey_horse.name).any?
    return 0
  end

  def after_army_trip_points
    return 5 if after_army_trip.present? and Setting.where(name: 'after_army_trip', value: after_army_trip).any?
    return 0
  end

  def champion_points
    return 8 if champion and Setting.where(name: 'champion', value: champion.name).any?
    return 0
  end

  def top_scorer_points
    return 8 if top_scorer.present? and Setting.where(name: 'top_scorer', value: top_scorer).any?
    return 0
  end

  def bets_of_played_games
    return @bets_of_played_games if @bets_of_played_games
    @bets_of_played_games = bets.joins(:game).where.not(games: {score_a: nil})
  end

  def donkey
    sum = 0

    for bet in bets_of_played_games
      sum += 1 if bet.donkey?
    end
    sum
  end

    def bingo
    sum = 0

    for bet in bets_of_played_games
      sum += 1 if bet.bingo?
    end
    sum
  end

  def nadir
    sum = 0
    for bet in bets
      sum += 1 if bet.game.not_editable? and bet.nadir?
    end
    sum
  end

  def nadir_bingo
    sum = 0
    for bet in bets_of_played_games
      sum += 1 if bet.nadir? and (bet.bingo? or bet.kivoon?)
    end
    sum
  end

  def goal_diffrence
    sum = 0
    for bet in bets_of_played_games
      sum += 1 if bet.goal_difference? and !bet.draw?
    end
    sum
  end

  def kivoon
    sum = 0
    for bet in bets_of_played_games
      sum += 1 if (!bet.goal_difference? and bet.kivoon?) or (bet.draw? and bet.kivoon?)
    end
    sum
  end

  def account_name= value
    self.account = Account.where(name: value).first
  end
end
