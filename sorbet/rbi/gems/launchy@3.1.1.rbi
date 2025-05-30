# typed: strict

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `launchy` gem.
# Please instead update this file by running `bin/tapioca gem launchy`.


# The entry point into Launchy. This is the sole supported public API.
#
#   Launchy.open( uri, options = {} )
#
# The currently defined global options are:
#
#   :debug        Turn on debugging output
#   :application  Explicitly state what application class is going to be used.
#                 This must be a child class of Launchy::Application
#   :host_os      Explicitly state what host operating system to pretend to be
#   :dry_run      Do nothing and print the command that would be executed on $stdout
#
# Other options may be used, and those will be passed directly to the
# application class
#
# source://launchy//lib/launchy.rb#24
module Launchy
  class << self
    # source://launchy//lib/launchy.rb#60
    def app_for_name(name); end

    # source://launchy//lib/launchy.rb#56
    def app_for_uri(uri); end

    # source://launchy//lib/launchy.rb#66
    def app_for_uri_string(str); end

    # source://launchy//lib/launchy.rb#113
    def application; end

    # source://launchy//lib/launchy.rb#109
    def application=(app); end

    # source://launchy//lib/launchy.rb#133
    def bug_report_message; end

    # source://launchy//lib/launchy.rb#99
    def debug=(enabled); end

    # we may do logging before a call to 'open', hence the need to check
    # LAUNCHY_DEBUG here
    #
    # @return [Boolean]
    #
    # source://launchy//lib/launchy.rb#105
    def debug?; end

    # source://launchy//lib/launchy.rb#125
    def dry_run=(dry_run); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy.rb#129
    def dry_run?; end

    # source://launchy//lib/launchy.rb#91
    def extract_global_options(options); end

    # source://launchy//lib/launchy.rb#121
    def host_os; end

    # source://launchy//lib/launchy.rb#117
    def host_os=(host_os); end

    # source://launchy//lib/launchy.rb#137
    def log(msg); end

    # Launch an application for the given uri string
    #
    # source://launchy//lib/launchy.rb#29
    def open(uri_s, options = T.unsafe(nil)); end

    # source://launchy//lib/launchy.rb#141
    def path; end

    # source://launchy//lib/launchy.rb#145
    def path=(path); end

    # source://launchy//lib/launchy.rb#83
    def reset_global_options; end

    # @raise [Launchy::ArgumentError]
    #
    # source://launchy//lib/launchy.rb#70
    def string_to_uri(str); end

    private

    # source://launchy//lib/launchy.rb#151
    def to_bool(arg); end
  end
end

# Application is the base class of all the application types that launchy may
# invoke. It essentially defines the public api of the launchy system.
#
# Every class that inherits from Application must define:
#
# 1. A constructor taking no parameters
# 2. An instance method 'open' taking a string or URI as the first parameter and a
#    hash as the second
# 3. A class method 'handles?' that takes a String and returns true if that
#    class can handle the input.
#
# source://launchy//lib/launchy/application.rb#16
class Launchy::Application
  extend ::Launchy::DescendantTracker

  # @return [Application] a new instance of Application
  #
  # source://launchy//lib/launchy/application.rb#66
  def initialize; end

  # source://launchy//lib/launchy/application.rb#71
  def find_executable(bin, *paths); end

  # Returns the value of attribute host_os_family.
  #
  # source://launchy//lib/launchy/application.rb#64
  def host_os_family; end

  # source://launchy//lib/launchy/application.rb#75
  def run(cmd, *args); end

  # Returns the value of attribute runner.
  #
  # source://launchy//lib/launchy/application.rb#64
  def runner; end

  class << self
    # Find the given executable in the available paths
    #
    # returns the path to the executable or nil if not found
    #
    # source://launchy//lib/launchy/application.rb#43
    def find_executable(bin, *paths); end

    # Find the application with the given name
    #
    # returns the Class that has the given name
    #
    # @raise [ApplicationNotFoundError]
    #
    # source://launchy//lib/launchy/application.rb#33
    def for_name(name); end

    # Find the application that handles the given uri.
    #
    # returns the Class that can handle the uri
    #
    # @raise [ApplicationNotFoundError]
    #
    # source://launchy//lib/launchy/application.rb#23
    def handling(uri); end

    # Does this class have the given name-like string?
    #
    # returns true if the class has the given name
    #
    # @return [Boolean]
    #
    # source://launchy//lib/launchy/application.rb#59
    def has_name?(qname); end
  end
end

