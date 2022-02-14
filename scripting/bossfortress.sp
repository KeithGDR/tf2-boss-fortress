//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_DESCRIPTION "Boss Fortress is a mod which allows players to be different kinds of bosses."
#define PLUGIN_VERSION "1.0.0"

#define INVALID_BOSS_ID -1

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//ConVars
//ConVar convar_Status;

//Globals
int g_BossID[MAXPLAYERS + 1] = {INVALID_BOSS_ID, ...};

//bossdata
ArrayList g_BossData_List;
StringMap g_BossData_Config;
StringMap g_BossData_Name;
StringMap g_BossData_Model;
StringMap g_BossData_Class;
StringMap g_BossData_ThirdPerson;
StringMap g_BossData_Health;
StringMap g_BossData_Speed;
StringMap g_BossData_HeadSize;
StringMap g_BossData_TorsoSize;
StringMap g_BossData_HandSize;
StringMap g_BossData_Weapons;

public Plugin myinfo = 
{
	name = "Boss Fortress", 
	author = "Keith Warren (Shaders Allen)", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("bossfortress");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	//LoadTranslations("NEWPROJECT.phrases");
	
	//CreateConVar("sm_newproject_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	//convar_Status = CreateConVar("sm_newproject_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	//AutoExecConfig();

	HookEvent("player_spawn", Event_OnPlayerSpawn);

	//bossdata
	g_BossData_List = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_BossData_Config = new StringMap();
	g_BossData_Name = new StringMap();
	g_BossData_Model = new StringMap();
	g_BossData_Class = new StringMap();
	g_BossData_ThirdPerson = new StringMap();
	g_BossData_Health = new StringMap();
	g_BossData_Speed = new StringMap();
	g_BossData_HeadSize = new StringMap();
	g_BossData_TorsoSize = new StringMap();
	g_BossData_HandSize = new StringMap();
	g_BossData_Weapons = new StringMap();

	RegAdminCmd("sm_boss", Command_SetBoss, ADMFLAG_SLAY, "Sets a certain client to a certain boss.");
	RegAdminCmd("sm_setboss", Command_SetBoss, ADMFLAG_SLAY, "Sets a certain client to a certain boss.");
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
			ResetClientBoss(i);
	}
}

public void OnConfigsExecuted()
{
	ParseBossConfigs();
}

void ParseBossConfigs()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/bossfortress/bosses");
	PrintToServer(sPath);

	if (!DirExists(sPath))
	{
		LogError("Error while parsing bosses directory: missing directory");
		return;
	}

	g_BossData_List.Clear();
	g_BossData_Config.Clear();
	g_BossData_Name.Clear();
	g_BossData_Model.Clear();
	g_BossData_Class.Clear();
	g_BossData_ThirdPerson.Clear();
	g_BossData_Health.Clear();
	g_BossData_Speed.Clear();
	g_BossData_HeadSize.Clear();
	g_BossData_TorsoSize.Clear();
	g_BossData_HandSize.Clear();
	g_BossData_Weapons.Clear();

	char sFile[PLATFORM_MAX_PATH];
	char sFullPath[PLATFORM_MAX_PATH];
	FileType type;
	Handle dir = OpenDirectory(sPath);

	while (ReadDirEntry(dir, sFile, sizeof(sFile), type))
	{
		if (type != FileType_File)
			continue;
		
		TrimString(sFile);
		FormatEx(sFullPath, sizeof(sFullPath), "%s/%s", sPath, sFile);
		ParseBossConfig(sFile, sFullPath);
	}

	delete dir;
	LogMessage("Boss configurations parsed successfully. (%i bosses available)", g_BossData_List.Length);
}

