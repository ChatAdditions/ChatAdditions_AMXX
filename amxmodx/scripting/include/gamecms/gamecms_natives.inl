// ￿
//https://dev-cs.ru/threads/222/page-2#post-30354
//------------------ Стоки  и нативы --------------------------------//
public plugin_natives() 
{
	register_library("gamecms_api");
	#if defined USE_ADMINS
		register_native("cmsapi_get_alladmins", "native_cmsapi_get_alladmins");
		register_native("cmsapi_service_timeleft", "native_cmsapi_service_timeleft");
		register_native("cmsapi_get_online_admins", "native_cmsapi_get_online_admins");
		register_native("cmsapi_get_all_purchases", "native_cmsapi_get_all_purchases");
		register_native("cmsapi_get_user_services", "native_cmsapi_get_user_services");
		register_native("cmsapi_is_admin_active", "native_cmsapi_is_admin_active");
		register_native("cmsapi_get_admin_ident", "native_cmsapi_get_admin_ident");
		register_native("cmsapi_get_admin_info", "native_cmsapi_get_admin_info");
		register_native("cmsapi_reaccess_admin", "native_cmsapi_reaccess_admin");
		register_native("cmsapi_set_user_flags", "native_cmsapi_set_user_flags");
		#if defined _add_admin
		register_native("cmsapi_add_account", "native_cmsapi_add_account");
		#endif
	#endif
	register_native("cmsapi_get_api_status", "native_cmsapi_get_api_status");
	register_native("cmsapi_get_forum_data", "native_cmsapi_get_forum_data");
	register_native("cmsapi_is_user_member", "native_cmsapi_is_user_member");
	register_native("cmsapi_get_user_money", "native_cmsapi_get_user_money");
	register_native("cmsapi_set_user_money", "native_cmsapi_set_user_money");
	register_native("cmsapi_add_user_money", "native_cmsapi_add_user_money");
	register_native("cmsapi_get_server_id", "native_cmsapi_get_server_id");
	register_native("cmsapi_get_user_regdate", "native_cmsapi_get_user_regdate");
	register_native("cmsapi_get_user_nick", "native_cmsapi_get_user_nick");
	register_native("cmsapi_get_user_group", "native_cmsapi_get_user_group");
	register_native("cmsapi_get_user_authid64", "native_cmsapi_get_user_authid64");
	register_native("cmsapi_reload_wallet", "native_cmsapi_reload_wallet");
	register_native("cmsapi_get_user_lastactiv", "_cmsapi_get_user_lastactiv");
	register_native("cmsapi_get_user_discount", "native_cmsapi_get_user_discount");
	register_native("cmsapi_get_user_gametime", "native_cmsapi_get_user_gametime");
	register_native("cmsapi_get_table_name", "native_cmsapi_get_table_name");
	#if defined PL_GAMEMONEY
		register_native("cmsapi_get_user_bank", "native_cmsapi_get_user_bank");
		register_native("cmsapi_set_user_bank", "native_cmsapi_set_user_bank");
		register_native("cmsapi_add_user_bank", "native_cmsapi_add_user_bank");
	#endif
	#if defined _gamecms_user_settings
		register_native("cmsapi_get_user_setting", "native_cmsapi_get_user_setting");
		register_native("cmsapi_set_user_setting", "native_cmsapi_set_user_setting");
	#endif
	
}

any:GetMemberData(id, iIdentifier, szData[] = "", iDataLen = 0, iExtraIdentifier = 0)
{
	new szUserData[userDataID];
	if(TrieGetArray(g_trhPlayerInfo, g_szAuthIDs[id], szUserData, sizeof(szUserData)))
	{
		if(iDataLen > 0)
		{
			copy(szData, iDataLen, szUserData[iIdentifier]);

			if(iExtraIdentifier > 0)
				return szUserData[iExtraIdentifier];
		}
	}

	return szUserData[iIdentifier];
}

stock SetMemberData(id, iIdentifier, any:iValue, AddParam = SET)
{
	new szUserData[userDataID];
	TrieGetArray(g_trhPlayerInfo, g_szAuthIDs[id], szUserData, sizeof(szUserData));

	if(AddParam == ADD)
		szUserData[iIdentifier] += iValue;
	else
		szUserData[iIdentifier] = iValue;

	return TrieSetArray(g_trhPlayerInfo, g_szAuthIDs[id], szUserData, sizeof(szUserData));
}

