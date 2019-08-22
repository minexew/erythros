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

I64 TelnetSvcShell(ETelnetSession *ts)
{
    I64 i;
    CHashFun *ccmd;	
    I64 (*cexe)(EConsole *con, I64 argc, U8 **argv);
    U64 ccmd_table = Fs->hash_table;
    EConReadLine *sh_rl = CAlloc(sizeof(EConReadLine));

	sh_rl->history = CAlloc(sizeof(EConHistory));
    sh_rl->ac = CAlloc(sizeof(EConAutoComplete));

	U8 *shell_cur_dir = CAlloc(1024);
	U8 *shell_prev_dir = CAlloc(1024);

    U8 *shell_pmt = CAlloc(256);
    U8 *shell_input_buf;
    U8 *shell_cmd_buf = CAlloc(1024);
    U8 *shell_nul;
    U8 *shell_nul2;

    U8 *user;
    U8 *pass;

    Bool shell_exit = FALSE;

    I64 res;
    U8 **argv = NULL;
    I64 argc = 0;

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
    goto ts_do_login;

ts_do_shell:
    while (!shell_exit)
    {       
		StrPrint(shell_cur_dir, "!:/%s", Fs->cur_dir);
		shell_cur_dir[0] = Fs->cur_dv->drv_let;
        shell_nul = CAlloc(1024);
		shell_nul2 = shell_nul;
        StrPrint(shell_nul, "!:%s", Fs->cur_dir);
        shell_nul[0] = Fs->cur_dv->drv_let;
		shell_nul = StrReplace(shell_nul, blkdev.home_dir, "~");
		Free(shell_nul2);

		ConPrint(ts->con, "\x1b]0;%s@%s: %s\x07", wmgr->session->user, wmgr->session->hostname, shell_nul);
        
 		StrPrint(shell_pmt, "\x1b[1;32m%s@%s", wmgr->session->user, wmgr->session->hostname);        
		ConPrint(ts->con, shell_pmt);
		StrPrint(shell_pmt, "\x1b[0;37m:\x1b[1;34m");
		ConPrint(ts->con, shell_pmt);
		StrPrint(shell_pmt, "%s\x1b[0;39m$$ ", shell_nul);
		ConPrint(ts->con, shell_pmt);
    
		Free(shell_nul);

        argc = 0;
        shell_input_buf = ConReadLine(ts->con, sh_rl, 4096);

        if (!shell_input_buf)
		{
			goto ts_prompt_next;
		}

		// TODO: add history item / env variable expansion here, before ParseArgs
		// ex: !(hist_idx)

		argv = ParseArgs(shell_input_buf, &argc);
        if (argc)
        {
			if (!(StrCmp(argv[0], "exit")))
			{
                Sleep(10);
                shell_exit = TRUE;
                goto ts_prompt_next;
			}

            /*
			sh_rl->history->pos++;
			if (sh_rl->history->pos > sh_rl->history->limit)
			{
				MemCpy(sh_rl->history->entries, sh_rl->history->entries+8, sh_rl->history->limit-1);
				sh_rl->history->pos--;
			}
			sh_rl->history->entries[sh_rl->history->pos-1] = StrNew(shell_input_buf);
            */

            StrPrint(shell_cmd_buf, "CCMD_%s", argv[0]);
            ccmd = HashFind(shell_cmd_buf, ccmd_table, -1);
            if (ccmd)
            {
                cexe = ccmd->exe_addr;
				ts->con->rl = sh_rl;
                res = cexe(ts->con, argc, argv);
                goto ts_prompt_next;
            }
            else
            {
            }
            ConPrint(ts->con, "%s: command not found\n", argv[0]);
        }
ts_prompt_next:
        if (argc)
        {
    		FreeArgs(argc, argv);
        }
		if (shell_input_buf)
		{
			Free(shell_input_buf);
		}
    }
    Free(shell_pmt);
    Free(shell_cmd_buf);
    Free(shell_cur_dir);
    Free(shell_prev_dir);
}

I64 TelnetSvcClientInputHandler(ETelnetSession *ts)
{
    U8 cmd_s_resp[3];
    I64 cmd_state = NULL;
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
                        case TELNET_IAC:
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
                            FifoU8Ins(ts->con->stdin, '\x0a');
                            break;                            
                        case '\x7f':
                            FifoU8Ins(ts->con->stdin, '\x08');
                            break;
                        default:
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
    CTask *shell_proc_task=Spawn(&TelnetSvcShell, ts, , mp_cnt-3);
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