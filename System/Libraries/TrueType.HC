/*
Quick 'n Dirty TrueType Rasterizer by Alec Murphy
TrueType File Format Parser based on FontReaderCs by Iain Ballard, converted to HolyC by Alec Murphy

https://github.com/i-e-b/FontReaderCs

BSD 3-Clause License

Copyright (c) 2018, Iain Ballard
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

U32 ttf_Seek(U8 *data, U32 *pos, U32 newPos)
{
    I64 oldPos = pos[0];
    pos[0] = newPos;
    return oldPos;
}

U8 ttf_GetUint8(U64 data, U32 *pos){ U8 byte = *(data+pos[0])(U8*) & 0xFF; pos[0]++; return byte; } 
U16 ttf_GetUint16(U64 data, U32 *pos){ U16 word = *(data+pos[0])(U16*) & 0xFFFF; pos[0]+=2; return EndianU16(word); } 
I16 ttf_GetInt16(U64 data, U32 *pos) { return ttf_GetUint16(data, pos)(I16); }
U32 ttf_GetUint32(U64 data, U32 *pos){ U32 dword = *(data+pos[0])(U32*) & 0xFFFFFFFF; pos[0]+=4; return EndianU32(dword); } 
I32 ttf_GetInt32(U64 data, U32 *pos) { return ttf_GetUint32(data, pos); }
I16 ttf_GetFWord(U8 *data, U32 *pos) { return ttf_GetInt16(data, pos); }
F64 ttf_GetFixed(U8 *data, U32 *pos)
{ // TODO: fixed to float conversion
    return ToF64(ttf_GetInt32(data, pos) / (1 << 16));
}
U8 *ttf_GetString(U8 *data, U32 *pos, I64 length) {
    U8 *result = CAlloc(length+1);
    I64 i;
    for(i = 0; i < length; i++) {
        result[i] = ttf_GetUint8(data, pos);
    }
    return result;
}
CDate ttf_GetDate(U8 *data, U32 *pos)
{ // TODO: implement this
    U32 i = ttf_GetUint32(data, pos);
    i = ttf_GetUint32(data, pos);
    return NULL;
}
U0 ttf_Skip(U8 *data, U32 *pos, I64 dist)
{
    pos[0] += dist;
}
U16 ttf_PickUint16(U8 *data, I64 baseAddr, I32 index)
{
    I64 i = index*2;
    U16 a = data[baseAddr+i];
    U16 b = data[baseAddr+i+1];
    return ((a << 8) + b) & 0xFFFF;
}
I16 ttf_PickInt16(U8 *data, I64 baseAddr, I32 index)
{
    I64 i = index*2;
    I16 a = data[baseAddr+i];
    I16 b = data[baseAddr+i+1];
    return ((a << 8) + b) & 0xFFFF;
}

#define TTF_HEADER_MAGIC     0x5f0f3cf5

#define GLYF_ON_CURVE       1
#define GLYF_X_IS_BYTE      2
#define GLYF_Y_IS_BYTE      4
#define GLYF_REPEAT         8
#define GLYF_X_DELTA       16
#define GLYF_Y_DELTA       32

class ttf_OffsetEntry
{
    U32 Checksum;
    U32 Offset;
    U32 Length;
};

class ttf_FontHeader
{
    F64 Version;
    F64 Revision;
    U32 ChecksumAdjustment;
    U32 MagicNumber;
    U16 Flags;
    U16 UnitsPerEm;
    CDate Created;
    CDate Modified;
    I16 xMin;
    I16 yMin;
    I16 xMax;
    I16 yMax;
    U16 MacStyle;
    U16 LowestRecPPEM;
    I16 FontDirectionHint;
    I16 IndexToLocFormat;
    I16 GlyphDataFormat;
};

// enum GlyphTypes

#define glyf_Simple         0
#define glyf_Compound       1
#define glyf_Empty          2

// enum CompoundGlyphFlags

#define GLYF_ARG_1_AND_2_ARE_WORDS     1
#define GLYF_ARGS_ARE_XY_VALUES        2
#define GLYF_ROUND_XY_TO_GRID          4
#define GLYF_WE_HAVE_A_SCALE           8
#define GLYF_RESERVED1                 16
#define GLYF_MORE_COMPONENTS           32
#define GLYF_WE_HAVE_AN_X_AND_Y_SCALE  64
#define GLYF_WE_HAVE_A_TWO_BY_TWO      128
#define GLYF_WE_HAVE_INSTRUCTIONS      256
#define GLYF_USE_MY_METRICS            512
#define GLYF_OVERLAP_COMPONENT         1024

class ttf_CompoundComponent
{
    I32 GlyphIndex;
    F64 **Matrix;  // variable sized
    I32 DestPointIndex;
    I32 SrcPointIndex;
};

class ttf_End
{
    ttf_End *next;
    U16 value;
}

class ttf_SimpleGlyphFlag
{
    ttf_SimpleGlyphFlag *next;
    U8 flag;
};

class ttf_GlyphPoint
{
    ttf_GlyphPoint *next;
    Bool OnCurve;
    F64 X;
    F64 Y;
};

class ttf_Glyph
{
    I32 GlyphType;
    I32 NumberOfContours;
    F64 xMin, xMax, yMin, yMax;
    ttf_CompoundComponent **Components;
    U8 SourceCharacter;
    U8 *SourceFont;
    ttf_SimpleGlyphFlag *Flags;
    ttf_GlyphPoint *Points;
    ttf_End *ContourEnds;
    CDC *dc;
};

class ttf_tablesList
{
    ttf_tablesList *next;
    U8 *string;
    ttf_OffsetEntry *offsetEntry;
};

class ttf_unicodeIndexesList
{
    ttf_unicodeIndexesList *next;
    U8 ch;
    I32 idx;
};

class ttf_glyphCacheList
{
    ttf_glyphCacheList *next;
    I32 idx;
    ttf_Glyph *glyph;
};

class ttf_TrueTypeFont
{
    ttf_TrueTypeFont *prev;
    ttf_TrueTypeFont *next;
    U64 data;
    I64 size;
    U32 pos;
    U8 *_filename;
    ttf_tablesList *_tables;
    ttf_unicodeIndexesList *_unicodeIndexes;
    ttf_glyphCacheList *_glyphCache;
    ttf_FontHeader *_header;
    U32 _scalarType;
    U16 _searchRange;
    U16 _entrySelector;
    U16 _rangeShift;
    U16 _length;
};

U0 ttf_tablesListAdd(ttf_tablesList *tables, U8 *tag, ttf_OffsetEntry *entry)
{
    ttf_tablesList *new = CAlloc(sizeof(ttf_tablesList));
    while (tables->next)
    {
        tables = tables->next;
    }
    new->string = tag;
    new->offsetEntry = entry;
    tables->next = new;
}

U0 ttf_unicodeIndexesListAdd(ttf_unicodeIndexesList *indexes, U8 ch, I32 idx)
{
    ttf_unicodeIndexesList *new = CAlloc(sizeof(ttf_unicodeIndexesList));
    while (indexes->next)
    {
        indexes = indexes->next;
    }
    new->ch = ch;
    new->idx = idx;
    indexes->next = new;
}

U0 ttf_glyphCacheListAdd(ttf_glyphCacheList *glyphs, I32 idx, ttf_Glyph *glyph)
{
    ttf_glyphCacheList *new = CAlloc(sizeof(ttf_glyphCacheList));
    while (glyphs->next)
    {
        glyphs = glyphs->next;
    }
    new->idx = idx;
    new->glyph = glyph;
    glyphs->next = new;
}

ttf_tablesList *ttf_ReadOffsetTables(ttf_TrueTypeFont *ttf)
{
    I64 i;
    U8 *tag;
    ttf_OffsetEntry *entry;
    ttf_tablesList *tables = CAlloc(sizeof(ttf_tablesList));

    // DO NOT REARRANGE CALLS!
    ttf->_scalarType = ttf_GetUint32(ttf->data, &ttf->pos);
    I64 numTables = ttf_GetUint16(ttf->data, &ttf->pos) & 0xFFFF;
    ttf->_searchRange = ttf_GetUint16(ttf->data, &ttf->pos);
    ttf->_entrySelector = ttf_GetUint16(ttf->data, &ttf->pos);
    ttf->_rangeShift = ttf_GetUint16(ttf->data, &ttf->pos);
    for (i = 0; i < numTables; i++)
    {
        tag = ttf_GetString(ttf->data, &ttf->pos, 4);
        entry = CAlloc(sizeof(ttf_OffsetEntry));
        entry->Checksum = ttf_GetUint32(ttf->data, &ttf->pos);
        entry->Offset = ttf_GetUint32(ttf->data, &ttf->pos);
        entry->Length = ttf_GetUint32(ttf->data, &ttf->pos);
        ttf_tablesListAdd(tables, tag, entry);
    }
    return tables;
}

Bool ttf_OffsetTablesContainsKey(ttf_TrueTypeFont *ttf, U8 *key)
{
    ttf_tablesList *tables = ttf->_tables;
    while (tables)
    {
        if (tables->string)
        {
            if (!StrCmp(tables->string, key)) { return TRUE; }; 
        }
        tables = tables->next;
    }
    return FALSE;
}

ttf_tablesList *ttf_OffsetTablesGetKey(ttf_TrueTypeFont *ttf, U8 *key)
{
    ttf_tablesList *tables = ttf->_tables;
    while (tables)
    {
        if (tables->string)
        {
            if (!StrCmp(tables->string, key)) { return tables; }; 
        }
        tables = tables->next;
    }
    return NULL;
}

Bool ttf_UnicodeIndexesContainsKey(ttf_TrueTypeFont *ttf, U8 key)
{
    ttf_unicodeIndexesList *indexes = ttf->_unicodeIndexes;
    while (indexes)
    {
        if (indexes->ch)
        {
            if (indexes->ch==key) { return TRUE; }; 
        }
        indexes = indexes->next;
    }
    return FALSE;
}

ttf_unicodeIndexesList *ttf_UnicodeIndexesGetKey(ttf_TrueTypeFont *ttf, U8 key)
{
    ttf_unicodeIndexesList *indexes = ttf->_unicodeIndexes;
    while (indexes)
    {
        if (indexes->ch)
        {
            if (indexes->ch==key) { return indexes; }; 
        }
        indexes = indexes->next;
    }
    return NULL;
}

Bool ttf_GlyphCacheContainsKey(ttf_TrueTypeFont *ttf, I32 key)
{
    ttf_glyphCacheList *cache = ttf->_glyphCache;
    while (cache)
    {
        if (cache->idx)
        {
            if (cache->idx==key) { return TRUE; }; 
        }
        cache = cache->next;
    }
    return FALSE;
}

ttf_glyphCacheList *ttf_GlyphCacheGetKey(ttf_TrueTypeFont *ttf, I32 key)
{
    ttf_glyphCacheList *cache = ttf->_glyphCache;
    while (cache)
    {
        if (cache->idx)
        {
            if (cache->idx==key) { return cache; }; 
        }
        cache = cache->next;
    }
    return NULL;
}

U16 ttf_GlyphCount(ttf_TrueTypeFont *ttf)
{
    if (!ttf_OffsetTablesContainsKey(ttf, "maxp"))
    {
        Panic("Bad font: maxp table missing (no glyph count)");
    }
    ttf_tablesList *maxp = ttf_OffsetTablesGetKey(ttf, "maxp");
    U32 old = ttf_Seek(ttf->data, &ttf->pos, maxp->offsetEntry->Offset + 4);
    U16 count = ttf_GetUint16(ttf->data, &ttf->pos);
    ttf_Seek(ttf->data, &ttf->pos, old);
    return count;
}

ttf_FontHeader *ttf_ReadHeadTable(ttf_TrueTypeFont *ttf)
{
    if (!ttf_OffsetTablesContainsKey(ttf, "head"))
    {
        Panic("Bad font: Header table missing!");
    }
    ttf_tablesList *head = ttf_OffsetTablesGetKey(ttf, "head");
    ttf_Seek(ttf->data, &ttf->pos, head->offsetEntry->Offset);
    
    ttf_FontHeader *h = CAlloc(sizeof(ttf_FontHeader));

    // DO NOT REARRANGE CALLS!
    h->Version = ttf_GetFixed(ttf->data, &ttf->pos);
    h->Revision = ttf_GetFixed(ttf->data, &ttf->pos);
    h->ChecksumAdjustment = ttf_GetUint32(ttf->data, &ttf->pos);
    h->MagicNumber = ttf_GetUint32(ttf->data, &ttf->pos);

    if (h->MagicNumber != TTF_HEADER_MAGIC)
    {
        Panic("Bad font: incorrect identifier in header table");
    }

    h->Flags = ttf_GetUint16(ttf->data, &ttf->pos);
    h->UnitsPerEm = ttf_GetUint16(ttf->data, &ttf->pos);
    h->Created = ttf_GetDate(ttf->data, &ttf->pos);
    h->Modified = ttf_GetDate(ttf->data, &ttf->pos);

    h->xMin = ttf_GetFWord(ttf->data, &ttf->pos);
    h->yMin = ttf_GetFWord(ttf->data, &ttf->pos);
    h->xMax = ttf_GetFWord(ttf->data, &ttf->pos);
    h->yMax = ttf_GetFWord(ttf->data, &ttf->pos);

    h->MacStyle = ttf_GetUint16(ttf->data, &ttf->pos);
    h->LowestRecPPEM = ttf_GetUint16(ttf->data, &ttf->pos);
    h->FontDirectionHint = ttf_GetInt16(ttf->data, &ttf->pos);
    h->IndexToLocFormat = ttf_GetInt16(ttf->data, &ttf->pos);
    h->GlyphDataFormat = ttf_GetInt16(ttf->data, &ttf->pos);

    return h;
}

ttf_TrueTypeFont *TrueTypeFont(U8 *filename)
{
    ttf_TrueTypeFont *ttf = CAlloc(sizeof(ttf_TrueTypeFont));
    ttf->_filename = StrNew(StrLastOcc(filename, "/")+1);
    *StrLastOcc(ttf->_filename, ".") = NULL;
    ttf->data = FileRead(filename, &ttf->size);

    ttf->_unicodeIndexes = CAlloc(sizeof(ttf_unicodeIndexesList));
    ttf->_glyphCache = CAlloc(sizeof(ttf_glyphCacheList));

    // The order that things are read below is important
    // DO NOT REARRANGE CALLS!
    ttf->_tables = ttf_ReadOffsetTables(ttf);
    ttf->_header = ttf_ReadHeadTable(ttf);
    ttf->_length = ttf_GlyphCount(ttf);

    if (!ttf_OffsetTablesContainsKey(ttf, "glyf"))
    {
        Panic("Bad font: glyf table missing");
    }
    if (!ttf_OffsetTablesContainsKey(ttf, "loca"))
    {
        Panic("Bad font: loca table missing");
    }

    return ttf;
}

I16 ttf_GlyphIndexForChar(ttf_TrueTypeFont *ttf, U8 wantedChar)
{
    // read cmap table if possible,
    // then call down to the index based ReadGlyph.

    if (!ttf_OffsetTablesContainsKey(ttf, "cmap"))
    {
        Panic("Can't translate character: cmap table missing");
    }
    ttf_tablesList *cmap = ttf_OffsetTablesGetKey(ttf, "cmap");
    ttf_Seek(ttf->data, &ttf->pos, cmap->offsetEntry->Offset);
    
    I64 i;
    U16 vers = ttf_GetUint16(ttf->data, &ttf->pos);
    U16 numTables = ttf_GetUint16(ttf->data, &ttf->pos);
    U32 offset = 0;
    Bool found = FALSE;
    
    for (i = 0; i < numTables; i++)
    {
        U16 platform = ttf_GetUint16(ttf->data, &ttf->pos);
        U16 encoding = ttf_GetUint16(ttf->data, &ttf->pos);
        offset = ttf_GetUint32(ttf->data, &ttf->pos);
    
        if (platform == 3 && encoding == 1) // Unicode 2 byte encoding for Basic Multilingual Plane
        {
            found = TRUE;
            break;
        }
    }
    
    if (!found) {
        return 0; // the specific 'missing' glyph
    }
    
    // format 4 table
    if (offset < ttf->pos) { ttf_Seek(ttf->data, &ttf->pos, cmap->offsetEntry->Offset + offset); } // guessing
    else { ttf_Seek(ttf->data, &ttf->pos, offset); }
    
    U16 subtableFmt = ttf_GetUint16(ttf->data, &ttf->pos);
    
    U16 byteLength = ttf_GetUint16(ttf->data, &ttf->pos);
    U16 res1 = ttf_GetUint16(ttf->data, &ttf->pos); // should be 0
    U16 segCountX2 = ttf_GetUint16(ttf->data, &ttf->pos);
    U16 searchRange = ttf_GetUint16(ttf->data, &ttf->pos);
    U16 entrySelector = ttf_GetUint16(ttf->data, &ttf->pos);
    U16 rangeShift = ttf_GetUint16(ttf->data, &ttf->pos);
    
    if (subtableFmt != 4)
    {
        Panic("Invalid font: Unicode BMP table with non- format 4 subtable");
    }
    
    // read the parallel arrays
    I32 segs = segCountX2 / 2;
    I32 endsBase = ttf->pos;
    I32 startsBase = endsBase + segCountX2 + 2;
    I32 idDeltaBase = startsBase + segCountX2;
    I32 idRangeOffsetBase = idDeltaBase + segCountX2;
    
    I32 targetSegment = -1;
    
    I32 c = wantedChar & 0xFF;
    
    for (i = 0; i < segs; i++)
    {
        I32 end = ttf_PickUint16(ttf->data, endsBase, i);
        I32 start = ttf_PickUint16(ttf->data, startsBase, i);
        if (end >= c && start <= c) {
            targetSegment = i;
            break;
        }
    }
    
    if (targetSegment < 0) return 0; // the specific 'missing' glyph
    
    U16 rangeOffset = ttf_PickUint16(ttf->data, idRangeOffsetBase, targetSegment);
    if (rangeOffset == 0) {
        // direct lookup:
        U16 lu = ttf_PickInt16(ttf->data, idDeltaBase, targetSegment); // this can represent a negative by way of the modulo
        I32 glyphIdx = (lu + c) % 65536;
        return glyphIdx;
    }
    
    // Complex case. The TrueType spec expects us to have mapped the font into memory, then do some
    // nasty pointer arithmetic. "This obscure indexing trick works because glyphIdArray immediately follows idRangeOffset in the font file"
    
    // https://docs.microsoft.com/en-us/typography/opentype/spec/cmap
    // https://github.com/LayoutFarm/Typography/wiki/How-To-Translate-Unicode-Character-Codes-to-TrueType-Glyph-Indices-in-Windows-95
    // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html
    //
    U16 ros = ttf_PickUint16(ttf->data, idRangeOffsetBase, targetSegment);
    U16 startc = ttf_PickUint16(ttf->data, startsBase, targetSegment);
    I32 offsro = idRangeOffsetBase + (targetSegment * 2);
    I32 glyphIndexAddress = ros + 2 * (c - startc) + offsro;
    U16 res = ttf_PickInt16(ttf->data, glyphIndexAddress, 0);
    
    return res;
}

U0 ttf_EndsAdd(ttf_End *ends, U16 value)
{
    ttf_End *new = CAlloc(sizeof(ttf_End));
    while (ends->next)
    {
        ends = ends->next;
    }
    new->value = value;
    ends->next = new;
}

U16 ttf_EndsMax(ttf_End *ends)
{
    U16 res = 0;
    while (ends)
    {
        res = Max(res, ends->value);
        ends = ends->next;
    }
    return res & 0xFFFF;
}

U0 ttf_FlagsAdd(ttf_SimpleGlyphFlag *flags, U8 flag)
{
    ttf_SimpleGlyphFlag *new = CAlloc(sizeof(ttf_SimpleGlyphFlag));
    while (flags->next)
    {
        flags = flags->next;
    }
    new->flag = flag;
    flags->next = new;
}

U0 ttf_PointsAdd(ttf_GlyphPoint *points, Bool onCurve)
{
    ttf_GlyphPoint *new = CAlloc(sizeof(ttf_GlyphPoint));
    while (points->next)
    {
        points = points->next;
    }
    new->OnCurve = onCurve;
    points->next = new;
}

U0 ttf_ElaborateCoordsX(ttf_TrueTypeFont *ttf, ttf_SimpleGlyphFlag *flags, ttf_GlyphPoint *points)
{
    F64 value = 0.0;
    if (!flags || !points) { return; }
    flags = flags->next;
    points = points->next;
    while (flags)
    {
        if (flags->flag & GLYF_X_IS_BYTE)
        {
            if (flags->flag & GLYF_X_DELTA)
            {
                value += ToF64(ttf_GetUint8(ttf->data, &ttf->pos));
            }
            else
            {
                value -= ToF64(ttf_GetUint8(ttf->data, &ttf->pos));
            }
            
        } else if (!(flags->flag & GLYF_X_DELTA))
        {
            value += ToF64(ttf_GetInt16(ttf->data, &ttf->pos));
        }
        else
        {
            // value not changed
            // this is why X and Y are separate
        }
        points->X = value;
        while (points->X > 32767)
        {
            points->X -= 65536;
        }
        flags = flags->next;
        points = points->next;
    }
}

U0 ttf_ElaborateCoordsY(ttf_TrueTypeFont *ttf, ttf_SimpleGlyphFlag *flags, ttf_GlyphPoint *points)
{
    F64 value = 0.0;
    if (!flags || !points) { return; }
    flags = flags->next;
    points = points->next;
    while (flags)
    {
        if (flags->flag & GLYF_Y_IS_BYTE)
        {
            if (flags->flag & GLYF_Y_DELTA)
            {
                value += ToF64(ttf_GetUint8(ttf->data, &ttf->pos));
            }
            else
            {
                value -= ToF64(ttf_GetUint8(ttf->data, &ttf->pos));
            }
            
        } else if (!(flags->flag & GLYF_Y_DELTA))
        {
            value += ToF64(ttf_GetInt16(ttf->data, &ttf->pos));
        }
        else
        {
            // value not changed
            // this is why X and Y are separate
        }
        points->Y = value;
        while (points->Y > 32767)
        {
            points->Y -= 65536;
        }
        flags = flags->next;
        points = points->next;
    }
}

U0 ttf_ReadSimpleGlyph(ttf_TrueTypeFont *ttf, ttf_Glyph *g)
{
    I64 i;
    U8 flag;
    U8 repeatCount;
    ttf_GlyphPoint *point;
    g->GlyphType = glyf_Simple;
    g->ContourEnds = CAlloc(sizeof(ttf_End));

    for (i = 0; i < g->NumberOfContours; i++)
    {
        ttf_EndsAdd(g->ContourEnds, ttf_GetUint16(ttf->data, &ttf->pos));
    }

    // Skip past hinting instructions
    ttf_Skip(ttf->data, &ttf->pos, ttf_GetUint16(ttf->data, &ttf->pos));

    U16 numPoints = ttf_EndsMax(g->ContourEnds) + 1;

    // Flags and points match up
    g->Flags = CAlloc(sizeof(ttf_SimpleGlyphFlag));
    g->Points = CAlloc(sizeof(ttf_GlyphPoint));

    // Read point flags, creating base entries
    for (i = 0; i < numPoints; i++)
    {
        flag = ttf_GetUint8(ttf->data, &ttf->pos);
        ttf_FlagsAdd(g->Flags, flag);
        ttf_PointsAdd(g->Points, flag & GLYF_ON_CURVE);

        if (flag & GLYF_REPEAT)
        {
            repeatCount = ttf_GetUint8(ttf->data, &ttf->pos);
            i += (repeatCount & 0xFF);
            while (repeatCount-- > 0)
            {
                ttf_FlagsAdd(g->Flags, flag);
                ttf_PointsAdd(g->Points, flag & GLYF_ON_CURVE);
            }
        }
    }

    // Fill out point data
    ttf_ElaborateCoordsX(ttf, g->Flags, g->Points);
    ttf_ElaborateCoordsY(ttf, g->Flags, g->Points);
}

U32 ttf_GetGlyphOffset(ttf_TrueTypeFont *ttf, I32 index)
{
    ttf_tablesList *loca = ttf_OffsetTablesGetKey(ttf, "loca");
    ttf_tablesList *glyf = ttf_OffsetTablesGetKey(ttf, "glyf");
    U32 size = loca->offsetEntry->Offset + loca->offsetEntry->Length;
    U32 offset, old, target;
    
    if (ttf->_header->IndexToLocFormat == 1) {
        target = loca->offsetEntry->Offset + index * 4;
        if (target + 4 > size)
        {
            Panic("Glyph index out of range");
        }
        old = ttf_Seek(ttf->data, &ttf->pos, target);
        offset = ttf_GetUint32(ttf->data, &ttf->pos);
    } else {
        target = loca->offsetEntry->Offset + index * 2;
        if (target + 2 > size)
        {
            Panic("Glyph index out of range");
        }
        old = ttf_Seek(ttf->data, &ttf->pos, target);
        offset = ttf_GetUint16(ttf->data, &ttf->pos) * 2;
    }    
    ttf_Seek(ttf->data, &ttf->pos, old);
    return offset + glyf->offsetEntry->Offset;
}

ttf_Glyph *ttf_ReadGlyphByIndex(ttf_TrueTypeFont *ttf, I32 index, Bool forceEmpty)
{
    ttf_tablesList *glyf = ttf_OffsetTablesGetKey(ttf, "glyf");
    U32 offset = ttf_GetGlyphOffset(ttf, index);
    
    if (offset >= glyf->offsetEntry->Offset + glyf->offsetEntry->Length)
    {
        Panic("Bad font: Invalid glyph offset (too high) at index");
    }
    if (offset < glyf->offsetEntry->Offset)
    {
        Panic("Bad font: Invalid glyph offset (too low) at index");
    }

    ttf_Seek(ttf->data, &ttf->pos, offset);
    ttf_Glyph *g = CAlloc(sizeof(ttf_Glyph));
    g->NumberOfContours = ttf_GetInt16(ttf->data, &ttf->pos);
    g->xMin = ttf_GetFWord(ttf->data, &ttf->pos);
    g->yMin = ttf_GetFWord(ttf->data, &ttf->pos);
    g->xMax = ttf_GetFWord(ttf->data, &ttf->pos);
    g->yMax = ttf_GetFWord(ttf->data, &ttf->pos);

    if (g->NumberOfContours < -1)
    {
        Panic("Bad font: Invalid contour count at index");
    }
    U32 baseOffset = ttf->pos;
    if (forceEmpty || g->NumberOfContours == 0)
    {
        g->GlyphType = glyf_Empty;
        return g;
    }
    if (g->NumberOfContours == -1)
    {
        // Compounds not yet supported
        g->GlyphType = glyf_Empty;
        return g;
    }
    ttf_ReadSimpleGlyph(ttf, g);
    return g;
}

ttf_Glyph *ttf_ReadGlyph(ttf_TrueTypeFont *ttf, U8 ch)
{
    if (!ttf_UnicodeIndexesContainsKey(ttf, ch))
    {
        ttf_unicodeIndexesListAdd(ttf->_unicodeIndexes, ch, ttf_GlyphIndexForChar(ttf, ch));
    }
    U32 offset = ttf_UnicodeIndexesGetKey(ttf, ch)->idx;

    if (!ttf_GlyphCacheContainsKey(ttf, offset))
    {
        ttf_Glyph *g = ttf_ReadGlyphByIndex(ttf, offset, cond(ch==' ',1, 0));
        g->SourceCharacter = ch;
        g->SourceFont = ttf->_filename;
        ttf_glyphCacheListAdd(ttf->_glyphCache, offset, g);
    }
    return ttf_GlyphCacheGetKey(ttf, offset)->glyph;
}

I64 ttf_FindX1(CDC *dc)
{
  I64 x=0;
  I64 y=0;
  while (x<dc->width)
  {
    y=0;
    while (y<dc->height)
    {
      if (GrPeek(dc,x,y)!=TRANSPARENT)
      {
        return x;
      }
      y++;
    }
    x++;
  }
  return -1; 
}
I64 ttf_FindX2(CDC *dc)
{
  I64 x=dc->width-1;
  I64 y=dc->height-1;
  while (x>-1)
  {
    y=dc->height-1;
    while (y>-1)
    {
      if (GrPeek(dc,x,y)!=TRANSPARENT)
      {
        return x;
      }
      y--;
    }
    x--;
  }
  return -1; 
}

I64 ttf_CtxFindX1(EContext2D *ctx)
{
  I64 x=0;
  I64 y=0;
  while (x<ctx->width)
  {
    y=0;
    while (y<ctx->height)
    {
      if (Peek2D(ctx,x,y)!=ctx->alpha_color)
      {
        return x;
      }
      y++;
    }
    x++;
  }
  return -1; 
}
I64 ttf_CtxFindX2(EContext2D *ctx)
{
  I64 x=ctx->width-1;
  I64 y=ctx->height-1;
  while (x>-1)
  {
    y=ctx->height-1;
    while (y>-1)
    {
      if (Peek2D(ctx,x,y)!=ctx->alpha_color)
      {
        return x;
      }
      y--;
    }
    x--;
  }
  return -1; 
}
I64 ttf_CtxFindY1(EContext2D *ctx)
{
  I64 x=0;
  I64 y=0;
  while (y<ctx->height)
  {
    x=0;
    while (x<ctx->width)
    {
      if (Peek2D(ctx,x,y)!=ctx->alpha_color)
      {
        return y;
      }
      x++;
    }
    y++;
  }
  return -1; 
}
I64 ttf_CtxFindY2(EContext2D *ctx)
{
  I64 x=ctx->width-1;
  I64 y=ctx->height-1;
  while (y>-1)
  {
    x=ctx->width-1;
    while (x>-1)
    {
      if (Peek2D(ctx,x,y)!=ctx->alpha_color)
      {
        return y;
      }
      x--;
    }
    y--;
  }
  return -1; 
}

U0 ttf_RenderGlyph(ttf_Glyph *g)
{
    I64 xofs = 128;
    I64 yofs = 128;

    F64 xx=0, yy=0;
    F64 fx=0, fy=0;

    I64 scale = 5;
    if (!g->Points) { return; };

    Bool first = TRUE;
    CDC *dc = DCNew(512,512);
    CDC *dc2 = DCNew(512,512);

    DCFill(dc);
    DCFill(dc2);
    dc->color = BLACK;

    I64 p = 0;
    ttf_End *ends = g->ContourEnds->next;
    ttf_GlyphPoint *point = g->Points->next;

    while (point)
    {
        if (first)
        {
            xx = ToI64(point->X/scale);
            yy = ToI64(point->Y/scale);
            fx = xx;
            fy = yy;
            //GrPlot(dc, xx+256, yy+256);
            first = FALSE;
        }
        else
        {
            GrLine(dc, xx+xofs, yy+yofs, ToI64(point->X/scale)+xofs, ToI64(point->Y/scale)+yofs);
            xx = ToI64(point->X/scale);
            yy = ToI64(point->Y/scale);
        }

        if (p == ends->value)
        {
            GrLine(dc, xx+xofs, yy+yofs, fx+xofs, fy+yofs);
            ends = ends->next;
            first = TRUE;
        }
        p++;
        point = point->next;
    }

    GrBlot(dc2, 0, 0, dc);

    dc->color=1;
    GrFloodFill(dc, 0, 0);
    DCColorChg(dc, TRANSPARENT, 0);

    dc2->color=0;
    GrFloodFill(dc2, 0, 0);
    dc2->color=TRANSPARENT;
    GrFloodFill(dc2, 0, 0);
    dc2->color=0;
    GrFloodFill(dc2, 0, 0);

    DCColorChg(dc2, TRANSPARENT, 1);
    DCColorChg(dc2, 0, TRANSPARENT);
    GrBlot(dc, 0, 0, dc2);
    DCDel(dc2);
    DCColorChg(dc, 1, TRANSPARENT);

    g->dc = DCExt(dc, ttf_FindX1(dc), 0, ttf_FindX2(dc), dc->height-1);

    DCDel(dc);
}

I64 ttf_DrawGlyph(EContext2D *ctx, I64 x, I64 y, F64 size, U32 color, ttf_Glyph *g, Bool draw=TRUE)
{
    I64 cx, cy, oy, width;
    F64 fx, fy;
    I64 dx, dy;
    if (!g->dc)
    {
        ttf_RenderGlyph(g);
        if (!draw) return NULL;
    }
    CDC *tmpdc = DCNew(g->dc->width, g->dc->height);
    DCFill(tmpdc);
    dy=0;
    for (fy=0;fy<g->dc->height;fy+=size)
    {
        dx=0;
        for (fx=0;fx<g->dc->width;fx+=size)
        {
            tmpdc->color = GrPeek(g->dc,ToI64(fx),ToI64(fy));
            GrPlot(tmpdc,dx,dy);
            dx++;
        }
        dy++;
    }
    if (draw)
    {
        oy = 0;
        for (cy=tmpdc->height-1;cy>-1;cy--)
        {
            for (cx=0;cx<tmpdc->width;cx++)
            {
                if (!GrPeek(tmpdc, cx, cy))
                {
                    Plot2D(ctx, x+cx, -display.height/2+y+oy, color);
                }
            }
            oy++;
        }
    }
    width = ttf_FindX2(tmpdc) - ttf_FindX1(tmpdc);
    DCDel(tmpdc);
    return width;
}

I64 ttf_RenderText2D(EContext2D *ctx, I64 x, I64 y, F64 size=0.5, I64 space=2, ttf_TrueTypeFont *ttf, U8 *ttf_name, U8 *text, U32 color=0x0, Bool draw=TRUE)
{
    I64 ox = x;
    I64 oy = y;
    while (ttf)
    {
        if (!StrCmp(ttf->_filename, ttf_name))
        {
            break;
        }
        ttf = ttf->next;
    }
    if (!ttf) { return; }
    ttf_Glyph *g;
    I64 i, width;
    for (i=0; i<StrLen(text); i++)
    {
        if (text[i]==' ')
        {
            g = ttf_ReadGlyph(ttf, 't');
            width = ttf_DrawGlyph(ctx, x, y, size, color, g, FALSE);
            x += width + space;
        }
        else
        {
            g = ttf_ReadGlyph(ttf, text[i]);
            width = ttf_DrawGlyph(ctx, x, y, size, color, g, draw);
            x += width + space;
        }
    }
    return (x-ox) - space;
}

EContext2D *ttf_TextRect2D(I64 w, F64 size=0.5, I64 space=2, ttf_TrueTypeFont *ttf, U8 *ttf_name, U8 *text, U32 color=0x0)
{
    I64 x_offset = 0;
    I64 y_offset = 0;
    I64 x1, y1, x2, y2;

    EContext2D *ctx = NewContext2D(w, 256, display.bpp);
    EContext2D *rect = NULL;
    ctx->alpha_color=0xFFFFFF00 - color;

    Fill2D(ctx, ctx->alpha_color);
    ttf_RenderText2D(ctx, x_offset, y_offset, size, space, ttf, ttf_name, "Iy", color);
    y1 = ttf_CtxFindY1(ctx) - 4;
    y2 = ttf_CtxFindY2(ctx) + 4;

    //DocPrint(trace_log, "y1: %d, y2: %d\n", y1, y2);

    Fill2D(ctx, ctx->alpha_color);
    ttf_RenderText2D(ctx, x_offset, y_offset, size, space, ttf, ttf_name, text, color);
    x1 = ttf_CtxFindX1(ctx);
    x2 = ttf_CtxFindX2(ctx);

    rect = NewContext2D(x2-x1, y2-y1, display.bpp);
    rect->alpha_color=0xFFFFFF00 - color;
    Fill2D(rect, rect->alpha_color);
    Blot2D(rect, -x1, -y1, ctx);
    DelContext2D(ctx);
    return rect;
}