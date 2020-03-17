// ￿
//https://dev-cs.ru/threads/222/page-2#post-30354

CheckRemoveTime(g_Data[])
{
	if(g_Data[AdminActive] == -1)
	{
		if(get_pcvar_num(cpCvarsData[Debug]) > 1)
			log_amx("Истекает в конце карты для %s (admin_id %d, service: %d)", g_Data[AdminAuthId], g_Data[AdminId], g_Data[AdminService])
	}
	else if(g_Data[AdminActive] > 0)
	{
		new Float:flActiveTime = float(g_Data[AdminActive]);
		new iTimeLeft = get_timeleft();
		
		if((iTimeLeft == 0 || iTimeLeft > flActiveTime) && g_Data[AdminExpired][0] != '0')
		{
			
			new Float:fTimeLeft = g_Data[AdminId] ? flActiveTime - get_gametime() : flActiveTime;
			
			if(get_pcvar_num(cpCvarsData[Debug]) > 1)
				log_amx("Истекает через %.0f сек для: %s (admin_id: %d, admin_service: %d)", fTimeLeft, g_Data[AdminAuthId], g_Data[AdminId], g_Data[AdminService])
			
			if(task_exists(g_Data[AdminService]))
			{
				change_task(g_Data[AdminService], fTimeLeft);
			}
			else
			{
				set_task(fTimeLeft, "DeactivateAdmin", g_Data[AdminService], g_Data[AdminAuthId], charsmax(g_Data[AdminAuthId]));
			}
		}
	}
}

FnFindServiceId(Array:arhSource, arrSize, iAdminService)
{
	if(!arrSize)
		return;
	
	new index;
	do
	{	
		#if defined AMXX_182
			ArrayGetArray(arhSource, index, g_Data);
		#else
			ArrayGetArray(arhSource, index, g_Data, sizeof(g_Data));
		#endif
		
		if(g_Data[AdminService] == iAdminService)
		{
			copy(g_Data[AdminReason], charsmax(g_Data[AdminReason]), "Срок услуги истек!");
			g_Data[AdminActive] = 0;
			log_amx("Деактивация админа %s / admin_service: %d (admin_id %d)", g_Data[AdminAuthId], g_Data[AdminService], g_Data[AdminId]);
		}
		
		#if defined AMXX_182
			ArraySetArray(arhSource, index, g_Data);
		#else
			ArraySetArray(arhSource, index, g_Data, sizeof(g_Data));
		#endif

		index++;
	}
	while(index < arrSize)
}

public DeactivateAdmin(szAdminAuth[], iAdminService)
{
	FnFindServiceId(g_arhAllPurchServices, g_iPurchasedCount, iAdminService);
	FnFindServiceId(g_arhAllAdminsInfo, g_iAdminCount, iAdminService);
	
	new iClient = find_player("c", szAdminAuth);
	if(!iClient)
		iClient = find_player("ab", szAdminAuth);

	if(iClient)
		AuthorizeUser(iClient, .bSilentCheck = true);
}