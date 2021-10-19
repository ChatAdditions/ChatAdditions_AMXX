#include <amxmodx>
#include <ChatAdditions>
#include <CA_GAG_API>
#include <amxmisc>

#pragma ctrlchar '\'

new Float: g_flUserRequestTimeout[MAX_PLAYERS + 1];

static cvar_ca_requestungag_command[32],
	cvar_ca_requestungag_admin_flag[16],
	Float: cvar_ca_requestungag_delay;

public stock const PluginName[] = "CA Addon: Request UnGAG"
public stock const PluginVersion[] = CA_VERSION
public stock const PluginAuthor[] = "steelzzz"
public stock const PluginURL[] = "github.com/ChatAdditions/ChatsAdditions_AMXX"
public stock const PluginDescription[] = "Edit me";

public plugin_init()
{
	register_plugin(PluginName, PluginVersion, PluginAuthor);
	register_dictionary("CA_Addon_RequestUngag.txt");
	
	Register_CVars();
	AutoExecConfig(true, "CA_Addon_RequestUnGag", "ChatAdditions");

	register_clcmd(cvar_ca_requestungag_command, "Command_RequestUngag");

	new accessFlag = read_flags(cvar_ca_requestungag_admin_flag);
	register_clcmd("say", "Hook_Say", accessFlag, .FlagManager = false);
}

public Register_CVars()
{
	bind_pcvar_string(create_cvar("ca_requestungag_command", "say /sorry",
		.description = "Request ungag command"),
		cvar_ca_requestungag_command, charsmax(cvar_ca_requestungag_command)
	);
	
	bind_pcvar_string(create_cvar("ca_requestungag_admin_flag", "a",
		.description = "Admin Flag"),
		cvar_ca_requestungag_admin_flag, charsmax(cvar_ca_requestungag_admin_flag)
  );

	bind_pcvar_float(create_cvar("ca_requestungag_delay", "5.0",
		.description = "delay time request ungag",
		.has_min = true, .min_val = 1.0), 
	cvar_ca_requestungag_delay);
}

public Command_RequestUngag(iPlayer)
{
	if(!ca_has_user_gag(iPlayer))
	{
		client_print_color(iPlayer, print_team_default, "^4* ^1У вас нет мута.");
		return PLUGIN_HANDLED;
	}

	if(g_flUserRequestTimeout[iPlayer] > get_gametime())
	{
		client_print_color(iPlayer, print_team_default, "^4* ^1Попробуйте через %d сек.", floatround(g_flUserRequestTimeout[iPlayer] - get_gametime()));
		return PLUGIN_HANDLED;
	}

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i) || is_user_hltv(i) || is_user_bot(i))
		{
			continue;
		}

		if(~get_user_flags(i) & read_flags(cvar_ca_requestungag_admin_flag))
		{
			continue;
		}

		client_print_color(i, print_team_default, "^4* ^1Игрок ^4%n ^1просит снять мут, чтобы снять мут, напишите /unmute %d", iPlayer, iPlayer);
	}

	g_flUserRequestTimeout[iPlayer] = get_gametime() + cvar_ca_requestungag_delay;

	client_print_color(iPlayer, print_team_default, "^4* ^1Вы попросили снять гаг.");
	return PLUGIN_HANDLED;
}

public Hook_Say(iPlayer, iAccessLevel, iCid)
{
	if(!cmd_access(iPlayer, iAccessLevel, iCid, 1))
	{
		return PLUGIN_CONTINUE;
	}

	new sArgs[20];
	read_args(sArgs, charsmax(sArgs));

	remove_quotes(sArgs);

	/*if(containi(sArgs[1], "unmute") == -1)
	{
		return PLUGIN_CONTINUE;
	}

	replace(sArgs, charsmax(sArgs), "/unmute", "");*/
	new const strFind[] = "unmute";

	if(strncmp(sArgs[1], strFind, charsmax(strFind)) != 0)
	{
		return PLUGIN_CONTINUE
  	}

	new sUserId[3];
	copy(sUserId, charsmax(sUserId), sArgs[8]);

	new iUserId = str_to_num(sUserId);

	if(!is_user_connected(iUserId))
	{
		return PLUGIN_CONTINUE;
	}

	if(!ca_has_user_gag(iUserId))
	{
		return PLUGIN_CONTINUE;
	}

	ca_remove_user_gag(iUserId, iPlayer);
	client_print_color(iPlayer, print_team_default, "^4* ^1Вы успешно сняли мут с игрока %n", iUserId);

	return PLUGIN_CONTINUE;
}