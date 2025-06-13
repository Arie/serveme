# typed: false
# frozen_string_literal: true

FactoryBot.define do
  factory :file_upload_permission do
    user
    allowed_paths { [ 'addons/sourcemod/configs/' ] }
  end

  factory :server, class: 'LocalServer' do
    name { 'TF2 1' }
    path { '/tmp' }
    ip { '176.9.138.143' }
    port { '27015' }
    rcon { 'secret' }
    location
    latitude { 51 }
    longitude { 9 }
  end

  factory :user do
    uid { '123456789' }
    nickname { 'Terminator' }
    name { 'Joe Sixpack' }
    provider { 'steam' }
    latitude { 52.5 }
    longitude { 5.75 }

    trait :admin do
      after(:create) do |user|
        user.groups << Group.admin_group
      end
    end
  end

  factory :admin, class: 'User' do
    uid { '1337' }
    nickname { 'Admin' }
    name { 'Admin Abuse' }
    provider { 'steam' }
    groups { [ Group.admin_group ] }
  end

  factory :reservation do
    association :server
    association :user
    association :server_config
    password { 'secret' }
    rcon { 'supersecret' }
    starts_at { 1.minute.ago }
    ends_at { starts_at + 1.hour }

    trait :with_zipfile do
      after(:create) do |reservation|
        blob = ActiveStorage::Blob.create!(
          key: SecureRandom.hex,
          filename: 'foo.zip',
          content_type: 'application/zip',
          byte_size: 100,
          checksum: SecureRandom.hex,
          service_name: 'seaweedfs'
        )
        ActiveStorage::Attachment.create!(
          name: 'zipfile',
          record_type: 'Reservation',
          record_id: reservation.id,
          blob_id: blob.id
        )
      end
    end
  end

  factory :server_config do
    file { 'etf2l_6v6.cfg' }
  end

  factory :group do
    name { 'Super Secret Servers' }
  end

  factory :group_user do
    association :group
    association :user
  end

  factory :group_server do
    association :group
    association :server
  end

  factory :product do
    name { '1 year' }
    days { 366 }
    price { 9.00 }
    currency { 'EUR' }
  end

  factory :paypal_order do
    association :product
    association :user
  end

  factory :stripe_order do
    association :product
    association :user
  end

  factory :server_notification do
    message { 'This is the notification' }
    notification_type { 'public' }
  end

  factory :map_upload do
    association :user
    file do
      temp = Tempfile.new([ 'map', '.bsp' ], MAPS_DIR)
      temp.write('VBSP foobar')
      temp.close
      temp
    end
  end

  factory :file_upload do
    association :user
    file do
      temp = Tempfile.new([ 'map', '.bsp' ], MAPS_DIR)
      temp.write('VBSP foobar')
      temp.close
      temp
    end
  end

  factory :server_upload do
    association :server
    association :file_upload
  end

  factory :location do
    name { 'Netherlands' }
    flag { 'nl' }
  end

  factory :reservation_player do
    association :reservation
    association :user
    name { 'reservation player' }
    ip { '127.0.0.1' }
  end

  factory :rating do
    association :reservation
    association :user
    nickname { 'my nickname' }
    opinion { 'good' }
    reason { 'this server is aimaaiizing' }
  end

  factory :player_statistic do
    association :reservation_player
    ping { 100 }
    loss { 0 }
    minutes_connected { 11 }
  end

  factory :server_statistic do
    association :reservation
    association :server
    cpu_usage { 10 }
    fps { 66 }
    traffic_in { 51 }
    traffic_out { 241 }
  end

  factory :voucher do
    association :product
    association :order
    association :created_by,    factory: :user
    association :claimed_by,    factory: :user
    code { 'foobar' }
  end

  factory :reservation_status do
    reservation_id { 1 }
    status { 'this is the status' }
  end

  factory :whitelist_tf do
    tf_whitelist_id { rand(1000) }
    content { 'whitelist content' }
  end

  factory :order do
    association :product
    association :user
  end

  factory :stac_log do
    association :reservation
    filename { 'stac_log.log' }
    contents { 'log content' }
    filesize { 1024 }
  end
end
