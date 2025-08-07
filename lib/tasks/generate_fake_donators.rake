# typed: false
# frozen_string_literal: true

namespace :fake_data do
  desc "Generate fake donators with history"
  task generate_donators: :environment do
    puts "Generating fake donators..."

    # Sample Steam IDs (these are valid format but fake IDs)
    fake_users = [
      { nickname: "RocketJumper", uid: "76561198000000001", joined: 10.years.ago },
      { nickname: "MedicMain2013", uid: "76561198000000002", joined: 8.years.ago },
      { nickname: "xXx_Spy_xXx", uid: "76561198000000003", joined: 6.years.ago },
      { nickname: "HeavyWeaponsGuy", uid: "76561198000000004", joined: 5.years.ago },
      { nickname: "ScoutMaster", uid: "76561198000000005", joined: 4.years.ago },
      { nickname: "DemoKnight", uid: "76561198000000006", joined: 3.years.ago },
      { nickname: "EngineerGaming", uid: "76561198000000007", joined: 2.years.ago },
      { nickname: "SniperElite", uid: "76561198000000008", joined: 18.months.ago },
      { nickname: "PyroShark", uid: "76561198000000009", joined: 1.year.ago },
      { nickname: "SoldierBoy76", uid: "76561198000000010", joined: 6.months.ago },
      { nickname: "CompetitiveTF2", uid: "76561198000000011", joined: 3.months.ago },
      { nickname: "CasualGamer", uid: "76561198000000012", joined: 1.month.ago }
    ]

    # Find or create products if they don't exist
    products = []
    products << Product.find_or_create_by(name: "1 Month") do |p|
      p.price = 5.0
      p.currency = "USD"
      p.days = 31
    end

    products << Product.find_or_create_by(name: "3 Months") do |p|
      p.price = 12.0
      p.currency = "USD"
      p.days = 93
    end

    products << Product.find_or_create_by(name: "6 Months") do |p|
      p.price = 20.0
      p.currency = "USD"
      p.days = 186
    end

    products << Product.find_or_create_by(name: "1 Year") do |p|
      p.price = 35.0
      p.currency = "USD"
      p.days = 365
    end

    donator_group = Group.donator_group

    fake_users.each do |user_data|
      # Create user
      user = User.find_or_create_by(uid: user_data[:uid]) do |u|
        u.provider = "steam"
        u.name = user_data[:nickname]
        u.nickname = user_data[:nickname]
        u.created_at = user_data[:joined]
        u.updated_at = user_data[:joined]
      end

      puts "Processing #{user.nickname}..."

      # Generate donation history based on when they joined
      case user.nickname
      when "RocketJumper"
        # Long-time supporter with many donations
        create_order(user, products[3], 9.years.ago, "Completed") # 1 year
        create_order(user, products[3], 8.years.ago, "Completed") # 1 year
        create_order(user, products[2], 7.years.ago, "Completed") # 6 months
        create_order(user, products[3], 78.months.ago, "Completed") # 1 year (6.5 years)
        create_order(user, products[3], 66.months.ago, "Completed") # 1 year (5.5 years)
        create_order(user, products[1], 54.months.ago, "Completed") # 3 months (4.5 years)
        create_order(user, products[3], 4.years.ago, "Completed") # 1 year
        create_order(user, products[3], 3.years.ago, "Completed") # 1 year
        create_order(user, products[3], 2.years.ago, "Completed") # 1 year
        create_order(user, products[3], 1.year.ago, "Completed") # 1 year
        # Currently active
        add_donator_period(user, donator_group, 9.years.ago, 1.year.from_now)

      when "MedicMain2013"
        # Sporadic supporter
        create_order(user, products[2], 7.years.ago, "Completed") # 6 months
        create_order(user, products[1], 5.years.ago, "Completed") # 3 months
        create_order(user, products[0], 3.years.ago, "Completed") # 1 month
        create_order(user, products[3], 6.months.ago, "Completed") # 1 year
        # Currently active
        add_donator_period(user, donator_group, 6.months.ago, 6.months.from_now)

      when "xXx_Spy_xXx"
        # Was active, now expired
        create_order(user, products[3], 5.years.ago, "Completed") # 1 year
        create_order(user, products[2], 3.years.ago, "Completed") # 6 months
        create_order(user, products[1], 2.years.ago, "Completed") # 3 months
        # Expired 6 months ago
        add_donator_period(user, donator_group, 2.years.ago, 6.months.ago)

      when "HeavyWeaponsGuy"
        # Regular supporter, expiring soon
        create_order(user, products[1], 4.years.ago, "Completed") # 3 months
        create_order(user, products[2], 42.months.ago, "Completed") # 6 months (3.5 years)
        create_order(user, products[3], 30.months.ago, "Completed") # 1 year (2.5 years)
        create_order(user, products[3], 18.months.ago, "Completed") # 1 year (1.5 years)
        create_order(user, products[0], 3.months.ago, "Completed") # 1 month
        # Expiring in 5 days
        add_donator_period(user, donator_group, 3.months.ago, 5.days.from_now)

      when "ScoutMaster"
        # Multiple short donations
        5.times do |i|
          create_order(user, products[0], (3.years - i * 6.months).ago, "Completed") # 1 month each
        end
        # Currently not active

      when "DemoKnight"
        # One big donation
        create_order(user, products[3], 2.years.ago, "Completed") # 1 year
        create_order(user, products[3], 1.year.ago, "Completed") # 1 year
        # Currently active
        add_donator_period(user, donator_group, 1.year.ago, 1.week.from_now)

      when "EngineerGaming"
        # New but committed supporter
        create_order(user, products[3], 1.year.ago, "Completed") # 1 year
        create_order(user, products[3], 1.week.ago, "Completed") # 1 year
        # Currently active for a long time
        add_donator_period(user, donator_group, 1.week.ago, 1.year.from_now)

      when "SniperElite"
        # Failed payment attempts
        create_order(user, products[1], 1.year.ago, "Failed")
        create_order(user, products[1], 11.months.ago, "Completed") # 3 months
        create_order(user, products[0], 6.months.ago, "Failed")
        create_order(user, products[2], 5.months.ago, "Completed") # 6 months
        # Currently active
        add_donator_period(user, donator_group, 5.months.ago, 1.month.from_now)

      when "PyroShark"
        # Recent joiner, immediate supporter
        create_order(user, products[2], 11.months.ago, "Completed") # 6 months
        create_order(user, products[1], 5.months.ago, "Completed") # 3 months
        # Currently active
        add_donator_period(user, donator_group, 5.months.ago, 2.months.from_now)

      when "SoldierBoy76", "CompetitiveTF2", "CasualGamer"
        # New users, not donators yet
        # No orders or donator status
      end
    end

    puts "Fake donators generated successfully!"
    puts "Total users created: #{fake_users.count}"
    puts "Active donators: #{Group.donator_group.users.count}"
  end

  private

  define_method(:create_order) do |user, product, created_at, status|
    PaypalOrder.create!(
      user: user,
      product: product,
      status: status,
      created_at: created_at,
      updated_at: created_at,
      payment_id: "FAKE-#{SecureRandom.hex(8)}"
    )
  end

  define_method(:add_donator_period) do |user, group, starts_at, expires_at|
    user.group_users.where(group: group).destroy_all

    # Add new donator status
    user.group_users.create!(
      group: group,
      expires_at: expires_at,
      created_at: starts_at,
      updated_at: starts_at
    )
  end
end

desc "Alias for fake_data:generate_donators"
task generate_fake_donators: "fake_data:generate_donators"