SetMemberDataFloat(id, iIdentifier, Float:iValue, AddParam = SET)
{
	new szUserData[userDataID];
	TrieGetArray(g_trhPlayerInfo, g_szAuthIDs[id], szUserData, sizeof(szUserData));

	if(AddParam == ADD)
		szUserData[iIdentifier] = _:(Float:szUserData[iIdentifier] + iValue);
	else
		szUserData[iIdentifier] = _:iValue;

	
	return TrieSetArray(g_trhPlayerInfo, g_szAuthIDs[id], szUserData, sizeof(szUserData));
}


//Получение статуса работы плагина
public native_cmsapi_get_api_status()
	return g_bitAPIstatus;


//получение ID сервера из таблицы серверов
public native_cmsapi_get_server_id()
	return g_iServerId;


//получение szAuthId игрока в формате steamid64 (profileID)
public native_cmsapi_get_user_authid64()
	return set_string(2, g_szAuthIDs64[get_param(1)], get_param(3));

	
//получение имени таблицы в БД по ее указателю (enum TablePtr)
public native_cmsapi_get_table_name()
	return set_string(2, TABLE_NAMES[TablePtr:get_param(1)], get_param(3));


// Дата последнего посещения сайта
public _cmsapi_get_user_lastactiv()
{
	new szLastActivity[MAX_STRING_LEN], iTime;
	if(GetMemberData(get_param(1), MemberLastActivity, szLastActivity, charsmax(szLastActivity)))
	{
		set_string(2, szLastActivity, charsmax(szLastActivity));
		iTime = parse_time(szLastActivity, "%Y-%m-%d %H:%M:%S");
	}
	
	return iTime;
}

// Персональная скидка участника
public native_cmsapi_get_user_discount()
	return GetMemberData(get_param(1), MemberDiscount);


//Списание средств со счета на сайте
public native_cmsapi_reload_wallet()
	UpdateMemberData(get_param(1), get_param(2), bool:get_param(3));


//Получение ника игрока, указанного в профиле форума
public native_cmsapi_get_user_nick()
{
	new szMemberName[MAX_NAME_LENGTH*2];
	if(GetMemberData(get_param(1), MemberName, szMemberName, charsmax(szMemberName)))
		return set_string(2, szMemberName, charsmax(szMemberName));

	return -1;
}

//Получение группы пользователя на сайте
public native_cmsapi_get_user_group()
{
	new szMemberGroupName[MAX_NAME_LENGTH*2];
	new iLen = get_param(3);
	new iGroup = GetMemberData(get_param(1), MemberGroupName, szMemberGroupName, charsmax(szMemberGroupName), MemberGroup)
	
	if(iLen != 0)
		set_string(2, szMemberGroupName, iLen);

	return iGroup;
}

//передаем данные с форума
public native_cmsapi_get_forum_data()
{
	new szUserData[userDataID];
	if(TrieGetArray(g_trhPlayerInfo, g_szAuthIDs[get_param(1)], szUserData, sizeof szUserData))
	{
		new pl_Array[4];
		pl_Array[0] = szUserData[MemberThanks];
		pl_Array[1] = szUserData[MemberAnswers];
		pl_Array[2] = szUserData[MemberRaiting];
		pl_Array[3] = szUserData[MemberMessages];
		
		set_array(2, pl_Array, sizeof(pl_Array));
		set_string(3, szUserData[MemberName], get_param(4));

		return 1;
	}
	
	return 0;
}

//проверка игрока на регистрацию
public native_cmsapi_is_user_member()
	return GetMemberData(get_param(1), MemberId);

	
//узнать баланс игрока
public native_cmsapi_get_user_money()
	return _:GetMemberData(get_param(1), MemberMoney);

	
//установка баланса игрока
public native_cmsapi_set_user_money()
	return SetMemberDataFloat(get_param(1), MemberMoney, get_param_f(2));