void ParseBossConfig(const char[] file, const char[] path)
{
	KeyValues kv = new KeyValues("boss");

	if (kv.ImportFromFile(path) && kv.GetNum("parse_file", 1) == 1)
	{
		g_BossData_List.PushString(file);
		g_BossData_Config.SetString(file, path);
		
		char sName[MAX_NAME_LENGTH];
		kv.GetString("name", sName, sizeof(sName));
		g_BossData_Name.SetString(file, sName);

		char sModel[PLATFORM_MAX_PATH];
		kv.GetString("model", sModel, sizeof(sModel));
		g_BossData_Model.SetString(file, sModel);
		PrepareModel(sModel);

		char sClass[64];
		kv.GetString("class", sClass, sizeof(sClass));
		g_BossData_Class.SetString(file, sClass);

		int thirdperson = kv.GetNum("thirdperson", 1);
		g_BossData_ThirdPerson.SetValue(file, thirdperson);

		int health = kv.GetNum("health", 1000);
		g_BossData_Health.SetValue(file, health);

		float speed = kv.GetFloat("speed", 1.0);
		g_BossData_Speed.SetValue(file, speed);

		float head_size = kv.GetFloat("head_size", 1.0);
		g_BossData_HeadSize.SetValue(file, head_size);

		float torso_size = kv.GetFloat("torso_size", 1.0);
		g_BossData_TorsoSize.SetValue(file, torso_size);

		float hand_size = kv.GetFloat("hand_size", 1.0);
		g_BossData_HandSize.SetValue(file, hand_size);

		if (kv.JumpToKey("weapons") && kv.GotoFirstSubKey())
		{
			StringMap weapons = new StringMap();
			char sSlot[12]; char sWeapon[64]; char sEntity[64]; int index;

			do
			{
				kv.GetSectionName(sSlot, sizeof(sSlot));

				if (strlen(sSlot) == 0)
					continue;

				StringMap slot = new StringMap();

				kv.GetString("weapon", sWeapon, sizeof(sWeapon));
				slot.SetString("weapon", sWeapon);

				kv.GetString("entity", sEntity, sizeof(sEntity));

				if (StrContains(sEntity, "tf_weapon_") != 0)
					Format(sEntity, sizeof(sEntity), "tf_weapon_%s", sEntity);
				
				slot.SetString("entity", sEntity);

				index = kv.GetNum("index");
				slot.SetValue("index", index);

				weapons.SetValue(sSlot, slot);
			}
			while (kv.GotoNextKey());
			
			g_BossData_Weapons.SetValue(file, weapons);

			kv.Rewind();
		}

		PrintToServer("end: %s", kv.GetNum("test") == 1 ? "found" : "not found");
	}

	delete kv;
}

public void OnClientConnected(int client)
{
	g_BossID[client] = INVALID_BOSS_ID;
}

public void OnClientDisconnect_Post(int client)
{
	g_BossID[client] = INVALID_BOSS_ID;
}

bool SetClientBoss(int client, int boss)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client))
		return false;
	
	if (boss == INVALID_BOSS_ID)
	{
		ResetClientBoss(client);
		return true;
	}

	g_BossID[client] = boss;

	char sFile[PLATFORM_MAX_PATH];
	g_BossData_List.GetString(boss, sFile, sizeof(sFile));

	char sName[MAX_NAME_LENGTH];
	g_BossData_Name.GetString(sFile, sName, sizeof(sName));

	PrintToChat(client, "You are now the boss: %s", sName);

	SetBossAttributes(client);

	return true;
}

void ResetClientBoss(int client)
{
	if (g_BossID[client] == INVALID_BOSS_ID)
		return;
	
	g_BossID[client] = INVALID_BOSS_ID;
	PrintToChat(client, "You are no longer a boss.");

	ResetBossAttributes(client);
}

