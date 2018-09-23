(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                                mpdfvars.pas
********************************************************
 unit description :    variables used in pdf file format
********************************************************
 bugs :                                              ---
********************************************************
 other :
      11.XII.2005 - implemented Clone(...) procedure in
                    other units(objects)
        2.IV.2005 - first root data types (pdfbase.pas)
********************************************************)
unit mpdfvars;

interface
uses sysutils, classes, math,
     mpdfbase, mpdffilters;
type

TPDFobject      = class;

TPDFdicentry    = record
                   Name : String;
                   Value : TPDFvariable;
                  end;
PPDFdicentry    = ^TPDFdicentry;

TPDFbasevar     = class ( TPDFvariable )
                  protected
                    value   : TPDFvariant;
                  protected
                    {$IFNDEF USE_BORLAND_VARIANT}
                    procedure setAsInt( v : PDFint );
                    function getAsInt : PDFint;
                    procedure setAsFloat( v : PDFreal );
                    function getAsFloat : PDFreal;
                    procedure setAsBool( v : PDFbool );
                    function getAsBool : PDFbool;
                    procedure setAsString( v : string );
                    function getAsString : string;
                    {$ENDIF}
                    function getAsVariant : TPDFvariant;
                    procedure setAsVariant( v : TPDFvariant );

                  public
                    vartype : TPDFvartypes;
                    function Clone : TPDFvariable; override;
                    function isEmpty : PDFbool; override;
                    property asVariant : TPDFvariant read getAsVariant write setAsVariant;
                    {$IFNDEF USE_BORLAND_VARIANT}
                    property asInt : PDFint read getAsInt write setAsInt;
                    property asFloat : PDFreal read getAsFloat write setAsFloat;
                    property asBool : PDFbool read getAsBool write setAsBool;
                    property asString : string read getAsString write setAsString;
                    {$ELSE}
                    property asInt : TPDFvariant read getAsVariant write setAsVariant;
                    property asFloat : TPDFvariant read getAsVariant write setAsVariant;
                    property asBool : TPDFvariant read getAsVariant write setAsVariant;
                    property asString : TPDFvariant read getAsvariant write setAsVariant;
                    {$ENDIF}

                    procedure print( stream : TStream ); override;
                    constructor Create(); overload;
                     {$IFNDEF USE_BORLAND_VARIANT}
                      constructor Create( v : TPDFvariant ); overload;
                     {$ENDIF}
                    constructor Create( long : PDFint ); overload;
                    constructor Create( float : PDFreal ); overload;
                    constructor Create( bool : PDFbool ); overload;
                    constructor Create( str : string; strtype : TPDFvartypes = vtString ); overload;
                    destructor Destroy; override;
                  end;

TPDFarray       = class ( TPDFvariable )
                  private
                   v : array of TPDFvariable;
                   vcount : PDFint;
                   useSingle : boolean; //if true then object is either array or single object ;)
                   function getItem( i : PDFint ):TPDFvariable;
                   procedure setItem( i : PDFint; obj : TPDFvariable );
                  public
                   property item[ i : PDFint ] : TPDFvariable read getItem write setItem; default;
                   property count : PDFint read vcount;

                   function Clone : TPDFvariable; override;
                   function isEmpty : boolean; override;
                   procedure Clear;
                   function push( v : TPDFvariable ) : PDFint;
                   function shift( v : TPDFvariable ) : PDFint;
                   procedure print( stream : TStream ); override;
                   constructor Create( useSingle : boolean = false ); overload;
                   constructor Create( v : array of TPDFvariable ); overload;
                   constructor Create( const pdfarray : TPDFarray ); overload;
                  end;

//object is an array in witch selecting some elements
TPDFcontainer   = class ( TPDFarray )
                  private
                   SelItem : TPDFvariable;
                  public
                   constructor Create; overload;
                   constructor Create( v : array of TPDFvariable ); overload;
                   property Selected : TPDFvariable read SelItem;
                   function select( i : PDFint ) : PDFbool;
                  end;

TPDFrect        = class ( TPDFarray )
                   function isEmpty : boolean;  override;
                   procedure setCoords( llx, lly, urx, ury : PDFint );
                   procedure print( stream : TStream ); override;
                   function Equals( rect : TPDFrect ): boolean;
                   constructor Create; overload;
                   constructor Create( llx,lly,urx,ury : PDFint ); overload;
                  end;

TPDFmatrix = class ( TPDFvariable )
              protected
                a,b,c,d,e,f : PDFreal;
              public
                property mA : PDFreal read a;
                property mB : PDFreal read b;
                property mC : PDFreal read c;
                property mD : PDFreal read d;
                property mE : PDFreal read e;
                property mF : PDFreal read f;
                function Clone : TPDFvariable; override;
                procedure Multi( matrix : TPDFmatrix );
                procedure make( a,b,c,d,e,f : PDFreal );
                procedure loadIdentity;
                constructor Create; overload;
                constructor Create( alfa : PDFreal ); overload; //rotation
                constructor Create( vx,vy : PDFreal; matrixtype : TPDFmatrixtype ); overload; //translation
                constructor Create( a,b,c,d,e,f : PDFreal ); overload;
             end;

TPDFobjref      = class ( TPDFvariable )       // zapisuje 'n n R'
                  public
                   v    : TPDFobject;
                   function isEmpty : boolean;  override;
                   function Clone : TPDFvariable; override;
                   procedure print( stream : TStream ); override;
                   constructor Create; overload;
                   constructor Create( obj : TPDFobject ); overload;
                   destructor Destroy; override;
                  end;

