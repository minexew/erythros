/* Erythros 'vi'-style editor by alec
 * Portions based on Kilo editor by antirez
 * https://github.com/antirez/kilo 
 *
 * Kilo -- A very simple editor in less than 1-kilo lines of code (as counted
 *         by "cloc"). Does not depend on libcurses, directly emits VT100
 *         escapes on the terminal.
 *
 * -----------------------------------------------------------------------
 *
 * Copyright (C) 2016 Salvatore Sanfilippo <antirez at gmail dot com>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *  *  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *
 *  *  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* Syntax highlight types */
#define VI_HL_NORMAL 0
#define VI_HL_NONPRINT 1
#define VI_HL_COMMENT 2   /* Single line comment. */
#define VI_HL_MLCOMMENT 3 /* Multi-line comment. */
#define VI_HL_KEYWORD 4
#define VI_HL_CLASS 5
#define VI_HL_STRING 6
#define VI_HL_NUMBER 7
#define VI_HL_MATCH 8      /* Search match. */

#define VI_HL_HIGHLIGHT_STRINGS (1<<0)
#define VI_HL_HIGHLIGHT_NUMBERS (1<<1)

class vi_editorSyntax {
    U8 **filematch;
    U8 **keywords;
    U8 **classes;    
    U8 *singleline_comment_start;
    U8 *multiline_comment_start;
    U8 *multiline_comment_end;
    I64 flags;
};

/* This structure represents a single line of the file we are editing. */
class vi_erow {
    I64 idx;            /* Row index in the file, zero-based. */
    I64 size;           /* Size of the row, excluding the null term. */
    I64 rsize;          /* Size of the rendered row. */
    U8 *chars;        /* Row content. */
    U8 *render;       /* Row content "rendered" for screen (for TABs). */
    U8 *hl;  /* Syntax highlight type for each character in render.*/
    I64 VI_HL_oc;          /* Row had open comment at end in last syntax highlight
                           check. */
};

#define VI_MODE_NORMAL      0
#define VI_MODE_INSERT      1
#define VI_MODE_VISUAL      2

class vi_editorConfig {
    Bool quit;  /* Quit program */
    I64 cx,cy;  /* Cursor x and y position in characters */
    I64 rowoff;     /* Offset of row displayed. */
    I64 coloff;     /* Offset of column displayed. */
    I64 screenrows; /* Number of rows that we can show */
    I64 screencols; /* Number of cols that we can show */
    I64 numrows;    /* Number of rows */
    I64 rawmode;    /* Is terminal raw mode enabled? */
    vi_erow *row;      /* Rows */
    I64 dirty;      /* File modified but not saved. */
    Bool init;
    Bool incmd; /* Are we inside of a command? */
    I64 cmd; /* Command */
    U8 *cmdbuf; /* Command input buffer */
    I64 *filename; /* Currently open filename */
    U8 *statusmsg;
    U8 *errormsg;
    I64 mode; /* NORMAL, INSERT, VISUAL */
    vi_editorSyntax *syntax;    /* Current syntax highlight, or NULL. */
};

/* =========================== Syntax highlights DB =========================
 *
 * In order to add a new syntax, define two arrays with a list of file name
 * matches and keywords. The file name matches are used in order to match
 * a given syntax with a given file name: if a match pattern starts with a
 * dot, it is matched as the last past of the filename, for example ".c".
 * Otherwise the pattern is just searched inside the filenme, like "Makefile").
 *
 * The list of keywords to highlight is just a list of words, however if they
 * a trailing '|' character is added at the end, they are highlighted in
 * a different color, so that you can have two different sets of keywords.
 *
 * Finally add a stanza in the HLDB global variable with two two arrays
 * of strings, and a set of flags in order to enable highlighting of
 * comments and numbers.
 *
 * The characters for single and multi line comments must be exactly two
 * and must be provided as well (see the C language example).
 *
 * There is no support to highlight patterns currently. */

/* HolyC */
U8 *C_VI_HL_extensions[5] = {".hc",".hc.z", ".HC", ".HC.Z", NULL};

U8 **C_VI_HL_keywords;
U8 **C_VI_HL_classes;

I64 VI_HL_populate = 0;
I64 VI_HL_keywords_cnt = 0;
I64 VI_HL_keywords_idx = 0;
I64 VI_HL_classes_cnt = 0;
I64 VI_HL_classes_idx = 0;
I64 vi_i;

CHashTable  *vi_lookup_tbl;
CHashSrcSym *vi_lookup_sym;