# The class handling the browser application and all of its schemes
#
# source://launchy//lib/launchy/applications/browser.rb#8
class Launchy::Application::Browser < ::Launchy::Application
  # use a call back mechanism to get the right app_list that is decided by the
  # host_os_family class.
  #
  # source://launchy//lib/launchy/applications/browser.rb#42
  def app_list; end

  # Get the full commandline of what we are going to add the uri to
  #
  # @raise [Launchy::CommandNotFoundError]
  #
  # source://launchy//lib/launchy/applications/browser.rb#56
  def browser_cmdline; end

  # source://launchy//lib/launchy/applications/browser.rb#46
  def browser_env; end

  # source://launchy//lib/launchy/applications/browser.rb#74
  def cmd_and_args(uri, _options = T.unsafe(nil)); end

  # source://launchy//lib/launchy/applications/browser.rb#25
  def cygwin_app_list; end

  # hardcode this to open?
  #
  # source://launchy//lib/launchy/applications/browser.rb#30
  def darwin_app_list; end

  # source://launchy//lib/launchy/applications/browser.rb#34
  def nix_app_list; end

  # final assembly of the command and do %s substitution
  # http://www.catb.org/~esr/BROWSER/index.html
  #
  # source://launchy//lib/launchy/applications/browser.rb#83
  def open(uri, options = T.unsafe(nil)); end

  # The escaped \\ is necessary so that when shellsplit is done later,
  # the "launchy", with quotes, goes through to the commandline, since that
  #
  # source://launchy//lib/launchy/applications/browser.rb#21
  def windows_app_list; end

  class << self
    # @return [Boolean]
    #
    # source://launchy//lib/launchy/applications/browser.rb#13
    def handles?(uri); end

    # source://launchy//lib/launchy/applications/browser.rb#9
    def schemes; end
  end
end

# source://launchy//lib/launchy/error.rb#5
class Launchy::ApplicationNotFoundError < ::Launchy::Error; end

# source://launchy//lib/launchy/error.rb#7
class Launchy::ArgumentError < ::Launchy::Error; end

# Internal: Ecapsulate the commandline argumens passed to Launchy
#
# source://launchy//lib/launchy/argv.rb#6
class Launchy::Argv
  # @return [Argv] a new instance of Argv
  #
  # source://launchy//lib/launchy/argv.rb#9
  def initialize(*args); end

  # source://launchy//lib/launchy/argv.rb#37
  def ==(other); end

  # source://launchy//lib/launchy/argv.rb#21
  def [](idx); end

  # Returns the value of attribute argv.
  #
  # source://launchy//lib/launchy/argv.rb#7
  def argv; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/argv.rb#29
  def blank?; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/argv.rb#33
  def executable?; end

  # source://launchy//lib/launchy/argv.rb#13
  def to_s; end

  # source://launchy//lib/launchy/argv.rb#17
  def to_str; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/argv.rb#25
  def valid?; end
end

# Internal: Command line interface for Launchy
#
# source://launchy//lib/launchy/cli.rb#8
class Launchy::Cli
  # @return [Cli] a new instance of Cli
  #
  # source://launchy//lib/launchy/cli.rb#11
  def initialize; end

  # source://launchy//lib/launchy/cli.rb#70
  def error_output(error); end

  # source://launchy//lib/launchy/cli.rb#63
  def good_run(argv, env); end

  # Returns the value of attribute options.
  #
  # source://launchy//lib/launchy/cli.rb#9
  def options; end

  # source://launchy//lib/launchy/cli.rb#56
  def parse(argv, _env); end

  # source://launchy//lib/launchy/cli.rb#15
  def parser; end

  # source://launchy//lib/launchy/cli.rb#80
  def run(argv = T.unsafe(nil), env = T.unsafe(nil)); end
end

# source://launchy//lib/launchy/error.rb#6
class Launchy::CommandNotFoundError < ::Launchy::Error; end

# Use by either
#
#   class Foo
#     extend DescendantTracker
#   end
#
# or
#
#   class Foo
#     class << self
#       include DescendantTracker
#     end
#   end
#
# It will track all the classes that inherit from the extended class and keep
# them in a Set that is available via the 'children' method.
#
# source://launchy//lib/launchy/descendant_tracker.rb#24
module Launchy::DescendantTracker
  # The list of children that are registered
  #
  # source://launchy//lib/launchy/descendant_tracker.rb#35
  def children; end

  # Find one of the child classes by calling the given method
  # and passing all the rest of the parameters to that method in
  # each child
  #
  # source://launchy//lib/launchy/descendant_tracker.rb#44
  def find_child(method, *args); end

  # source://launchy//lib/launchy/descendant_tracker.rb#25
  def inherited(klass); end
end

# Internal: Namespace for detecting the environment that Launchy is running in
#
# source://launchy//lib/launchy/detect.rb#6
module Launchy::Detect; end

# Internal: Determine the host operating system that Launchy is running on
#
# source://launchy//lib/launchy/detect/host_os.rb#9
class Launchy::Detect::HostOs
  # @return [HostOs] a new instance of HostOs
  #
  # source://launchy//lib/launchy/detect/host_os.rb#14
  def initialize(host_os = T.unsafe(nil)); end

  # source://launchy//lib/launchy/detect/host_os.rb#26
  def default_host_os; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os.rb#10
  def host_os; end

  # source://launchy//lib/launchy/detect/host_os.rb#30
  def override_host_os; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os.rb#10
  def to_s; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os.rb#10
  def to_str; end
end

