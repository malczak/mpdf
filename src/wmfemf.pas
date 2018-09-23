unit wmfemf;

interface

// based on article : http://www.csn.ul.ie/~caolan/publink/libwmf/libwmf/doc/ora-wmf.html

const
 PMKey = $9AC6CDD7;

 //wmf functions (standard metarecord type )
   // Record Name Function Number
        AbortDoc = $0052;
        Arc = $0817;
        Chord = $0830;
        DeleteObject = $01f0;
        Ellipse = $0418;
        EndDoc = $005E;
        EndPage = $0050;
        ExcludeClipRect = $0415;
        ExtFloodFill = $0548;
        FillRegion = $0228;
        FloodFill = $0419;
        FrameRegion = $0429;
        IntersectClipRect = $0416;
        InvertRegion = $012A;
        LineTo = $0213;
        MoveTo = $0214;
        OffsetClipRgn = $0220;
        OffsetViewportOrg = $0211;
        OffsetWindowOrg = $020F;
        PaintRegion = $012B;
        PatBlt = $061D;
        Pie = $081A;
        RealizePalette = $0035;
        Rectangle = $041B;
        ResetDc = $014C;
        ResizePalette = $0139;
        RestoreDC = $0127;
        RoundRect = $061C;
        SaveDC = $001E;
        ScaleViewportExt = $0412;
        ScaleWindowExt = $0410;
        SelectClipRegion = $012C;
        SelectObject = $012D;
        SelectPalette = $0234;
        SetTextAlign = $012E;
        SetBkColor = $0201;
        SetBkMode = $0102;
        SetDibToDev = $0d33;
        SetMapMode = $0103;
        SetMapperFlags = $0231;
        SetPalEntries = $0037;
        SetPixel = $041F;
        SetPolyFillMode = $0106;
        SetRelabs = $0105;
        SetROP2 = $0104;
        SetStretchBltMode = $0107;
        SetTextCharExtra = $0108;
        SetTextColor = $0209;
        SetTextJustification = $020A;
        SetViewportExt = $020E;
        SetViewportOrg = $020D;
        SetWindowExt = $020C;
        SetWindowOrg = $020B;
        StartDoc = $014D;
        StartPage = $004F;

        AnimatePalette = $0436;
        BitBlt = $0922;
        CreateBitmap = $06FE;
        CreateBitmapIndirect = $02FD;
        CreateBrush = $00F8;
        CreateBrushIndirect = $02FC;
        CreateFontIndirect = $02FB;
        CreatePalette = $00F7;
        CreatePatternBrush = $01F9;
        CreatePenIndirect = $02FA;
        CreateRegion = $06FF;
        DibBitblt = $0940;
        DibCreatePatternBrush = $0142;
        DibStretchBlt = $0B41;
        DrawText = $062F;
        Escape = $0626;
        ExtTextOut = $0A32;
        Polygon = $0324;
        PolyPolygon = $0538;
        Polyline = $0325;
        TextOut = $0521;
        StretchBlt = $0B23;
        StretchDIBits = $0F43;

 //emf functions
type
WORD  = System.word;
DWORD = longword;
LONG  = longint;
SHORT = shortint;

PMheader  = record    //Aldus Placeable Metafiles
             Key          : DWORD;
             Handle       : WORD;
             Left,
             Top,
             Right,
             Bottom       : SHORT;
             Inch         : WORD;
             Reserved     : DWORD;
             Checksum     : WORD;
            end;

CBheader  = record
             MappingMode,
             Width,
             Height       : LONG;
             Handle       : WORD;
            end;

WMFheader = record
              FileType,
              HeaderSize,
              Version     : WORD;
              FileSize    : DWORD;
              NumOfObject : WORD;
              MaxRecSize  : DWORD;
              NumOfParams : WORD;
               case PreHeader : byte of
                1 : ( Placeable : PMheader );
                2 : ( Clipboard : CBheader );
            end;

WMFfunction = record
               FuncId : Byte;
               Params : Word;
               Parameters : array of Word;
              end;

EMFheader = record
              RecordType,
              RecordSize      : DWORD;
              BoundsLeft,
              BoundsRight,
              BoundsTop,
              BoundsBottom,
              FrameLeft,
              FrameRight,
              FrameTop,
              FrameBottom     : LONG;
              Signature,
              Version,
              Size,
              NumOfRecords    : DWORD;
              NumOfHandles,
              Reserved        : WORD;
              SizeOfDescrip,
              OffsOfDescrip,
              NumPalEntries   : DWORD;
              WidthDevPixels,
              HeightDevPixels,
              WidthDevMM,
              HeightDevMM     : LONG;
            end;
            
implementation

end.
