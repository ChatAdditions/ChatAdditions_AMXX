// ￿
//https://dev-cs.ru/threads/222/page-2#post-30354

#if defined _gamecms_groups_included
	#endinput
#endif
#define _gamecms_groups_included

#if !defined MAX_FMT_LENGTH
	#define MAX_FMT_LENGTH 256
#endif

/*
	Использование группы пользователя для выдачи флагов:
	1. вариант
		- флаги берутся из нижеуказанного массива
		- номера в массиве- это поле id ваших групп в таблице users_groups
		- содержимое массива - флаги, которые будут выданы игроку
		- флаги будут выданы на всех серверах, где установлен данный плагин с использованием функции выдачи флагов группы
			Это полезно, например, для главного админа. Не нужно выдавать услугу на каждый сервер.
	2. вариант
		- создаем на сайте услуги, при присвоении которой будет выдаваться какая-то группа
		- флаги, указанные при создании услуги будут присвоены игроку, которому выдана эта группа
		- услуга должна быть создана для каждого сервера, где работает присвоение флагов по группе
	Минусы:
		- создание услуг для 2-го варианта ничем не проще обычной выдачи услуги
		- присвоение флагов происходит после получения информации с сайта об игроке
			Некоторые плагины, которые читают флаги при подключении игрока не будут эти флаги видеть
			Это исправляется в исходниках тех плагинов.
		- для получения флагов по группе у игрока должен быть указан SteamID в профиле
	Особенности:
		- не конфликтует с выдачей флагов по услугам
		- можно использовать только для определенных групп, например, как в нижеуказанном массиве
		- не зависит от команды перезагрузки админов (amx_reloadadmins)
		- реагирует на команду перезагрузки пользователя (cms_reloadusers)
		- работает только по SteamID из профиля
		- добавляет флаги по имеющимся услугам, если они отсутствуют во флагах группы
			Например, ВИПу выданы флаги "abcd" по группе + флаги "ptr" по имеющейся услуге (услугам)
		- меню для управления группой (смены группы) пользователя "на лету"
*/

////////
#if defined FROM_ARRAY
new Trie:trhGroupFlags;
#endif
///////////

enum _:GroupInfo
{
	GroupId,
	GroupName[MAX_STRING_LEN*2],
	GroupFlags[MAX_STRING_LEN]
};

new pGroupCmd, g_bitGroupCmdAccess, pnum, item_callback, item_access;
new Array:g_GroupInfo;
new g_MenuCallback, g_PlayersMenu, g_GroupsMenu;
new g_szName[MAX_NAME_LENGTH], szFmtName[MAX_FMT_LENGTH / 2], players[MAX_PLAYERS], szTargetAuth[MAX_STRING_LEN], szMenuCmd[MAX_STRING_LEN];

FnPrpareUsersGroup()
{
	g_GroupInfo = ArrayCreate(GroupInfo);
	g_MenuCallback = menu_makecallback("AdminPlayersGroupMenu_Callback");
	
	cpCvarsData[CmdGroupMenu]	= register_cvar("cms_cmd_group_menu", "say /group");
	cpCvarsData[CmdGroupMenuAccess]	= register_cvar("cms_cmd_group_menu_access", "l");
		
	#if defined FROM_ARRAY
		trhGroupFlags = TrieCreate();
		register_concmd("cms_add_user_group", "CmdAddUserGroup", ADMIN_RCON);
	#endif
}

FnPrpareUsersGroupPost()
{
	new szCvar[MAX_STRING_LEN];
	get_pcvar_string(cpCvarsData[CmdGroupMenuAccess], szCvar, charsmax(szCvar));
	get_pcvar_string(cpCvarsData[CmdGroupMenu], szMenuCmd, charsmax(szMenuCmd));
	g_bitGroupCmdAccess = read_flags(szCvar);
	pGroupCmd = register_clcmd(szMenuCmd, "AdminPlayersGroupMenu", g_bitGroupCmdAccess);
}

