class Tf2LineParser::Events::DominationDecorator < TF2LineParser::PvpEventDecorator

  def text
    "#{player.name} dominated #{target.name}"
  end

end