TPDFdictionary  = class ( TPDFvariable )
                  protected
                   entries : array of TPDFdicentry;
                   ecount  : PDFuint;

                   procedure setVariantValue( Name : string; val : TPDFvariant);
                   procedure setValue( Name : string; obj : TPDFvariable);

                   procedure setInt( Name : string; obj : PDFint);
                   procedure setReal( Name : string; obj : PDFreal);
                   procedure setString( Name : string; obj : string);
                   procedure setBool( Name : string; obj : PDFbool);

                   procedure setArray( Name : string; obj : TPDFarray);
                   procedure setObjref( Name : string; obj : TPDFobjref);

                   function getValueByName( Name : String ) : TPDFvariable;

                   function getValueAsInt( Name : String ) : PDFint;
                   function getValueAsReal( Name : String ) : PDFreal;
                   function getValueAsString( Name : String ) : string;
                   function getValueAsBool( Name : String ) : PDFbool;

                   function getValueAsArray( Name : String ) : TPDFarray;
                   function getValueAsObjref( Name : String ) : TPDFobjref; 
                  public
                   function entryPtr( ename : string ): PPDFvariable;
                   function isEmpty : boolean; override;
                   function Clone : TPDFvariable; override;

                   procedure deleteEntry( Entry : TPDFvariable ); overload;
                   procedure deleteEntry( Name : String ); overload;

                   function clearEntry( ename : string ) : TPDFvariable; overload;
                   function clearEntry( pos : PDFint; var ename : string ) : TPDFvariable; overload;

                   function exchangeEntry( ename : string; value : TPDFvariable ) : TPDFvariable;

                   procedure addEntry( ename : string; const evalue : TPDFvariable = nil; onecheck : boolean = false ); overload;
                   procedure addEntry( ename, evalue : string ); overload;
                   procedure addEntry( ename : string; const evalue : PDFint  ); overload;
                   procedure addEntry( ename : string; const evalue : PDFreal ); overload;
                   procedure addEntry( ename : string; const evalue : PDFbool ); overload;

                   property Entry[ ename : string ] : TPDFvariable read getValueByName write setValue; default;
                   property EntryAsInt[ ename : string ] : PDFint read getValueAsInt write setInt;
                   property EntryAsReal[ ename : string ] : PDFreal read getValueAsReal write setReal;
                   property EntryAsString[ ename : string ] : string read getValueAsString write setString;
                   property EntryAsBool[ ename : string ] : PDFbool read getValueAsBool write setBool;
                   property EntryAsArray[ ename : string ] : TPDFarray read getValueAsArray write setArray;
                   property EntryAsObjref[ ename : string ] : TPDFobjref read getValueAsObjref write setObjref;
                   property Count : PDFuint read ecount;


                   procedure CopyTo( var d : TPDFdictionary );
                   function EntryArray( pos : PDFuint ) : TPDFvariable;
                   procedure print( stream : TStream ); override;
                   constructor Create;
                   destructor Destroy; override;
                  end;

//TPDFobject      = class ( TPDFvariable )       // zapisuje caly obiekt
TPDFobject      = class ( TPDFdictionary )
                  protected
                  objd       : TPDFvariable; //can be a dictionary or any other pdfvariable
                   objid      : TPDFobjid;    /// -> this value is set while saving object to file
                   function getDictionary : TPDFdictionary;
                  public
                   objpos     : PDFulong;
                   function isEmpty : boolean; override;
                   function Clone : TPDFvariable; override;

                   property Dictionary : TPDFdictionary read getDictionary; //returns objd only if objd is TPDFdictionary
                   property ID : TPDFobjid read objid;
//                   procedure print( stream : TStream );
                   procedure setObjectId( onum, gnum : PDFuint );
                   function getObjectNum : PDFuint;
                   function getGenerateNum : PDFuint;
                   procedure SaveToStream( stream : TStream); virtual;

                   procedure setVariable( objv : TPDFvariable ); virtual;
                   function getVariable : TPDFvariable;
                   function clearVariable : TPDFvariable;

                   constructor Create; overload;//creates with dictionary
                   constructor Create( pdfvar : TPDFvariable ); overload;
                   destructor Destroy; override;
                  end;

TPDFobjarray    = array of TPDFobject;

TPDFfilters     = array of TPDFfilter;

TPDFstream      = class ( TPDFobject )
                  protected
                   filcount : PDFushort;
                   filters  : TPDFfilters;
                  public
                   stream   : TStringStream;
                   procedure addFilter( f : TPDFfilter );
                   function isEmpty : boolean; override;
                   function Clone : TPDFvariable; override;
                   procedure CopyFrom( const Src : TPDFstream; Count : PDFlong );
                   procedure Compress;
                   procedure SaveToStream( stream : TStream); override;
//                   procedure print( stream : TStream ); override;
                   constructor Create; overload;
                   destructor Destroy; override;
                  end;

{* PDF 1.5 - tree, name tree and number tree *}
TPDFtree        = class ( TPDFobject )
                  protected
                   entries : PPDFvariable;
                  public
                   constructor Create( Parent : TPDFtree ); virtual;
                   procedure print( stream : TStream ); virtual; abstract;
                   procedure addChild( Child : TPDFtree ); virtual; abstract;
                   procedure removeChild( Child : TPDFtree ); virtual; abstract;
                   procedure deleteChild( Child : TPDFtree ); virtual; abstract;
                   procedure add( key : TPDFbasevar; value : TPDFbasevar ); virtual; abstract;
                   procedure remove( key : TPDFbasevar ); virtual; abstract;
                   destructor Destroy; override;
                  end;

TPDFnametree    = class ( TPDFtree )
                  public
                   procedure print( stream : TStream ); override;
                  end;

TPDFnumtree    = class ( TPDFtree )
                  public
                   procedure print( stream : TStream ); override;
                  end;
//TPDF

implementation
const PDFFilterName : array [TPDFfilter] of string = ('FlateDecode');

//*********************************************** TPDFbasevar
constructor TPDFbasevar.Create();
begin
 inherited;
 mpdftype := mpdfBasevar;
 FillChar( value, sizeof(value), 0 );
 vartype := vtNull;
end;

{$IFNDEF USE_BORLAND_VARIANT}
constructor TPDFbasevar.Create( v : TPDFvariant );
begin
 Create;
 value := v;
  case value.i of
   0 : vartype := vtBool;
   1 : vartype := vtInt;
   2 : vartype := vtFloat;
   3 : vartype := vtString;
  end;
end;
{$ENDIF}

constructor TPDFbasevar.Create( long : PDFint );
begin
 Create;
 vartype := vtInt;
 value.Int := long;
end;

