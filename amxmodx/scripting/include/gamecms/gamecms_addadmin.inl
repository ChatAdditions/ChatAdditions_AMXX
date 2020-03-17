// ￿
//https://dev-cs.ru/threads/222/page-2#post-30354

#define _add_admin

FnAddAdminConcmd()
	register_srvcmd("amx_addadmin", "CmdAddAdmin", ADMIN_RCON, "<playername|auth>  [password] <accessflags> [authtype] [days] - add specified player as an admin to Database")


/*======== Обработка консольной команды =============*/
//amx_addadmin "счастливое лицо" "пароль" "флаги" "тип авторизации" "время в минутах"
//amx_addadmin "STEAM_0:0:123456" "" "abcd" "ce" "300"
//amx_addadmin "Moi Nick" "paroliwe" "abipr" "ab" "300"
public CmdAddAdmin(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	if (g_hDbTuple == Empty_Handle)
	{
		log_amx("[API-AddAdmin] Нет связи с базой данных. Добавление админов невозможно!");
		return PLUGIN_CONTINUE;
	}

	new AdmInfo[AdminInfo];
	new argsnum = read_argc();
	
	read_argv(1, AdmInfo[AdminAuthId], charsmax(AdmInfo[AdminAuthId]));
	read_argv(2, AdmInfo[AdminPassword], charsmax(AdmInfo[AdminPassword]));
	read_argv(3, AdmInfo[AdminServiceFlags], charsmax(AdmInfo[AdminServiceFlags]));
	
	if(argsnum > 4)
		read_argv(4, AdmInfo[AdminType], charsmax(AdmInfo[AdminType]));
	
	if(argsnum > 5)
	{
		new szTime[MAX_INT_LEN];
		read_argv(5, szTime, charsmax(szTime));
		AdmInfo[AdminServiceTime] = str_to_num(szTime);
	}
	//AdmInfo[AdminServiceTime] = read_argv_int(5);	//мммм а чета не работает.. видимо, инклуд АМХ староват

	FnCheckParams(AdmInfo);

	return PLUGIN_HANDLED;
}

/** Добаление аккаунтов в базу данных
*	@iClient - индекс игрока
*	@szAuthType[] - тип авторизации (смотри amxconst.inc: Admin authentication behavior flags)
*	@szFlags[] - флаги (уровни) доступа (смотри amxconst.inc: Admin level constants)
*	@iTime - время в минутах, 0- навсегда (если время не указано, значит 0)
*	@szPasswd[] - пароль доступа (если нужен)
*	@iServiceId - номер услуги на сайте
*		//При указании параметра, флаги услуги будут определены автоматически
*		//При отсутствии, номер услуги будет определен по флагам
*	@force_write - проверка введенных данных (true- включить). При отключеной функции все косяки при добавлении- ваши косяки)
*	cmsapi_add_account(id, "a", 180, "parol", "prt", 0, false)
*	(игроку №id с его ником выданы флаги "prt" на 180 минут, пароль- "parol") кикнет его нафиг после добавления в базу)
*/
//native cmsapi_add_account(iClient, szAuthType[], iTime = 0,  szPasswd[] = "", szFlags[] = "", iServiceId = 0, force_write = false)

public native_cmsapi_add_account(nId, params)
{
	if (g_hDbTuple == Empty_Handle)
	{
		log_amx("[API-AddAdmin] Нет связи с базой данных. Добавление админов невозможно!");
		return;
	}

	new AdmInfo[AdminInfo], id;
	id = get_param(1);
	get_string(2, AdmInfo[AdminType], charsmax(AdmInfo[AdminType]));
	
	if(containi(AdmInfo[AdminType], "c") != -1)
	{
		AdmInfo[AdminAuthId] = g_szAuthIDs[id];
	}
	else
	{
		get_user_name(id, AdmInfo[AdminAuthId], charsmax(AdmInfo[AdminAuthId]));
	}
	
	AdmInfo[AdminServiceTime] = get_param(3);
	get_string(4, AdmInfo[AdminPassword], charsmax(AdmInfo[AdminPassword]));
	get_string(5, AdmInfo[AdminServiceFlags], charsmax(AdmInfo[AdminServiceFlags]));
	AdmInfo[AdminServiceId] = get_param(6);		

	if(!bool:get_param(7))
	{
		FnAddAccount(AdmInfo);
		return;
	}

	FnCheckParams(AdmInfo);
}

