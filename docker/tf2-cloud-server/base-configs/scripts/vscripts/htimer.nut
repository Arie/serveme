::HTimer <- {}

function HTimer::OnGameEvent_teamplay_round_start(params)
{
    local old = Entities.FindByName(null, "custom_timer")
    if (old != null)
        old.Kill()

    SpawnEntityFromTable("team_round_timer", {
        targetname = "custom_timer",
        timer_length = 1800,
        max_length = 1800,
        start_paused = 0,
        show_in_hud = 1,
        auto_countdown = 1,
        "OnFinished#1": "custom_win,RoundWin,,0,-1"
    })

    SpawnEntityFromTable("game_round_win", {
        targetname = "custom_win",
        TeamNum = 0,
        force_map_reset = 1
    })

    EntFire("custom_timer", "Enable", "", 0.5)
    EntFire("custom_timer", "ShowInHUD", "1", 0.5)
}

__CollectGameEventCallbacks(HTimer)