constructor TPDFbasevar.Create( float : PDFreal );
begin
 Create;
 vartype := vtFloat;
 value.Float := float;
end;

constructor TPDFbasevar.Create( bool : PDFbool );
begin
 Create;
 vartype := vtBool;
 value.Bool := bool;
end;

constructor TPDFbasevar.Create( str : string; strtype : TPDFvartypes = vtString );
begin
 Create;
   if not ( strtype in TPDFstringtypes ) then strtype := vtString;
 {$IFNDEF USE_BORLAND_VARIANT}
 value.Str := new( PString );
 SetLength( Value.Str^, length(str) );
 Value.Str^ := str;
// value.Str := StrNew( PChar(str) );
 {$ELSE}
 value := str;
 {$ENDIF}
 vartype := strtype;
end;

function TPDFbasevar.Clone : TPDFvariable;
var s : string;
begin
 {$IFNDEF USE_BORLAND_VARIANT}
 case vartype of
  vtBool         : result := TPDFbasevar.Create( value.Bool );
  vtInt          : result := TPDFbasevar.Create( value.Int );
  vtFloat        : result := TPDFbasevar.Create( value.Float );
    else
        s := String( value.Str^ );
        result := TPDFbasevar.Create( String( value.Str^ ), vartype );
 end;
 {$ELSE}
  result := TPDFbasevar.Create( value );
 {$ENDIF}
end;

function TPDFbasevar.isEmpty : PDFbool;
begin
 result := false;
 {$IFNDEF USE_BORLAND_VARIANT}
      if vartype in TPDFstringtypes then
          result := ( Length( String( value.Str^ ) )=0 );
 {$ELSE}
      if vartype in TPDFstringtypes then
          result := ( Length( String( value ) )=0 );
 {$ENDIF}
end;

procedure TPDFbasevar.print( stream : TStream );
begin
 case vartype of
  vtBool         : if value.Bool then PDFwritestring(stream, 'true') else PDFwritestring( stream, 'false');
  vtInt          : PDFwritestring( stream, '%d',   [ value.Int                         ] );
  vtFloat        : PDFwritestring( stream, '%g',   [ value.Float                       ] );
  vtDefStr       : PDFwritestring( stream, '%s',   [ string(value.Str^)                 ] );
  vtBinStr       : PDFwritestring( stream, '(%s)', [ PDFbincheck( string(value.Str^)  ) ] );
  vtString       : PDFwritestring( stream, '(%s)', [ string(value.Str^)                 ] );
  vtHexStr       : PDFwritestring( stream, '<%s>', [ PDFhexstring( string(value.Str^)  )] );
  vtName         : PDFwritestring( stream, '/%s',  [ string(value.Str^)                 ] ); //<< tutuaj jest blad
 end;
end;

{$IFNDEF USE_BORLAND_VARIANT}
procedure TPDFbasevar.setAsInt( v : PDFint );
begin
  if vartype<>vtInt then
   begin
     if vartype in TPDFstringtypes then
      begin
                 SetLength( value.Str^, 0 );
                 Dispose( value.Str );
      end;
    vartype := vtInt;
   end;
 value.Int := v;
end;
function TPDFbasevar.getAsInt : PDFint;
var code : integer;
    oldtype : TPDFvartypes;
begin
 result := value.Int;
 if vartype<>vtInt then
  case vartype of
   vtDefStr,
   vtString : begin
                try
                  result := StrToInt( value.Str^ );
                except
                  result := MaxInt;
                end;
              end;
   vtFloat  : result := trunc( value.float );
  end;
end;
procedure TPDFbasevar.setAsFloat( v : PDFreal );
begin
  if vartype<>vtInt then
   begin
     if vartype in TPDFstringtypes then
      begin
                 SetLength( value.Str^, 0 );
                 Dispose( value.Str );
      end;
    vartype := vtFloat;
   end;
 value.Float := v;
end;
function TPDFbasevar.getAsFloat : PDFreal;
begin
 result := value.Float;
  if vartype<>vtInt then
   if vartype in [vtDefStr,vtString] then
    begin
     try
      result := StrToFloat( value.Str^ );
     except
      result := MaxDouble;
     end;
    end;
end;
procedure TPDFbasevar.setAsBool( v : PDFbool );
begin
  if vartype<>vtInt then
   begin
     if vartype in TPDFstringtypes then
      begin
                 SetLength( value.Str^, 0 );
                 Dispose( value.Str );
      end;
    vartype := vtBool;
   end;
  value.Bool := v;
end;
function TPDFbasevar.getAsBool : PDFbool;
begin
 result := value.Bool;
end;
procedure TPDFbasevar.setAsString( v : string );
begin
  if Length(v)=0 then exit;

    if value.str=nil then value.Str := New(PString);
   SetLength( value.Str^, length(v) );
   value.Str^ := v;

{  if value.str<>nil then StrDispose( value.str );
 value.Str := StrNew( Pchar(v) ); }

end;
function TPDFbasevar.getAsString : string;
begin
   case vartype of
     vtInt   : result := IntToStr( value.Int );
     vtFloat : result := FloatToStr( value.Int );
     vtBool  : if value.Bool then result := 'true' else result := 'false';
      else result := string( value.Str^ );
   end;
end;
{$ENDIF}

function TPDFbasevar.getAsVariant : TPDFvariant;
begin
 result := value;
end;
procedure TPDFbasevar.setAsVariant( v : TPDFvariant );
begin
 value := v;
end;

destructor TPDFbasevar.Destroy;
begin
 {$IFNDEF USE_BORLAND_VARIANT}
  if vartype in TPDFstringtypes then
  begin
   setLength( value.Str^, 0 );
   Dispose( value.Str );
//   StrDispose( value.Str );
  end;
 {$ENDIF}
 inherited;
end;
//*********************************************** TPDFarray
constructor TPDFarray.Create( useSingle : boolean );
begin
 inherited Create;
 mpdftype := mpdfArray;
 self.useSingle := useSingle;
 vcount := 0;
 SetLength( v, vcount );
end;

