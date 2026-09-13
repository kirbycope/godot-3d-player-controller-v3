extends SteamTest
## Purpose: the host's weather is the client's weather. WeatherFX.set_weather on the host fires weather_changed,
## world.gd relays it by RPC and the client's WeatherFX follows, once for a storm and again for snow, so it is the
## change that is seen to cross and not a coincidence of forecasts.


func test_the_hosts_weather_reaches_the_client_and_changes_again() -> void:
	var weather_fx: WeatherFX = world_node("WeatherFX") as WeatherFX
	if is_host:
		weather_fx.set_weather(ClimateData.WeatherType.STORM)
		assert_eq(weather_fx.active_weather, ClimateData.WeatherType.STORM, "The host storms")
		mark("storm")
		await await_step("storm_seen")
		weather_fx.set_weather(ClimateData.WeatherType.SNOW)
		assert_eq(weather_fx.active_weather, ClimateData.WeatherType.SNOW, "then snows")
		mark("snow")
		await await_step("snow_seen")
		weather_fx.set_weather(ClimateData.WeatherType.BLUE_SKY)
		weather_fx.resume_forecast()
	else:
		await await_step("storm")
		await wait_for(func() -> bool: return weather_fx.active_weather == ClimateData.WeatherType.STORM, "The storm reaches the client")
		mark("storm_seen")
		await await_step("snow")
		await wait_for(func() -> bool: return weather_fx.active_weather == ClimateData.WeatherType.SNOW, "and so does the snow")
		mark("snow_seen")
	await barrier("done")
