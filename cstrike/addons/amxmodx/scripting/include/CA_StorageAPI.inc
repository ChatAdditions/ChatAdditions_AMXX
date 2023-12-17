#if defined _CA_STORAGE_API_included
    #endinput
#endif

#define _CA_STORAGE_API_included

/*
 *
 */
native CA_Storage_Save(const name[], const authID[], const IP[], const reason[], const adminName[], const adminAuthID[], const adminIP[], const expireAt, const flags)

/*
 *
 */
native CA_Storage_Load(const authID[])

/*
 *
 */
native CA_Storage_Remove(const authID[])


/*
 *
 */
forward CA_Storage_Initialized()

/*
 *
 */
forward CA_Storage_Saved(const name[], const authID[], const IP[], const reason[],
    const adminName[], const adminAuthID[], const adminIP[],
    const createdAt, const expireAt, const flags)

/*
 *
 */
forward CA_Storage_Loaded(const name[], const authID[], const IP[], const reason[],
    const adminName[], const adminAuthID[], const adminIP[],
    const createdAt, const expireAt, const flags)

/*
 *
 */
forward CA_Storage_Removed()
