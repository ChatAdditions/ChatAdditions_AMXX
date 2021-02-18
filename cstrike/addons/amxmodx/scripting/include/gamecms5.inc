#if defined _gamecms5_included
	#endinput
#endif
#define _gamecms5_included

#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32;
#endif
#if !defined MAX_NAME_LENGTH
	const MAX_NAME_LENGTH =	32;
#endif

#define API_5

#define MAX_STRING_LEN	33
#define MAX_INT_LEN			11
#define DUPLICATE_ENTRY		1062
#define DUPLICATE_COLUMN	1060
#define MAX_QUERY_MEDIUM_LEN 2048
#define MAX_QUERY_SMALL_LEN 256

#if AMXX_VERSION_NUM < 183
	#define client_disconnected client_disconnect
	#define socket_is_readable socket_change
	#include <colorchat>
	stock MaxClients;
	#define AMXX_182
#else
	#define client_disconnect client_disconnected
#endif

#include gamecms/gamecms_stocks.inl
#define IsValidPlayer(%0) (0 < %0 < MaxClients)


//GagManager
#define TIME_NOT_EXPIRING		0
#define TIME_MAP_END_EXPIRING	-1

enum		//Проверка наличния блокировки
{
	BLOCK_STATUS_NONE = -1,		//Нет блокировки
	BLOCK_STATUS_ALL,			//Блокировка голос+чат
	BLOCK_STATUS_CHAT,			//Блокировка чат
	BLOCK_STATUS_VOICE			//Блокировка голос
}

enum		//Управление блокировкой
{
	BLOCK_FUNC_ADD = 1,		//Добавить блокировку
	BLOCK_FUNC_CHANGE,		//Изменить блокировку
	BLOCK_FUNC_REMOVE		//Удалить блокировку
}

stock SiteUrl[MAX_STRING_LEN]; //example: http://site.com

/* Указатели таблиц для получения их имен через cmsapi_get_table_name*/
enum TablePtr
{
	admins_services,
	dialogs,
	users_groups,
	services,
	services_tarifs,
	config_secondary,
	sortition,
	sortition__participants,
	users__friends,
	users__online,
	last_online
}

stock const TABLE_NAMES[TablePtr][] = //Названия таблиц в БД, которые нужно изменить при обновлении движка
{
	"admins__services",	//admins__services
	"pm__dialogs",		//pm__dialogs
	"users__groups",	//users__groups
	"services",
	"services__tarifs",
	"config__secondary",
	"sortition",
	"sortition__participants",
	"users__friends",
	"users__online",
	"last_online"
}


enum (<<=1)			//api status
{
	UseGameCms = 1,		//используется база данных GameCMS без загрузки админов
    UseGameCmsAdmins,	//используется база данных GameCMS с загрузкой админов
}

enum _:AdminInfo
{
	AdminId,
	AdminAuthId[MAX_STRING_LEN],
	AdminPassword[MAX_STRING_LEN],
	AdminServiceFlags[MAX_STRING_LEN],
	AdminType[5],
	AdminExpired[MAX_STRING_LEN],
	AdminReason[MAX_STRING_LEN*2],
	AdminActive,
	AdminPaused,
	AdminService,
	AdminServiceId,
	AdminServiceName[MAX_STRING_LEN*2],
	AdminServiceTime
};

enum _:userDataID
{
	MemberId,
	MemberLogin[MAX_NAME_LENGTH],
	MemberName[MAX_NAME_LENGTH*2],
	MemberBirth[MAX_INT_LEN + 1],
	MemberNick[MAX_NAME_LENGTH],
	Float:MemberMoney,
	Float:MemberMoneyCurr,
	Float:MemberMoneyOld,
	MemberGameTime,
	MemberGameTimeCurr,
	MemberPrefix[MAX_STRING_LEN],
	MemberGameMoney,
	MemberGameMoneyCurr,
	MemberGameMoneyOld,
	MemberMessages,
	MemberGroup,
	MemberGroupName[MAX_NAME_LENGTH*2],
	MemberThanks,
	MemberAnswers,
	MemberRaiting,
	MemberRegDate[MAX_STRING_LEN],
	MemberLastActivity[MAX_INT_LEN],
	MemberDiscount
};

