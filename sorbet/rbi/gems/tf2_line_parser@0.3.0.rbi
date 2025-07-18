# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `tf2_line_parser` gem.
# Please instead update this file by running `bin/tapioca gem tf2_line_parser`.


# source://tf2_line_parser//lib/tf2_line_parser/version.rb#3
module TF2LineParser; end

# source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#4
module TF2LineParser::Events; end

# source://tf2_line_parser//lib/tf2_line_parser/events/airshot.rb#5
class TF2LineParser::Events::Airshot < ::TF2LineParser::Events::Damage
  # @return [Airshot] a new instance of Airshot
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/airshot.rb#38
  def initialize(time, player_name, player_uid, player_steamid, player_team, target_name, target_uid, target_steamid, target_team, value, weapon, airshot); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/airshot.rb#14
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/airshot.rb#6
    def regex; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/airshot.rb#10
    def regex_airshot; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/airshot.rb#18
    def regex_results(matched_line); end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/assist.rb#5
class TF2LineParser::Events::Assist < ::TF2LineParser::Events::PVPEvent
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/assist.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/assist.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/capture_block.rb#5
class TF2LineParser::Events::CaptureBlock < ::TF2LineParser::Events::Event
  # @return [CaptureBlock] a new instance of CaptureBlock
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/capture_block.rb#14
  def initialize(time, player_name, player_uid, player_steam_id, player_team, cap_number, cap_name); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/capture_block.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/capture_block.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/charge_deployed.rb#5
class TF2LineParser::Events::ChargeDeployed < ::TF2LineParser::Events::Event
  # @return [ChargeDeployed] a new instance of ChargeDeployed
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/charge_deployed.rb#14
  def initialize(time, name, uid, steam_id, team); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/charge_deployed.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/charge_deployed.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#5
class TF2LineParser::Events::Chat < ::TF2LineParser::Events::Event
  # @return [Chat] a new instance of Chat
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#6
  def initialize(time, player_name, player_uid, player_steam_id, player_team, message); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#12
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#16
    def regex_results(matched_line); end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/connect.rb#5
class TF2LineParser::Events::Connect < ::TF2LineParser::Events::Event
  # @return [Connect] a new instance of Connect
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/connect.rb#6
  def initialize(time, player_name, player_uid, player_steam_id, player_team, message); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/connect.rb#12
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/connect.rb#16
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/console_say.rb#5
class TF2LineParser::Events::ConsoleSay < ::TF2LineParser::Events::Event
  # @return [ConsoleSay] a new instance of ConsoleSay
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/console_say.rb#14
  def initialize(time, message); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/console_say.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/console_say.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/current_score.rb#5
class TF2LineParser::Events::CurrentScore < ::TF2LineParser::Events::Score
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/current_score.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#5
class TF2LineParser::Events::Damage < ::TF2LineParser::Events::Event
  # @return [Damage] a new instance of Damage
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#45
  def initialize(time, player_name, player_uid, player_steamid, player_team, target_name, target_uid, target_steamid, target_team, value, weapon); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#22
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#6
    def regex; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#10
    def regex_damage_against; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#14
    def regex_realdamage; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#26
    def regex_results(matched_line); end

    # source://tf2_line_parser//lib/tf2_line_parser/events/damage.rb#18
    def regex_weapon; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/disconnect.rb#5
