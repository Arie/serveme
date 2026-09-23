
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define SPELL_COUNT 16
#define SPELL_RARE	7

ConVar g_cvBanned;
bool   g_Banned[SPELL_COUNT], g_Enabled;

public Plugin myinfo =
{
	name		= "[TF2] Spell Banlist",
	author		= "Coco",
	description = "Banlist for Halloween Spells (both Kart & normal ones)",
	version		= "1.0",
	url			= "@chocochocotorta"
};

public void OnPluginStart()
{
	g_cvBanned = CreateConVar("sm_spellban_spells", "", "Add number of the spell to ban and a comma to add more.\nExample of banning Bats, Lightning Ball & Meteor Shower: 1,7,9");

	HookConVarChange(g_cvBanned, OnCvarChanged);
	LoadBanlist();
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	LoadBanlist();
}

public void OnGameFrame()
{
	if (!g_Enabled)
		return;

	int ent = -1;

	while ((ent = FindEntityByClassname(ent, "tf_weapon_spellbook")) != -1)
	{
		int spell = GetEntProp(ent, Prop_Send, "m_iSelectedSpellIndex");

		if (spell >= 0 && spell < SPELL_COUNT && g_Banned[spell])
			ReplaceSpell(ent, spell);
	}
}

void ReplaceSpell(int spellbook, int oldSpell)
{
	int spell = GetRandomReplacement(oldSpell);

	if (spell == -1)
	{
		SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", -1);
		SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 0);
		return;
	}

	SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", spell);
	SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", GetCharges(spell));
}

int GetRandomReplacement(int oldSpell)
{
	int	 spells[SPELL_COUNT];
	int	 count;

	bool rare = oldSpell >= SPELL_RARE;

	for (int i = 0; i < SPELL_COUNT; i++)
	{
		if (g_Banned[i])
			continue;

		if ((i >= SPELL_RARE) != rare)
			continue;

		spells[count++] = i;
	}

	if (!count)
	{
		for (int i = 0; i < SPELL_COUNT; i++)
			if (!g_Banned[i])
				spells[count++] = i;
	}

	return count ? spells[GetRandomInt(0, count - 1)] : -1;
}

// Just hardcode the quantity of Spellbook charges for Fireball, Bats, Blast Jump and Teleport here
// The others spells only contain 1 charge, so this will be no issue
int GetCharges(int spell)
{
	return (spell == 0 || spell == 1 || spell == 4 || spell == 6) ? 2 : 1;
}

void LoadBanlist()
{
	for (int i = 0; i < SPELL_COUNT; i++)
		g_Banned[i] = false;

	char buffer[128], parts[SPELL_COUNT][8];
	g_cvBanned.GetString(buffer, sizeof(buffer));
	TrimString(buffer);

	// No value, disable it!
	if (buffer[0] == '\0')
	{
		g_Enabled = false;
		return;
	}

	g_Enabled = true;

	int count = ExplodeString(buffer, ",", parts, sizeof(parts), sizeof(parts[]));

	for (int i = 0; i < count; i++)
	{
		TrimString(parts[i]);
		int spell = StringToInt(parts[i]);

		if (spell >= 0 && spell < SPELL_COUNT)
			g_Banned[spell] = true;
	}
}