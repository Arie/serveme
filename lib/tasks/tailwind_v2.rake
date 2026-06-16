# typed: false
# frozen_string_literal: true

require "tailwindcss/ruby"

namespace :tailwind_v2 do
  input  = Rails.root.join("config/tailwind/v2.tailwind.css").to_s
  # Served as a static file from public/ — NOT through Sprockets. Tailwind v4 output
  # (escaped selectors, @layer, modern CSS) is not parseable by this app's sassc-rails
  # pipeline, so the bundle must bypass the asset pipeline entirely.
  output = Rails.root.join("public/builds/v2.css").to_s

  desc "Build the scoped v2 Tailwind bundle"
  task :build do
    FileUtils.mkdir_p(File.dirname(output))
    command = [ Tailwindcss::Ruby.executable, "-i", input, "-o", output, "--minify" ]
    puts "Building v2.css: #{command.join(' ')}"
    system(*command, exception: true)
  end

  desc "Watch and rebuild the v2 Tailwind bundle"
  task :watch do
    FileUtils.mkdir_p(File.dirname(output))
    command = [ Tailwindcss::Ruby.executable, "-i", input, "-o", output, "--watch" ]
    system(*command, exception: true)
  end
end

# Ensure the bundle is built before assets are precompiled (Kamal deploy).
if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance([ "tailwind_v2:build" ])
end