//изменение баланса игрока
public native_cmsapi_add_user_money()
	return SetMemberDataFloat(get_param(1), MemberMoney, get_param_f(2), ADD);

	
//Общее время игры на всех серверах
public native_cmsapi_get_user_gametime()
	return GetMemberData(get_param(1), MemberGameTime);


#if defined PL_GAMEMONEY
//узнать баланс банка игрока
public native_cmsapi_get_user_bank()
{
	if(g_bGameMoneyError)
		return 0;

	return GetMemberData(get_param(1), MemberGameMoney);
}
	
//установить баланс банка игрока
public native_cmsapi_set_user_bank()
{
	if(g_bGameMoneyError)
		return 0;
	
	return SetMemberData(get_param(1), MemberGameMoney, get_param(2));
}

//изменить баланс банка игрока
public native_cmsapi_add_user_bank()
{
	if(g_bGameMoneyError)
		return 0;
	
	return SetMemberData(get_param(1), MemberGameMoney, get_param(2), ADD);
}
#endif

//узнать дату регистрации игрока на сайте
public native_cmsapi_get_user_regdate()
{
	new szRegDate[MAX_STRING_LEN], iTime;
	if(GetMemberData(get_param(1), MemberRegDate, szRegDate, charsmax(szRegDate)))
	{
		iTime = parse_time(szRegDate, "%Y-%m-%d %H:%M:%S");
		
		if(bool:get_param(4) == true)
			format_time(szRegDate, charsmax(szRegDate), "%d-%m-%Y", iTime)
		
		set_string(2, szRegDate, charsmax(szRegDate));
	}

	return iTime;
}

// ====================================================== admins ============================================== //

#if defined USE_ADMINS
//Перепроверка наличия услуг у игрока
public native_cmsapi_reaccess_admin()
{
	if(get_pcvar_num(cpAmxMode))
		AuthorizeUser(get_param(1), .bSilentCheck = false);
}

//Передаем срок окончания админки
public native_cmsapi_service_timeleft (nid, params)
{
	new id = get_param(1);
	g_Data[AdminExpired][0] = EOS;
	new szServiceName[MAX_STRING_LEN], Array:found, itime;

	if(/*params > 3 && */get_string(4, szServiceName, charsmax(szServiceName)))
	{
		found = cmsapi_get_user_services(id, _, szServiceName, _, bool:get_param(5));
		if(!found)
			return -2;
		#if defined AMXX_182
		ArrayGetArray(found, 0, g_Data);
		#else
		ArrayGetArray(found, 0, g_Data, sizeof(g_Data));
		#endif
	}
	else if(!getAdminsData(id, g_Data[AdminExpired], charsmax(g_Data[AdminExpired])))
		return -2;

	if(!equali(g_Data[AdminExpired], "0000", 4))
		itime = parse_time(g_Data[AdminExpired], "%Y-%m-%d %H:%M:%S");

	new iLen = get_param(3);
	if(iLen > 0)
		set_string(2, g_Data[AdminExpired], iLen);

	return itime > 0 ? itime : 0;
}
//Проверяем, не отключен ли админ в админ-центре
public native_cmsapi_is_admin_active()
{
	g_Data[AdminReason][0] = EOS;
	new szServiceName[MAX_STRING_LEN];
	get_string(4, szServiceName, charsmax(szServiceName))
	new Array:found = cmsapi_get_user_services(get_param(1), _, szServiceName, _, bool:get_param(5));
	if(found)
	{
		new i = ArraySize(found);
		for(new index; index < i; index++)
		{
			#if defined AMXX_182
			ArrayGetArray(found, index, g_Data);
			#else
			ArrayGetArray(found, index, g_Data, sizeof(g_Data));
			#endif
			if(g_Data[AdminActive] != 0 && g_Data[AdminActive] != 2)
				break;
		}
	}

	return set_string(2, g_Data[AdminReason], get_param(3)) ? false : true;
}
	

//Получение данных всех загруженных админов
public Array:native_cmsapi_get_alladmins()
	return g_arhAllAdminsInfo;

//Получение данных авторизовавшихся админов
public Trie:native_cmsapi_get_online_admins()
	return g_trhOnlineAdminsInfo;

