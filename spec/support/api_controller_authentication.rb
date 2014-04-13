module ApiControllerAuthentication

  def self.included(base)
    base.extend Macros
  end

  module Macros

    def stub_api_authentication
      before do
        controller.stub(:verify_api_key)
      end
    end

  end

end

RSpec.configuration.include(ApiControllerAuthentication, :type => :controller)
