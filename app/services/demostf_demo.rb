# typed: true
# frozen_string_literal: true

# A demos.tf demo as people paste its link (`https://demos.tf/1527264`), and a check with the
# demos.tf API that it is there before the live map is sent to play it.
class DemostfDemo
  extend T::Sig

  class Error < StandardError; end

  API_URL = "https://api.demos.tf/demos/"
  LINK = %r{\A(?:https?://)?(?:www\.)?demos\.tf/(\d{1,12})/?(?:[?#]\S*)?\z}i

  attr_reader :id

  sig { params(id: Integer).void }
  def initialize(id)
    @id = id
  end

  # The demo a demos.tf link points to, or nil when the input is not such a link.
  sig { params(input: String).returns(T.nilable(DemostfDemo)) }
  def self.parse(input)
    match = LINK.match(input.strip)
    new(match[1].to_i) if match
  end

  # Checks that demos.tf has the demo. Raises Error with what is wrong.
  sig { returns(DemostfDemo) }
  def check!
    response = Faraday.new(url: API_URL) do |f|
      f.options.timeout = 5
      f.options.open_timeout = 2
    end.get(id.to_s)
    raise Error, "demos.tf has no demo #{id}" if response.status == 404
    raise Error, "demos.tf did not answer about demo #{id}, try again later" unless response.success?

    self
  rescue Faraday::Error
    raise Error, "demos.tf did not answer about demo #{id}, try again later"
  end
end