constructor TPDFarray.Create( v : array of TPDFvariable );
var i : PDFuint;
begin
 Create( Length(v)=1 );
 vcount := Length( v );
 SetLength( self.v, vcount );
  for i:=0 to vcount-1 do self.v[i] := v[i];
 v[0]:= nil;
end;

constructor TPDFarray.Create( const pdfarray : TPDFarray );
var i : PDFuint;
begin
 Create( pdfarray.Count=1 );
 vcount := pdfarray.count;
   if vcount>0 then
    begin
     SetLength( v, vcount );
     i := 0;
      while i<vcount do
       begin
        // kopiowanie :) - uzupelnic dla pozostalych typow :: zrobmy kazdemu obiektowi :) metode CLONE !!
        v[i] := pdfarray[i].Clone;
        inc(i);
       end;
    end;
end;

function TPDFarray.Clone : TPDFvariable;
var pa : TPDFarray;
     i : PDFuint;
begin
 pa := TPDFarray.Create;
 pa.vcount := vcount;
  if pa.vcount>0 then
    begin
     SetLength( pa.v, vcount );
     i := 0;
      while i<vcount do
       begin
        pa.v[i] := v[i].Clone;
        Inc(i);
       end;
    end;
 result := pa;
end;

function TPDFarray.isEmpty : boolean;
var p, last : ^TPDFvariable;
begin
 result := ( vcount=0 );
  if result then exit;
//check if any of elements isnt empty
 result := true;
 p := @v[0];
 last := @v[ vcount-1 ];
  while LongInt(Pointer(p)) <= Longint(Pointer(last)) do
   begin
     if p<>nil then
      result := result and p^.isEmpty;
    inc(p);
   end;
end;

procedure TPDFarray.print( stream : TStream );
//const se : array[0..3] of char = ( pdfArrayStart, pdfArrayEnd, #0, #0 );
var p, last : ^TPDFvariable;
    s : PDFuchar;
    single : boolean;
begin
 s := 0;
 single := (vcount=1) and (useSingle=true);
  if single=false then
   PDFwritestring( stream, pdfArrayStart);
 p := @v[0];
 last := @v[ vcount-1 ];
   while LongInt(Pointer(p)) <= Longint(Pointer(last)) do
    begin
     if s<>0 then stream.Write( s, 1 );

       if p^.isEmpty=false then
        begin
           p^.print( stream );
           s := PDFuchar(pdfSpace);
        end;
      inc(p);
    end;
  if single=false then
   PDFwritestring( stream, pdfArrayEnd);
end;

function TPDFarray.getItem( i : PDFint ):TPDFvariable;
begin
 result := nil;
  if (i>=0) and (i<vcount) then
    result := v[ i ];
end;

procedure TPDFarray.setItem( i : PDFint; obj : TPDFvariable );
begin
 if i in [0..vcount-1] then
   v[i] := obj;
end;

function TPDFarray.push( v : TPDFvariable ) : PDFint;
begin
  if v=nil then exit;
 Inc(vcount);
 SetLength( self.v, vcount );
 self.v[ vcount-1 ] := v;
 result := vcount-1;
end;

function TPDFarray.shift( v : TPDFvariable ) : PDFint;
var f,p,p1 : ^TPDFvariable;
begin
 Inc( vcount );
 SetLength( self.v, vcount );
  if  vcount>1 then
   begin
    p := @self.v[ vcount-1 ];
    f := @self.v[ 0 ];
     while Longint(Pointer(p)) > Longint(Pointer(f)) do
      begin
       p1 := p;
       dec(p1);
       p^ := p1^;
       dec(p);
      end;
   end;
 self.v[0] := v;
 result := 0;
end;

procedure TPDFarray.Clear;
begin
 while vcount>0 do
  begin
   Dec( vcount );
   v[ vcount ].Destroy;
  end;
 SetLength( v, 0 );
end;

//*********************************************** TPDFrect1
constructor TPDFrect.Create;
begin
 inherited Create( [ TPDFbasevar.Create(0),
                     TPDFbasevar.Create(0),
                     TPDFbasevar.Create(0),
                     TPDFbasevar.Create(0) ] );
 mpdftype := mpdfRect;
end;

constructor TPDFrect.Create( llx,lly,urx,ury : PDFint );
begin
 inherited Create( [ TPDFbasevar.Create(llx),
                     TPDFbasevar.Create(lly),
                     TPDFbasevar.Create(urx),
                     TPDFbasevar.Create(ury) ] );
 mpdftype := mpdfRect;
end;

procedure TPDFrect.setCoords( llx, lly, urx, ury : PDFint );
begin
 TPDFbasevar(v[0]).asInt := llx;
 TPDFbasevar(v[1]).asInt := lly;
 TPDFbasevar(v[2]).asInt := urx;
 TPDFbasevar(v[3]).asInt := ury;
end;

function TPDFrect.Equals( rect : TPDFrect ): boolean;
begin
 result := (TPDFbasevar(rect.v[0]).asInt=TPDFbasevar(v[0]).asInt) and
           (TPDFbasevar(rect.v[1]).asInt=TPDFbasevar(v[1]).asInt) and
           (TPDFbasevar(rect.v[2]).asInt=TPDFbasevar(v[2]).asInt) and
           (TPDFbasevar(rect.v[3]).asInt=TPDFbasevar(v[0]).asInt);
end;

function TPDFrect.isEmpty : boolean;
begin
 result := (TPDFbasevar(v[0]).asInt=0)and(TPDFbasevar(v[1]).asInt=0)and
           (TPDFbasevar(v[2]).asInt=0)and(TPDFbasevar(v[3]).asInt=0);
end;

procedure TPDFrect.print( stream : TStream );
begin
 PDFwritestring( stream, pdfRectStart+'%d %d %d %d'+pdfRectEnd, [TPDFbasevar(v[0]).asInt,
                                                                 TPDFbasevar(v[1]).asInt,
                                                                 TPDFbasevar(v[2]).asInt,
                                                                 TPDFbasevar(v[3]).asInt] );
end;
//*********************************************** TPDFrect1

//*********************************************** TPDFmatrix
constructor TPDFmatrix.Create;
begin
 inherited Create;
 mpdftype := mpdfMatrix;
 a := 1; b := 0; // 0
 c := 0; d := 1; // 0
 e := 0; f := 0; // 1
