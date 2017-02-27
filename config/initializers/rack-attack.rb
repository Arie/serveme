class Rack::Attack
  throttle('reservations/i_am_feeling_lucky', limit: 5, period: 60.seconds) do |req|
    if req.path == '/reservations/i_am_feeling_lucky' && req.post?
      req.ip
    end
  end
end

Rails.application.config.middleware.use Rack::Attack
