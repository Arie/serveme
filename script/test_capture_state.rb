# frozen_string_literal: true

#
# Captures host state from the test-host container into a YAML report.
# Uses `docker exec` rather than SSH+sudo because the provisioning narrows
# the app user's sudoers to iptables only.

require "yaml"
require "fileutils"
require "open3"

module TestCaptureState
  REPORT_DIR = "tmp/test_docker_host"
  CONTAINER = "serveme-test-host"

  module_function

  def run(label:, **)
    state = capture
    FileUtils.mkdir_p(REPORT_DIR)
    path = File.join(REPORT_DIR, "#{label}-report.yml")
    File.write(path, state.to_yaml)
    puts "[#{label}] Wrote state report to #{path}"
    puts "=" * 70
    state.each { |k, v| puts format("  %-30s %s", k, v.is_a?(Array) ? v.inspect : v) }
    puts "=" * 70
    state
  end

  def capture
    state = {}
    state["docker_installed"] = exec_yn("which docker > /dev/null 2>&1")
    state["docker_version"] = exec_string("docker --version 2>&1 || echo MISSING")
    state["compose_available"] = exec_string("docker compose version 2>&1 | head -1 || echo MISSING")
    state["app_user_exists"] = exec_yn("id ubuntu > /dev/null 2>&1")
    state["app_user_in_docker_group"] = exec_yn("id -nG ubuntu 2>/dev/null | tr ' ' '\\n' | grep -qx docker")
    state["sudoers_iptables_only"] = exec_yn("grep -q '^ubuntu ALL=(root) NOPASSWD: /usr/sbin/iptables' /etc/sudoers.d/ubuntu 2>/dev/null")
    state["caddyfile_systemd_path"] = exec_yn("test -f /etc/caddy/Caddyfile")
    state["caddyfile_compose_path"] = exec_yn("test -f /opt/serveme-host/Caddyfile")
    state["compose_file_present"] = exec_yn("test -f /opt/serveme-host/docker-compose.yml")
    state["env_file_present"] = exec_yn("test -f /opt/serveme-host/.env")
    state["env_file_mode"] = exec_string("stat -c '%a' /opt/serveme-host/.env 2>/dev/null || echo missing")
    state["caddy_systemd_active"] = exec_string("systemctl is-active caddy 2>/dev/null || echo missing")
    state["websocket_systemd_active"] = exec_string("systemctl is-active websocket-echo 2>/dev/null || echo missing")
    state["docker_containers"] = exec_string("docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null").lines.map(&:strip).reject(&:empty?)
    state["listening_tcp_ports"] = exec_string("ss -tlnH 2>/dev/null | awk '{print $4}' | sort -u").lines.map(&:strip).reject(&:empty?)
    state["websocket_echo_on_8083"] = exec_yn("ss -tln 2>/dev/null | awk '{print $4}' | grep -qE ':8083$'")
    state["caddy_on_80"] = exec_yn("ss -tln 2>/dev/null | awk '{print $4}' | grep -qE ':80$'")
    state["caddy_on_443"] = exec_yn("ss -tln 2>/dev/null | awk '{print $4}' | grep -qE ':443$'")
    state["websocket_responds"] = exec_yn("timeout 2 bash -c 'exec 3<>/dev/tcp/127.0.0.1/8083 && echo OK >&3'")
    state["caddy_redirects_http"] = exec_string("curl -ksS --max-time 5 -o /dev/null -w '%{http_code}' http://localhost/ 2>&1 || echo FAIL")
    state["ufw_status"] = exec_string("ufw status 2>/dev/null | head -1 || echo not-installed")
    state
  end

  def exec_string(cmd)
    out, = Open3.capture2("docker", "exec", CONTAINER, "bash", "-lc", cmd)
    out.strip
  end

  def exec_yn(cmd)
    _, status = Open3.capture2("docker", "exec", CONTAINER, "bash", "-lc", cmd)
    status.success? ? "YES" : "NO"
  end
end

if $PROGRAM_NAME == __FILE__
  label = ARGV[0] || "current"
  TestCaptureState.run(label: label)
end
