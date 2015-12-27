# frozen_string_literal: true
class NfoControlPanel

  attr_reader :server_name, :page

  def initialize(server_name)
    @server_name = server_name
  end

  def restart
    login

    page          = agent.get(control_url)

    control_form  = page.form("controlform")
    selects = control_form.field_with(:name => 'selection')
    if selects
      selects.option_with(:value => "restart").click
      agent.submit(control_form, control_form.buttons.first)
    else
      Raven.capture_message("NFO restart error", extra: { page: page.inspect } ) if Rails.env.production?
    end
  end

  private

  def login
    @login ||= begin
                page = agent.get(login_url)
                signin_form = page.form('form')
                signin_form.email     = NFO_EMAIL
                signin_form.password  = NFO_PASSWORD
                agent.submit(signin_form, signin_form.buttons.first)
               end
  end

  def control_url
    "https://www.nfoservers.com/control/control.pl?loadpage=Server%20control&name=#{server_name}&typeofserver=game"
  end

  def agent
    @agent ||= Mechanize.new
  end

  def login_url
    'https://www.nfoservers.com/control/login.html'
  end

end