# Detect the current host os family
#
# If the current host familiy cannot be detected then return
# HostOsFamily::Unknown
#
# source://launchy//lib/launchy/detect/host_os_family.rb#9
class Launchy::Detect::HostOsFamily
  extend ::Launchy::DescendantTracker

  # @return [HostOsFamily] a new instance of HostOsFamily
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#44
  def initialize(host_os = T.unsafe(nil)); end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#60
  def cygwin?; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#52
  def darwin?; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#42
  def host_os; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#56
  def nix?; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#48
  def windows?; end

  class << self
    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#37
    def cygwin?; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#29
    def darwin?; end

    # @raise [NotFoundError]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#14
    def detect(host_os = T.unsafe(nil)); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#21
    def matches?(host_os); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#33
    def nix?; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#25
    def windows?; end
  end
end

# Cygwin - if anyone is still using that
#
# source://launchy//lib/launchy/detect/host_os_family.rb#101
class Launchy::Detect::HostOsFamily::Cygwin < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#106
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#102
    def matching_regex; end
  end
end

# Mac OS X family
#
# source://launchy//lib/launchy/detect/host_os_family.rb#79
class Launchy::Detect::HostOsFamily::Darwin < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#84
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#80
    def matching_regex; end
  end
end

# All the *nix family of operating systems, and BSDs
#
# source://launchy//lib/launchy/detect/host_os_family.rb#90
class Launchy::Detect::HostOsFamily::Nix < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#95
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#91
    def matching_regex; end
  end
end

# source://launchy//lib/launchy/detect/host_os_family.rb#10
class Launchy::Detect::HostOsFamily::NotFoundError < ::Launchy::Error; end

# ---------------------------
# All known host os families
# ---------------------------
#
# source://launchy//lib/launchy/detect/host_os_family.rb#68
class Launchy::Detect::HostOsFamily::Windows < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#73
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#69
    def matching_regex; end
  end
end

# Detect the current desktop environment for *nix machines
# Currently this is Linux centric. The detection is based upon the detection
# used by xdg-open from http://portland.freedesktop.org/
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#9
class Launchy::Detect::NixDesktopEnvironment
  extend ::Launchy::DescendantTracker

  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#28
    def browsers; end

    # Detect the current *nix desktop environment
    #
    # If the current dekstop environment be detected, the return
    # NixDekstopEnvironment::Unknown
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#18
    def detect; end

    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#24
    def fallback_browsers; end
  end
end

# Gnome desktop environment
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#49
class Launchy::Detect::NixDesktopEnvironment::Gnome < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#55
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#50
    def is_current_desktop_environment?; end
  end
end

# KDE desktop environment
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#37
class Launchy::Detect::NixDesktopEnvironment::Kde < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#43
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#38
    def is_current_desktop_environment?; end
  end
end

# The one that is found when all else fails. And this must be declared last
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#87
class Launchy::Detect::NixDesktopEnvironment::NotFound < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#92
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#88
    def is_current_desktop_environment?; end
  end
end

# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#10
class Launchy::Detect::NixDesktopEnvironment::NotFoundError < ::Launchy::Error; end

# Fall back environment as the last case
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#76
class Launchy::Detect::NixDesktopEnvironment::Xdg < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#81
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#77
    def is_current_desktop_environment?; end
  end
end

# Xfce desktop environment
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#61
class Launchy::Detect::NixDesktopEnvironment::Xfce < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#70
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#62
    def is_current_desktop_environment?; end
  end
end

# source://launchy//lib/launchy/error.rb#4
class Launchy::Error < ::StandardError; end

# Internal: Run a command in a child process
#
# source://launchy//lib/launchy/runner.rb#7
class Launchy::Runner
  # source://launchy//lib/launchy/runner.rb#48
  def commandline_normalize(cmdline); end

  # source://launchy//lib/launchy/runner.rb#33
  def dry_run(cmd, *args); end

  # source://launchy//lib/launchy/runner.rb#8
  def run(cmd, *args); end

  # cut it down to just the shell commands that will be passed to exec or
  # posix_spawn. The cmd argument is split according to shell rules and the
  # args are not escaped because the whole set is passed to system as *args
  # and in that case system shell escaping rules are not done.
  #
  # source://launchy//lib/launchy/runner.rb#42
  def shell_commands(cmd, args); end

  # source://launchy//lib/launchy/runner.rb#21
  def wet_run(cmd, *args); end
end

# source://launchy//lib/launchy/version.rb#4
Launchy::VERSION = T.let(T.unsafe(nil), String)

# Internal: Version number of Launchy
#
# source://launchy//lib/launchy/version.rb#7
module Launchy::Version
  class << self
    # source://launchy//lib/launchy/version.rb#12
    def to_a; end

    # source://launchy//lib/launchy/version.rb#16
    def to_s; end
  end
end

# source://launchy//lib/launchy/version.rb#8
Launchy::Version::MAJOR = T.let(T.unsafe(nil), Integer)

# source://launchy//lib/launchy/version.rb#9
Launchy::Version::MINOR = T.let(T.unsafe(nil), Integer)

# source://launchy//lib/launchy/version.rb#10
Launchy::Version::PATCH = T.let(T.unsafe(nil), Integer)