while (VI_HL_populate<2)
{
    vi_lookup_tbl = adam_task->hash_table;
    while (vi_lookup_tbl)
    {
	    for (vi_i = 0; vi_i <= vi_lookup_tbl->mask; vi_i++)
	    {
		    vi_lookup_sym = vi_lookup_tbl->body[vi_i];
		    while (vi_lookup_sym)
		    {
			    if (vi_lookup_sym->type & HTT_KEYWORD)
			    {
                    if (VI_HL_populate)
                    {
                        C_VI_HL_keywords[VI_HL_keywords_idx] = StrNew(vi_lookup_sym->str);
                        VI_HL_keywords_idx++;
                    }
                    else
                    {
                        VI_HL_keywords_cnt++;
                    }
			    }
			    if (vi_lookup_sym->type & HTT_CLASS || vi_lookup_sym->type & HTT_ASM_KEYWORD ||
                    vi_lookup_sym->type & HTT_INTERNAL_TYPE)
			    {
                    if (VI_HL_populate)
                    {
                        C_VI_HL_classes[VI_HL_classes_idx] = StrNew(vi_lookup_sym->str);
                        VI_HL_classes_idx++;
                    }
                    else
                    {
                        VI_HL_classes_cnt++;
                    }
			    }
			    vi_lookup_sym = vi_lookup_sym->next;
		    }
	    }  
	    vi_lookup_tbl = vi_lookup_tbl->next;
    } 
    if (!VI_HL_populate)
    {
        C_VI_HL_keywords = CAlloc(sizeof(U8*) * VI_HL_keywords_cnt+1);
        C_VI_HL_classes = CAlloc(sizeof(U8*) * VI_HL_classes_cnt+1);
    }
    VI_HL_populate++;
}

#define HLDB_ENTRIES 1

Bool _vi_isdigit(I64 n)
{
    return n>47 && n<58;
}

Bool _vi_isspace(I64 ch)
{
    switch (ch & 0xFF)
    {
        case ' ':
        case '\t':
        case '\n':
        case '\v':
        case '\f':
        case '\r':
            return TRUE;
            break;
        default:
            return FALSE;
            break;
    }
    return FALSE;
}

I64 _vi_is_separator(I64 c) {
    U8 ch[2];
    ch[0] = c;
    ch[1] = NULL;
    return c == '\0' || _vi_isspace(c) || StrFirstOcc(",.()+-/*=~%[];", &ch) != NULL;
}

U0 _vi_memmove(U8 *dest, U8 *src, I64 n)
{
    U8 *pd = dest;
    U8 *ps = src;
    //if (__np_anyptrlt(ps, pd))
    if(ps < pd)
        for (pd += n, ps += n; n--;)
            *--pd = *--ps;
    else
        while(n--)
            *pd++ = *ps++;
    return dest;
}

U8 *_vi_realloc(U8 *ptr, I64 size)
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

U0 _vi_ResetAllRows(EConsole *con)
{
    I64 i;
    DCFill(con->ch_buf, NULL);
	for (i=0;i<display.width*128;i++)
	{
		con->fg_buf[i]=con->fg_color;
		con->bg_buf[i]=con->bg_color;
	}
}

EConsole *_vi_SaveAndInitConsoleState(EConsole *con)
{
    // Save current console state
    EConsole *state = CAlloc(sizeof(EConsole));
    MemCpy(state, con, sizeof(EConsole));
    // Init console buffers for vi
	CDC *ch_buf = DCNew(display.width, 1024);
	U8 *fg_buf  = CAlloc(display.width*1024);
	U8 *bg_buf  = CAlloc(display.width*1024);
	con->ch_buf = ch_buf;
	con->fg_buf = fg_buf;
	con->bg_buf = bg_buf;
    _vi_ResetAllRows(con);   
    return state;
}

U0 _vi_ResumeConsoleState(EConsole *con, EConsole *state)
{
    CDC *ch_buf = con->ch_buf;
    U8 *fg_buf  = con->fg_buf;
    U8 *bg_buf  = con->bg_buf;
    MemCpy(con, state, sizeof(EConsole));
    DCDel(ch_buf);
    Free(fg_buf);
    Free(bg_buf);
}

/* Return true if the specified row last char is part of a multi line comment
 * that starts at this row or at one before, and does not end at the end
 * of the row but spawns to the next row. */
U0 _vi_editorRowHasOpenComment(vi_erow *row) {
    if (row->hl && row->rsize && row->hl[row->rsize-1] == VI_HL_MLCOMMENT &&
        (row->rsize < 2 || (row->render[row->rsize-2] != '*' ||
                            row->render[row->rsize-1] != '/'))) return 1;
    return 0;
}

/* Set every byte of row->hl (that corresponds to every character in the line)
 * to the right syntax highlight type (VI_HL_* defines). */
