module ApplicationHelper

  def just_after_midnight?(clock = Time.now)
    [0, 1, 2].include?(clock.hour)
  end

end
