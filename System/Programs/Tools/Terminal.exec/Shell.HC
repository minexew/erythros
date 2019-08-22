I64 ShellGetCmdEntries(CHashTable *tbl, U8 **entries=NULL)
{
	I64 i;
	I64 cnt = 0;
	CHashSrcSym *sym;
	U8 *srch_pfx = "CCMD_";
	while (tbl)
	{
		for (i = 0; i <= tbl->mask; i++)
		{
			sym = tbl->body[i];
			while (sym)
			{
				if (StrLen(sym->str) >= StrLen(srch_pfx) && sym->type & HTT_FUN == HTT_FUN)
				{
					if (!MemCmp(sym->str, srch_pfx, StrLen(srch_pfx)))
					{
						if (entries)
						{
							entries[cnt] = StrNew(sym->str);
						}
						cnt++;
					}
				}
				sym = sym->next;
			}
		}
		tbl = tbl->next;
	} 
	return cnt;
}

I64 ShellGetDirEntries(U8 **entries=NULL, U8 *path = NULL)
{
	I64 cnt = 0;
	CDirEntry *de;
	if (!path)
	{
		de = FilesFind(path);
	}
	else
	{
		de = FilesFind(Fs->cur_dir);
	}
	while (de)
	{
		if (entries)
		{
			if (de->attr & RS_ATTR_DIR == RS_ATTR_DIR)
			{
				entries[cnt] = CAlloc(StrLen(de->name)+2);
				StrCpy(entries[cnt], de->name);
				entries[cnt][StrLen(entries[cnt])] = '/';
				entries[cnt][StrLen(entries[cnt])] = NULL;
			}
			else
			{
				entries[cnt] = StrNew(de->name);
			}
		}
		cnt++;
		de = de->next;
	}
	DirTreeDel(de);
	return cnt;
}

U0 ShellRefreshACDirEntries(EConReadLine *rl)
{ // Refresh level 2 (DirEntry) entries.
	I64 i;
	if (rl->ac->entries[1])
	{
		for (i = 0; i < rl->ac->length[1]; i++)
		{
			Free(rl->ac->entries[1][i]);
		}
		Free (rl->ac->entries[1]);
	}
	rl->ac->length[1] = ShellGetDirEntries;
	rl->ac->entries[1] = CAlloc(sizeof(U64)*rl->ac->length[1]);
	ShellGetDirEntries(rl->ac->entries[1]);	
}

U0 ShellRefreshACCmdEntries(EConReadLine *rl, U64 ccmd_table)
{ // Refresh level 1 (command) entries.
	if (!rl->ac)
	{
		rl->ac = CAlloc(sizeof(EConAutoComplete));
		rl->ac->depth = 2;
		rl->ac->length[0] = ShellGetCmdEntries(ccmd_table);
		rl->ac->entries = CAlloc(sizeof(U64)*8);
		rl->ac->entries[0] = CAlloc(sizeof(U64)*rl->ac->length[0]);
		ShellGetCmdEntries(ccmd_table, rl->ac->entries[0]);
	}
}

U0 ShellInitHistory(EConReadLine *rl)
{
	rl->history = CAlloc(sizeof(EConHistory));
	rl->history->limit = 1000;
	rl->history->entries = CAlloc(sizeof(U64) * rl->history->limit);
}