end;

constructor TPDFmatrix.Create( alfa : PDFreal );
var se,ce : extended;
begin
 Create;
 sincos( DegToRad( alfa ), se, ce );
 a := ce;  b := se;
 c := -se; d := ce;
end;

constructor TPDFmatrix.Create( vx,vy : PDFreal; matrixtype : TPDFmatrixtype );
var se,ce : extended;
begin
 Create;
  case matrixtype of
   mtTranslate : begin
                  e := vx;
                  f := vy;
                 end;
   mtScale : begin
              a := vx;
              d := vy;
             end;
   mtRotate : begin
                sincos( DegToRad(vx), se, ce );
                a := se;  c := -ce;
                sincos( DegToRad(vy), se, ce );
                b := se;  d := ce;
              end;
  end;
end;

constructor TPDFmatrix.Create( a,b,c,d,e,f : PDFreal );
begin
 Create;
 self.a := a; self.b := b;
 self.c := c; self.d := d;
 self.e := e; self.f := f;
end;                      

function TPDFmatrix.Clone : TPDFvariable;
begin
 result := TPDFmatrix.Create( a,b,c,d,e,f );
end;

procedure TPDFmatrix.Multi( matrix : TPDFmatrix );
var tmp : array [1..6] of PDFreal;
begin
 tmp[1] := a * matrix.a + b * matrix.c;             //a
 tmp[2] := a * matrix.b + b * matrix.d;             //b
 tmp[3] := c * matrix.a + d * matrix.c;             //c
 tmp[4] := c * matrix.b + d * matrix.d;             //d
 tmp[5] := e * matrix.a + f * matrix.c + matrix.e;  //e
 tmp[6] := e * matrix.b + f * matrix.d + matrix.f;  //f
 matrix.Destroy;
 a := tmp[1]; b := tmp[2];
 c := tmp[3]; d := tmp[4];
 e := tmp[5]; f := tmp[6];
end;

procedure TPDFmatrix.make( a,b,c,d,e,f : PDFreal );
begin
 self.a := a; self.b := b;
 self.c := c; self.d := d;
 self.e := e; self.f := f;
end;

procedure TPDFmatrix.loadIdentity;
begin
 a := 1; b := 0; // 0
 c := 0; d := 1; // 0
 e := 0; f := 0; // 1
end;
//*********************************************** TPDFmatrix

{****************************************************** TPDFdictionary ***********}
constructor TPDFdictionary.Create;
begin
 inherited;
 mpdftype := mpdfDictionary;
 ecount := 0;
 SetLength( entries, ecount );
end;

function TPDFdictionary.entryPtr( ename : String ) : PPDFvariable;
var p,last : ^TPDFdicentry;
begin
 result := nil;
  if ecount=0 then exit;
 p := @entries[0];
 last := @entries[ ecount-1 ];
  repeat
    if p^.Name = ename then
     begin
      result := @p^.Value;
      exit;
     end;
   inc(p);
  until Longint(Pointer(p)) > Longint(Pointer(last));
end;

procedure TPDFdictionary.deleteEntry( Entry : TPDFvariable );
var s,p,last : ^TPDFdicentry;
begin
 last := @entries[ecount-1];
 s := @entries[0];
  repeat
          if s^.Value = Entry then
          begin
            FreeAndNil( s^.Value );
            p := s; inc(p);
             repeat
              s^ := p^;
              Inc(p); Inc(s);
             until s=@entries[ ecount-1 ];
           Dec(ecount);
           SetLength(entries,ecount);
           break;
          end;
   inc( s );
  until Longint(Pointer(s)) > Longint(Pointer(last));
end;

procedure TPDFdictionary.deleteEntry( Name : String );
var s,p,last : ^TPDFdicentry;
begin
  if ecount=0 then exit;
   if ecount=1 then
    begin
      entries[0].Value.Destroy;
      SetLength(entries,0);
      ecount := 0;
      exit;
    end;
 last := @entries[ecount-1];
 s := @entries[0];
  repeat
          if s^.Name = Name then
          begin
            s^.Value.Destroy;
            p := s; inc(p);
             while s<>last do
              begin
                s^ := p^;
                Inc(p); Inc(s);
              end;
           Dec(ecount);
           SetLength(entries,ecount);
           break;
          end;
   inc( s );
  until Longint(Pointer(s)) > Longint(Pointer(last));
end;

function TPDFdictionary.exchangeEntry( ename : string; value : TPDFvariable ) : TPDFvariable;
var s,p,last : ^TPDFdicentry;
begin
 result := nil;
 last := @entries[ecount-1];
 s := @entries[0];
  repeat
          if s^.Name = ename then
          begin
            result := s^.Value;
            s^.Value := value;
            break;
          end;
   inc( s );
  until Longint(Pointer(s)) > Longint(Pointer(last));
end;

procedure TPDFdictionary.addEntry( ename : string; const evalue : TPDFvariable; onecheck : boolean );
//onecheck -> check (or not) if entry exists
var
 addnew : boolean;
 e,p,last : ^TPDFdicentry;
begin
 addnew := true;

  if onecheck then
   if ecount>0 then
    begin
       p := @entries[0];
       last := @entries[ ecount-1 ];
        repeat
          if p^.Name = ename then
           begin
             FreeAndNil( p^.Value );
             e := p;
             addnew := false;
             break;
           end;
         inc(p);
        until Longint(Pointer(p)) > Longint(Pointer(last));
    end;

     if addnew then
      begin
       inc( ecount );
       SetLength( entries, ecount );
       e := @entries[ ecount-1 ];
      end;

 e^.Name := ename;
 e^.Value := evalue;
end;

procedure TPDFdictionary.addEntry( ename, evalue : string );
begin
 addEntry( ename, TPDFbasevar.Create(evalue) );
end;

procedure TPDFdictionary.addEntry( ename : string; const evalue : PDFint  );
begin
 addEntry( ename, TPDFbasevar.Create(evalue) );
end;

procedure TPDFdictionary.addEntry( ename : string; const evalue : PDFreal );
begin
 addEntry( ename, TPDFbasevar.Create(evalue) );
