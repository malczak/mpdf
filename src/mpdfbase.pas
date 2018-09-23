(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                                mpdfbase.pas
********************************************************
 unit description :    mPDF base types and base routines
********************************************************
 bugs :                                              ---
********************************************************
 other :                                             ---
 2.I.2007 - line 326, pdf 1.5 name/number trees ds
********************************************************)
unit mpdfbase;

interface
uses SysUtils, Classes, Windows;

type
//avaible objects types
//************** avaible pdf objects (v1.4 & v1.5) **********************************\\
TMPDFtype       = ( mpdfVariable, mpdfBasevar, mpdfArray, mpdfContainer,
                    mpdfRect, mpdfMatrix, mpdfObjref,mpdfDictionary,
                    mpdfFilter, mpdfObject,
                    //pdf file objects (all inherited form TPDFobject)
                    mpdfStream, mpdfPages, mpdfPage, mpdfInfo,
                    mpdfContents, mpdfResources, mpdfFont, mpdfXObject,
                    mpdfImage, mpdfForm, mpdfCatalog,
                    //other
                    mpdfImporter, mpdfTemplate,
                    mpdfNIL,
                    //new in pdf v1.5
                    mpdfTreeRoot, mpdfTree );


//base types
PDFushort       = Byte;
PDFbool         = Boolean;
PDFchar         = ShortInt;
PDFpchar        = PChar;
PDFuchar        = Byte;
PDFuint         = Word;
PDFint          = Integer;
PDFulong        = LongWord;
PDFlong         = LongInt;
PDFreal         = Real;
TPDFvariable    = class
                   protected
                    mpdftype : TMPDFtype;
                   public
                    property getType : TMPDFtype read mpdftype;
                    function Clone : TPDFvariable; virtual;
                    constructor Create; overload;
                    function isEmpty : boolean; virtual;
                    procedure print( stream : TStream ); virtual; abstract;
                    destructor Destroy; override;
                  end;
PPDFvariable    = ^TPDFvariable;

//resources
TPDFobjID       = PDFulong;
TPDFfontID      = PDFulong;
TPDFimageID     = PDFulong;
TPDFtplID       = PDFulong; //template idenifier


//other
TPDFprocedure   = ( pPDF, pText, pImageC, pImageB, pImageI );

TPDFpagelayout  = ( plSinglePage, plOneColumn, plTwoColumnLeft, plTwoColumnRight );
TPDFpagemode    = ( pmUseNone, pmUseOutlines, pmUseThumbs, pmFullScreen );
TPDFrestype     = ( rtExtGState, rtColorSpace, rtPattern, rtShading, rtXObject, rtFont, rtProperties );

TPDFpoint       = record
                   x,y : PDFint;
                  end;

//VARIANT records
//      vtNUll, vtDefStr, vtBinaryStr -> used only internaly in lib
TPDFvartypes    = ( vtNull, vtDefStr, vtBinStr, vtBool, vtInt, vtFloat, vtString, vtHexStr, vtName );
TPDFfilter      = ( pfFlateDecode );
TPDFmatrixtype  = ( mtTranslate, mtRotate, mtScale );
TPDFvariant     ={$IFNDEF USE_BORLAND_VARIANT}
                  packed record
                   case  i:Byte  of
                    0  :  ( Bool  : PDFbool; );
                    1  :  ( Int   : PDFint; );
                    2  :  ( Float : PDFreal; );
                    3  :  ( Str   : PString; );
                  end;
                {$ELSE}
                 Variant;
                {$ENDIF}

const
 //pdf save strings
 pdfEol         =       ''+Char($0D);
 pdfHeader      =       '%%PDF-1.%d'+pdfEol;
 pdfBinary      =       '%‚„œ”'+pdfEol;

 pdfEof         =       '%%EOF'+pdfEol;

 pdfObjStart    =       '%d %d obj'+pdfEol;
 pdfObjEnd      =       pdfEol+'endobj'+pdfEol;
 pdfObjRef      =       '%d %d R';
 pdfStreamStart =       Char(13)+'stream'+Char(13)+Char(10);
 pdfStreamEnd   =       Char(13)+'endstream';