//Получение данных о всех купленных доп. услугах на сервере
public Array:native_cmsapi_get_all_purchases()
	return g_arhAllPurchServices;

	// добавление флагов (услуг)
// native cmsapi_set_user_flags(index, szFlags[], iTime = -1, szServiceName[] = "", bSilentCheck = false, bAuthorize = true)
public native_cmsapi_set_user_flags()
{
	new iArrayIndex = -1;
	new tmpData[AdminInfo];
	new id = get_param(1);
	get_string(2, tmpData[AdminServiceFlags], charsmax(tmpData[AdminServiceFlags]));

	new iFlags = read_flags(tmpData[AdminServiceFlags]);
	if((get_user_flags(id) & iFlags) == iFlags)
		return iArrayIndex;

	tmpData[AdminAuthId] = g_szAuthIDs[id];
	tmpData[AdminType] = "ce";
	tmpData[AdminActive] = get_param(3);

	switch(tmpData[AdminActive])
	{
		case 1: tmpData[AdminExpired] = "0000-00-00 00:00:00";
		case -1: tmpData[AdminExpired] = "В конце карты";
		default: format_time(tmpData[AdminExpired], charsmax(tmpData[AdminExpired]), "%Y-%m-%d %H:%M:%S", (get_systime() + tmpData[AdminActive]));
	}

	get_string(4, tmpData[AdminServiceName], charsmax(tmpData[AdminServiceName]));
	
	new Array:exist = cmsapi_get_user_services(id, _, tmpData[AdminServiceFlags]);
	if(exist)
	{
		new i = ArraySize(exist);
		for(new index; index < i; index++)
		{
			#if defined AMXX_182
				ArrayGetArray(exist, index, g_Data);
			#else
				ArrayGetArray(exist, index, g_Data, sizeof(g_Data));
			#endif
			
			if(g_Data[AdminActive] != 0 && g_Data[AdminActive] != 2)
				return iArrayIndex;
		}
	}

	if(containi(tmpData[AdminServiceFlags], "_") != -1)
	{
		#if defined AMXX_182
			ArrayPushArray(g_arhAllPurchServices, tmpData);
		#else
			ArrayPushArray(g_arhAllPurchServices, tmpData, sizeof(tmpData));
		#endif
		
		g_iPurchasedCount = ArraySize(g_arhAllPurchServices);
	}
	else
	{
		#if defined AMXX_182
			iArrayIndex = ArrayPushArray(g_arhAllAdminsInfo, tmpData);
		#else
			iArrayIndex = ArrayPushArray(g_arhAllAdminsInfo, tmpData, sizeof(tmpData));
		#endif

		g_iAdminCount = ArraySize(g_arhAllAdminsInfo);
	}
		
	if(get_pcvar_num(cpAmxMode) && bool:get_param(6))
		AuthorizeUser(id, .bSilentCheck = bool:get_param(5));

	return iArrayIndex;
}

//Получение данных о купленных услугах игрока
public Array:native_cmsapi_get_user_services()
{
	ArrayClear(g_arrUserServices);
	
	new szServiceName[MAX_STRING_LEN], iServiceId, id;
	get_string(3, szServiceName, charsmax(szServiceName));
	iServiceId = get_param(4);
	id = get_param(1);

	static szUserAuth[MAX_STRING_LEN];
	if(!get_string(2, szUserAuth, charsmax(szUserAuth)))
		szUserAuth = g_szAuthIDs[id];

	if(!id && !szUserAuth[0])
	{
		log_amx("cmsapi_get_user_services: Invalid player id (%d)", id);
		return Invalid_Array;
	}

	if(!szServiceName[0])
	{
		FnFindUserServices(id, szUserAuth, g_arhAllPurchServices, iServiceId, .flags=false);
		FnFindUserServices(id, szUserAuth, g_arhAllAdminsInfo, iServiceId, .flags=false);
	}
	else if(containi(szServiceName, "_") != -1)
		FnFindUserServices(id, szUserAuth, g_arhAllPurchServices, iServiceId, szServiceName, false);
	else if(szServiceName[0])
		FnFindUserServices(id, szUserAuth, g_arhAllAdminsInfo, iServiceId, szServiceName, true, bool:get_param(5));

	return ArraySize(g_arrUserServices) ? g_arrUserServices : Invalid_Array;
}