/*======== Меню игроков =========*/
public AdminPlayersGroupMenu(id)
{
	if(!cmd_access(id, g_bitGroupCmdAccess, pGroupCmd, 0))
		return PLUGIN_HANDLED;

	g_PlayersMenu = menu_create("\yВыбрать игрока", "AdminPlayersGroupMenu_Handler", 1);
	get_players(players, pnum, "ch");

	new szUserData[userDataID], iExist, iTarget;
	for (new i; i < pnum; i++)
	{
		iTarget = players[i];
		if(iTarget == id)
			continue;

		get_user_name(iTarget, g_szName, charsmax(g_szName));

		iExist = TrieGetArray(g_trhPlayerInfo, g_szAuthIDs[iTarget], szUserData, sizeof(szUserData));
		if(iExist)
		{
			formatex(szFmtName, charsmax(szFmtName), "\y%s \w[%s]", g_szName, szUserData[MemberGroupName]);
		}
		else
		{
			formatex(szFmtName, charsmax(szFmtName), "\y%s \w[Not registered]", g_szName);
		}

		menu_additem(g_PlayersMenu, szFmtName, g_szAuthIDs[iTarget], 0, g_MenuCallback);
	}

	menu_setprop(g_PlayersMenu, MPROP_BACKNAME, "\yНазад");
	menu_setprop(g_PlayersMenu, MPROP_NEXTNAME, "\yДалее");
	menu_setprop(g_PlayersMenu, MPROP_EXITNAME, "\yВыход");
	menu_display(id, g_PlayersMenu, 0);
	
	return PLUGIN_HANDLED;
}

public AdminPlayersGroupMenu_Callback(id, menu, item)
{
	new szAuth[MAX_STRING_LEN];
	menu_item_getinfo(menu, item, item_access, szAuth, charsmax(szAuth),_,_, item_callback);

	return TrieKeyExists(g_trhPlayerInfo, szAuth) ? ITEM_ENABLED : ITEM_DISABLED;
 }
 
public AdminPlayersGroupMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new szAuth[MAX_STRING_LEN];
	menu_item_getinfo(menu, item, item_access, szAuth, charsmax(szAuth), _, _, item_callback);

	copy(szTargetAuth, charsmax(szTargetAuth), szAuth); 
	
	menu_destroy(menu);
	GroupsMenu(id);

	return PLUGIN_HANDLED;
}

public GroupsMenu(id)
{
	new szHeader[MAX_FMT_LENGTH / 2], s_ItemNum[MAX_INT_LEN];
	new szUserData[userDataID];
	TrieGetArray(g_trhPlayerInfo, szTargetAuth, szUserData, sizeof szUserData);
	formatex(szHeader, charsmax(szHeader), "\yВыберите группу ^n\wТекущая группа: \y[%s]", szUserData[MemberGroupName]);

	g_GroupsMenu = menu_create(szHeader, "GroupsMenuhandler", 1);
	
	new groupData[GroupInfo];
	new arrIndex, arrSize = ArraySize(g_GroupInfo);
	for(arrIndex = 0; arrIndex < arrSize; ++arrIndex)
	{
		#if defined AMXX_182
			ArrayGetArray(g_GroupInfo, arrIndex, groupData);
		#else
			ArrayGetArray(g_GroupInfo, arrIndex, groupData, sizeof(groupData));
		#endif
		if(szUserData[MemberGroup] == groupData[GroupId])
			continue;

		num_to_str(arrIndex, s_ItemNum, charsmax(s_ItemNum));
		menu_additem(g_GroupsMenu, groupData[GroupName], s_ItemNum);	
	}
	
	menu_setprop(g_GroupsMenu, MPROP_EXITNAME, "\yВыход");
	menu_display(id, g_GroupsMenu, 0);

	return PLUGIN_HANDLED;
}

public GroupsMenuhandler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new szData[MAX_INT_LEN];
	menu_item_getinfo(menu, item, item_access, szData, charsmax(szData),_,_, item_callback);

	new arrIndex = str_to_num(szData);
	new groupData[GroupInfo]
	#if defined AMXX_182
		if(ArrayGetArray(g_GroupInfo, arrIndex, groupData))
	#else
		if(ArrayGetArray(g_GroupInfo, arrIndex, groupData, sizeof(groupData)))
	#endif
		FnSendUpdateQuery(szTargetAuth, groupData[GroupId], arrIndex, id);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}    