enum
{
	LOAD_ALL,
	LOAD,
	UPDATE,
	SAVE,
	SET,
	ADD
}

/*========================== Plugin GameCMS API BEGIN ==========================*/

/**
*	Получение статуса работы плагина
*	@return		Битсумма значения enum api status
*/
native cmsapi_get_api_status();


/**
*	Получение имени таблицы в БД по ее указателю
*	
*	@Pointer		Указатель таблицы
*	@szTableName	Массив для записи имени таблицы
*	@Len			максимальный размер массива
*	@return			Количество ячеек, записанных в массив
*/

native cmsapi_get_table_name(TablePtr:Pointer, szTableName[], Len)

/**
*	Получение данных участника форума
*	
*	@id				id игрока
*	@szData			Массив с данными участника форума
*		szData[0]		количество "спасибо"
*		szData[1]		количество ответов на форуме
*		szData[2]		рейтинг на форуме
*		szData[3]		количество новых личных сообщений
*	@szName				Имя игрока, указанное в профиле
*	@NameLen			Размер массива для записи имени
*	@return			1 - При успешном получении данных об игроке
*					0 - Если игрок не зарегистрирован или ошибка при получении данных
*/
native cmsapi_get_forum_data(id, szData[4], szName[]="", NameLen=0);


/**
*	Получение ника игрока, указанного в профиле форума
*	
*	@id			id игрока
*	@szNick		Ник игрока
*	@Len		Размер массива
*		@Note:	Максимально кол-во символов в нике (32)
*
*	@return		Количество ячеек, записанных в массив
*				-1 - Если игрок не зарегистрирован или ошибка при получении данных
*/
native cmsapi_get_user_nick(id, szNick[], Len);


/**
*	Получение id группы пользователя
*	
*	@id			id игрока
*	@szGroup	Массив для записи названия группы пользователя
*	@Len		Размер массива
*	@return		id группы пользователя
*				0 - пользователь не найден (не зарегистрирован)
*/
native cmsapi_get_user_group(id, szGroup[] = "", Len = 0);


/**
*	Получение даты окончания услуги
*	
*	@id			id игрока
*	@szDate		Дата истечения срока услуги в формате ГГГГ-ММ-ДД
*	@iLen		Размер массива szDate[]
*	@srvName	Флаги услуги
*	@part		Совпадение наименования услуги (флагов): true - частичное совпадение, false - полное совпадение
*	@return		Время окончания в формате UNIX
*				-1- до смены карты
*				0- нет ограничений
*				-2- услуга не найдена
*/
native cmsapi_service_timeleft(id, szDate[]="", iLen=0, srvName[]="", bool:part = false);


/**
*	Возвращает причину отключения услуги
*	
*	@id			id игрока
*	@szReason	Причина отключения услуги
*	@iLen		Размер массива szReason[]
*	@srvName	Флаги услуги
*	@part		Совпадение наименования услуги (флагов): true - частичное совпадение, false - полное совпадение
*	@return		true-  услуга активна
*				false- услуга выключена
*/
native bool:cmsapi_is_admin_active(id, szReason[], iLen, const srvName[]="", bool:part = false);


/**
*	Проверка регистрации игрока на сайте
*	
*	@id			id игрока
*	@return		id пользователя в БД
*				0 - пользователь не найден (не зарегистрирован)
*/
native cmsapi_is_user_member(id);


/**
*	Получение информации о балансе кошелька зарегистрированного игрока
*	
*	@id			id игрока
*	@return		Баланс игрока на сайте
*/
native Float:cmsapi_get_user_money(id);


/**
*	Установка баланса кошелька зарегистрированного игрока
*	
*	@id					id игрока
*	@Float:fAmmount		Новое значение баланса
*	@return				1 в случае успеха, 0 в противном случае
*/
native cmsapi_set_user_money(id, Float:fAmmount);


