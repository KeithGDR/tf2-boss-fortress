#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_DESCRIPTION "Create and manage boss archetypes players can play as through easy to use API functions."
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>

#define MAX_BOSSES 256
#define MAX_BOSS_NAME_LENGTH 64

enum struct Boss
{
	char name[MAX_BOSS_NAME_LENGTH];

	void Add(const char[] name)
	{
		strcopy(this.name, sizeof(Boss::name), name);
	}
}

Boss g_Bosses[MAX_BOSSES];
int g_TotalBosses;

public Plugin myinfo = 
{
	name = "[TF2] Boss-Fortress", 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("tf2-boss-fortress.phrases");

	ParseBosses();
}

void ParseBosses()
{
	//Parse the path to where the boss configs are located.
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/boss-fortress/");

	//Check if the directory exists and if it doesn't, make it.
	if (!DirExists(sPath))
		CreateDirectory(sPath, 511);
	
	
}