void SetBossAttributes(int client)
{
	if (g_BossID[client] == INVALID_BOSS_ID || !IsPlayerAlive(client))
		return;
	
	int boss = g_BossID[client];

	char sFile[PLATFORM_MAX_PATH];
	g_BossData_List.GetString(boss, sFile, sizeof(sFile));

	//class
	char sClass[64];
	g_BossData_Class.GetString(sFile, sClass, sizeof(sClass));

	if (strlen(sClass) > 0)
	{
		TF2_SetPlayerClass(client, TF2_GetClass(sClass));
		TF2_RegeneratePlayer(client);
	}

	//weapons
	StringMap weapons;
	if (g_BossData_Weapons.GetValue(sFile, weapons) && weapons != null)
	{
		TF2_RemoveAllWeapons(client);

		char sSlot[12]; StringMap slot;
		for (int i = 0; i < 5; i++)
		{
			IntToString(i, sSlot, sizeof(sSlot));
			weapons.GetValue(sSlot, slot);

			if (slot == null)
				continue;
			
			char sEntity[64];
			slot.GetString("entity", sEntity, sizeof(sEntity));

			int index;
			slot.GetValue("index", index);

			int entity = CreateEntityByName(sEntity);

			if (IsValidEntity(entity))
			{
				SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
				SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
				DispatchSpawn(entity);

				EquipPlayerWeapon(client, entity);
			}
		}
	}

	//model
	char sModel[PLATFORM_MAX_PATH];
	g_BossData_Model.GetString(sFile, sModel, sizeof(sModel));

	if (strlen(sModel) > 0 && IsModelPrecached(sModel))
		SetModel(client, sModel);

	//thirdperson
	int thirdperson;
	if (g_BossData_ThirdPerson.GetValue(sFile, thirdperson) && thirdperson == 1)
	{
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
	}

	//health
	int health;
	g_BossData_Health.GetValue(sFile, health);

	if (health < 1)
		health = 1;
	
	SetEntityHealth(client, health);

	//speed
	float speed;
	g_BossData_Speed.GetValue(sFile, speed);

	TF2Attrib_ApplyMoveSpeedBonus(client, speed);

	//head size
	float head_size;
	g_BossData_HeadSize.GetValue(sFile, head_size);
	TF2_SetHeadSize(client, head_size);

	//torso size
	float torso_size;
	g_BossData_TorsoSize.GetValue(sFile, torso_size);
	TF2_SetTorsoSize(client, torso_size);

	//hand size
	float hand_size;
	g_BossData_HandSize.GetValue(sFile, hand_size);
	TF2_SetHandSize(client, hand_size);

}

void ResetBossAttributes(int client)
{
	SetEntityHealth(client, 1);
	TF2_RegeneratePlayer(client);
	
	SetModel(client, "");

	SetVariantInt(0);
	AcceptEntityInput(client, "SetForcedTauntCam");
	
	TF2Attrib_RemoveMoveSpeedBonus(client);
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0)
		SetBossAttributes(client);
}

public Action Command_SetBoss(int client, int args)
{
	if (args == 0)
	{
		OpenBossesMenu(client);
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int target = FindTarget(client, sTarget, false, true);

	if (target == -1)
	{
		ReplyToCommand(client, "Invalid target specified.");
		return Plugin_Handled;
	}

	char sBossID[12];
	GetCmdArg(2, sBossID, sizeof(sBossID));
	int bossid = StringToInt(sBossID);

	if (!IsStringNumber(sBossID))
		bossid = GetBossIDFromName(sBossID);

	SetClientBoss(target, bossid);

	return Plugin_Handled;
}

void OpenBossesMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BossesMenu);
	menu.SetTitle("Pick a boss:");

	menu.AddItem("", "Normal Player");

	char sFile[PLATFORM_MAX_PATH]; char sName[MAX_NAME_LENGTH];
	for (int i = 0; i < g_BossData_List.Length; i++)
	{
		g_BossData_List.GetString(i, sFile, sizeof(sFile));
		g_BossData_Name.GetString(sFile, sName, sizeof(sName));
		menu.AddItem(sFile, strlen(sName) > 0 ? sName : sFile);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_BossesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sFile[PLATFORM_MAX_PATH];
			menu.GetItem(param2, sFile, sizeof(sFile));
			SetClientBoss(param1, strlen(sFile) > 0 ? GetBossIDFromFile(sFile) : INVALID_BOSS_ID);
		}
		case MenuAction_End:
			delete menu;
	}
}

int GetBossIDFromFile(const char[] file)
{
	char sFile[PLATFORM_MAX_PATH];
	for (int i = 0; i < g_BossData_List.Length; i++)
	{
		g_BossData_List.GetString(i, sFile, sizeof(sFile));

		if (StrContains(sFile, file, false) != -1)
			return i;
	}

	return INVALID_BOSS_ID;
}

int GetBossIDFromName(const char[] name)
{
	char sFile[PLATFORM_MAX_PATH]; char sName[MAX_NAME_LENGTH];
	for (int i = 0; i < g_BossData_List.Length; i++)
	{
		g_BossData_List.GetString(i, sFile, sizeof(sFile));
		g_BossData_Name.GetString(sFile, sName, sizeof(sName));

		if (StrContains(sName, name, false) != -1)
			return i;
	}

	return INVALID_BOSS_ID;
}