/**
*	Изменение баланса кошелька зарегистрированного игрока (добавить / отнять)
*	
*	@id					id игрока
*	@Float:fAmmount		Добавить значение к балансу
*	@return				1 в случае успеха, 0 в противном случае
*/
native cmsapi_add_user_money(id, Float:fAmmount);


/**
*	Получение данных всех имеющихся на сервере админов
*	
*	@return		New array handle or Invalid_Array if empty
*/
native Array:cmsapi_get_alladmins();


/**
*	Получение данных авторизовавшихся админов
*	
*	@return		New Map handle or Invalid_Trie if empty
*/
native Trie:cmsapi_get_online_admins();


/**
*	Получение данных о всех купленных доп. услугах
*	
*	@return		New array handle or Invalid_Array if empty
*/
native Array:cmsapi_get_all_purchases();


/**
*	Получение данных о купленных услугах игрока
*	
*	@index			id игрока
*	@szAuth[]		steamID игрока
*	@szService[]	Название услуги
*	@serviceID		Номер услуги
*	@part			Совпадение наименования услуги (флагов): true - частичное совпадение, false - полное совпадение
*	@return			New array handle or Invalid_Array if empty
*
*	@Note		Запрос информации обо всех услугах игрока: (szService[] = "" И serviceID = 0)
*	@Note		Запрос информации о конкретной услуге: (szService[] = "`services`.`rights`" ИЛИ serviceID = `services`.`id`)
*/
native Array:cmsapi_get_user_services(const index, const szAuth[] = "", const szService[] = "", serviceID = 0, bool:part = false);


/**
*	Общее время, проведенное игроком на всех серверах проекта
*	
*	@index		Индекс игрока
*	@return		Время в секундах
*/
native cmsapi_get_user_gametime(index);


/**
*	Получение ID админа
*
*	@index		Индекс игрока
*	@szAuth[]	Массив для записи идентификатора услуги (ник / steamid)
*	@iLen		Размер массива
*	@return		ID админа в базе, 0 - если игрок не имеет флагов или ошибка при получении данных
*/
native cmsapi_get_admin_ident(index, szAuth[] = "", iLen = 0);

/**
*	Получение данных по ID админа
*	
*	@aID		ID администратора в БД сайта
*	@return		New Map handle
*				0 - администратор не найден
*/
native Trie:cmsapi_get_admin_info(aID);

/**
*	Получение идентификатора текущего сервера в БД сайта
*
*	@return		Идентификатора текущего сервера
*/
native cmsapi_get_server_id();


/**
*	Получение информации о балансе БАНКА ИГРОВЫХ ДЕНЕГ зарегистрированного игрока
*
*	@id			Индекс игрока
*	@return		Значение баланса игровых денег
*/
native cmsapi_get_user_bank(id);


/**
*	Установка баланса БАНКА ИГРОВЫХ ДЕНЕГ зарегистрированного игрока
*	
*	@id			Индекс игрока
*	@ammount	Новое значение баланса
*	@return		1 в случае успеха, 0 в противном случае
*/
native cmsapi_set_user_bank(id, ammount);


/**
*	Изменение баланса ИГРОВЫХ ДЕНЕГ зарегистрированного игрока  (добавить / отнять)
*	
*	@id			Индекс игрока
*	@ammount	Добавить значение к балансу
*	@return		1 в случае успеха, 0 в противном случае
*/
native cmsapi_add_user_bank(id, ammount);


/**
*	Получение даты  регистрации игрока на сайте
*
*	@id			Индекс игрока
*	@shortTime	true- короткий формат даты ДД-ММ-ГГГГ
*				false - ГГГГ-ММ-ДД Ч:М:С
*	@szDate		Дата регистрации в формате @shortTime
*	@iLen		Размер массива szDate[]
*	@return		Время в формате UNIX
*				0 - пользователь не найден (не зарегистрирован)
*/
native cmsapi_get_user_regdate(id, szDate[] = "", iLen = 0, bool:shortTime = true);


