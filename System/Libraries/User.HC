#define EOS_MAX_USERS 128

class EOSUser
{
    Bool user;
    U8 name[32];
    U8 fullname[32];
    U8 passwd[32];
    U8 groups[32];
};

EOSUser *eos_users = CAlloc(sizeof(EOSUser)*EOS_MAX_USERS);

U0 SetUpDebugUsers()
{
    U32 md5_h[4];
    U8 *debug_pass = "debugpassword";
    StrPrint(eos_users[10].name, "staff");
    StrPrint(eos_users[10].fullname, "Staff Group");

    StrPrint(eos_users[0].user, TRUE);
    StrPrint(eos_users[0].name, "user");
    StrPrint(eos_users[0].fullname, "Erythros User");
    eos_users[0].groups[1] = 10;
    md5(debug_pass, StrLen(debug_pass), &md5_h[0]);
    StrPrint(eos_users[0].passwd, "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        md5_h[0].u8[0], md5_h[0].u8[1], md5_h[0].u8[2], md5_h[0].u8[3],
        md5_h[1].u8[0], md5_h[1].u8[1], md5_h[1].u8[2], md5_h[1].u8[3],
        md5_h[2].u8[0], md5_h[2].u8[1], md5_h[2].u8[2], md5_h[2].u8[3],
        md5_h[3].u8[0], md5_h[3].u8[1], md5_h[3].u8[2], md5_h[3].u8[3]);
}

SetUpDebugUsers;