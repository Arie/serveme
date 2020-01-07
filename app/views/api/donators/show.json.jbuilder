# frozen_string_literal: true

json.donator do
  json.steam_uid @user.uid
  json.expires_at @donator.expires_at
end
json.actions do
  json.destroy api_donator_url(@user.uid)
end