class TF2LineParser::Events::Disconnect < ::TF2LineParser::Events::Event
  # @return [Disconnect] a new instance of Disconnect
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/disconnect.rb#6
  def initialize(time, player_name, player_uid, player_steam_id, player_team, message); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/disconnect.rb#12
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/disconnect.rb#16
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/domination.rb#5
class TF2LineParser::Events::Domination < ::TF2LineParser::Events::PVPEvent
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/domination.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/domination.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#5
class TF2LineParser::Events::Event
  # Returns the value of attribute airshot.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def airshot; end

  # Sets the attribute airshot
  #
  # @param value the value to set the attribute airshot to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def airshot=(_arg0); end

  # Returns the value of attribute cap_name.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def cap_name; end

  # Sets the attribute cap_name
  #
  # @param value the value to set the attribute cap_name to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def cap_name=(_arg0); end

  # Returns the value of attribute cap_number.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def cap_number; end

  # Sets the attribute cap_number
  #
  # @param value the value to set the attribute cap_number to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def cap_number=(_arg0); end

  # Returns the value of attribute customkill.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def customkill; end

  # Sets the attribute customkill
  #
  # @param value the value to set the attribute customkill to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def customkill=(_arg0); end

  # Returns the value of attribute healing.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def healing; end

  # Sets the attribute healing
  #
  # @param value the value to set the attribute healing to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def healing=(_arg0); end

  # Returns the value of attribute item.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def item; end

  # Sets the attribute item
  #
  # @param value the value to set the attribute item to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def item=(_arg0); end

  # Returns the value of attribute length.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def length; end

  # Sets the attribute length
  #
  # @param value the value to set the attribute length to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def length=(_arg0); end

  # Returns the value of attribute message.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def message; end

  # Sets the attribute message
  #
  # @param value the value to set the attribute message to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def message=(_arg0); end

  # Returns the value of attribute method.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def method; end

  # Sets the attribute method
  #
  # @param value the value to set the attribute method to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def method=(_arg0); end

  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#68
  def parse_time(time_string); end

  # Returns the value of attribute player.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def player; end

  # Sets the attribute player
  #
  # @param value the value to set the attribute player to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def player=(_arg0); end

  # Returns the value of attribute role.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def role; end

  # Sets the attribute role
  #
  # @param value the value to set the attribute role to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def role=(_arg0); end

  # Returns the value of attribute score.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def score; end

  # Sets the attribute score
  #
  # @param value the value to set the attribute score to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def score=(_arg0); end

  # Returns the value of attribute target.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def target; end

  # Sets the attribute target
  #
  # @param value the value to set the attribute target to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def target=(_arg0); end

  # Returns the value of attribute team.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def team; end

  # Sets the attribute team
  #
  # @param value the value to set the attribute team to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def team=(_arg0); end

  # Returns the value of attribute time.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def time; end

  # Sets the attribute time
  #
  # @param value the value to set the attribute time to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def time=(_arg0); end

  # Returns the value of attribute type.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def type; end

  # Sets the attribute type
  #
  # @param value the value to set the attribute type to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def type=(_arg0); end

  # Returns the value of attribute ubercharge.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def ubercharge; end

  # Sets the attribute ubercharge
  #
  # @param value the value to set the attribute ubercharge to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def ubercharge=(_arg0); end

  # Returns the value of attribute unknown.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def unknown; end

  # Sets the attribute unknown
  #
  # @param value the value to set the attribute unknown to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def unknown=(_arg0); end

  # Returns the value of attribute value.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def value; end

  # Sets the attribute value
  #
  # @param value the value to set the attribute value to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def value=(_arg0); end

  # Returns the value of attribute weapon.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def weapon; end

  # Sets the attribute weapon
  #
  # @param value the value to set the attribute weapon to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#6
  def weapon=(_arg0); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#72
    def parse_player_section(section); end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#133
    def parse_target_section(section); end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#25
    def regex_cap; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#29
    def regex_console; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#33
    def regex_message; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#17
    def regex_player; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#45
    def regex_results(matched_line); end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#21
    def regex_target; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#13
    def regex_time; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#9
    def time_format; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/event.rb#37
    def types; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/final_score.rb#5
class TF2LineParser::Events::FinalScore < ::TF2LineParser::Events::Score
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/final_score.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/headshot_damage.rb#5
class TF2LineParser::Events::HeadshotDamage < ::TF2LineParser::Events::Damage
  # @return [HeadshotDamage] a new instance of HeadshotDamage
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/headshot_damage.rb#18
  def initialize(time, player_name, player_uid, player_steamid, player_team, target_name, target_uid, target_steamid, target_team, value, weapon); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/headshot_damage.rb#14
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/headshot_damage.rb#6
    def regex; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/headshot_damage.rb#10
    def regex_headshot; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/heal.rb#5
class TF2LineParser::Events::Heal < ::TF2LineParser::Events::Event
  # @return [Heal] a new instance of Heal
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/heal.rb#14
  def initialize(time, player_name, player_uid, player_steam_id, player_team, target_name, target_uid, target_steam_id, target_team, value); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/heal.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/heal.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/kill.rb#5
