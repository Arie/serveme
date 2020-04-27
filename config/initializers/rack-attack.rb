class Rack::Attack
  throttle('req/ip', limit: 200, period: 3.minutes) do |req|
    req.ip
  end
  throttle('reservations/i_am_feeling_lucky', limit: 5, period: 60.seconds) do |req|
    if req.path == '/reservations/i_am_feeling_lucky' && req.post?
      req.ip
    end
  end
  self.throttled_response = lambda do |env|
    [ 503,  # status
      {},   # headers
      ['']] # body
  end
end

Rails.application.config.middleware.use Rack::Attack
