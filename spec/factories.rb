FactoryGirl.define do

  factory :server, :class => "LocalServer" do
    name "TF2 1"
    path "/home/tf2/tf2-1"
    ip "fakkelbrigade.eu"
    port "27015"
    location
  end

  factory :user do
    uid "123456789"
    nickname "Terminator"
    name "Joe Sixpack"
    provider "steam"
  end

  factory :admin, :class => "User" do
    uid "1337"
    nickname "Admin"
    name "Admin Abuse"
    provider "steam"
    groups { [ Group.donator_group ] }
  end

  factory :reservation do
    association :server
    association :user
    password "secret"
    rcon "supersecret"
    starts_at 1.minute.ago
    ends_at { starts_at + 1.hour }
  end

  factory :group do
    name "Super Secret Servers"
  end

  factory :product do
    name "1 year"
    days 366
    price 9.00
    currency "EUR"
  end

  factory :paypal_order do
    association :product
    association :user
  end

  factory :server_notification do
    message "This is the notification"
    notification_type 'public'
  end

  factory :map_upload do
    association :user
    file do
      temp = Tempfile.new(["map", ".bsp"])
      temp.write("VBSP foobar")
      temp.close
      temp
    end
  end

  factory :location do
    name "Netherlands"
    flag "nl"
  end

end