FnSendUpdateQuery(szAuth[], userGroup, arrIndex, id)
{
	new iTarget = find_player("c", szAuth);
	if(!iTarget)
	{
		if(id)
			client_print_color(id, 0, "^4Игрок вышел с сервера");

		return;
	}
	
	new szQuery[MAX_QUERY_SMALL_LEN];
	formatex(szQuery, charsmax(szQuery), "UPDATE `users` SET `rights`='%d' WHERE `id`='%d';", userGroup, cmsapi_is_user_member(iTarget));

	new pData[5];
	pData[0] = UPDATE;
	pData[1] = iTarget;
	pData[2] = arrIndex;
	pData[3] = id;

	SQL_ThreadQuery(g_hDbTuple, "FnGroupQueryHandler", szQuery, pData, sizeof(pData));
}

#if defined FROM_ARRAY
public CmdAddUserGroup(id, level, cid)
{
	if(!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	new szData[MAX_NAME_LENGTH];
	read_args(szData, charsmax(szData));

	if(szData[0])
	{
		new szGroupNum[MAX_INT_LEN], szGroupFlags[MAX_NAME_LENGTH];
		new iItems = parse(szData, szGroupNum, charsmax(szGroupNum), szGroupFlags, charsmax(szGroupFlags));

		if(iItems < 2)
		{
			log_amx("cms_add_user_group command must have 2 arguments");
			return PLUGIN_HANDLED;
		}
		
		if(get_pcvar_num(cpCvarsData[Debug]) > 2)
			log_amx("cms_add_user_group num %s, flags %s", szGroupNum, szGroupFlags);
		
		TrieSetString(trhGroupFlags, szGroupNum, szGroupFlags);
	}

	return PLUGIN_CONTINUE;
}
#endif

public LoadGroups()
{
	new pquery[MAX_QUERY_SMALL_LEN * 2];
	#if defined FROM_ARRAY
		formatex(pquery, charsmax(pquery), 	"SELECT `id`, cast(convert(`name` using utf8) as binary) as `name` FROM `%s`", TABLE_NAMES[TablePtr:users_groups]);
	#else
		formatex(pquery, charsmax(pquery), 	"SELECT `users_groups`.`id`, `services`.`rights` as `flags`, \
		cast(convert(`users_groups`.`name` using utf8) as binary) as `name` FROM `users_groups` \
		LEFT JOIN `services` ON `users_groups`.`id` = `services`.`users_group` WHERE `services`.`server` ='%d'", g_iServerId);
		replace_all(pquery, charsmax(pquery), "users_groups", TABLE_NAMES[TablePtr:users_groups]);
		replace_all(pquery, charsmax(pquery), "services", TABLE_NAMES[TablePtr:services]);
	#endif
	
	new szData[2]; 
	szData[0] = LOAD;
	
	return SQL_ThreadQuery(g_hDbTuple, "FnGroupQueryHandler", pquery, szData, sizeof(szData));
}

public FnGroupQueryHandler(failstate, Handle:query, szError[], iError, postData[], postDataSize)
{
	if(SQL_Error(szError, iError, failstate))
		return SQL_FreeHandle(query);

	new groupData[GroupInfo];
	switch(postData[0])
	{
		case LOAD:
		{
			if(SQL_NumResults(query)) 
			{	
				while(SQL_MoreResults(query))
				{
					groupData[GroupId] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));
					SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), groupData[GroupName], charsmax(groupData[GroupName]));
					#if !defined FROM_ARRAY
						SQL_ReadResult(query, SQL_FieldNameToNum(query, "flags"), groupData[GroupFlags], charsmax(groupData[GroupFlags]));
					#else
						groupData[GroupFlags][0] = EOS;
						TrieGetString(trhGroupFlags, get_id_key(groupData[GroupId]), groupData[GroupFlags], charsmax(groupData[GroupFlags]));
					#endif

					mysql_escape_string(groupData[GroupName], charsmax(groupData[GroupName]));
	
					#if defined AMXX_182
						ArrayPushArray(g_GroupInfo, groupData);
					#else
						ArrayPushArray(g_GroupInfo, groupData, sizeof(groupData));
					#endif
					SQL_NextRow(query);
				}
				#if defined FROM_ARRAY
					TrieDestroy(trhGroupFlags);
				#endif
			}
		}
		case UPDATE:
		{
			new iTarget = postData[1];
			new id = postData[3];
			if(!SQL_AffectedRows(query))
			{
				log_amx("Something wrong...");
				return PLUGIN_HANDLED;
			}

			#if defined AMXX_182
				ArrayGetArray(g_GroupInfo, postData[2], groupData);
			#else
				ArrayGetArray(g_GroupInfo, postData[2], groupData, sizeof(groupData));
			#endif
			
			new szPlayerName[MAX_NAME_LENGTH];
			get_user_name(iTarget, szPlayerName, charsmax(szPlayerName));

			if(id)
			{
				new szAdmName[MAX_NAME_LENGTH];
				get_user_name(id, szAdmName, charsmax(szAdmName));
				client_print_color(iTarget, 0, "^1Администратор ^4%s ^1изменил Вашу группу на ^4%s", szAdmName, groupData[GroupName]);
				client_print_color(id, 0, "^1Игроку ^4%s ^1изменена группа на ^4%s", szPlayerName, groupData[GroupName]);
			}
			else
			{
				client_print_color(iTarget, 0, "^1Ваша группа изменена на ^4%s", groupData[GroupName]);
			}

			if(get_pcvar_num(cpCvarsData[Debug]) > 2)
				log_amx("Игроку %s изменена группа на %s", szPlayerName, groupData[GroupName]);

			FnReloadUserData(iTarget);
		}
	}
	
	return PLUGIN_HANDLED;
}