end;

procedure TPDFdictionary.addEntry( ename : string; const evalue : PDFbool );
begin
 addEntry( ename, TPDFbasevar.Create(evalue) );
end;

function TPDFdictionary.clearEntry( ename : string ) : TPDFvariable;
var s,p,last : ^TPDFdicentry;
begin
 result := nil;
 last := @entries[ecount-1];
 s := @entries[0];
  repeat
          if s^.Name = ename then
          begin
            result := s^.Value;
            s^.Value := nil;
            break;
          end;
   inc( s );
  until Longint(Pointer(s)) > Longint(Pointer(last));
end;

function TPDFdictionary.clearEntry( pos : PDFint; var ename : string ) : TPDFvariable;
begin
 result := entries[pos].Value;
 ename := entries[pos].Name;
 entries[pos].Value := nil;
end;

procedure TPDFdictionary.setValue( Name : string; obj : TPDFvariable);
var p,last : ^TPDFdicentry;
begin
  if (ecount=0)or(obj=nil) then exit;
 p := @entries[0];
 last := @entries[ ecount-1 ];
  repeat
    if p^.Name = Name then
     begin
       if p^.Value<>nil then FreeAndNil( p^.Value );
      p^.Value := obj;
      exit;
     end;
   inc(p);
  until Longint(Pointer(p)) > Longint(Pointer(last));
 addEntry(Name,obj);
end;

procedure TPDFdictionary.setVariantValue( Name : string; val : TPDFvariant);
var p,last : ^TPDFdicentry;
begin
  if ecount=0 then exit;
 p := @entries[0];
 last := @entries[ ecount-1 ];
  repeat
    if p^.Name = Name then
     begin
       case val.i of
         0 : TPDFbasevar( p^.Value ).asBool   := val.Bool;
         1 : TPDFbasevar( p^.Value ).asInt    := val.Int;
         2 : TPDFbasevar( p^.Value ).asFloat  := val.Float;
         3 : TPDFbasevar( p^.Value ).asString := val.Str^;
       end;
      exit;
     end;
   inc(p);
  until Longint(Pointer(p)) > Longint(Pointer(last));
 {$IFNDEF USE_BORLAND_VARIANT}
 addEntry(Name,TPDFbasevar.Create( val ));
 {$ELSE}
   case Variants.VarType( val ) of
   varSmallint,
   varInteger         : addEntry(Name,TPDFbasevar.Create( PDFint(val) ));
   varSingle,
   varDouble          : addEntry(Name,TPDFbasevar.Create( PDFreal(val) ));
   varString          : addEntry(Name,TPDFbasevar.Create( string(val) ));
   varBoolean         : addEntry(Name,TPDFbasevar.Create( PDFbool(val) ));
  end;
 {$ENDIF}
end;

procedure TPDFdictionary.setInt( Name : string; obj : PDFint);
var v : TPDFvariant;
begin
 v.Int := obj;
 v.i := 1;
 setVariantValue( Name, v );
end;

procedure TPDFdictionary.setReal( Name : string; obj : PDFreal);
var v : TPDFvariant;
begin
 v.Float := obj;
  v.i := 2;
 setVariantValue( Name, v );
end;

procedure TPDFdictionary.setString( Name : string; obj : string);
var v : TPDFvariant;
begin
 {$IFNDEF USE_BORLAND_VARIANT}
//  v.Str := StrNew( PChar(obj) );
  v.i := 3;
  v.Str := new(PString);
  SetLength( v.Str^, length(obj) );
  v.Str^ := obj;
 {$ELSE}
  v := obj;
 {$ENDIF}
 setVariantValue( Name, v );
 SetLength( v.Str^, 0 );
 Dispose( v.Str );
end;

procedure TPDFdictionary.setBool( Name : string; obj : PDFbool);
var v : TPDFvariant;
begin
 v.Bool := obj;
 v.i := 0;
 setVariantValue( Name, v );
end;

procedure TPDFdictionary.setArray( Name : string; obj : TPDFarray);
begin
 setValue( Name, obj as TPDFvariable );
end;

procedure TPDFdictionary.setObjref( Name : string; obj : TPDFobjref);
begin
 setValue( Name, obj as TPDFvariable );
end;

function TPDFdictionary.getValueByName( Name : String ) : TPDFvariable;
var p,last : ^TPDFdicentry;
begin
  if ecount=0 then exit;
 result := nil;
 p := @entries[0];
 last := @entries[ ecount-1 ];
  repeat
    if p^.Name = Name then
     begin
      result := p^.value;
      break;
     end;
   inc(p);
  until Longint(Pointer(p)) > Longint(Pointer(last));
end;

function TPDFdictionary.getValueAsString( Name : String ) : string;
var p : TPDFbasevar;
begin
 result := '';
 p := getValueByName( Name ) as TPDFbasevar;
  if p<>nil then result := p.asString;
end;

function TPDFdictionary.getValueAsInt( Name : String ) : PDFInt;
var p : TPDFbasevar;
begin
 result := 0;
 p := getValueByName( Name ) as TPDFbasevar;
  if p<>nil then result := p.asInt;
end;

function TPDFdictionary.getValueAsReal( Name : String ) : PDFreal;
var p : TPDFbasevar;
begin
 result := 0.0;
 p := getValueByName( Name ) as TPDFbasevar;
  if p<>nil then result := p.asFloat;
end;

function TPDFdictionary.getValueAsBool( Name : String ) : PDFbool;
var p : TPDFbasevar;
begin
 result := false;
 p := getValueByName( Name ) as TPDFbasevar;
  if p<>nil then result := p.asBool;
end;

function TPDFdictionary.getValueAsArray( Name : String ) : TPDFarray;
var p : TPDFvariable;
begin
 result := nil;
 p := getValueByName( Name );
  if p<>nil then result := TPDFarray( p );
end;

function TPDFdictionary.getValueAsObjref( Name : String ) : TPDFobjref;
var p : TPDFvariable;
begin
 result := nil;
 p := getValueByName( Name );
  if p<>nil then result := TPDFobjref( p );
end;