class TF2LineParser::Events::Kill < ::TF2LineParser::Events::PVPEvent
  # @return [Kill] a new instance of Kill
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/kill.rb#22
  def initialize(time, player_name, player_uid, player_steam_id, player_team, target_name, target_uid, target_steam_id, target_team, weapon, customkill); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/kill.rb#18
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/kill.rb#6
    def regex; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/kill.rb#14
    def regex_customkill; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/kill.rb#10
    def regex_weapon; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/match_end.rb#5
class TF2LineParser::Events::MatchEnd < ::TF2LineParser::Events::RoundEventWithVariables
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/match_end.rb#10
    def round_type; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/match_end.rb#14
    def round_variable; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/match_end.rb#6
    def round_variable_regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/medic_death.rb#5
class TF2LineParser::Events::MedicDeath < ::TF2LineParser::Events::Event
  # @return [MedicDeath] a new instance of MedicDeath
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/medic_death.rb#18
  def initialize(time, player_name, player_uid, player_steam_id, player_team, target_name, target_uid, target_steam_id, target_team, healing, ubercharge); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/medic_death.rb#14
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/medic_death.rb#6
    def regex; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/medic_death.rb#10
    def regex_medic_death_info; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/pvp_event.rb#5
class TF2LineParser::Events::PVPEvent < ::TF2LineParser::Events::Event
  # @return [PVPEvent] a new instance of PVPEvent
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/pvp_event.rb#10
  def initialize(time, player_name, player_uid, player_steam_id, player_team, target_name, target_uid, target_steam_id, target_team); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/pvp_event.rb#6
    def attributes; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/pickup_item.rb#5
class TF2LineParser::Events::PickupItem < ::TF2LineParser::Events::PlayerActionEvent
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/pickup_item.rb#6
    def action_text; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/pickup_item.rb#18
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/pickup_item.rb#14
    def item; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/pickup_item.rb#10
    def regex_action; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/player_action_event.rb#5
class TF2LineParser::Events::PlayerActionEvent < ::TF2LineParser::Events::Event
  # @return [PlayerActionEvent] a new instance of PlayerActionEvent
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/player_action_event.rb#14
  def initialize(time, player_name, player_uid, player_steam_id, player_team, item = T.unsafe(nil)); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/player_action_event.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/player_action_event.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/point_capture.rb#5
class TF2LineParser::Events::PointCapture < ::TF2LineParser::Events::Event
  # @return [PointCapture] a new instance of PointCapture
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/point_capture.rb#14
  def initialize(time, team, cap_number, cap_name); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/point_capture.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/point_capture.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/rcon_command.rb#5
class TF2LineParser::Events::RconCommand < ::TF2LineParser::Events::Event
  # @return [RconCommand] a new instance of RconCommand
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/rcon_command.rb#18
  def initialize(time, message); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/rcon_command.rb#14
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/rcon_command.rb#6
    def regex; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/rcon_command.rb#10
    def regex_rcon; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/revenge.rb#5
class TF2LineParser::Events::Revenge < ::TF2LineParser::Events::PVPEvent
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/revenge.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/revenge.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/role_change.rb#5
class TF2LineParser::Events::RoleChange < ::TF2LineParser::Events::PlayerActionEvent
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/role_change.rb#6
    def action_text; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/role_change.rb#18
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/role_change.rb#14
    def item; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/role_change.rb#10
    def regex_action; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/round_event_with_variables.rb#5
class TF2LineParser::Events::RoundEventWithVariables < ::TF2LineParser::Events::Event
  # @return [RoundEventWithVariables] a new instance of RoundEventWithVariables
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/round_event_with_variables.rb#14
  def initialize(time, round_variable); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/round_event_with_variables.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/round_event_with_variables.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/round_event_without_variables.rb#5
class TF2LineParser::Events::RoundEventWithoutVariables < ::TF2LineParser::Events::Event
  # @return [RoundEventWithoutVariables] a new instance of RoundEventWithoutVariables
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/round_event_without_variables.rb#14
  def initialize(time); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/round_event_without_variables.rb#10
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/round_event_without_variables.rb#6
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/round_length.rb#5
class TF2LineParser::Events::RoundLength < ::TF2LineParser::Events::RoundEventWithVariables
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/round_length.rb#6
    def round_type; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/round_length.rb#14
    def round_variable; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/round_length.rb#10
    def round_variable_regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/round_stalemate.rb#5
class TF2LineParser::Events::RoundStalemate < ::TF2LineParser::Events::RoundEventWithoutVariables
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/round_stalemate.rb#6
    def round_type; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/round_start.rb#5