FnCheckUserGroup(id)
{
	new szUserData[userDataID];
	if(!TrieGetArray(g_trhPlayerInfo, g_szAuthIDs[id], szUserData, sizeof szUserData))
		return;

	new groupData[GroupInfo];
	new arrIndex, arrSize = ArraySize(g_GroupInfo);
	for(arrIndex = 0; arrIndex < arrSize; ++arrIndex)
	{
		#if defined AMXX_182
			ArrayGetArray(g_GroupInfo, arrIndex, groupData);
		#else
			ArrayGetArray(g_GroupInfo, arrIndex, groupData, sizeof(groupData));
		#endif

		if(szUserData[MemberGroup] == groupData[GroupId])
		{
			if(groupData[GroupFlags][0])
				FnSetUserGroupFlags(id, groupData[GroupId], groupData[GroupName], groupData[GroupFlags]);
			break;
		}
	}
}

FnSetUserGroupFlags(id, groupId = 0, groupName[] = "", groupFlags[] = "")
{
	new tempData[AdminInfo];
	new bool:iExist;
	if(TrieGetArray(g_trhOnlineAdminsInfo, get_id_key(id), tempData, sizeof tempData))
		iExist = true;
	
	copy(tempData[AdminServiceName], charsmax(tempData[AdminServiceName]), groupName);
	tempData[AdminActive] = 1;

	new iIndex = cmsapi_set_user_flags(id, groupFlags, tempData[AdminActive], tempData[AdminServiceName], false, false);
	if(iIndex != -1)
	{
		new szName[MAX_NAME_LENGTH];
		get_user_name(id, szName, charsmax(szName));
	
		if(get_pcvar_num(cpCvarsData[Debug]))
			log_amx("%s флагов группы: ^"<%s>^" (steamId профиля ^"%s^") (флаги ^"%s^") (группа ^"%s^")", iExist ? "Добавление" : "Установка", 
				szName, g_szAuthIDs[id], groupFlags, groupName);

		new tmpData[AdminInfo];
		#if defined AMXX_182
			ArrayGetArray(g_arhAllAdminsInfo, iIndex, tmpData);
		#else
			ArrayGetArray(g_arhAllAdminsInfo, iIndex, tmpData, sizeof(tmpData));
		#endif
		
		tmpData[AdminId] = -groupId;
		
		#if defined AMXX_182
			ArraySetArray(g_arhAllAdminsInfo, iIndex, tmpData);
		#else
			ArraySetArray(g_arhAllAdminsInfo, iIndex, tmpData, sizeof(tmpData));
		#endif
		
		cmsapi_reaccess_admin(id);
	}
}