U0 _vi_editorUpdateSyntax(vi_editorConfig *E, vi_erow *row) {
    row->hl = _vi_realloc(row->hl,row->rsize);
    MemSet(row->hl,VI_HL_NORMAL,row->rsize);

    //return;
    
    if (E->syntax == NULL) return; /* No syntax, everything is VI_HL_NORMAL. */

    I64 i, prev_sep, in_string, in_comment;
    U8 *p;
    U8 **keywords = E->syntax->keywords;
    U8 **classes = E->syntax->classes;
    U8 *scs = E->syntax->singleline_comment_start;
    U8 *mcs = E->syntax->multiline_comment_start;
    U8 *mce = E->syntax->multiline_comment_end;

    /* Point to the first non-space char. */
    p = row->render;
    i = 0; /* Current char offset */
    while(*p && _vi_isspace(*p)) {
        p++;
        i++;
    }
    prev_sep = 1; /* Tell the parser if 'i' points to start of word. */
    in_string = 0; /* Are we inside "" or '' ? */
    in_comment = 0; /* Are we inside multi-line comment? */

    /* If the previous line has an open comment, this line starts
     * with an open comment state. */
    if (row->idx > 0 && _vi_editorRowHasOpenComment(&E->row[row->idx-1]))
        in_comment = 1;

    while(*p) {
        /* Handle // comments. */
        if (prev_sep && *p == scs[0] && *(p+1) == scs[1]) {
            /* From here to end is a comment */
            MemSet(row->hl+i,VI_HL_COMMENT,row->size-i);
            return;
        }

        /* Handle multi line comments. */
        if (in_comment) {
            row->hl[i] = VI_HL_MLCOMMENT;
            if (*p == mce[0] && *(p+1) == mce[1]) {
                row->hl[i+1] = VI_HL_MLCOMMENT;
                p += 2; i += 2;
                in_comment = 0;
                prev_sep = 1;
                goto vi_eus_cont;
            } else {
                prev_sep = 0;
                p++; i++;
                goto vi_eus_cont;
            }
        } else if (*p == mcs[0] && *(p+1) == mcs[1]) {
            row->hl[i] = VI_HL_MLCOMMENT;
            row->hl[i+1] = VI_HL_MLCOMMENT;
            p += 2; i += 2;
            in_comment = 1;
            prev_sep = 0;
            goto vi_eus_cont;
        }

        /* Handle "" and '' */
        if (in_string) {
            row->hl[i] = VI_HL_STRING;
            if (*p == '\\') {
                row->hl[i+1] = VI_HL_STRING;
                p += 2; i += 2;
                prev_sep = 0;
                goto vi_eus_cont;
            }
            if (*p == in_string) in_string = 0;
            p++; i++;
            goto vi_eus_cont;
        } else {
            if (*p == '"' || *p == '\'') {
                in_string = *p;
                row->hl[i] = VI_HL_STRING;
                p++; i++;
                prev_sep = 0;
                goto vi_eus_cont;
            }
        }

        /* Handle non printable chars. */
        if (!Bt(char_bmp_printable,*p)) {
            row->hl[i] = VI_HL_NONPRINT;
            p++; i++;
            prev_sep = 0;
            goto vi_eus_cont;
        }

        /* Handle numbers */
        if ((_vi_isdigit(*p) && (prev_sep || row->hl[i-1] == VI_HL_NUMBER)) ||
            (*p == '.' && i >0 && row->hl[i-1] == VI_HL_NUMBER)) {
            row->hl[i] = VI_HL_NUMBER;
            p++; i++;
            prev_sep = 0;
            goto vi_eus_cont;
        }

        /* Handle keywords and classes */
        if (prev_sep) {
            I64 j;
            for (j = 0; keywords[j]; j++) {
                I64 klen = StrLen(keywords[j]);

                if (!MemCmp(p,keywords[j],klen) &&
                    _vi_is_separator(*(p+klen)))
                {
                    // Keyword 
                    MemSet(row->hl+i, VI_HL_KEYWORD, klen);
                    p += klen;
                    i += klen;
                    break;
                }
            }
            if (keywords[j] != NULL) {
                prev_sep = 0;
                goto vi_eus_cont; // We had a keyword match
            }
            for (j = 0; classes[j]; j++) {
                klen = StrLen(classes[j]);

                if (!MemCmp(p,classes[j],klen) &&
                    _vi_is_separator(*(p+klen)))
                {
                    // Class
                    MemSet(row->hl+i, VI_HL_CLASS, klen);
                    p += klen;
                    i += klen;
                    break;
                }
            }
            if (classes[j] != NULL) {
                prev_sep = 0;
                goto vi_eus_cont; // We had a class match
            }
        }

        /* Not special chars */
        prev_sep = _vi_is_separator(*p);
        p++; i++;
vi_eus_cont:        
    }

    /* Propagate syntax change to the next row if the open commen
     * state changed. This may recursively affect all the following rows
     * in the file. */
    I64 oc = _vi_editorRowHasOpenComment(row);
    if (row->VI_HL_oc != oc && row->idx+1 < E->numrows)
        _vi_editorUpdateSyntax(E, &E->row[row->idx+1]);
    row->VI_HL_oc = oc;
}