class TF2LineParser::Events::RoundStart < ::TF2LineParser::Events::RoundEventWithoutVariables
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/round_start.rb#6
    def round_type; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/round_win.rb#5
class TF2LineParser::Events::RoundWin < ::TF2LineParser::Events::RoundEventWithVariables
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/round_win.rb#6
    def round_type; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/round_win.rb#14
    def round_variable; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/round_win.rb#10
    def round_variable_regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#28
class TF2LineParser::Events::Say < ::TF2LineParser::Events::Chat
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#29
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/score.rb#5
class TF2LineParser::Events::Score < ::TF2LineParser::Events::Event
  # @return [Score] a new instance of Score
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/score.rb#18
  def initialize(time, team, score); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/score.rb#14
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/score.rb#6
    def regex_score; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/score.rb#10
    def regex_team; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/spawn.rb#5
class TF2LineParser::Events::Spawn < ::TF2LineParser::Events::RoleChange
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/spawn.rb#6
    def action_text; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/spawn.rb#10
    def attributes; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/suicide.rb#5
class TF2LineParser::Events::Suicide < ::TF2LineParser::Events::PlayerActionEvent
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/suicide.rb#6
    def action_text; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/suicide.rb#18
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/suicide.rb#14
    def item; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/suicide.rb#10
    def regex_action; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#34
class TF2LineParser::Events::TeamSay < ::TF2LineParser::Events::Chat
  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/chat.rb#35
    def regex; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/events/unknown.rb#5
class TF2LineParser::Events::Unknown < ::TF2LineParser::Events::Event
  # @return [Unknown] a new instance of Unknown
  #
  # source://tf2_line_parser//lib/tf2_line_parser/events/unknown.rb#18
  def initialize(time, unknown); end

  class << self
    # source://tf2_line_parser//lib/tf2_line_parser/events/unknown.rb#14
    def attributes; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/unknown.rb#6
    def regex; end

    # source://tf2_line_parser//lib/tf2_line_parser/events/unknown.rb#10
    def regex_unknown; end
  end
end

# source://tf2_line_parser//lib/tf2_line_parser/line.rb#8
class TF2LineParser::Line
  # @return [Line] a new instance of Line
  #
  # source://tf2_line_parser//lib/tf2_line_parser/line.rb#11
  def initialize(line); end

  # Returns the value of attribute line.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/line.rb#9
  def line; end

  # Sets the attribute line
  #
  # @param value the value to set the attribute line to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/line.rb#9
  def line=(_arg0); end

  # source://tf2_line_parser//lib/tf2_line_parser/line.rb#15
  def parse; end
end

# source://tf2_line_parser//lib/tf2_line_parser/parser.rb#4
class TF2LineParser::Parser
  # @return [Parser] a new instance of Parser
  #
  # source://tf2_line_parser//lib/tf2_line_parser/parser.rb#7
  def initialize(line); end

  # Returns the value of attribute line.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/parser.rb#5
  def line; end

  # Sets the attribute line
  #
  # @param value the value to set the attribute line to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/parser.rb#5
  def line=(_arg0); end

  # source://tf2_line_parser//lib/tf2_line_parser/parser.rb#11
  def parse; end
end

# source://tf2_line_parser//lib/tf2_line_parser/player.rb#4
class TF2LineParser::Player
  # @return [Player] a new instance of Player
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#7
  def initialize(name, uid, steam_id, team); end

  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#14
  def ==(other); end

  # Returns the value of attribute name.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def name; end

  # Sets the attribute name
  #
  # @param value the value to set the attribute name to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def name=(_arg0); end

  # Returns the value of attribute steam_id.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def steam_id; end

  # Sets the attribute steam_id
  #
  # @param value the value to set the attribute steam_id to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def steam_id=(_arg0); end

  # Returns the value of attribute team.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def team; end

  # Sets the attribute team
  #
  # @param value the value to set the attribute team to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def team=(_arg0); end

  # Returns the value of attribute uid.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def uid; end

  # Sets the attribute uid
  #
  # @param value the value to set the attribute uid to.
  #
  # source://tf2_line_parser//lib/tf2_line_parser/player.rb#5
  def uid=(_arg0); end
end

# source://tf2_line_parser//lib/tf2_line_parser/version.rb#4
TF2LineParser::VERSION = T.let(T.unsafe(nil), String)
