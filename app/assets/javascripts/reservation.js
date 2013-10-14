jQuery(function($) {
  function formatServer(server) {
    element = server.element;
    return "<span class='flags flags-" + $(element).data('flag') + "'></span>" + server.text;
  };

  function enableDefaultWhitelist() {
    $("#reservation_whitelist_id").val('');
    $(".reservation_whitelist").hide();
    $("#reservation_custom_whitelist_id").val('');
    $(".reservation_custom_whitelist_id").hide();
  };

  function enableLeagueWhitelist() {
    $(".reservation_whitelist").show();
    $("#reservation_custom_whitelist_id").val('', true);
    $(".reservation_custom_whitelist_id").hide();
  };

  function enableCustomWhitelist() {
    $(".reservation_custom_whitelist_id").show();
    $("#reservation_whitelist_id").val('');
    $(".reservation_whitelist").hide();
  };

  if ($("#whitelist_type_default_whitelist").is(':checked'))  { enableDefaultWhitelist(); };
  if ($("#whitelist_type_league_whitelist").is(':checked')) { enableLeagueWhitelist(); };
  if ($("#whitelist_type_custom_whitelist").is(':checked')) { enableCustomWhitelist(); };

  $("#reservation_first_map").select2();

  $("#reservation_server_id").select2({
    formatResult: formatServer,
    formatSelection: formatServer,
    escapeMarkup: function(m) { return m }
  });

  $("#whitelist_type_default_whitelist").change(function() {
    enableDefaultWhitelist();
  });

  $("#whitelist_type_custom_whitelist").change(function() {
  enableCustomWhitelist();
  });

  $("#whitelist_type_league_whitelist").change(function() {
    enableLeagueWhitelist();
  });

});