function TPDFdictionary.Clone : TPDFvariable;
var pd : TPDFdictionary;
    v  : TPDFvariable;
    i  : PDFuint;
begin
 pd := TPDFdictionary.Create;
 i  := 0;
  while i<ecount do
   begin
    pd.addEntry( entries[i].Name, entries[i].Value.Clone );
    Inc(i);
   end;
 result := pd;
end;

function TPDFdictionary.isEmpty : boolean;
begin
 result := (ecount = 0);
end;

procedure TPDFDictionary.CopyTo( var d : TPDFdictionary );
var p,last : ^TPDFdicentry;
begin
  if ecount=0 then exit;
 p := @entries[0];
 last := @entries[ ecount-1 ];
  repeat
   d.addEntry( p^.Name, p^.Value.Clone );
   inc(p);
  until Longint(Pointer(p)) > Longint(Pointer(last));
end;

function TPDFdictionary.EntryArray( pos : PDFuint ) : TPDFvariable;
begin
 result := nil;
  if (pos>=ecount) or (ecount=0) then exit;
 result := entries[ pos ].Value;
end;

procedure TPDFdictionary.print( stream : TStream );
var p,last : ^TPDFdicentry;
begin
  if ecount=0 then exit;
 PDFwritestring(stream,pdfDictStart);
 p := @entries[0];
 last := @entries[ ecount-1 ];
  repeat
    if p^.Value<>nil then
     if p^.Value.isEmpty = false then
       begin
        PDFwritestring( stream, '/%s ', [p^.Name] );
        p^.value.print( stream );
        PDFwritestring( stream, pdfEol );
       end;
   inc(p);
  until Longint(Pointer(p)) > Longint(Pointer(last));
 PDFwritestring(stream,pdfDictEnd);
end;

destructor TPDFdictionary.Destroy;
var i : PDFint;
begin
  for i:=0 to ecount-1 do
   if entries[i].Value<>nil then
    FreeAndNil( entries[i].Value );
//    entries[i].Value.destroy;
 SetLength( entries, 0 );
 inherited;
end;
{****************************************************** TPDFdictionary ***********}

{****************************************************** TPDFobject ***********}
constructor TPDFobject.Create;
begin
 inherited;
 mpdftype := mpdfObject;
// objd := TPDFdictionary.Create;
 objd := self as TPDFdictionary;
 objid := 0;
 objpos := 0;
end;

constructor TPDFobject.Create( pdfvar : TPDFvariable );
begin
 inherited Create;
 objd := self as TPDFdictionary;
  if not(pdfvar is TPDFobject) then objd := pdfvar;
 objid := 0;
 objpos := 0;
end;

procedure TPDFobject.setObjectId( onum, gnum : PDFuint );
begin
 objid := ( gnum shl 16 ) or onum;
end;

function TPDFobject.isEmpty : boolean;
begin
// result := (self.objd = nil);
 result := false;
end;

function TPDFobject.Clone : TPDFvariable;
begin
 result := TPDFobject.Create( objd.Clone );
end;

function TPDFobject.getObjectNum : PDFuint;
begin
 result := objid;
end;

function TPDFobject.getGenerateNum : PDFuint;
begin
 result := objid shr 16;
end;

{procedure TPDFobject.SaveToStream( stream : TStream);
procedure TPDFobject.SaveToStream( stream : TStream);
begin
 objpos := stream.Position;
 PDFwritestring( stream, pdfObjStart, [ getObjectNum, getGenerateNum ] );
  if objd<>nil then objd.print( stream );
 PDFwritestring( stream, pdfObjEnd );
end;}

procedure TPDFobject.setVariable( objv : TPDFvariable );
begin
   if (objd<>nil)and(objv<>nil) then
       FreeAndNil( objd );
 objd := objv;
end;

function TPDFobject.getVariable : TPDFvariable;
begin
 result := objd;
end;

function TPDFobject.clearVariable : TPDFvariable;
begin
 result := objd;
 objd := nil;
end;

function TPDFobject.getDictionary : TPDFdictionary;
begin
 result := nil;
//  if objd <> nil then
//   if objd is TPDFdictionary then
//    result := objd as TPDFdictionary;
 result := self as TPDFdictionary;
end;

procedure TPDFobject.SaveToStream( stream : TStream );
begin
 objpos := stream.Position;
 PDFwritestring( stream, pdfObjStart, [ getObjectNum, getGenerateNum ] );
  inherited print( stream );
//  if objd<>nil then objd.print( stream );
 PDFwritestring( stream, pdfObjEnd );
end;

destructor TPDFobject.Destroy;
begin
//  if objd<>nil then
//   objd.Destroy;
 inherited;
end;
{****************************************************** TPDFobject ***********}

{****************************************************** TPDFobjref ***********}
constructor TPDFobjref.Create;
begin
 inherited;
 mpdftype := mpdfObjref;
 v := nil;
end;

constructor TPDFobjref.Create( obj : TPDFobject );
begin
 inherited Create;
 mpdftype := mpdfObjref;
 v := nil;
   if obj<>nil then v := obj;
end;

function TPDFobjref.isEmpty : boolean;
begin
 result := (v=nil);
  if result=false then result := result or ( v.isEmpty );
end;

function TPDFobjref.Clone : TPDFvariable;
begin
 result := TPDFobjref.Create( v );
end;

procedure TPDFobjref.print( stream : TStream );
begin
// if v<>nil then
  PDFwritestring( stream, pdfObjRef, [ TPDFobject(v).getObjectNum, TPDFobject(v).getGenerateNum ] );
end;

destructor TPDFobjref.Destroy;
begin
 inherited;
end;
{****************************************************** TPDFobjref ***********}

{****************************************************** TPDFstream ***********}
constructor TPDFstream.Create;
begin
 inherited Create;
 mpdftype := mpdfStream;
 stream := TStringStream.Create('');
 filcount := 0;
  with Dictionary do
   begin
    addEntry('Length',0);
    addEntry('DecodeParams');
    addEntry('Filter',TPDFarray.Create(true));
   end;
end;

function TPDFstream.isEmpty : boolean;
begin
 result := ( stream.Size = 0 );
end;

