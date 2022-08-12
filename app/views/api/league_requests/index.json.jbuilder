# frozen_string_literal: true

json.array! @results, partial: 'api/league_requests/result', as: :result, locals: @asns