/* Update the rendered version and the syntax highlight of a row. */
U0 _vi_editorUpdateRow(vi_editorConfig *E, vi_erow *row) {
    I64 tabs = 0, nonprint = 0, j, idx;

   /* Create a version of the row we can directly print on the screen,
     * respecting tabs, substituting non printable characters with '?'. */
    if (row->render)
    {
        Free(row->render);
    }
    for (j = 0; j < row->size; j++)
        if (row->chars[j] == ScanCode2Char(SC_TAB)) tabs++;

    row->render = MAlloc(row->size + tabs*8 + nonprint*9 + 1);
    idx = 0;
    for (j = 0; j < row->size; j++) {
        if (row->chars[j] == ScanCode2Char(SC_TAB)) {
            row->render[idx++] = ' ';
            while((idx+1) % 8 != 0) row->render[idx++] = ' ';
        } else {
            row->render[idx++] = row->chars[j];
        }
    }
    row->rsize = idx;
    row->render[idx] = '\0';

    /* Update the syntax highlighting attributes of the row. */
    _vi_editorUpdateSyntax(E, row);
}

/* Insert a row at the specified position, shifting the other rows on the bottom
 * if required. */
U0 _vi_editorInsertRow(vi_editorConfig *E, I64 at, U8 *s, I64 len) {
    I64 j;
    if (at > E->numrows) return;
    E->row = _vi_realloc(E->row,sizeof(vi_erow)*(E->numrows+1));
    if (at != E->numrows) {
        _vi_memmove( &E->row[at+1], &E->row[at], sizeof(vi_erow) * E->numrows-at );
        for (j = at+1; j <= E->numrows; j++) E->row[j].idx++;
    }
    E->row[at].size = len;
    E->row[at].chars = MAlloc(len+1);
    MemCpy(E->row[at].chars,s,len+1);
    E->row[at].hl = NULL;
    E->row[at].VI_HL_oc = 0;
    E->row[at].render = NULL;
    E->row[at].rsize = 0;
    E->row[at].idx = at;
    _vi_editorUpdateRow(E, &E->row[at]);
    E->numrows++;
    E->dirty++;
}

/* Set an editor status message for the second line of the status, at the
 * end of the screen. */
U0 _vi_editorSetStatusMessage(vi_editorConfig *E, U8 *fmt, ...) {
   	U8 *buf;
	if (argc)
	{
		buf=StrPrintJoin(NULL, fmt, argc, argv);
	}
	else
	{
		buf=StrNew(fmt);
	}
    StrPrint(E->statusmsg, buf);
    Free(buf);
}

I64 _vi_editorOpen(vi_editorConfig *E, U8 *filename)
{
    if (E->filename) Free(E->filename);
    E->filename = StrNew(filename);
    I64 size;
    I64 pos = 0;
    
    if (!FileFind(E->filename))
    {
        StrPrint(E->statusmsg, "\"%s\" [New File]",
            E->filename);
        E->dirty = 0;
        return 0;
    }

    U8 *buf = FileRead(E->filename, &size);
    U8 *line = NULL;
    I64 len = 0;

    while (pos<size)
    {
        if (StrFirstOcc(buf+pos, "\n"))
        {
            line = CAlloc(StrFirstOcc(buf+pos, "\n")-(buf+pos) + 8);
            MemCpy(line, buf+pos, StrFirstOcc(buf+pos, "\n")-(buf+pos));

            while (line[StrLen(line)-1] == '\r' || line[StrLen(line)-1] == '\n')
            {
                line[StrLen(line)-1]=0;
            }
            pos = (StrFirstOcc(buf+pos, "\n")+1) - buf;
        }
        else
        {
            line = CAlloc(size-(buf+pos) + 8);
            MemCpy(line, buf+pos, size-(buf+pos));
            pos = size;
        }
        _vi_editorInsertRow(E,E->numrows,line,StrLen(line));
        Free(line);
    }

    StrPrint(E->statusmsg, "\"%s\" %d lines, %d characters",
        E->filename, E->numrows, size);

    Free(buf);
    E->dirty = 0;    
    return 0;
}

/* Select the syntax highlight scheme depending on the filename,
 * setting it in the global state E.syntax. */
U0 _vi_editorSelectSyntaxHighlight(vi_editorConfig *E, U8 *filename)
{
 
    // TODO: more syntax highlighting classes, just HolyC for now

    E->syntax = CAlloc(sizeof(vi_editorSyntax));
    E->syntax->keywords = C_VI_HL_keywords;
    E->syntax->classes = C_VI_HL_classes;
    E->syntax->singleline_comment_start = "//";
    E->syntax->multiline_comment_start = "/*";
    E->syntax->multiline_comment_end = "*/";
}