// pdfStreamEnd   =       'endstream';
 pdfDictStart   =       '<<';
 pdfDictEnd     =       '>>';
 pdfArrayStart  =       '[';
 pdfArrayEnd    =       ']';
 pdfRectStart   =       '[';
 pdfRectEnd     =       ']';
 pdfXref        =       'xref'+pdfEol;
 pdfXreffirst   =       '0000000000 65535 f '+pdfEol;
 pdfXrefelem    =       '%.10d %.5d n '+pdfEol;
 pdfXrefelemf   =       '%.10d %.5d f '+pdfEol;
 pdfTrailerStart=       'trailer'+pdfEol;
 pdfTrailerEnd  =       pdfEol+'startxref'+pdfEol;
 pdfSpace       =       ' ';

 //others
 TPDFstringtypes = [vtDefStr, vtBinStr, vtString, vtHexStr, vtName];
 PDFresourcedics  : array [1..7] of string = ('ExtGState','ColorSpace','Pattern','Shading','Font','XObject','Properties');
 PDFprocsetnames  : array[ TPDFprocedure ] of string = ('PDF', 'Text', 'ImageC', 'ImageB', 'ImageI');
 mpdfHex : array [0..15] of char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');

//functions and procedures

 procedure PDFwritestring( stream : TStream; s : string ); overload;
 procedure PDFwritestring( stream : TStream; const frmt: string; const Args: array of const); overload;
 function PDFhexstring(const s : string ) : string;
 function PDFunicode(const s : string ) : string;
 function PDFtoday : string;
 function PDFnow   : string;
 function PDFpack( hex : string ) : string; //32hex string -> 16binary data
 function PDFbincheck( instr : string ) : string;
 function PDFgettype( obj : TPDFvariable ) : TMPDFtype;
 function getObject( const d : TPDFvariable; ename : string; out obj : TPDFvariable ) : boolean;
 function PDFgetstring( s : string ) : string;


 procedure Dec_( v : TPDFvariable; d : PDFreal = 1.0 );
 procedure Inc_( v : TPDFvariable; d : PDFreal = 1.0 );

implementation
uses mpdfvars;


//*********************************************** TPDFvariable
constructor TPDFvariable.Create;
begin
 mpdftype := mpdfVariable;
end;

function TPDFvariable.Clone : TPDFvariable;
begin
 result := TPDFvariable.Create;
end;


function TPDFvariable.isEmpty : boolean;
begin
 //abstract
 result := false;
end;

destructor TPDFvariable.Destroy;
begin
 inherited;
end;
//*********************************************** TPDFvariable


procedure PDFwritestring( stream : TStream; s : string );
begin
 stream.WriteBuffer( s[1], Length( s ) );
end;

procedure PDFwritestring(stream : TStream; const frmt: string; const Args: array of const);
var s : string;
begin
 s := Format( frmt, Args );
 stream.WriteBuffer( s[1] , Length( s ) );
end;

function PDFhexstring(const s : string ) : string;
var i : integer;
    r : string;
begin
 setLength( r, 2*length(s) );
  for i:=1 to length(s) do
   begin
    r[  2*i  ] := mpdfHex[ ord(s[i]) mod 16 ];
    r[ 2*i-1 ] := mpdfHex[ ( ord(s[i]) div 16 ) mod 16 ];
   end;
 result := r;
end;

function PDFunicode(const s : string ) : string;
var i,wc : word;
    r : array of WideChar;
begin
 setLength( r, length(s) );
 {
   function MultiByteToWideChar(CodePage: UINT; dwFlags: DWORD;
                                const lpMultiByteStr: LPCSTR; cchMultiByte: Integer;
                                lpWideCharStr: LPWSTR; cchWideChar: Integer): Integer; stdcall;
 }
 i := MultiByteToWideChar( CP_ACP, MB_USEGLYPHCHARS, @s[1], length(s), @r[0], length(s) );
 result := '';
  for i:=0 to length(s)-1 do
   begin
    wc := word(r[i]);
    result := result + ( mpdfHex[(wc shr 12) and $F] + mpdfHex[(wc shr 8) and $F] + mpdfHex[(wc shr 4) and $F] + mpdfHex[wc and $F] );
   end;
 SetLength( r, 0 );
