// Erythros Telnet Service

class ETelnetSession
{
    CTcpSocket *s;
    EConsole *con;
};

#define EOS_TELNET_PORT 23

#define TELNET_WILL 251
#define TELNET_WONT 252
#define TELNET_DO   253
#define TELNET_DONT 254
#define TELNET_IAC  255

I64 TelnetSvcLogin(ETelnetSession *ts)
{
    I64 i;
    I64 tries = 0;
    Bool shell_exit = FALSE;
    EConReadLine *sh_rl = CAlloc(sizeof(EConReadLine));
	sh_rl->history = CAlloc(sizeof(EConHistory));
    sh_rl->ac = CAlloc(sizeof(EConAutoComplete));
    U8 *user;
    U8 *pass;
ts_do_login:
    user = NULL;
    pass = NULL;
    while (!StrLen(user) || !user)
    {
        if (user) { Free(user); };
        ConPrint(ts->con, "\n%s login: ", wmgr->session->hostname);
        user = ConReadLine(ts->con, sh_rl, 1024);
    }
    ConPrint(ts->con, "Password: ");
    ts->con->disable_echo = TRUE;
    pass = ConReadLine(ts->con, sh_rl, 1024);
    ts->con->disable_echo = FALSE;
    ConPrint(ts->con, "\n");
    for (i=0;i<EOS_MAX_USERS;i++)
    {
        if (!StrCmp(eos_users[i].name, user) && eos_users[i].user)
        {
            if (EOSPasswordMatch(i, pass))
            {
                goto ts_do_shell;
            }
        }
    }
    Free(user);
    Free(pass);
    Sleep(2000);
    ConPrint(ts->con, "\nLogin incorrect");
    tries++;
    if (tries>2)
    {
        ConPrint(ts->con, "\n");
        return;
    }
    goto ts_do_login;
ts_do_shell:
    Shell(ts->con);
}

I64 TelnetSvcClientInputHandler(ETelnetSession *ts)
{
    U8 cmd_s_resp[3];
    I64 cmd_state = NULL;
    I64 esc_state = NULL;
    U8 cmd_resp = NULL;
    I64 i, got;
    U8 *buf=CAlloc(128);
    cmd_s_resp[0] = TELNET_IAC;
    send( ts->s, "\xff\xfb\x01\xff\xfb\x03\xff\xfc\x22", 9, 0);
    while (1)
    {
        got = recv(ts->s, buf, 128, 0);
        for (i=0;i<got;i++)
        {
            switch (cmd_state)
            {
                case 2:
                    cmd_s_resp[1] = cmd_resp;
                    cmd_s_resp[2] = buf[i];
                    send(ts->s, &cmd_s_resp, 3, 0);
                    cmd_state = NULL;
                    break;
                case 1:
                    switch (buf[i])
                    {
                        case TELNET_DO:
                            cmd_resp = TELNET_WILL;
                            cmd_state++;
                            break;
                        case TELNET_WILL:
                            cmd_resp = TELNET_DO;
                            cmd_state++;
                            break;
                        default:
                            cmd_state = NULL;
                            break;
                    };                
                    break;
                default:
                    switch (buf[i])
                    {
                        case 0:
                            break;
                        case 'A'...'D':
                            if (esc_state==2)
                            {
                                switch (buf[i])
                                {
                                    case 'A':
                                        FifoU8Ins(ts->con->stdin, 17);
                                        break;
                                    case 'B':
                                        FifoU8Ins(ts->con->stdin, 18);
                                        break;
                                    case 'D':
                                        FifoU8Ins(ts->con->stdin, 20);
                                        break;
                                    case 'C':
                                        FifoU8Ins(ts->con->stdin, 19);
                                        break;
                                    default:
                                        break;
                                };
                            }
                            else
                            {
                                FifoU8Ins(ts->con->stdin, buf[i]);
                            }
                            esc_state = NULL;
                            break;
                        case '[':
                            if (esc_state==1)
                            {
                                esc_state++;

                            }
                            else
                            {
                                esc_state = NULL;
                                FifoU8Ins(ts->con->stdin, buf[i]);
                            }
                            break;
                        case 0x1b:
                            if (!esc_state)
                            {
                                esc_state++;
                            }
                            break;
                        case TELNET_IAC:
                            esc_state = NULL;
                            if (!cmd_state)
                            {
                                cmd_state++;
                            }
                            else
                            {
                                FifoU8Ins(ts->con->stdin, '\xff');
                                cmd_state = NULL;
                            }
                            break;
                        case '\x0d':
                            esc_state = NULL;
                            FifoU8Ins(ts->con->stdin, '\x0a');
                            break;                            
                        case '\x7f':
                            esc_state = NULL;
                            FifoU8Ins(ts->con->stdin, '\x08');
                            break;
                        default:
                            esc_state = NULL;
                            FifoU8Ins(ts->con->stdin, buf[i]);
                            break;         
                    };  
                    break;
            }

        }
        Sleep(1);
    }
    return 0;
}

I64 TelnetSvcSession(CTcpSocket *s)
{
    I64 i;
    ETelnetSession *ts = CAlloc(sizeof(ETelnetSession));
    EConsole *con = CAlloc(sizeof(EConsole));
	con->stdin=FifoU8New(1024);
	con->stdout=FifoU8New(1048576);
    con->ch_width = 80;
    con->ch_height = 25;
    ts->s = s;
    ts->con = con;
    CTask *shell_proc_task=Spawn(&TelnetSvcLogin, ts, , mp_cnt-3);
    U8 buf[2];
    buf[1] = NULL;
    CTask *shell_input_task=Spawn(&TelnetSvcClientInputHandler, ts,,mp_cnt-2);
    U8 *out_buf=CAlloc(1024);
    I64 buf_pos = 0;
    while (TaskValidate(shell_proc_task))
    {        
        buf_pos = 0;
        while (FifoU8Cnt(con->stdout) && buf_pos<1024)
        {
            FifoU8Rem(con->stdout, out_buf+buf_pos);
            buf_pos++;
            
        }
        if (buf_pos)
            send(s, out_buf, buf_pos, 0);
        Sleep(1);
    }
    Kill(shell_input_task);
    close(s);
    return 0;
}

U0 TelnetSvcShutdown()
{
    CTcpSocketListItem* item = tcp_socket_list[EOS_TELNET_PORT]->next;
    while (item)
    {
        close(item->sock);
        item = tcp_socket_list[EOS_TELNET_PORT]->next;
    }
    close(tcp_bound_sockets[EOS_TELNET_PORT]);
    tcp_bound_sockets[EOS_TELNET_PORT] = NULL;
}

U0 TelnetSvc()
{
    while (!my_ip) { Sleep(1); }; // Wait for Netcfg
    CTcpSocket *sock = socket(AF_INET, SOCK_STREAM);
    if (sock < 0)
        return -1;
    sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(EOS_TELNET_PORT);
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
        Spawn(&TelnetSvcSession, client,,mp_cnt-2);
        Sleep(1);
    }
    close(sock);
    return 0;  
}