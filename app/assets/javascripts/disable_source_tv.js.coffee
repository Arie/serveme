$ ->

  toggleSourceTVFields = ->
    if sourceTVDisabled()
      disableSourceTVFields()
    else
      enableSourceTVFields()

  sourceTVDisabled = ->
    sourceTVDisabler().is(":checked")

  disableSourceTVFields = ->
    tvPasswordField().attr("disabled", "disabled")
    relayPasswordField().attr("disabled", "disabled")

  enableSourceTVFields = ->
    tvPasswordField().removeAttr("disabled")
    relayPasswordField().removeAttr("disabled")

  sourceTVDisabler = ->
    $("#reservation_disable_source_tv")

  tvPasswordField = ->
    $("#reservation_tv_password")

  relayPasswordField = ->
    $("#reservation_tv_relaypassword")

  addBehavior = ->
    sourceTVDisabler().click (event) ->
      toggleSourceTVFields()

  toggleSourceTVFields()
  addBehavior()
