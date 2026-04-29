# frozen_string_literal: true

#
# Provisions the running serveme-test-host container via DockerHostSetupService
# and captures host state for BEFORE/AFTER comparison.
#
# Invoked via `bin/rails runner script/test_provision_host.rb <label> <key_path> <ssh_port>`.

require "net/ssh"
require_relative "test_capture_state"

label = ARGV[0] || "current"
key_path = ARGV[1] || "tmp/test_docker_host/key"
ssh_port = (ARGV[2] || "12222").to_i

location = Location.first || raise("Need at least one Location seeded for the test")

host = DockerHost.new(
  city: "Test",
  hostname: "test.local",
  ip: "127.0.0.1",
  start_port: 27115,
  max_containers: 1,
  ssh_user: "ubuntu",
  ssh_port: ssh_port,
  location: location,
  setup_status: "ssh_verified",
  active: false
)
host.id = 999_999
host.define_singleton_method(:update!) { |*_|self }
host.define_singleton_method(:update_columns) { |*_|self }
host.define_singleton_method(:reload) { self }
host.define_singleton_method(:save!) { |*_|self }
host.define_singleton_method(:save) { |*_|true }

service = DockerHostSetupService.new(host)
service.define_singleton_method(:ssh_to_host) do |&block|
  # Connect as root: the app user's sudoers gets narrowed mid-provision,
  # which would break the remaining steps if we connected as them.
  Net::SSH.start(
    "127.0.0.1", "root",
    port: ssh_port,
    keys: [ key_path ],
    keys_only: true,
    verify_host_key: :never,
    timeout: 15
  ) { |ssh| block.call(ssh) }
end
service.define_singleton_method(:local_ssh_public_key) { File.read("#{key_path}.pub").strip }

puts "[#{label}] Running provision_host…"
result = service.provision_host
puts "[#{label}] provision_host result: #{result.inspect}"
sleep 5
TestCaptureState.run(label: label, key_path: key_path, ssh_port: ssh_port)
