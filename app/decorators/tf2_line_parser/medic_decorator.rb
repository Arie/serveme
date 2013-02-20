class TF2LineParser::MedicDecorator < TF2LineParser::PlayerDecorator

  def name
    content_tag(:span, source.name, :class => team.downcase, :title => source.steam_id) +
      content_tag(:i, '', :class => 'icon-ambulance-large')
  end

end
