/*========================== Plugins STOCKS ==========================*/
stock get_id_key(index)
{
	new id_key[MAX_INT_LEN];
	num_to_str(index, id_key, charsmax(id_key));
	
	return id_key;
}

stock mysql_escape_string(string[],iLen)
{
	replace_all(string, iLen, "&#039;", "'")
	replace_all(string, iLen, "&lt;", "<")
	replace_all(string, iLen, "&gt;", ">")
	replace_all(string, iLen, "&quot;", "^"")	//"
	replace_all(string, iLen, "&amp;", "&")
}

stock mysql_insert_string(string[],iLen)
{
	replace_all(string, iLen, "\", "\\");
	replace_all(string, iLen, "\0", "\\0");
	replace_all(string, iLen, "\n", "\\n");
	replace_all(string, iLen, "\r", "\\r");
	replace_all(string, iLen, "\x1a", "\Z");
	replace_all(string, iLen, "'", "\'");
	replace_all(string, iLen, "\^"", "\\^"");
}

//добавление отсутствующих флагов
stock StAddExtraFlags(source[], dest[], iLen)
{
	new str[2], i, lenS = strlen(source), bool:added;
	while(lenS > i)
	{
		copy(str, charsmax(str), source[i++])
		if(containi(dest, str) == -1)
		{
			add(dest, iLen, str);
			added = true;
		}
	}
	return added;
}

//удаление повторяющихся символов (для флагов)
stock StReplaceDuplChar(dest[])
{
	new str[2], i, source[MAX_STRING_LEN*2], iLen = strlen(dest);
	copy(source, charsmax(source), dest);
	dest[0] = EOS;
	
	while(iLen > i)
	{
		copy(str, charsmax(str), source[i++])
		if(containi(dest, str) == -1)
			add(dest, iLen, str);
	}
}

//поиск функции в плагине
stock bool:FindPluginFunction(const szFunction[])
{
	new Num = get_pluginsnum();
	for(new Index; Index < Num; Index++)
	{
		if(get_func_id(szFunction, Index) != -1)
			return true;
	}
	
	return false;
}

//конвертация steamid32 в формат steamid64 (profileID)
stock StGetUserAuthid64(id, Steam64[], strLen, Steam32[MAX_STRING_LEN] = "")
{
	static SteamArr[3][MAX_STRING_LEN];
	if(!Steam32[0])
		get_user_authid(id, Steam32, charsmax(Steam32));
		
	strtok(Steam32, SteamArr[0], charsmax(SteamArr[]), SteamArr[1], charsmax(SteamArr[]), ':');
	strtok(SteamArr[1], SteamArr[1], charsmax(SteamArr[]), SteamArr[2], charsmax(SteamArr[]), ':');

	static szSteamCommID[MAX_STRING_LEN], makeID[3];
	makeID[0] = 76561197;
	makeID[1] = 960265728;

	makeID[2] = str_to_num(SteamArr[2])*2 + str_to_num(SteamArr[1]);
	if(num_to_str(makeID[2], szSteamCommID, charsmax(szSteamCommID)) > 9)
	{
		makeID[0] += 1;
		copy(szSteamCommID, charsmax(szSteamCommID), szSteamCommID[1]);
	}

	makeID[2] = makeID[1] + str_to_num(szSteamCommID);
	if(num_to_str(makeID[2], szSteamCommID, charsmax(szSteamCommID)) > 9)
	{
		makeID[0] += 1;
		copy(szSteamCommID, charsmax(szSteamCommID), szSteamCommID[1]);
	}

	format(Steam64, strLen, "%d%s", makeID[0], szSteamCommID);
}

stock SQL_Error(const szError[], iError, failstate)
{
	
	switch(failstate)
	{
		case TQUERY_CONNECT_FAILED:
		{
			log_amx("[Error] Connection error: %s (%d)", szError, iError);
			return 1;
		}
			
		case TQUERY_QUERY_FAILED:
		{
			if(iError != DUPLICATE_ENTRY && iError != DUPLICATE_COLUMN)
				log_amx("[Error] Query error: %s (%d)", szError, iError);
			return 1;
		}	 
	}
	
	return 0
}

stock ExplodeString(Output[][], Max, Size, Input[], Delimiter)
{
    new Idx, l = strlen(Input), Len;
    do
	{
		Len += (1 + copyc(Output[Idx], Size, Input[Len], Delimiter));
		trim(Output[Idx]);
	}
    while((Len < l) && (++Idx < Max))

    return Idx;
}

stock CvarsToArray(any:Output, Input[], Delimiter, type[])
{
    new Idx, l = strlen(Input), Len, temp[MAX_INT_LEN][MAX_STRING_LEN];
    do
	{
		Len += (1 + copyc(temp[Idx], charsmax(temp[]), Input[Len], Delimiter));
		remove_quotes(temp[Idx]);
		trim(temp[Idx]);
		
		switch(type[0])
		{
			case 't': ArrayPushCell(Output, str_to_num(temp[Idx]))
			case 'c': TrieSetCell(Output, temp[Idx], Idx);
		}

		++Idx;
	}
    while (Len < l)
	
    return Idx;
}

stock StIsEqualFlags(flags1[], flags2[], bool:part)
{
	new iFlagsBit = read_flags(flags1);
	if(part == true)
		return (iFlagsBit & read_flags(flags2));

	return (iFlagsBit & read_flags(flags2) == iFlagsBit);
}

stock StGetCmdArgNum(szArg[])
{
	remove_quotes(szArg);
	trim(szArg);
	return str_to_num(szArg);
}

stock StCheckUserPassword(szPasswd[], Passwd[], iAuthType)
{
	return iAuthType & FLAG_NOPASS ? 1 :
		equal(szPasswd, Passwd) ? 1 :
			iAuthType & FLAG_KICK ? 2 :
				0;
}