function TPDFstream.Clone : TPDFvariable;
var ps : TPDFstream;
begin
 ps := TPDFstream.Create( objd.Clone );
 ps.mpdftype := mpdfStream;
 ps.CopyFrom( self, 0 );
 result := ps;
end;

procedure TPDFstream.addFilter( f : TPDFfilter );
begin
 Inc( filcount );
 SetLength( filters, filcount );
 filters[ filcount-1 ] := f;
// Dictionary.getValueAsArray('Filter').push( TPDFbasevar.Create( PDFFilterName[f], stName ) );
 Dictionary.getValueAsArray('Filter').shift( TPDFbasevar.Create( PDFFilterName[f], vtName ) );
end;

procedure TPDFstream.Compress;
var tmpStream : TStringStream;
    f_pos : PDFint;
    s : string;
    buffer: Pointer;
    ss : PDFint;
begin
  if filcount>0 then
   begin
     tmpStream := TStringStream.Create('');
     f_pos := filcount;
      while f_pos > 0 do
       begin
        dec(f_pos);
        tmpStream.Size := 0;
//        tmpStream.WriteString( Compress( self.stream, TPDFfilter( filters[f_pos] ).Filter ) );
//        tmpStream.WriteString( ZCompressStr( self.stream.DataString ) );

//Decode( inbuf : PChar; insize : PDFint; out outbuf : PChar; out outSize : PDFint );
        s := '';
        
        Decode( Pchar(self.stream.DataString), self.stream.size, buffer, ss );

        SetLength(s,ss);
        Move(buffer^,s[1],ss);
        TmpStream.WriteString( s );
        FreeMem( buffer );

        self.stream.Size := 0;
        self.stream.WriteString( tmpStream.DataString )
       end;
      tmpStream.Destroy;
   end;
end;

procedure TPDFstream.CopyFrom( const Src : TPDFstream; Count : PDFlong );
var i : PDFuint;
    filters : TPDFarray;
    fname : string;
    s : string;
    ss : TStringStream;
begin
   filters := src.Dictionary.EntryAsArray['Filter'];
    if filters<>nil then
 (*    begin
       // if Dictionary.EntryAsArray['Filter'].Count=0 then
         // Dictionary.getValueAsArray('Filter').push( TPDFbasevar.Create( 'FlateDecode', vtName ) );
      ss := TStringStream.Create('');
      ss.CopyFrom( src.stream, Count );
      SetLength(s, Src.stream.Size );
      s := ss.DataString;
//      i := src.stream.Read( s[1], src.stream.size );
//      s := src.stream.ReadString( src.stream.size );
                    s := ZDecompressStr(s);
//                    TPDFstream( xref[i] ).Dictionary.deleteEntry('Filter');
      self.stream.WriteString( s );
//      self.stream.CopyFrom( Src.stream, Count );
      ss.Destroy;
      SetLength(s,0);  
    end else
             self.stream.CopyFrom( Src.stream, Count );*)
     case filters.getType of
      mpdfVariable,
      mpdfBasevar : self.Dictionary.getValueAsArray('Filter').push( TPDFbasevar.Create( TPDFbasevar(filters).asString, vtName ) );
      mpdfArray   :  for i:=0 to filters.Count-1 do
                      begin
                       fname := TPDFbasevar(filters[i]).asString;
                       self.Dictionary.getValueAsArray('Filter').push( TPDFbasevar.Create( fname, vtName ) );
                      end;
     end;
  self.stream.CopyFrom( Src.stream, Count );
//                    s := ZDecompressStr(s);
//                    TPDFstream( xref[i] ).Dictionary.deleteEntry('Filter');

end;

//procedure TPDFstream.SaveToStream( stream : TStream );
procedure TPDFstream.SaveToStream( stream : TStream );
begin
  if TPDFbasevar( Dictionary.Entry['Length'] ).vartype = vtInt then 
   Dictionary.EntryAsInt['Length'] := self.stream.Size;

   objpos := stream.Position;
   PDFwritestring( stream, pdfObjStart, [ getObjectNum, getGenerateNum ] );
    //if objd<>nil then
//    objd.print( stream );
//   (self as TPDFdictionary).print( stream );
   inherited print(stream);
   PDFwritestring( stream, pdfStreamStart );
   stream.CopyFrom( TStream( self.stream ), 0 );
   PDFwritestring( stream, pdfStreamEnd+pdfObjEnd );
end;

destructor TPDFstream.Destroy;
begin
 stream.Destroy;
 inherited;
end;

{****************************************************** TPDFstream ***********}

{****************************************************** TPDFcontainer ********}
constructor TPDFcontainer.Create;
begin
 inherited Create;
 SelItem := nil;
end;

constructor TPDFcontainer.Create( v : array of TPDFvariable );
begin
 inherited Create( v );
 SelItem := nil;
end;

function TPDFcontainer.select( i : PDFint ) : PDFbool;
begin
 result := false;
  if i >= vcount then exit;
 SelItem := v[i];
 result := True;
end;
{****************************************************** TPDFcontainer ********}

{****************************************************** TPDFtree ********}
constructor TPDFtree.Create( Parent : TPDFtree );
begin
 inherited Create();
 Dictionary.addEntry('Kids',TPDFarray.Create);
  if Parent<>nil then
   begin
    mpdftype := mpdfTree;
    Dictionary.addEntry('Limits',TPDFarray.Create);
    Dictionary.addEntry('Entries',TPDFarray.Create);
    entries := Dictionary.entryPtr('Entries');
    Parent.addChild( self );
   end else mpdftype := mpdfTreeRoot;
end;

destructor TPDFtree.Destroy;
begin
 inherited;
end;
{****************************************************** TPDFtree ********}
{****************************************************** TPDFnametree ********}
procedure TPDFnametree.print( stream : TStream );
begin
//wydrukuj zmieniajac nazwe entries
end;
{****************************************************** TPDFnametree ********}
{****************************************************** TPDFnumtree ********}
procedure TPDFnumtree.print( stream : TStream );
begin
//wydrukuj zmieniajac nazwe entries
end;
{****************************************************** TPDFnumtree ********}


end.