U0 Shell(EConsole *con)
{
	U64 ccmd_table = Fs->hash_table;
	EConReadLine *shell_rl = CAlloc(sizeof(EConReadLine));
	U8 *shell_pmt = CAlloc(256);
	U8 *shell_input_buf;
	U8 *shell_cmd_buf = CAlloc(1024);
	U8 *shell_nul;	

	I64 _i;
    I64 res;
	I64 argc;
	U8 **argv;
	U8 *shell_nul2;
	U8 *shell_cur_dir = CAlloc(1024);
	U8 *shell_prev_dir = CAlloc(1024);
	Bool shell_exit = FALSE;
    CHashFun *ccmd;	
    I64 (*cexe)(EConsole *con, I64 argc, U8 **argv);

	ConClear(con);
	ShellInitHistory(shell_rl);
	ShellRefreshACCmdEntries(shell_rl, ccmd_table);

	while (!shell_exit)
	{
		StrPrint(shell_cur_dir, "!:/%s", Fs->cur_dir);
		shell_cur_dir[0] = Fs->cur_dv->drv_let;
		//if (StrCmp(shell_prev_dir, shell_cur_dir)!=0)
		//{
			ShellRefreshACDirEntries(shell_rl);
		//	StrPrint(shell_prev_dir, shell_cur_dir);
		//}

        shell_nul = CAlloc(1024);
		shell_nul2 = shell_nul;

		//StrPrint(shell_nul, " %d: ", rl->ac->length[0]);
		//StrPrint(shell_nul, " %s: ", rl->ac->entries[0][1]);
		//ConPrint(con, shell_nul);

        StrPrint(shell_nul, "!:%s", Fs->cur_dir);
        shell_nul[0] = Fs->cur_dv->drv_let;

		shell_nul = StrReplace(shell_nul, blkdev.home_dir, "~");
		Free(shell_nul2);
        
		if (con->stdout)
		{
			ConPrint(con, "\x1b]0;%s@%s: %s\x07", wmgr->session->user, wmgr->session->hostname, shell_nul);
		}
		else
		{
			StrPrint(con->win->title, "%s@%s: %s", wmgr->session->user, wmgr->session->hostname, shell_nul);
		}
		ConSetColor(con, 0xADE25D00, con->bg_color);
		StrPrint(shell_pmt, "%s@%s", wmgr->session->user, wmgr->session->hostname);
		ConPrint(con, shell_pmt);

		ConSetColor(con, 0xFFFFFF00, con->bg_color);
		StrPrint(shell_pmt, ":");
		ConPrint(con, shell_pmt);

		ConSetColor(con, 0x729FCF00, con->bg_color);
		StrPrint(shell_pmt, "%s$$ ", shell_nul);
		ConPrint(con, shell_pmt);

		Free(shell_nul);

		argc = 0;
		argv = NULL;

		ConSetColor(con, 0xFFFFFF00, con->bg_color);
		con->etx = FALSE;
		shell_input_buf = ConReadLine(con, shell_rl, 4096);
		if (!shell_input_buf)
		{
			goto prompt_next;
		}

		// TODO: add history item / env variable expansion here, before ParseArgs
		// ex: !(hist_idx)

		argv = ParseArgs(shell_input_buf, &argc);
        if (argc)
        {
			if (!(StrCmp(argv[0], "exit")))
			{
				if (con->stdout)
				{
					shell_exit = TRUE;
				}
				else
				{
					con->win->msg_close = TRUE;
					while (1) { Sleep(1); };
				}
			}
			shell_rl->history->pos++;
			if (shell_rl->history->pos > shell_rl->history->limit)
			{
				MemCpy(shell_rl->history->entries, shell_rl->history->entries+8, shell_rl->history->limit-1);
				shell_rl->history->pos--;
			}
			shell_rl->history->entries[shell_rl->history->pos-1] = StrNew(shell_input_buf);

            StrPrint(shell_cmd_buf, "CCMD_%s", argv[0]);
            ccmd = HashFind(shell_cmd_buf, ccmd_table, -1);
            if (ccmd)
            {
                cexe = ccmd->exe_addr;
				con->rl = shell_rl;
                res = cexe(con, argc, argv);
                goto prompt_next;
            }
            else
            {
            }
            ConPrint(con, "%s: command not found\n", argv[0]);
        }
prompt_next:
		FreeArgs(argc, argv);
		if (shell_input_buf)
		{
			Free(shell_input_buf);
		}
		Sleep(1);
	}
}