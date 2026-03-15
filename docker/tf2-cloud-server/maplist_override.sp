#pragma semicolon 1
#include <sourcemod>

public Plugin:myinfo =
{
	name = "Map List Override",
	author = "serveme.tf",
	description = "Override 'maps' command to report all available maps from serveme.tf",
	version = "1.1",
	url = "https://serveme.tf"
};

#define MAPLIST_PATH "cfg/maplist_full.txt"

new Handle:g_MapList = INVALID_HANDLE;

public OnPluginStart()
{
	g_MapList = CreateArray(PLATFORM_MAX_PATH);
	LoadMapList();
	AddCommandListener(Command_Maps, "maps");
}

public OnMapStart()
{
	LoadMapList();
}

LoadMapList()
{
	ClearArray(g_MapList);

	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "../../%s", MAPLIST_PATH);

	new Handle:file = OpenFile(path, "r");
	if (file == INVALID_HANDLE)
	{
		PrintToServer("[MapListOverride] Could not open %s", path);
		return;
	}

	decl String:line[PLATFORM_MAX_PATH];
	while (ReadFileLine(file, line, sizeof(line)))
	{
		TrimString(line);
		if (strlen(line) > 0)
		{
			PushArrayString(g_MapList, line);
		}
	}
	CloseHandle(file);
	PrintToServer("[MapListOverride] Loaded %d maps from %s", GetArraySize(g_MapList), MAPLIST_PATH);
}

public Action:Command_Maps(client, const String:command[], argc)
{
	decl String:filter[64];
	new bool:hasFilter = false;

	if (argc >= 1)
	{
		GetCmdArg(1, filter, sizeof(filter));
		if (!StrEqual(filter, "*"))
		{
			hasFilter = true;
		}
	}

	new count = 0;
	decl String:mapName[PLATFORM_MAX_PATH];

	for (new i = 0; i < GetArraySize(g_MapList); i++)
	{
		GetArrayString(g_MapList, i, mapName, sizeof(mapName));

		if (hasFilter && StrContains(mapName, filter) == -1)
		{
			continue;
		}

		PrintToServer("PENDING:   (fs) %s", mapName);
		count++;
	}

	PrintToServer("-------------\n%d map(s) in list", count);

	return Plugin_Handled;
}