/**
*	Получение даты  последней активности пользователя на сайте
*
*	@id			Индекс игрока
*	@szDate		Дата последней активности в формате ГГГГ-ММ-ДД
*	@iLen		Размер массива szDate[]
*	@return		Время в формате UNIX
*				0 - пользователь не найден (не зарегистрирован)
*/
native cmsapi_get_user_lastactiv(id, szDate[]="", iLen=0);


/**
*	Получение величины персональной скидки на сайте
*
*	@id			Индекс игрока
*	@return		Cкидка в %
*/
native cmsapi_get_user_discount(id);


/**
*	Динамическая перепроверка прав доступа у игрока
*
*	@id		Индекс игрока
*	@noreturn
*/
native cmsapi_reaccess_admin(id);


/**
*	Получение szAuthId игрока в формате steamid64 (profileID)
*	
*	@index		Индекс игрока
*	@auth64[]	Массив для записи steamID64 игрока
*	@iLen		Размер массива auth64[]
*	@return		Количество ячеек, записанных в массив
*/
native cmsapi_get_user_authid64(index, auth64[], iLen);


/**
*	Изменение баланса на сайте
*
*	@index		Индекс игрока
*	@value		Сумма для добавления/списания (value / -value)
*	@send		Отправить запрос в БД: true - да, false - нет
*	@noreturn
*/
native cmsapi_reload_wallet(index, value, bool:send = false);


/**
*	Добавление флагов пользователю на текущую сессию до смены карты
*
*	@index				Индекс игрока
*	@szFlags[]			Флаги доступа
*	@iTime				Срок действия флагов, секунд (-1 - на карту)
*	@szServiceName[]	Название услуги (например, "вип за стим", "ночной вип" и т.п.)
*	@bSilentCheck		Тихое добавление без вызова форварда OnAPIAdminConnected
*	@bAuthorize			Авторизовать пользователя сразу
*	
*	@note				Добавляет данные в массив аккаунтов, для последующей авторизации игрока
*						Если bAuthorize = false, то авторизацию для выдачи флагов необходимо произвести через cmsapi_reaccess_admin(index)
*
*	@return				индекс ячейки, добавленной в массив админов (Array:cmsapi_get_alladmins), -1 - если услуга с этими флагами уже есть.
*/
native cmsapi_set_user_flags(index, const szFlags[], iTime = -1, const szServiceName[] = "", bSilentCheck = false, bAuthorize = true)


/** 
*	Добаление аккаунтов в базу данных
*
*	@iClient		Индекс игрока
*	@szAuthType[]	Тип авторизации (смотри amxconst.inc: Admin authentication behavior flags)
*	@szFlags[]		Флаги (уровни) доступа (смотри amxconst.inc: Admin level constants)
*	@iTime			Время в минутах, 0- навсегда (если время не указано, значит 0)
*	@szPasswd[]		Пароль доступа (если нужен)
*	@iServiceId		Номер услуги на сайте (если известен)
*	@check_params	Проверка введенных данных (true- включить). 
*	
*	@note			При отключеной функции check_params существует вероятность ошибок со стороны пользователя
*
*	@note			Пример:
*					cmsapi_add_account(id, "a", "180", "parol", "prt", 0, false)
*					игроку №id с его ником выданы флаги "prt" на 180 минут, пароль- "parol"
*/
native cmsapi_add_account(iClient, szAuthType[], iTime = 0,  szPasswd[] = "", szFlags[] = "", iServiceId = 0, check_params = false)

/** 
*	Получение настроек пользователя из базы данных
*
*	@iClient			Индекс игрока
*	@sszSettingName[]	Идентификатор настройки (название)
*	@value[]			Массив для записи значения настройки
*	@value_length		Размер массива для записи значения настройки
*	@return
*					- размер записанного массива, если передается массив для записи значения
*					- цифровое значение настройки, если массив не передан
*					- -1, если идентификатор настройки не найден
*/
native cmsapi_get_user_setting(iClient, szSettingName[], value[] = "", value_length = 0)

