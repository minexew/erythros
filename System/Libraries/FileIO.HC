#define EOS_ATTR_PERMS      0x2000

#define EOS_FP_OWNER_R      0x1
#define EOS_FP_OWNER_W      0x2
#define EOS_FP_OWNER_X      0x4

#define EOS_FP_GROUP_R      0x8
#define EOS_FP_GROUP_W      0x10
#define EOS_FP_GROUP_X      0x20

#define EOS_FP_WORLD_R      0x40
#define EOS_FP_WORLD_W      0x80
#define EOS_FP_WORLD_X      0x100

#define EOS_FILENAME_LEN    35

class CDirEntryRaw
{
  U16   attr;
  U8    name[CDIR_FILENAME_LEN];
  I64   clus,size;
  CDate datetime;    
};

I64 EOSGetFileInfo(CDirEntry *de)
{// Retrieve EOS File Info 
    if (de->attr & EOS_ATTR_PERMS && !de->name[EOS_FILENAME_LEN-1])
    {
        // perms
        de->user_data.u16[0] = cond(de->name[EOS_FILENAME_LEN+1] & 1, 0x100, 0);
        de->user_data.u16[0] += de->name[EOS_FILENAME_LEN+2];
        // owner
        de->user_data.u16[1] = de->name[EOS_FILENAME_LEN+1] >> 1;
        // group
        de->user_data.u16[2] = de->name[EOS_FILENAME_LEN];
        return 0;
    }
    return 1;
}

I64 EOSStoreFileInfo(CDirEntry *de)
{// Store EOS File Info to disk, RedSea only
    I64 i;
    de->attr |= EOS_ATTR_PERMS;
    U8 *delim = StrLastOcc(de->full_name, "/");
    *delim=0;
    CDrv *dv = Let2Drv(de->full_name[0]);
    if (dv->fs_type != FSt_REDSEA) { return 1; };
    I64 clus = Name2DirClus(dv, delim);
    *delim='/';
    CDirEntryRaw *buf=CAlloc(BLK_SIZE);
    CDirEntryRaw *buf2;

    if (clus)
    {
        I64 blk = Clus2Blk(dv, clus);
        if (blk)
        {
            while (blk<dv->bd->max_blk)
            {
                BlkRead(dv, buf, blk, 1);
                buf2=buf;
                for (i=0; i<8; i++)
                {
                    if (buf2->clus == de->clus &&
                        buf2->size == de->size)
                    {
                        buf2->attr = de->attr;
                        buf2->name[EOS_FILENAME_LEN-1] = NULL;

                        // group
                        buf2->name[EOS_FILENAME_LEN] = de->user_data.u16[2];
                        // owner
                        buf2->name[EOS_FILENAME_LEN+1] = de->user_data.u16[1] << 1;
                        // perms
                        if (de->user_data.u16[0] & 0x100)
                        {
                            buf2->name[EOS_FILENAME_LEN+1] |= 1;
                        }
                        buf2->name[EOS_FILENAME_LEN+2] = de->user_data.u16[0] & 0xFF;

                        BlkWrite(dv, buf, blk, 1);
                        Free(buf);
                        return 0;
                    }
                    buf2++;                
                }
                blk++;
            }
        }
    }

    // uh oh

    Free(buf);
    return 1;
}

U0 EOSSetFilePerm(CDirEntry *de, I64 flag)
{
    switch (flag)
    {
        case EOS_FP_OWNER_R:
        case EOS_FP_OWNER_W:
        case EOS_FP_GROUP_R:
        case EOS_FP_WORLD_R:
            de->user_data.u16[0] &= ~flag;
            break;
        default:
            de->user_data.u16[0] |= flag;
            break;
    }
}

U0 EOSClearFilePerm(CDirEntry *de, I64 flag)
{
    switch (flag)
    {
        case EOS_FP_OWNER_R:
        case EOS_FP_OWNER_W:
        case EOS_FP_GROUP_R:
        case EOS_FP_WORLD_R:
            de->user_data.u16[0] |= flag;
            break;
        default:
            de->user_data.u16[0] &= ~flag;
            break;
    }
}

U8 EOSSetOwner(CDirEntry *de, I64 owner)
{
    de->user_data.u16[1] = owner;
}

U8 EOSSetGroup(CDirEntry *de, I64 group)
{
    de->user_data.u16[2] = group;
}