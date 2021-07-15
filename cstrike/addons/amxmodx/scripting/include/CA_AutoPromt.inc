/**
*   'id' -- Игрок у которого проверяем, находиться ли игрок 'pPlayer' в муте.
*   1 -- Да | 0 -- Нет.
*/
native ca_get_user_muted(const id,const pPlayer)

/**
*   'id' -- Игрок которому мутим игрока 'pPlayer'
*   1 -- Замутить | 0 -- Размутить
*/
native ca_set_user_muted(const id,const pPlayer,const iMuted = 0)