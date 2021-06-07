# frozen_string_literal: true

Given 'there is a donator only server' do
  @server = create :server, name: 'Donator Only Server', groups: [Group.donator_group]
end