U0 _vi_initEditor(vi_editorConfig *E, EConsole *con) {
    E->cx = 0;
    E->cy = 0;
    E->rowoff = 0;
    E->coloff = 0;
    E->numrows = 0;
    E->row = NULL;
    E->dirty = 0;
    E->init = TRUE;
    E->quit = FALSE;
    E->filename = NULL;
    E->syntax = NULL;
    E->incmd = FALSE;
    E->mode = VI_MODE_NORMAL;
    E->cmd = 0;
    E->cmdbuf = CAlloc(1024);
    E->statusmsg = CAlloc(1024);
    E->errormsg = CAlloc(1024);
    E->screencols = con->ch_width;
    E->screenrows = con->ch_height - 1; /* Get room for status bar. */
}

U0 _vi_editorSyntaxToColor(EConsole *con, I64 val)
{
    U32 color = 0xFFFFFF00;
    switch (val)
    {
        case VI_HL_COMMENT:
        case VI_HL_MLCOMMENT:
            color = 0x55FEFE00;
            break;
        case VI_HL_KEYWORD:
            color = 0xFEFE5500;
            break;
        case VI_HL_CLASS:
            color = 0x55FE5500;
            break;
        case VI_HL_STRING:
            color = 0xFE55FE00;
            break;
        case VI_HL_NUMBER:
            color = 0x55FEFE00;
            break;
        case VI_HL_MATCH:
            color = 0x5555FE00;
            break;
        default:
            break;
    }
    ConSetColor(con, color, 0);
}

/* ============================= Terminal update ============================ */

/* This function writes the whole screen using the Erythros EConsole class
 * starting from the logical state of the editor in the global state 'E'. */
U0 _vi_editorRefreshScreen(vi_editorConfig *E, EConsole *con) {
    I64 y;
    vi_erow *r;
    U8 buf[32];

    /* Hide cursor. */
    con->disable_cursor = TRUE;

    /* Go home. */
    con->scroll_x = 0;
    con->scroll_y = 0;
    con->screen_x = 0;
    con->screen_y = 0;

    _vi_ResetAllRows(con);

    for (y = 0; y < E->screenrows; y++) {
        I64 filerow = E->rowoff+y;
        
        if (filerow >= E->numrows) {
            //con->screen_x = 0;
            //con->screen_y = y;
            ConSetColor(con, 0x729FCF00, 0);
            ConPrint(con, "~");
            ConSetColor(con, 0xFFFFFF00, 0);
            goto vi_ers_cont;
        }

        r = &E->row[filerow];

        I64 len = r->rsize - E->coloff;
        I64 current_color = -1;
        if (len > 0) {
            if (len > E->screencols) len = E->screencols;
            U8 *c = r->render+E->coloff;
            U8 *hl = r->hl+E->coloff;
            I64 j;
            for (j = 0; j < len; j++) {
                if (hl[j] == VI_HL_NONPRINT) {
                    U8 sym[2];
                    sym[1] = NULL;
                    ConSetColor(con, 0, 0xFF000000);
                    if (c[j] <= 26)
                        sym[0] = '@'+c[j];
                    else
                        sym[0] = '?';
                    ConPrint(con, &sym);
                    ConSetColor(con, 0xFFFFFF00, 0);
                } else if (hl[j] == VI_HL_NORMAL) {
                    if (current_color != -1) {
                        ConSetColor(con, 0xFFFFFF00, 0);
                        current_color = -1;
                    }
                    if (c[j]!=5)
                    {
                        sym[0] = c[j];
                        ConPrint(con, &sym);
                    }
                    ConSetColor(con, 0xFFFFFF00, 0);
                } else {
                    _vi_editorSyntaxToColor(con, hl[j]);
                    if (c[j]!=5)
                    {
                        sym[0] = c[j];
                        ConPrint(con, &sym);
                    }
                    ConSetColor(con, 0xFFFFFF00, 0);
                }
            }
        }
vi_ers_cont:
        ConSetColor(con, 0xFFFFFF00, 0);
        ConPrint(con, "\n");
    }

    // TODO: config tab size

    /* Put cursor at its current position. Note that the horizontal position
     * at which the cursor is displayed may be different compared to 'E->cx'
     * because of TABs. */
    I64 cx = 1;
    filerow = E->rowoff+E->cy;
    vi_erow *row = cond((filerow >= E->numrows), NULL, &E->row[filerow]);
    if (row) {
        for (j = E->coloff; j < (E->cx+E->coloff); j++) {
            if (j < row->size && row->chars[j] == ScanCode2Char(SC_TAB)) cx += 7-((cx)%8);
            cx++;
        }
    }
    con->screen_x = cx-1;
    con->screen_y = E->cy;

    I64 prev_x, prev_y;

    switch (E->mode)
    {
        case VI_MODE_INSERT:
            if (StrLen(E->errormsg)) StrPrint(E->errormsg, "");
            if (StrLen(E->statusmsg)) StrPrint(E->statusmsg, "");
            prev_x = con->screen_x;
            prev_y = con->screen_y;
            con->screen_x = 0;
            con->screen_y = E->screenrows;
            ConSetColor(con, 0, 0xFEFEFE00);
            ConPrint(con, "-- INSERT --");
            ConSetColor(con, 0xFFFFFF00, 0);
            con->screen_x = prev_x;
            con->screen_y = prev_y;
            break;
        case VI_MODE_NORMAL:
            if (StrLen(E->errormsg))
            {
                prev_x = con->screen_x;
                prev_y = con->screen_y;
                con->screen_x = 0;
                con->screen_y = E->screenrows;
                ConSetColor(con, 0xFFFFFF00, 0xFE000000);
                ConPrint(con, E->errormsg);
                ConSetColor(con, 0xFFFFFF00, 0);
                con->screen_x = prev_x;
                con->screen_y = prev_y;
            }
            if (StrLen(E->statusmsg) && !StrLen(E->errormsg))
            {
                prev_x = con->screen_x;
                prev_y = con->screen_y;
                con->screen_x = 0;
                con->screen_y = E->screenrows;
                ConSetColor(con, 0, 0xFEFEFE00);
                ConPrint(con, E->statusmsg);
                ConSetColor(con, 0xFFFFFF00, 0);
                con->screen_x = prev_x;
                con->screen_y = prev_y;
            }
            break;
        default:
            break;
    }

    /* Show cursor. */
    con->disable_cursor = FALSE;
}

