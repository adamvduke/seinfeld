require File.join(File.dirname(__FILE__), "test_helper")

class UserTest < ActiveSupport::TestCase
  fixtures do
    @disabled = Seinfeld::User.create! :login => 'disabled', :disabled => true
    @newb     = Seinfeld::User.create! :login => 'newb'
    @user     = Seinfeld::User.create! :login => 'user', 
      :streak_start => Date.civil(2007, 12, 30), :streak_end => Date.civil(2007, 12, 31), :current_streak => 2,
      :longest_streak_start => Date.civil(2007, 12, 30), :longest_streak_end => Date.civil(2007, 12, 31), :longest_streak => 2
    @user.progressions.create!(:created_at => Date.civil(2007, 12, 30))
    @user.progressions.create!(:created_at => Date.civil(2007, 12, 31))
    Seinfeld::Progression.create! :user_id => @user.id+1
    @today = Date.civil(2008, 1, 3)
  end

  test "#first_page finds the first page of all users" do
    assert_equal [@disabled, @newb], Seinfeld::User.first_page(2)
    assert_equal [@user],            Seinfeld::User.first_page(2, @newb.id)
    assert_nil                       Seinfeld::User.first_page(2, @user.id)
  end

  test "#first_page finds the first page of active users" do
    assert_equal [@newb, @user], Seinfeld::User.active.first_page(2)
    assert_nil                   Seinfeld::User.active.first_page(2, @user.id)
  end

  test "#paginated_each pages through available users" do
    users = []
    Seinfeld::User.paginated_each(2) { |u| users << u }
    assert_equal [@disabled, @newb, @user], users
  end

  test "#paginated_each pages through active users" do
    users = []
    Seinfeld::User.active.paginated_each(2) { |u| users << u }
    assert_equal [@newb, @user], users
  end

  test "#update_progress with newb, keeping the streak" do
    parsed_dates = [Date.civil(2007, 12, 31), Date.civil(2008, 1, 1), Date.civil(2008, 1, 2)]

    assert_equal 0, @newb.progressions.count
    @newb.update_progress parsed_dates, @today
    assert_equal 3, @newb.progressions.count
    assert_equal parsed_dates, @newb.progress_for(2008, 1, 1)

    assert_equal 3, @newb.longest_streak
    assert_equal 3, @newb.current_streak
    assert_equal Date.civil(2007, 12, 31), @newb.longest_streak_start
    assert_equal Date.civil(2008, 1, 2),   @newb.longest_streak_end
    assert_equal Date.civil(2007, 12, 31), @newb.streak_start
    assert_equal Date.civil(2008, 1, 2),   @newb.streak_end
  end

  test "#update_progress with newb, breaking the streak" do
    parsed_dates = [Date.civil(2007, 12, 31), Date.civil(2008, 1, 1)]

    assert_equal 0, @newb.progressions.count
    @newb.update_progress parsed_dates, @today
    assert_equal 2, @newb.progressions.count
    assert_equal parsed_dates, @newb.progress_for(2008, 1, 1)

    assert_equal 2, @newb.longest_streak
    assert_equal 0, @newb.current_streak
    assert_equal Date.civil(2007, 12, 31), @newb.longest_streak_start
    assert_equal Date.civil(2008, 1, 1),   @newb.longest_streak_end
    assert_equal Date.civil(2007, 12, 31), @newb.streak_start
    assert_equal Date.civil(2008, 1, 1),   @newb.streak_end
  end

  test "#update_progress with user, keeping the streak" do
    parsed_dates = [Date.civil(2007, 12, 31), Date.civil(2008, 1, 1), Date.civil(2008, 1, 2)]

    assert_equal 2, @user.progressions.count
    @user.update_progress parsed_dates, @today
    assert_equal 4, @user.progressions.count
    assert_equal parsed_dates, @user.progress_for(2008, 1, 1)

    assert_equal 4, @user.longest_streak
    assert_equal 4, @user.current_streak
    assert_equal Date.civil(2007, 12, 30), @user.longest_streak_start
    assert_equal Date.civil(2008, 1, 2),   @user.longest_streak_end
    assert_equal Date.civil(2007, 12, 30), @user.streak_start
    assert_equal Date.civil(2008, 1, 2),   @user.streak_end
  end

  test "#update_progress with user, breaking the streak" do
    parsed_dates = [Date.civil(2007, 12, 31), Date.civil(2008, 1, 1)]

    assert_equal 2, @user.progressions.count
    @user.update_progress parsed_dates, @today
    assert_equal 3, @user.progressions.count
    assert_equal parsed_dates, @user.progress_for(2008, 1, 1)

    assert_equal 3, @user.longest_streak
    assert_equal 0, @user.current_streak
    assert_equal Date.civil(2007, 12, 30), @user.longest_streak_start
    assert_equal Date.civil(2008, 1, 1),   @user.longest_streak_end
    assert_equal Date.civil(2007, 12, 30), @user.streak_start
    assert_equal Date.civil(2008, 1, 1),   @user.streak_end
  end

  test "#update_progress with user, starting new strea" do
    parsed_dates = [Date.civil(2007, 12, 31), Date.civil(2008, 1, 2)]

    assert_equal 2, @user.progressions.count
    @user.update_progress parsed_dates, @today
    assert_equal 3, @user.progressions.count
    assert_equal parsed_dates, @user.progress_for(2008, 1, 1)

    assert_equal 2, @user.longest_streak
    assert_equal 1, @user.current_streak
    assert_equal Date.civil(2007, 12, 30), @user.longest_streak_start
    assert_equal Date.civil(2007, 12, 31), @user.longest_streak_end
    assert_equal Date.civil(2008, 1, 2),   @user.streak_start
    assert_equal Date.civil(2008, 1, 2),   @user.streak_end
  end

  test "#clear_progress clears all user data" do
    assert_equal 3, Seinfeld::Progression.count

    @user.clear_progress
    assert_equal 1, Seinfeld::Progression.count
    assert_equal 0, @user.progressions.count
    assert_nil      @user.streak_start
    assert_nil      @user.streak_end
    assert_nil      @user.current_streak
    assert_nil      @user.longest_streak_start
    assert_nil      @user.longest_streak_end
    assert_nil      @user.longest_streak
  end

  test "#longest_streak_url with longest streak" do
    user = Seinfeld::User.new :login => 'bob',
      :longest_streak_start => Time.zone.local(2010, 5, 1), 
      :longest_streak_end   => Time.zone.local(2010, 6, 1)
    assert_equal "/~bob/2010/5", user.longest_streak_url
  end

  test "#longest_streak_url without longest streak start" do
    user = Seinfeld::User.new :login => 'bob',
      :longest_streak_end   => Time.zone.local(2010, 6, 1)
    assert_equal "/~bob", user.longest_streak_url
  end

  test "#longest_streak_url without longest streak end" do
    user = Seinfeld::User.new :login => 'bob', 
      :longest_streak_end   => Time.zone.local(2010, 6, 1)
    assert_equal "/~bob", user.longest_streak_url
  end
end