/*======== Обработка параметров добавления =============*/
FnCheckParams(AdmInfo[])
{
	switch(AdmInfo[AdminType][0])
	{
		case 'a':
		{
			if(!FnCheckPass(AdmInfo[AdminPassword]))
				return PLUGIN_CONTINUE;
			
			if(AdmInfo[AdminType][1] == 'c')
			{
				if(!FnCheckSteam(AdmInfo[AdminAuthId]))
					return PLUGIN_CONTINUE;
				log_amx("[API-AddAdmin] Установлена авторизация по STEAM ID + пароль");
			}
			else
			{
				log_amx("[API-AddAdmin] Установлена авторизация по Ник + пароль");
			}
		}
		case 'c':
		{
			if(!FnCheckSteam(AdmInfo[AdminAuthId]))
				return PLUGIN_CONTINUE;
			
			if(AdmInfo[AdminType][1] == 'e')
			{
				log_amx("[API-AddAdmin] Установлена авторизация по STEAM ID");
			}
			else
			{
				if(!FnCheckPass(AdmInfo[AdminPassword]))
					return PLUGIN_CONTINUE;
				log_amx("[API-AddAdmin] Установлена авторизация по STEAM ID + пароль");
			}
		}
		default:
		{
			log_amx("[API-AddAdmin] Неверный тип авторизации");
			return PLUGIN_CONTINUE;
		}
	}

	FnAddAccount(AdmInfo);
	
	return PLUGIN_CONTINUE;
}

FnCheckPass(pass[])
{
	if(!(pass[0]))
	{
		log_amx("[API-AddAdmin] Необходимо указать пароль");
		return PLUGIN_CONTINUE;
	}
	
	return PLUGIN_HANDLED;
}

FnCheckSteam(steam[])
{
	if(containi(steam, "STEAM_") == -1 && containi(steam, "VALVE_") == -1)
	{
		log_amx("[API-AddAdmin] Неверный формат STEAM ID (Пример: STEAM_0:0:0000000)");
		return PLUGIN_CONTINUE;
	}
	
	return PLUGIN_HANDLED;
}

