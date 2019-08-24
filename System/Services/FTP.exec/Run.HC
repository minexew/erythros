// Erythros FTP Service

class EFTPSession
{
    CTcpSocket *s;
};

#define EOS_FTP_CMD_PORT    21
#define EOS_FTP_DATA_PORT   20

U8 *_ftp_realloc(U8 *ptr, I64 size)
{        
    U8 *new;
    if (!ptr) {
        new = MAlloc(size);
        if (!new) { goto _ra_error; }
    } else {
        if (MSize(ptr) < size) {
            new = MAlloc(size);
            if (!new) { goto _ra_error; }
            MemCpy(new, ptr, MSize(ptr));
            Free(ptr);
        } else {
            new = ptr;
        }
    }
    return new;
_ra_error:
    return NULL;    
}

I64 FTPSvcSession(CTcpSocket *s)
{
    CTcpSocket *data_s;
    I64 data_sock;
    I64 err;
    I64 got;
    I64 step;
    I64 total;
    U8 **argv;
    I64 argc = NULL;
    I64 uid = -1;
    U16 pasv_port;
    U8 *user_str;
    U8 *pass_str;
    Bool ftp_quit = FALSE;
    Bool type_binary = FALSE;
    U8 *recv_buf = CAlloc(1048576);
    U8 *send_buf = CAlloc(1048576);
    U8 *rnfr = NULL;

    I64 retr_size = 0;
    U8 *retr_buf = NULL;
    I64 stor_size = 0;
    I64 file_size = 0;
    U8 *stor_buf = NULL;

    CDirEntry *tmpde = NULL;
    CDirEntry *tmpde2 = NULL;
    CDateStruct *ds = CAlloc(sizeof(CDateStruct));
    StrPrint(send_buf, "220 Erythros FTP Service ready.\n");
    send(s, send_buf, StrLen(send_buf), 0);
    while (!ftp_quit)
    {
        MemSet(recv_buf, 0, 1024);
        got = recv(s, recv_buf, 1024, 0);
        if (got<=0)
        {
            goto ftp_sess_cleanup;
        }
        while (recv_buf[StrLen(recv_buf)-1] == '\r' || 
            recv_buf[StrLen(recv_buf)-1] == '\n')
        {
            recv_buf[StrLen(recv_buf)-1] = NULL;
        }
        argc = NULL;
		argv = ParseArgs(recv_buf, &argc);
        if (argc)
        {
            if (!StrCmp("FEAT", argv[0]))
            {
                StrPrint(send_buf, "211 End FEAT.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("USER", argv[0]))
            {
                if (uid==-1)
                {
                    user_str = StrNew(argv[1]);
                    StrPrint(send_buf, "331 Username ok, send password.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                }
                goto ftp_next_cmd;
            }
            if (!StrCmp("PASS", argv[0]))
            {
                if (uid==-1)
                {
                    pass_str = StrNew(argv[1]);
                    StrPrint(send_buf, "230 Login successful.\n");
                    // 530 Authentication failed.
                    send(s, send_buf, StrLen(send_buf), 0);
                }
                goto ftp_next_cmd;
            }         
            if (!StrCmp("PASV", argv[0]))
            {
                pasv_port = 0x2000 + (RandU16 & 0x1FFF);
                while (tcp_bound_sockets[pasv_port])
                {
                    pasv_port = 0x2000 + (RandU16 & 0x1FFF);
                }
                U32 en0_addr = virtio_net.ipv4.addr;
                CTcpSocket *sock = socket(AF_INET, SOCK_STREAM);
                if (sock < 0)
                    return -1;
                sockaddr_in addr;
                addr.sin_family = AF_INET;
                addr.sin_port = htons(pasv_port);
                addr.sin_addr.s_addr = INADDR_ANY;
                if (bind(sock, &addr, sizeof(addr)) < 0) {
                    close(sock); /* Failed to bind to port */
                    return -1;
                }
                I64 error = listen(sock, 1);
                if (error < 0) { /* listen: error */
                    return -1;
                }
                StrPrint(send_buf, "227 Entering passive mode (%d,%d,%d,%d,%d,%d).\n",
                    en0_addr.u8[3], en0_addr.u8[2], en0_addr.u8[1], en0_addr.u8[0],
                    pasv_port.u8[1], pasv_port.u8[0]);
                send(s, send_buf, StrLen(send_buf), 0);
                data_sock = accept(sock, 0, 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("MKD", argv[0]) && argc>1)
            {
                if (FileFind(argv[1]))
                {
                    StrPrint(send_buf, "550 File exists.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                    goto ftp_next_cmd;
                }
                DirMk(argv[1]);
                StrPrint(send_buf, "257 \"%s\" directory created.\n", argv[1]);
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("RMD", argv[0]) && argc>1)
            {
                if (!FileFind(argv[1]))
                {
                    StrPrint(send_buf, "550 No such file or directory.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                    goto ftp_next_cmd;
                }
                DelTree(argv[1]);
                StrPrint(send_buf, "250 \"%s\" directory removed.\n", argv[1]);
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("RNFR", argv[0]) && argc>1)
            {
                rnfr = StrNew(argv[1]);
                StrPrint(send_buf, "350 Ready for destination name.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("RNTO", argv[0]) && argc>1 && rnfr)
            {
                Move(rnfr, argv[1]);
                Free(rnfr);
                rnfr = NULL;
                StrPrint(send_buf, "250 renaming ok.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }                    
            if (!StrCmp("DELE", argv[0]) && argc>1)
            {
                if (!FileFind(argv[1]))
                {
                    StrPrint(send_buf, "550 No such file or directory.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                    goto ftp_next_cmd;
                }
                Del(argv[1]);
                StrPrint(send_buf, "250 File removed.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("RETR", argv[0]) && argc>1)
            {
                if (!FileFind(argv[1]))
                {
                    StrPrint(send_buf, "550 No such file or directory.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                    goto ftp_next_cmd;
                }
                retr_size = 0;
                retr_buf = FileReadRaw(argv[1], &retr_size);
                StrPrint(send_buf, "150 File status okay; about to open data connection.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                err = 0;
                got = 0;
                step = 0;
                total = 0;
                while (total < retr_size)
                {
                    step = retr_size - total;
                    if (step > 1024) { step = 1024; };
                    err = send(data_sock, retr_buf + total, step, 0);
                    if (err < 0)
                    {
                        Free(retr_buf);
                        close(data_sock);
                    }
                    total += step;
                    Sleep(1);
                }
                Free(retr_buf);
                TcpSend2(data_sock, TCP_FLAG_ACK | TCP_FLAG_FIN);
                StrPrint(send_buf, "226 Transfer complete.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;               
            }
            if ((!StrCmp("STOR", argv[0]) || !StrCmp("APPE", argv[0])) && argc>1)
            {
                stor_buf = NULL;
                err = 0;
                got = 0;
                step = 1024;
                file_size = 0;
                if (!StrCmp("APPE", argv[0]))
                {
                    if (FileFind(argv[1]))
                    {
                        stor_buf = FileReadRaw(argv[1], &file_size);
                    }
                }
                stor_size = file_size + step;
                StrPrint(send_buf, "150 File status okay; about to open data connection.\n");
                send(s, send_buf, StrLen(send_buf), 0);
ftp_stor_loop:
                stor_buf = _ftp_realloc(stor_buf, stor_size);
                got = recv(data_sock, stor_buf+stor_size-step , step, 0);
                if (got <= 0)
                {
                    FileWriteRaw(argv[1], stor_buf, file_size);
                    Free(stor_buf);
                    close(data_sock);
                    StrPrint(send_buf, "226 Transfer complete.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                    goto ftp_next_cmd;               
                }
                stor_size += step;
                file_size += got;
                goto ftp_stor_loop;
            }
            if (!StrCmp("LIST", argv[0]))
            {
                StrPrint(send_buf, "150 File status okay; about to open data connection.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                if (argc>1)
                {
                    tmpde = FilesFind(argv[1]);
                }
                else
                {
                    tmpde = FilesFind(Fs->cur_dir);
                }
                tmpde2 = tmpde;
                while (tmpde2)
                {
                    if (!!StrCmp(tmpde2->name, ".") && !!StrCmp(tmpde2->name, ".."))
                    {
                        Date2Struct(ds, tmpde2->datetime);
                        StrPrint(send_buf, "modify=%04d%02d%02d%02d%02d%02d;perm=%s;size=%d;type=%s;unix.gid=%d;unix.mode=%04d;unix.uid=%d; %s\r\n",
                            ds->year, ds->mon, ds->day_of_mon, ds->hour, ds->min, ds->sec, cond(tmpde2->attr&RS_ATTR_DIR, "eldfmcp", "radfw"),
                            tmpde2->size, cond(tmpde2->attr&RS_ATTR_DIR, "dir", "file"), cond(tmpde2->attr&RS_ATTR_DIR, 0, 1000),
                            cond(tmpde2->attr&RS_ATTR_DIR, 755, 664), cond(tmpde2->attr&RS_ATTR_DIR, 0, 1000), tmpde2->name);
                        send(data_sock, send_buf, StrLen(send_buf), 0);
                    }
                    tmpde2 = tmpde2->next;
                }
                DirTreeDel(tmpde);
                TcpSend2(data_sock, TCP_FLAG_ACK | TCP_FLAG_FIN);
                //close(data_sock);
                //close(sock);
                StrPrint(send_buf, "226 Transfer complete.\n");
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("CWD", argv[0]) && argc>1)
            {
                Cd(argv[1]);
                StrPrint(send_buf, "250 \"%s\" is the current directory.\n", Fs->cur_dir);
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("PWD", argv[0]))
            {
                StrPrint(send_buf, "257 \"%s\" is the current directory.\n", Fs->cur_dir);
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("SYST", argv[0]))
            {
                StrPrint(send_buf, "215 UNIX Type: L8\n");
                send(s, send_buf, StrLen(send_buf), 0);
                goto ftp_next_cmd;
            }
            if (!StrCmp("TYPE", argv[0]))
            {
                if (!StrCmp("A", argv[1]))
                {
                    type_binary = FALSE;
                    StrPrint(send_buf, "200 Type set to: ASCII.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                    goto ftp_next_cmd;
                }
                if (!StrCmp("I", argv[1]))
                {
                    type_binary = TRUE;
                    StrPrint(send_buf, "200 Type set to: Binary.\n");
                    send(s, send_buf, StrLen(send_buf), 0);
                    goto ftp_next_cmd;
                }
            }
            StrPrint(send_buf, "500 Command \"%s\" not understood.\n", argv[0]);
            send(s, send_buf, StrLen(send_buf), 0);
        }
ftp_next_cmd:
        if (argc)
        {
		    FreeArgs(argc, argv);
            argc = NULL;
        }
    }
ftp_sess_cleanup:
    Free(recv_buf);
    Free(send_buf);
    Free(ds);
    close(s);
    return 0;

}

U0 FTPSvcShutdown()
{

}

I64 FTPSvc()
{
    while (!my_ip) { Sleep(1); }; // Wait for Netcfg
    CTcpSocket *sock = socket(AF_INET, SOCK_STREAM);
    if (sock < 0)
        return -1;
    sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(EOS_FTP_CMD_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;
    if (bind(sock, &addr, sizeof(addr)) < 0) {
        close(sock); /* Failed to bind to port */
        return -1;
    }
    I64 error = listen(sock, 1);
    if (error < 0) { /* listen: error */
        return -1;
    }
    while (1)
    {
        I64 client = accept(sock, 0, 0);
        Spawn(&FTPSvcSession, client,,mp_cnt-2);
        Sleep(1);
    }
    close(sock);
    return 0;  
}