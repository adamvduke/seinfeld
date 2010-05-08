class Seinfeld
  class User < ActiveRecord::Base
    has_many :progressions, :order => 'seinfeld_progressions.created_at', :dependent => :delete_all

    scope :active,              where(:disabled => false)
    scope :best_current_streak, where('current_streak > 0').order('current_streak desc, login').limit(15)
    scope :best_alltime_streak, where('longest_streak > 0').order('longest_streak desc, login').limit(15)

    def self.paginated_each(limit = 30)
      since = 0
      while users = first_page(limit, since)
        users.each do |user|
          yield user
          since = user.id if user.id > since
        end
      end
    end

    def self.first_page(limit = 30, since = 0)
      users   = where('id > ?', since).order('id').limit(limit)
      users.blank? ? nil : users
    end

    # Public: Queries a user's progress for a given month.
    #
    # Example
    #
    #   # find progressions from 5 days before and after April 2010.
    #   user.progress_for(2010, 4, 5)
    #
    # year  - Integer year to query.
    # month - Integer month to query.
    # extra - Number of days to pad on both sides.  (default: 0)
    #
    # Returns Array of Dates.
    def progress_for(year, month, extra = 0)
      beginning = Date.new(year, month)
      ending    = (beginning >> 1) - 1
      progressions.
        where(:created_at => (beginning - extra)..(ending + extra)).
        map { |p| p.created_date }
    end

    # Public: Scans the given days for streaks and updates the user model 
    # with stats.
    #
    # days  - Array of Date objects.  These are usually from 
    #         Seinfeld::Feed#committed_days
    # today - A Date instance representing today (default: Date.today).
    #
    # Returns nothing.
    def update_progress(days = nil, today = Date.today)
      Time.zone = time_zone || "UTC"
      days    ||= Feed.fetch(login).committed_days
      days      = filter_existing_days(days)
      streaks   = [current_streak = Streak.new(streak_start, streak_end)]

      days.sort!
      transaction do
        streaks = scan_days_for_streaks(days)
        update_from_streaks(streaks, today)
        save!
      end
    end

    # Public: Clears all progression data for a user.
    #
    # Returns nothing.
    def clear_progress
      progressions.delete_all
      update_attributes \
        :streak_start => nil, :streak_end => nil, :current_streak => nil,
        :longest_streak => nil, :longest_streak_start => nil, :longest_streak_end => nil
    end

    # Public: Generates a URL to the user's longest streak.
    #
    # Returns a String URL of either the year/month of the longest streak,
    # or the user's page if they have no streaks.
    def longest_streak_url
      if longest_streak_start.nil? || longest_streak_end.nil?
        "/~#{login}"
      else
        "/~#{login}/#{longest_streak_start.year}/#{longest_streak_start.month}"
      end
    end

    # Filters out any days that this user already has an X on.
    #
    # days - Array of Date instances.
    #
    # Returns a filtered Array.
    def filter_existing_days(days)
      if !days.empty?
        existing = progressions.where(:created_at => days).
          map { |p| p.created_date }
        days -= existing
      end
      days
    end

    # Scan the days for Streaks, starting with the user's current streak.
    #
    # days - Array of Date objects. These should be sorted and not in the
    #        user's list already.
    #
    # Returns an Array of Streak instances.
    def scan_days_for_streaks(days)
      streaks = [current_streak = Streak.new(streak_start, streak_end)]
      days.each do |day|
        if current_streak.current?(day)
          current_streak.ended = day
        else
          streaks << (current_streak = Streak.new(day))
        end
        progressions.create!(:created_at => day)
      end
      streaks
    end

    # Update User attributes based on the given streaks.
    #
    # streaks - Array of Streak objects.  This is used to set the various 
    #           streak related attributes on User.
    # today   - A Date instance representing today.
    def update_from_streaks(streaks, today)
      highest_streak = streaks.empty? ? 0 : streaks.max { |a, b| a.days <=> b.days }
      if latest_streak = streaks.last
        self.streak_start   = latest_streak.started
        self.streak_end     = latest_streak.ended
        self.current_streak = latest_streak.current?(today) ? latest_streak.days : 0
      end

      if highest_streak.days > longest_streak.to_i
        self.longest_streak       = highest_streak.days
        self.longest_streak_start = highest_streak.started
        self.longest_streak_end   = highest_streak.ended
      end
    end
  end
end