/* Insert a character at the specified position in a row, moving the remaining
 * chars on the right if needed. */
U0 _vi_editorRowInsertChar(vi_editorConfig *E, vi_erow *row, I64 at, U8 c) {
    if (at > row->size) {
        /* Pad the string with spaces if the insert location is outside the
         * current length by more than a single character. */
        I64 padlen = at-row->size;
        /* In the next line +2 means: new char and null term. */
        row->chars = _vi_realloc(row->chars,row->size+padlen+2);
        MemSet(row->chars+row->size,' ',padlen);
        row->chars[row->size+padlen+1] = '\0';
        row->size += padlen+1;
    } else {
        /* If we are in the middle of the string just make space for 1 new
         * char plus the (already existing) null term. */
        row->chars = _vi_realloc(row->chars,row->size+2);
        _vi_memmove(row->chars+at+1,row->chars+at,row->size-at+1);
        row->size++;
    }
    row->chars[at] = c;
    _vi_editorUpdateRow(E, row);
    E->dirty++;
}

/* Append the string 's' at the end of a row */
U0 _vi_editorRowAppendString(vi_editorConfig *E, vi_erow *row, U8 *s, I64 len) {
    row->chars = _vi_realloc(row->chars,row->size+len+1);
    MemCpy(row->chars+row->size,s,len);
    row->size += len;
    row->chars[row->size] = '\0';
    _vi_editorUpdateRow(E, row);
    E->dirty++;
}

/* Delete the character at offset 'at' from the specified row. */
U0 _vi_editorRowDelChar(vi_editorConfig *E, vi_erow *row, I64 at) {
    if (row->size <= at) return;
    _vi_memmove(row->chars+at,row->chars+at+1,row->size-at);
    _vi_editorUpdateRow(E, row);
    row->size--;
    E->dirty++;
}

/* Free row's heap allocated stuff. */
U0 _vi_editorFreeRow(vi_erow *row) {
    Free(row->render);
    Free(row->chars);
    Free(row->hl);
}

/* Remove the row at the specified position, shifting the remainign on the
 * top. */
U0 _vi_editorDelRow(vi_editorConfig *E, I64 at)
{
    I64 j;
    vi_erow *row;

    if (at >= E->numrows) return;
    row = &E->row[at];
    _vi_editorFreeRow(row);
    _vi_memmove( &E->row[at], &E->row[at+1], sizeof(vi_erow) * E->numrows-at-1 );
    for (j = at; j < E->numrows-1; j++) E->row[j].idx++;
    E->numrows--;
    E->dirty++;
}

/* Insert the specified char at the current prompt position. */
U0 _vi_editorInsertChar(vi_editorConfig *E, U8 c) {
    I64 filerow = E->rowoff+E->cy;
    I64 filecol = E->coloff+E->cx;
    vi_erow *row = cond((filerow >= E->numrows), NULL, &E->row[filerow]);

    /* If the row where the cursor is currently located does not exist in our
     * logical representaion of the file, add enough empty rows as needed. */
    if (!row) {
        while(E->numrows <= filerow)
            _vi_editorInsertRow(E, E->numrows,"",0);
    }
    row = &E->row[filerow];
    _vi_editorRowInsertChar(E, row,filecol,c);
    if (E->cx == E->screencols-1)
        E->coloff++;
    else
        E->cx++;
    E->dirty++;
}