/*======== Добавление админов в БД =============*/
FnAddAccount(AdmInfo[])
{
	mysql_escape_string(AdmInfo[AdminAuthId], charsmax(AdmInfo[AdminAuthId])*2);
	mysql_escape_string(AdmInfo[AdminPassword], charsmax(AdmInfo[AdminPassword])*2);

	#define szQuery g_szQueryStr
	
	new Array:pl_ServiceInfo;
	if(AdmInfo[AdminServiceId])
		pl_ServiceInfo = cmsapi_get_user_services(0, AdmInfo[AdminAuthId], "", AdmInfo[AdminServiceId]);
	else
		pl_ServiceInfo = cmsapi_get_user_services(0, AdmInfo[AdminAuthId], AdmInfo[AdminServiceFlags]);
	
	new iLen;
	if(pl_ServiceInfo)
	{	
		new pl_Data[AdminInfo];
		ArrayGetArray(pl_ServiceInfo, 0, pl_Data);
		if(pl_Data[AdminActive] == 1)
		{
			log_amx("[API-AddAdmin] Услуга уже выдана на неограниченное время");
			return;
		}
		
		AdmInfo[AdminActive] = pl_Data[AdminActive];
		AdmInfo[AdminId] = pl_Data[AdminId];
		AdmInfo[AdminServiceId] = pl_Data[AdminServiceId];
	}
	
	new szData[3];
	
	if(AdmInfo[AdminActive] > 1 && AdmInfo[AdminId] > 0)
	{
		if(AdmInfo[AdminServiceTime])
		{
			iLen += formatex(szQuery[iLen], charsmax(szQuery) - iLen, "UPDATE %s SET `service_time`= `service_time`+'%d',\
				`ending_date`= (SELECT DATE_ADD(`ending_date`, INTERVAL '%d' MINUTE)) WHERE `admin_id` = '%d' AND `service` = '%d'",
				TABLE_NAMES[admins_services], AdmInfo[AdminServiceTime], AdmInfo[AdminServiceTime], AdmInfo[AdminId], AdmInfo[AdminServiceId]);
		}
		else
		{
			iLen += formatex(szQuery[iLen], charsmax(szQuery) - iLen, "UPDATE %s SET \
				`ending_date`= '0000-00-00 00:00:00' WHERE `admin_id` = '%d' AND `service` = '%d'", TABLE_NAMES[admins_services], AdmInfo[AdminId], AdmInfo[AdminServiceId]);
		}
		
		szData[0] = UPDATE;
		szData[1] = AdmInfo[AdminId];
	}
	else
	{
		new b_Time[MAX_STRING_LEN], e_Time[MAX_STRING_LEN];
		format_time(b_Time, charsmax(b_Time), "%Y-%m-%d %H:%M:%S");

		if(AdmInfo[AdminServiceTime])
		{
			format_time(e_Time, charsmax(e_Time), "%Y-%m-%d %H:%M:%S", (get_systime() + 60 * AdmInfo[AdminServiceTime]));
			AdmInfo[AdminServiceTime] = AdmInfo[AdminServiceTime] / 60 /24;
		}
		else
		{
			e_Time = "0000-00-00 00:00:00";
		}

		iLen += formatex(szQuery[iLen], charsmax(szQuery) - iLen,
			"INSERT IGNORE INTO admins (name, type, pass, server, user_id) values ('%s', '%s', '%s', '%d', '%d');",
			AdmInfo[AdminAuthId], AdmInfo[AdminType], AdmInfo[AdminPassword], g_iServerId, cmsapi_is_user_member(find_player("c", AdmInfo[AdminAuthId])));
				
		if(AdmInfo[AdminServiceId])
		{
			iLen += formatex(szQuery[iLen], charsmax(szQuery) - iLen,
				"INSERT INTO %s (rights_und, service_time, bought_date, ending_date, admin_id, service) values \
				((SELECT `rights` FROM `services` WHERE `services`.`id` = '%d' AND `server` = '%d'), '%d', '%s', '%s', LAST_INSERT_ID(), '%d');",
				TABLE_NAMES[admins_services], AdmInfo[AdminServiceId], g_iServerId, AdmInfo[AdminServiceTime], b_Time, e_Time, AdmInfo[AdminServiceId]);
		}
		else
		{
			iLen += formatex(szQuery[iLen], charsmax(szQuery) - iLen,
				"INSERT INTO %s (rights_und, service_time, bought_date, ending_date, admin_id, service) values \
				('%s', '%d', '%s', '%s', LAST_INSERT_ID(), (SELECT `id` FROM `services` WHERE `services`.`rights` = '%s' AND `server` = '%d'));",
				TABLE_NAMES[admins_services], AdmInfo[AdminServiceFlags], AdmInfo[AdminServiceTime], b_Time, e_Time, AdmInfo[AdminServiceFlags], g_iServerId);
		}
		
		szData[0] = SAVE;
	}
	
	szData[2] = AdmInfo[AdminServiceId];

	if(get_pcvar_num(cpCvarsData[Debug]) > 2)
		log_amx(szQuery);

	SQL_ThreadQuery(g_hDbTuple, "FnAddAccount_Post", szQuery, szData, sizeof(szData));
}

public FnAddAccount_Post(failstate, Handle:query, szError[], iError, szData[], iLen)
{
	if(SQL_ErrorAPI(szError, iError, failstate))
		return PLUGIN_CONTINUE;

	new adminId;
	if(szData[0] == SAVE)
	{
		adminId = SQL_GetInsertId(query);
		log_amx("[API-AddAdmin] Админ №%d (услуга %s ) успешно добавлен", adminId, szData[2]);
	}
	else
	{
		adminId = szData[1]
		log_amx("[API-AddAdmin] Админ №%d (услуга %s ) успешно изменен", adminId, szData[2]);
	}

	if(adminId)
	{
		server_cmd("amx_reloadadmins %d", adminId);
		return PLUGIN_HANDLED;
	}
		
	return PLUGIN_CONTINUE;
}