end;

function PDFtoday : String;
var
  St: TSystemTime;
begin
 GetLocalTime(St);
 result := Format('D:%.4d%.2d%.2d%.2d%.2d%.2d+01''00''',[st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond ]);
end;

function PDFnow   : string;
var
  St: TSystemTime;
begin
 GetLocalTime(St);
 result := Format('T:%.2d%.2d%.2d+01''00''',[st.wHour,st.wMinute,st.wSecond]);
end;

function PDFpack( hex : string ) : string;
var i , j, k : word;
    ordA : shortint;
begin
          ordA := 10 - ord('A');
          hex := UpperCase( hex );
          result := '0000000000000000';
          j := 1;
           for i := 1 to 16 do
            begin
              case hex[ j ] of
               '0'..'9' : k := StrToInt(hex[j]);
               'A'..'F' : k := Ord(hex[j])+ordA
              end;
             result[i] := char( ( k and $F ) shl 4 );
              case hex[ j+1 ] of
               '0'..'9' : k := StrToInt(hex[j+1]);
               'A'..'F' : k := Ord(hex[j+1])+ordA;
              end;
             result[i] := char(  byte(result[i]) or ( k and $F ) );
             inc( j, 2 );
            end;
end;

function PDFbincheck( instr : string ) : string;
var i,len : longword;
    c : char;
begin
 len := length(instr);
 result := '';
  for i := 1 to len do
   begin
    c := instr[i];
     case Byte( c ) of
      $0A : result := result + '\n';// LF
      $0D : result := result + '\r';// CR
      $09 : result := result + '\t';// tabv
      $08 : result := result + '\b';// backspace
      $0C : result := result + '\f';// form-feed
      $28 : result := result + '\(';// (
      $29 : result := result + '\)';// )
      $5c : result := result + '\\';// \
       else result := result + c;
     end;
  end;
end;

function PDFgettype( obj : TPDFvariable ) : TMPDFtype;
begin
 result := mpdfNIL;
  if obj<>nil then result := TPDFvariable( obj ).getType;
end;

function getObject( const d : TPDFvariable; ename : string; out obj : TPDFvariable ) : boolean;
begin
 obj := TPDFdictionary(d)[ ename ];
 result := false;
  if obj<>nil then
   begin
      if obj.getType = mpdfObjref then obj := TPDFobjref( obj ).v;
    result := (d<>nil);
   end;
end;

function PDFgetstring( s : string ) : string;
var i : word;
begin
 result := '';
 i := 1;
  while i<=length(s) do
   begin
    if not ( s[i] in ['(',')'] ) then
     if s[i]='\' then
      begin
        case s[i+1] of
         'n' : result := result + char($0A); //LF
         'r' : result := result + char($0D); //CR
         't' : result := result + char($09); //tab
         'b' : result := result + char($08); //Backspace
         'f' : result := result + char($0C); //form-feed
         else result := result + s[i+1];
        end;
       inc(i);
      end else result := result + s[i];
  inc(i);
 end;
end;

procedure Dec_( v : TPDFvariable; d : PDFreal = 1.0 );
begin
 if v.getType = mpdfBasevar then
  case TPDFbasevar(v).vartype of
   vtInt : TPDFbasevar(v).asInt := TPDFbasevar(v).asInt - trunc(d);
   vtFloat : TPDFbasevar(v).asFloat := TPDFbasevar(v).asFloat - d;
   vtDefStr : TPDFbasevar(v).asInt := TPDFbasevar(v).asInt - trunc(d);
  end;
end;

procedure Inc_( v : TPDFvariable; d : PDFreal = 1.0 );
begin
 if v.getType = mpdfBasevar then
  case TPDFbasevar(v).vartype of
   vtInt : TPDFbasevar(v).asInt := TPDFbasevar(v).asInt + trunc(d);
   vtFloat : TPDFbasevar(v).asFloat := TPDFbasevar(v).asFloat + d;
   vtDefStr : TPDFbasevar(v).asInt := TPDFbasevar(v).asInt + trunc(d);
  end;
end;

end.