/* Delete the char at the current prompt position. */
U0 _vi_editorDelChar(vi_editorConfig *E, U8 ch) {
    I64 filerow = E->rowoff+E->cy;
    I64 filecol = E->coloff+E->cx;
    vi_erow *row = cond((filerow >= E->numrows), NULL, &E->row[filerow]);

    if (!row || (filecol == 0 && filerow == 0)) return;
    if (filecol == 0) {
        /* Handle the case of column 0, we need to move the current line
         * on the right of the previous one. */
        filecol = E->row[filerow-1].size;
        _vi_editorRowAppendString(E, &E->row[filerow-1],row->chars,row->size);
        _vi_editorDelRow(E, filerow);
        row = NULL;
        if (E->cy == 0)
            E->rowoff--;
        else
            E->cy--;
        E->cx = filecol;
        if (E->cx >= E->screencols) {
            I64 shift = (E->screencols-E->cx)+1;
            E->cx -= shift;
            E->coloff += shift;
        }
    } else {
        if (ch==21)
        {
            _vi_editorRowDelChar(E,row,filecol);
        }
        else
        {
            _vi_editorRowDelChar(E,row,filecol-1);
            if (E->cx == 0 && E->coloff)
                E->coloff--;
            else
                E->cx--;

        }
    }
    if (row) _vi_editorUpdateRow(E, row);
    E->dirty++;
}

/* ========================= Editor events handling  ======================== */

/* Handle cursor position change because arrow keys were pressed. */
U0 _vi_editorMoveCursor(vi_editorConfig *E, U8 key) {
    I64 filerow = E->rowoff+E->cy;
    I64 filecol = E->coloff+E->cx;
    I64 rowlen;
    vi_erow *row = cond((filerow >= E->numrows), NULL, &E->row[filerow]);

    switch(key) {
    case 19: //LEFT
        if (E->cx == 0) {
            if (E->coloff) {
                E->coloff--;
            } else {
                if (filerow > 0) {
                    E->cy--;
                    E->cx = E->row[filerow-1].size;
                    if (E->cx > E->screencols-1) {
                        E->coloff = E->cx-E->screencols+1;
                        E->cx = E->screencols-1;
                    }
                }
            }
        } else {
            E->cx -= 1;
        }
        break;
    case 20: // RIGHT
        if (row && filecol < row->size) {
            if (E->cx == E->screencols-1) {
                E->coloff++;
            } else {
                E->cx += 1;
            }
        } else if (row && filecol == row->size) {
            E->cx = 0;
            E->coloff = 0;
            if (E->cy == E->screenrows-1) {
                E->rowoff++;
            } else {
                E->cy += 1;
            }
        }
        break;
    case 17: // UP
        if (E->cy == 0) {
            if (E->rowoff) E->rowoff--;
        } else {
            E->cy -= 1;
        }
        break;
    case 18: // DOWN
        if (filerow < E->numrows) {
            if (E->cy == E->screenrows-1) {
                E->rowoff++;
            } else {
                E->cy += 1;
            }
        }
        break;
    }
    /* Fix cx if the current line has not enough chars. */
    filerow = E->rowoff+E->cy;
    filecol = E->coloff+E->cx;
    row = cond((filerow >= E->numrows), NULL, &E->row[filerow]);
    rowlen = cond(row, row->size, 0);
    if (filecol > rowlen) {
        E->cx -= filecol-rowlen;
        if (E->cx < 0) {
            E->coloff += E->cx;
            E->cx = 0;
        }
    }
}

/* Inserting a newline is slightly complex as we have to handle inserting a
 * newline in the middle of a line, splitting the line as needed. */
U0 _vi_editorInsertNewline(vi_editorConfig *E) {
    I64 filerow = E->rowoff+E->cy;
    I64 filecol = E->coloff+E->cx;
    vi_erow *row = cond((filerow >= E->numrows), NULL, &E->row[filerow]);

    if (!row) {
        if (filerow == E->numrows) {
            _vi_editorInsertRow(E, filerow,"",0);
            goto vi_fixcursor;
        }
        return;
    }
    /* If the cursor is over the current line size, we want to conceptually
     * think it's just over the last character. */
    if (filecol >= row->size) filecol = row->size;
    if (filecol == 0) {
        _vi_editorInsertRow(E, filerow,"",0);
    } else {
        /* We are in the middle of a line. Split it between two rows. */
        _vi_editorInsertRow(E, filerow+1, row->chars+filecol, row->size-filecol);
        row = &E->row[filerow];
        row->chars[filecol] = '\0';
        row->size = filecol;
        _vi_editorUpdateRow(E, row);
    }
vi_fixcursor:
    if (E->cy == E->screenrows-1) {
        E->rowoff++;
    } else {
        E->cy++;
    }
    E->cx = 0;
    E->coloff = 0;
}

I64 _vi_editorSave(vi_editorConfig *E)
{
    I64 i;
    I64 size = 0;
    for (i=0; i<E->numrows; i++)
    {
        size += E->row[i].size + 1;
    }
    U8 *buf = CAlloc(size);
    I64 pos = 0;
    for (i=0; i<E->numrows; i++)
    {
        MemCpy(buf+pos, E->row[i].chars, E->row[i].size);
        pos += E->row[i].size;
        buf[pos] = '\n';
        pos++;
    }
    StrPrint(E->statusmsg, "\"%s\" %s%d lines, %d characters written",
        E->filename, cond(FileFind(E->filename), "", "[New File] "), E->numrows, size);
    FileWrite(E->filename, buf, size);
    Free(buf);
    return 0;
}