FnFindUserServices(id, szUserAuth[], Array:arhSource, iServiceId = 0, szServiceName[] = "", bool:flags, bool:part = false)
{
	static szUserName[MAX_STRING_LEN];
	get_user_name(id, szUserName, charsmax(szUserName));

	for(new index = 0; index < ArraySize(arhSource); index++)
	{
		#if defined AMXX_182
			ArrayGetArray(arhSource, index, g_Data);
		#else
			ArrayGetArray(arhSource, index, g_Data, sizeof(g_Data));
		#endif
		
		if(!equal(szUserAuth, g_Data[AdminAuthId]) && !equal(szUserName, g_Data[AdminAuthId]))
			continue;

		if(!szServiceName[0] && !iServiceId)
		{
			#if defined AMXX_182
				ArrayPushArray(g_arrUserServices, g_Data);
			#else
				ArrayPushArray(g_arrUserServices, g_Data, sizeof(g_Data));
			#endif
				continue;
		}
		else
		if(szServiceName[0] && (flags ? (StIsEqualFlags(szServiceName, g_Data[AdminServiceFlags], part)) : (equal(szServiceName, g_Data[AdminServiceFlags]))) ||
			iServiceId > 0 && iServiceId == g_Data[AdminServiceId])
		{
			#if defined AMXX_182
				ArrayPushArray(g_arrUserServices, g_Data);
			#else
				ArrayPushArray(g_arrUserServices, g_Data, sizeof(g_Data));
			#endif

			if(iServiceId)
				break;
		}
	}
}

//ID авторизовавшегося админа
public native_cmsapi_get_admin_ident()
{
	if(TrieGetArray(g_trhOnlineAdminsInfo, get_id_key(get_param(1)), g_Data, sizeof(g_Data)))
	{
		new iLen = get_param(3);
		if(iLen > 0)
			set_string(2, g_Data[AdminAuthId], iLen);
		return g_Data[AdminId];
	}
		
	return 0;
}


//Получение данных об администраторе (аккаунте) по ID (идентиф. номер в БД сайта) услуги
public Trie:native_cmsapi_get_admin_info()
{
	new	aID = get_param(1);
	if(!aID)
		return Invalid_Trie;

	new arrSize = ArraySize(g_arhAllAdminsInfo);
	for (new index = 0; index < arrSize; index++)
	{
		#if defined AMXX_182
			ArrayGetArray(g_arhAllAdminsInfo, index, g_Data);
		#else
			ArrayGetArray(g_arhAllAdminsInfo, index, g_Data, sizeof(g_Data));
		#endif
		if (aID == g_Data[AdminId])
		{
			TrieSetArray(g_trhAdminInfo, get_id_key(aID), g_Data, sizeof(g_Data));
			return g_trhAdminInfo;
		}	
	}

	return Invalid_Trie;
}

//данные авторизовавшегося админа
getAdminsData(id, Info[], iLen)
{
	if(TrieGetArray(g_trhOnlineAdminsInfo, get_id_key(id), g_Data, sizeof g_Data))
		return set_string(2, Info, iLen);
	
	return 0;
}
#endif


#if defined _gamecms_user_settings
public native_cmsapi_get_user_setting()
{
	new id = get_param(1);
	new szSettings[MAX_STRING_LEN], iValue[MAX_STRING_LEN];
	get_string(2, szSettings, charsmax(szSettings));
	
	if(FnGetUserSetting(id, szSettings, iValue, charsmax(iValue)))
	{
		if(get_param(4) != 0)
			return set_string(3, iValue, charsmax(iValue));

		return str_to_num(iValue);
	}
	
	return -1;
}

public native_cmsapi_set_user_setting()
{
	new id = get_param(1);
	new szSettings[MAX_STRING_LEN], iValue[MAX_STRING_LEN];
	get_string(2, szSettings, charsmax(szSettings));
	get_string(3, iValue, charsmax(iValue));

	return FnSetUserSetting(id, szSettings, iValue, bool:get_param(4));
}
#endif
	