/** 
*	Сохранение настроек пользователя в базу данных
*
*	@iClient			Индекс игрока
*	@sszSettingName[]	Идентификатор настройки (название)
*	@value[]			Массив со значением настройки
*	@delete				Удалить настройку
*	@return				true - при успешном изменении (удалении), false- при неудаче
*/
native bool:cmsapi_set_user_setting(iClient, szSettingName[], value[], bool:delete = false)


/**
*	Выполняется при заходе зарегистрированного игрока
*
*	@id			id игрока
*	@memberId	id профиля на сайте
*	@memberName	Имя пользователя на сайте
*	@noreturn
*/
forward OnAPIMemberConnected(id, memberId, memberName[])


/**
*	Выполняется при заходе зарегистрированного именинника
*	
*	@id					id игрока
*	@const szLogin[]	Имя игрока на сайте
*	@const SITE_URL[]	Адрес сайта (квар "cms_url") для вывода поздравительного Motd
*	@noreturn
*/
forward OnAPIBirthdayMember(id, const szLogin[], const SITE_URL[])


/**
*	Выполняется при успешной проверке соединения с БД
*
*	@Handle:sqlTuple	Кешированные данные о соединении с БД
*	@version[]			Версия плагина
*	@serverID			Номер сервера в БД сайта (столбец `servers`.id`)
*	@noreturn
*/
forward OnAPIPluginLoaded(Handle:sqlTuple, version[], serverID);


/**
*	Выполняется при неудачной инициализации БД.
*
*	@note	После выполнения, плагин останавливается.
*/
forward OnAPIPluginStop();


/**
*	Выполняется после успешной загрузки всех купленных услуг.
*
*	@noreturn
*/
forward OnAPIAdminsLoaded();


/**
*	Установка префикса в чат из БД
*	
*	@id			id игрока
*	@prefix[]	Префикс игрока в чате
*	@type		Тип префикса:
*				1- личный префикс
*				2- префикс группы (админ, вип и т.п.)
*	@noreturn
*/
forward OnAPISendChatPrefix(id, prefix[], type);

/**
*	Выполняется при выдаче флагов игроку (авторизация админа)
*	
*	@id					id игрока
*	@const szName[]		Ник админа
*	@adminID			ID админа в БД сайта
*	@Flags				Bitflag value- битсумма флагов
*	@noreturn
*/
forward OnAPIAdminConnected(id, const szName[], adminID, Flags);

/**
*	Выполняется при выходе админа (игрока с флагами доступа) с сервера
*	
*	@id			Индекс игрока
*	@noreturn
*/
forward OnAPIAdminDisconnected(id);


/*========================== Plugin GameCMS API END ==========================*/

/*========================== Plugin GameCMS GagManager BEGIN ==========================*/

/**
*	Проверка текущего блока от Админа
*
*	@index		Индекс игрока
*	@return
*				0-	voice + chat
*				1-	chat
*				2-	voice
*				-1- not blocked
*/
native cmsgag_is_user_blocked(index);


/**
*	Проверка текущего блока от игрока
*
*	@sender		Индекс отправителя 
*	@receiver	Индекс получателя
*	@return		1- получатель заблокировал отправителя, 0- нет блокировки игрока
*/
native cmsgag_is_user_muted_by(receiver, sender);


/**
*	Добавление блока игроку
*
*	@id			Индекс игрока
*	@typeFunc	Тип операции блокировки(1- создание, 2- удаление)
*	@blType		Тип блока (чат / голос)
*	@blReason[]	Причина
*	@blTime		Время
*	@printChat	Оповестить в чат об операции, false- нет, true- стандартное оповещение о блокировке/разблокировке
*	@return		0 - блокировка не установлена, >0 - установлена
*/
native cmsgag_add_user_block(id, typeFunc, blType = 0, blReason[] = "", blTime = 0, bool:printChat = true);


/*========================== Plugin GameCMS GagManager END ==========================*/

/*========================== Plugin GameCMS Time Awards BEGIN ==========================*/

/**
*	Общее время, проведенное игроком на всех серверах проекта
*	
*	@index		Индекс игрока
*	@return		Время игры в секундах
*/
native cmsta_get_user_realtime(index);

/*========================== Plugin GameCMS Time Awards END ==========================*/