U0 _vi_editorProcessKeypress(vi_editorConfig *E, EConsole *con)
{
    I64 prev_x, prev_y;
    EConReadLine *vim_rl;
    U8 ch;
    while (!FifoU8Cnt(con->stdin))
    {
        if (E->screencols != con->ch_width || 
            E->screenrows != con->ch_height -1)
        {
            E->screencols = con->ch_width;
            E->screenrows = con->ch_height -1; /* Get room for status bar. */
            _vi_editorRefreshScreen(E, con);
        }
        Sleep(1);
    }
    FifoU8Rem(con->stdin, &ch);

    // Handle cursor movement
    switch (E->mode)
    {
        case VI_MODE_NORMAL:
        case VI_MODE_INSERT:
            if (!E->incmd)
            {
                switch (ch)
                {
                    case 17:
                    case 18:
                    case 19:
                    case 20:
                        _vi_editorMoveCursor(E, ch);
                        break;
                    case 24:
                    case 25:
                        if (ch == 24 && E->cy != 0) //PGUP
                            E->cy = 0;
                        else if (ch == 25 && E->cy != E->screenrows-1) // PGDN
                            E->cy = E->screenrows-1;
                        I64 times = E->screenrows;
                        while(times--)
                            _vi_editorMoveCursor(E, cond(ch == 24, 17, 18));
                        break;
                    default:
                        break;
                };
            }            
            break;
        default:
            break;        
    };

    switch (E->mode)
    {
        case VI_MODE_NORMAL:
            if (!E->incmd)
            {
                switch (ch)
                {
                    case 'i':
                        E->mode = VI_MODE_INSERT;
                        break;
                    case ':':
                        StrPrint(E->errormsg, "");
                        StrPrint(E->statusmsg, "");
                        _vi_editorRefreshScreen(E, con);
                        vim_rl = CAlloc(sizeof(EConReadLine));
                    	vim_rl->history = CAlloc(sizeof(EConHistory));
                        vim_rl->ac = CAlloc(sizeof(EConAutoComplete));

                        prev_x = con->screen_x;
                        prev_y = con->screen_y;
                        con->screen_x = 0;
                        con->screen_y = E->screenrows;
                        ConSetColor(con, 0xFFFFFF00, 0);
                        ConPrint(con, ":");
                        E->cmdbuf = ConReadLine(con, vim_rl, 4096); // not sure how I feel about a ReadLine for this? :/                       
                        if (E->cmdbuf[0]=='q')
                        {
                            if (E->dirty && E->cmdbuf[1]!='!') // TODO: ParseOpts, just testing for now...
                            {
                                StrPrint(E->errormsg, "E37: No write since last change (add ! to override)");
                            }
                            else
                            {
                                E->quit = TRUE;
                            }
                        }
                        if (E->cmdbuf[0]=='w')
                        {
                            if (!_vi_editorSave(E))
                            {
                                E->dirty = FALSE;
                            }
                            else
                            {
                                StrPrint(E->errormsg, "E212: Can't open file for writing");
                            }
                        }
                        con->screen_x = prev_x;
                        con->screen_y = prev_y;
                        Free(vim_rl->ac);
                        Free(vim_rl->history);
                        Free(vim_rl);
                        break;
                };
            }
            break;
        case VI_MODE_INSERT:
            if (!E->incmd)
            {
                switch (ch)
                {
                    case 8:
                    case 21:
                        _vi_editorDelChar(E, ch);
                        break;
                    case 10:
                        _vi_editorInsertNewline(E);
                        break;
                    case 27:
                        E->mode = VI_MODE_NORMAL;
                        break;
                    default:
                        if ((Bt(char_bmp_printable, ch) && ch>31) || ch==9)
                        {
                            _vi_editorInsertChar(E, ch);
                        }
                        break;
                };
            }
            break;
        case VI_MODE_VISUAL:
            // TODO
            break;       
        default:
            break;
    };

};

I64 CCMD_vi(EConsole *con, I64 argc, U8 **argv)
{
    U8 ch;
    I64 i;
    vi_editorConfig E;
    EConsole *retr_con = _vi_SaveAndInitConsoleState(con);

    _vi_initEditor(&E, con);
    _vi_editorSelectSyntaxHighlight(&E, argv[1]);
    _vi_editorOpen(&E, argv[1]);

    while (!E.quit)
    {
        _vi_editorRefreshScreen(&E, con);
        _vi_editorProcessKeypress(&E, con);
    }
  
    _vi_ResumeConsoleState(con, retr_con);
    return 0;
}