# frozen_string_literal: true

json.servers do
  json.partial! 'servers/list', servers: @servers
end
