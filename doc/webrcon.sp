/*
Based on F2s logs.tf plugin and how it handles the !logs command
*/

#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <f2stocks>
#include <smlib>
#include <morecolors>
#undef REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0.0"

public Plugin:myinfo = {
	name        = "Web RCON Plugin",
	author      = "Arie",
	description = "Triggers the web rcon page on demand",
	version     = PLUGIN_VERSION,
	url         = "https://serveme.tf"
};

new Handle:g_hCvarWebRconUrl;

public OnPluginStart()
{
	RegConsoleCmd("say", Command_say);

	g_hCvarWebRconUrl = CreateConVar("sm_web_rcon_url", "", "URL for web RCON", FCVAR_NONE);
}

new Float:g_fSSTime[MAXPLAYERS + 1];


public Action:Command_say(client, args)
{
	if (client == 0)
		return Plugin_Continue;

	decl String:text[256];
	GetCmdArgString(text, sizeof(text));
	if (text[0] == '"' && strlen(text) >= 2)
	{
		strcopy(text, sizeof(text), text[1]);
		text[strlen(text) - 1] = '\0';
	}
	String_Trim(text, text, sizeof(text));

	if (StrEqual(text, "!webrcon", false) || StrEqual(text, ".webrcon", false))
	{
		// Check if the client has disable html motd.
		g_fSSTime[client] = GetTickedTime();
		QueryClientConVar(client, "cl_disablehtmlmotd", QueryConVar_DisableHtmlMotd);
	}

	return Plugin_Continue;
}


public QueryConVar_DisableHtmlMotd(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (!IsClientValid(client))
		return;

	if (result == ConVarQuery_Okay)
	{
		if (StringToInt(cvarValue) != 0)
		{
			decl String:nickname[32];
			GetClientName(client, nickname, sizeof(nickname));

			CPrintToChat(client, "%s%s%s", "{lightgreen}[WebRCON] {default}", nickname, ": To see web rcon in-game, you need to set: {aqua}cl_disablehtmlmotd 0");
			return;
		}
	}

	new Float:waitTime = 0.3;
	waitTime -= GetTickedTime() - g_fSSTime[client];
	if (waitTime <= 0.0)
		waitTime = 0.01;

	CreateTimer(waitTime, Timer_ShowRcon, client, TIMER_FLAG_NO_MAPCHANGE);
}


public Action:BlockSay(client, const String:text[], bool:teamSay)
{
	if (teamSay)
		return Plugin_Continue;
	if (StrEqual(text, "!webrcon", false) && Client_IsAdmin(client))
		return Plugin_Handled;
	return Plugin_Continue;
}


public Action:Timer_ShowRcon(Handle:timer, any:client)
{
	if (!IsClientValid(client))
		return;

	decl String:url[64];
	GetConVarString(g_hCvarWebRconUrl, url, sizeof(url));

	decl String:num[3];
	new Handle:Kv = CreateKeyValues("data");
	IntToString(MOTDPANEL_TYPE_URL, num, sizeof(num));
	KvSetString(Kv, "title", "Web RCON");
	KvSetString(Kv, "type", num);
	KvSetString(Kv, "msg", url);
	KvSetNum(Kv, "customsvr", 1);
	ShowVGUIPanel(client, "info", Kv);
	CloseHandle(Kv);
}
