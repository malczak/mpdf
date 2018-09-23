(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                                 mpdfdoc.pas
********************************************************
 unit description :         objects defined if pdf files
                         needed to create basic pdf file
********************************************************
 bugs :                                              ---
********************************************************
 other :
        12.IV.2005 -  resources are needed only if one
              of this occures in document : image, text
         2.IV.2005  - first root data types
********************************************************)
unit mpdfdoc;

{$DEFINE USE_SIZE_OPTIMALIZATION}

interface
uses sysutils, classes,
     mpdfbase, mpdfvars, mpdfgraphics, mpdffilters, mpdfencrypt,mpdfxobj,mpdffonts;

type

TPDFinfo        = class ( TPDFobject )
                  private
                   procedure setAuthor( v : string );
                   procedure setTitle( v : string );
                   procedure setSubject( v : string );
                   procedure setKeywords( v : string );
                   procedure setCreator( v : string );
                   procedure setModDate( v : string );
                   function getAuthor : string;
                   function getTitle : string;
                   function getSubject : string;
                   function getKeywords : string;
                   function getCreator : string;
                   function getModDate : string;
                  public
                    property Author : string read getAuthor write setAuthor;
                    property Title : string read getTitle write setTitle;
                    property Subject : string read getSubject write setSubject;
                    property Keywords : string read getKeywords write setKeywords;
                    property Creator : string read getCreator write setCreator;
                    property ModDate : string read getModDate write setModDate;
                   constructor Create;
                  end;

TPDFxreftable   = class ( TPDFobject )  //---> plum trzeba dorobic komunikacje obiektu z tym czyms zeby      ... co ?!
                  private
                    xrefsaved,
                    xrefcount    : PDFuint;
                    xref         : TPDFobjarray;
                    function getObject( id : PDFuint ) : TPDFobject;
                    procedure setObject( id : PDFuint; obj : TPDFobject );
                  public
                    //procedure add ( obj : PDFulong); -> add objects position :D
                    property Count : PDFuint read xrefcount;//>do TPDFfile
                    property savedCount : PDFuint read xrefsaved;//>do TPDFfile
                    property Item[id : PDFUint]:TPDFobject read getObject write setObject; default;//>do TPDFfile
                    procedure setLength( len : PDFuint );
                    procedure Push( obj : TPDFobject );//>do TPDFfile
                    procedure Exchange( todel, toset : TPDFobject);//>do TPDFfile
                    procedure Delete( obj : TPDFobject ); overload;//>do TPDFfile
                    procedure Delete( objpos : PDFuint ); overload;//>do TPDFfile
                    function DeleteByPtr( obj : TPDFobject ) : integer;
                    procedure SaveObjects( stream : TStream; encrypt : TPDFencryption = nil );//>do TPDFfile
                    procedure SaveToStream( stream : TStream ); override;
                    constructor Create;
                    destructor Destroy;override;
                  end;

TPDFtrailer     = class ( TPDFobject )
//TPDFtrailer     = class ( TPDFdictionary )
                  public
                    xrefpos  : PDFulong;
                    procedure SaveToStream( stream : TStream ); override;
                    constructor Create;
                    destructor Destroy; override;
                  end;


TPDFresources    = class ( TPDFobject )
                   private
                        fonts,
                        images : PDFuint;
                   public
                        procedure addProcSet( t : TPDFprocedure );
                        function isEmpty : PDFbool; override;
                        procedure addResource( res : TPDFobject; dest : TPDFrestype );
                        function getResource( from : TPDFrestype; var count : PDFint ) : TPDFobjarray;
                        function copyFrom( from : TPDFvariable ) : PDFbool; //--> while using this function resource should be raw object

                        procedure print( stream : TStream ); override;
                        procedure SaveToStream( stream : TStream ); override;
                        constructor Create; overload;
                        constructor Create( v : TPDFvariable ); overload;
                        destructor Destroy; override;
                   end;

TPDFpages       = class ( TPDFobject )
                    constructor Create( owner : TPDFobject = nil );
                    procedure SaveToStream( s : TStream ); override;
                    destructor Destroy; override;
                  end;

TPDFpage        = class ( TPDFobject )
                  private
                    font        : TPDFfontid;
                    canvas      : TPDFcanvas; //page can have ONLY one canvas but (!) it can use other canvases as well, canvas is created internally
                   public
                    PageNo      : PDFuint;

                //...
                    function Clone : TPDFvariable; override;
                    procedure SaveToStream( stream : TStream); override;
                    procedure setSize( width, height : PDFuint );
                    function getWidth : PDFuint;
                    function getHeight : PDFuint;
                    procedure setResources( res : TPDFvariable );
                    function getResources : TPDFvariable;
                    function setFont( f : TPDFfontid ) : TPDFfontid;
                    procedure setCanvas( canvas : TPDFcanvas);                  //sets main canvas of page
                    procedure assignCanvas( canvas : TPDFcanvas );              //sets canvas ti be used by page
                    function getCanvas : TPDFcanvas;                            //returns main canvas of page

                //more procedures to handle text, images, graphics :) without need to call main canvas (but not all canvas features)
                //only text, textfields, pictures, header and footer


                    constructor Create( obj : TPDFvariable ); overload;
                    constructor Create( pages : TPDFpages = nil );  overload;
                    destructor Destroy; override;
                   end;
TPDFpagearray   = array of TPDFpage;

TPDFcatalog     = class( TPDFobject )
                  public
                   pagelayout      : TPDFpagelayout;
                   pagemode        : TPDFpagemode;
                   outlines        : TPDFobject;
                   constructor Create;
                   destructor Destroy; override;
                  end;


implementation

{****************************************************** TPDFinfo ***********}
procedure TPDFinfo.setAuthor( v : string );
begin
 Dictionary.EntryAsString['Author'] := v;
end;

procedure TPDFinfo.setTitle( v : string );
begin
 Dictionary.EntryAsString['Title'] := v;
end;

procedure TPDFinfo.setSubject( v : string );
begin
 Dictionary.EntryAsString['Subject'] := v;
end;

procedure TPDFinfo.setKeywords( v : string );
begin
 Dictionary.EntryAsString['Keywords'] := v;
end;

procedure TPDFinfo.setCreator( v : string );
begin
 Dictionary.EntryAsString['Creator'] := v;
end;

procedure TPDFinfo.setModDate( v : string );
begin
 Dictionary.EntryAsString['ModDate'] := v;
end;

function TPDFinfo.getAuthor : string;
begin
 result :=  Dictionary.EntryAsString['Author'];
end;

function TPDFinfo.getTitle : string;
begin
 result :=  Dictionary.EntryAsString['Title'];
end;

function TPDFinfo.getSubject : string;
begin
 result :=  Dictionary.EntryAsString['Subject'];
end;

function TPDFinfo.getKeywords : string;
begin
 result :=  Dictionary.EntryAsString['Keywords'];
end;

function TPDFinfo.getCreator : string;
begin
 result :=  Dictionary.EntryAsString['Creator'];
end;

function TPDFinfo.getModDate : string;
begin
 result :=  Dictionary.EntryAsString['ModDate'];
end;

constructor TPDFinfo.Create;
begin
 inherited;
 mpdftype := mpdfInfo;
 with Dictionary do
  begin
         addEntry('Author','Mateusz Ma³czak');
         addEntry('Producer','MPDF for Delphi');
         addEntry('CreationDate',PDFtoday);
         addEntry('Title','');
         addEntry('Subject','');
         addEntry('Keywords','');
         addEntry('Creator','');
         addEntry('ModDate','');
  end;
end;
{****************************************************** TPDFinfo ***********}

{****************************************************** TPDFxreftable ***********}
constructor TPDFxreftable.Create;
begin
 inherited;
 xrefcount := 0;
 System.setLength( xref, xrefcount );
end;

function TPDFxreftable.getObject( id : PDFuint ) : TPDFobject;
begin
 result := nil;
  if xrefcount-id > 0 then
    result := TPDFobject(xref[ id ]);
end;

procedure TPDFxreftable.setObject( id : PDFuint; obj : TPDFobject );
begin
 if id > xrefcount then
  push( obj ) else
    begin
     FreeAndNil( xref[ id ] );
     xref[ id ] := obj;
//     obj.setObjectId( id, 0 );
    end;
end;

procedure TPDFxreftable.SaveObjects( stream : TStream; encrypt : TPDFencryption );
var i : PDFuint;
    pp,f, p, l  : ^TPDFobject;
begin
  pp := @xref[ 0 ];
  l := @xref[ xrefcount-1 ];
        //save all objects
   xrefsaved := 0;
   p := pp;
   f := pp;

    //rebuild and renumerate
        repeat
          if p^<>nil then
           if p^.isEmpty = false then
            begin
             inc( xrefsaved );
             p^.setObjectId( xrefsaved, 0 );
              if f<>p then
               begin
                f^ := p^;
                p^ := nil;
               end;
             Inc( f );
            end;// else FreeAndNil( p^ ); // ??
         Inc( p );
        until Longint(Pointer(p))>Longint(Pointer(l));

   p := pp;

        repeat
//         if p^<>nil then
//         if p^.isEmpty = false then
          begin
//           inc( xrefsaved );
//           p^.setObjectId( xrefsaved, 0 );
              if p^ is TPDFstream then TPDFstream( p^ ).Compress;
               if encrypt<>nil then
                 if encrypt<>p^ then
                   encrypt.Make( p^ );
//             p^.SaveToStream( stream );
               p^.SaveToStream( stream );

          end;
         Inc( p );
//        until Longint(Pointer(p))>Longint(Pointer(l));
        until Longint(Pointer(p))>=Longint(Pointer(f));
end;

//procedure TPDFxreftable.SaveToStream( stream : TStream );
procedure TPDFxreftable.SaveToStream( stream : TStream );
var i : PDFuint;
    p, l  : ^TPDFobject;
begin
 //save xref tabale
 objpos := stream.Position;
 PDFwritestring( stream, pdfXref );
 PDFwritestring( stream, '%d %d'+pdfeol, [ 0 , xrefsaved+1 ] );
 PDFwritestring( stream, pdfXreffirst );
 i := 0;
 p := @xref[0];
// l := @xref[ xrefcount-1 ];
 l := @xref[ savedcount-1 ];
   repeat
//   if p^ <> nil then
      begin
//     if p^.getObjectNum > 0 then
//        if p^<>nil then
          PDFwritestring( stream, pdfXrefelem, [ p^.objpos, 0 ] );
      end;// else
         // PDFwritestring( stream, pdfXrefelemf, [ 0, xrefsaved ] );
    Inc( p );
   until Longint(Pointer(p))>Longint(Pointer(l));
 PDFwritestring( stream, pdfEol );
end;

procedure TPDFxreftable.Push( obj : TPDFobject );
begin
 inc( xrefcount );
 System.SetLength( xref,xrefcount );
 obj.setObjectId( xrefcount, 0 );
 xref[ xrefcount-1 ] := obj;
end;

procedure TPDFxreftable.Exchange( todel, toset : TPDFobject);
begin
 xref[ todel.getObjectNum-1 ] := toset;
 toset.setObjectId( todel.getObjectNum, todel.getGenerateNum );
end;

procedure TPDFxreftable.setLength( len : PDFuint );
begin
  if len < xrefcount then exit;
 xrefcount := len;
 System.SetLength( xref,len );
end;

procedure TPDFxreftable.Delete( obj : TPDFobject );
begin
 xref[ obj.getObjectNum-1 ] := nil;
end;

function TPDFxreftable.DeleteByPtr( obj : TPDFobject ) : integer;
var i : PDFuint;
begin
 for i:=0 to xrefcount-1 do
  if xref[i] = obj then
   begin
    xref[i] := nil;
    break;
   end;
end;

procedure TPDFxreftable.Delete( objpos : PDFuint );
begin
  if (objpos<0) or (objpos>=xrefcount) then exit;
 xref[ objpos ] := nil;
end;

destructor TPDFxreftable.Destroy;
begin
  while xrefcount>0 do
   begin
    dec( xrefcount );
     if xref[ xrefcount ] <> nil then 
      FreeAndNil( xref[ xrefcount ] );
//    xref[ xrefcount ].Destroy;
   end;
 System.SetLength( xref, 0 );
 inherited;
end;
{****************************************************** TPDFxreftable ***********}

{****************************************************** TPDFtrailer ***********}
constructor TPDFtrailer.Create;
begin
 inherited;
//   with Dictionary do
   begin
    addEntry('Size',0);
  //  addEntry('Prev',0);
    addEntry('Root',TPDFobjref.Create);
    addEntry('Info',TPDFobjref.Create);
 //   addEntry('ID', TPDFarray.Create );
   end;
end;

//procedure TPDFtrailer.SaveToStream( stream : TStream );
procedure TPDFtrailer.SaveToStream( stream : TStream );
begin
 PDFwritestring( stream, pdfTrailerStart );
 inherited print( stream );
// objd.print( stream );
 PDFwritestring( stream, pdfTrailerEnd );
 PDFwritestring( stream, '%d'+pdfEol, [ xrefpos ] );
end;

destructor TPDFtrailer.Destroy;
begin
 inherited;
end;
{****************************************************** TPDFtrailer ***********}

{****************************************************** TPDFresources ***********}
constructor TPDFresources.Create;
var i : PDFuchar;
begin
 inherited;
 mpdftype := mpdfResources;
 images := 0;
 fonts := 0;
  with Dictionary do
   begin
    addEntry('ProcSet', TPDFarray.Create( [TPDFbasevar.Create('PDF',vtName)] ) );
     for i:=1 to 7 do
      addEntry( PDFresourcedics[i] ,TPDFdictionary.Create);
   end;
end;

constructor TPDFresources.Create( v : TPDFvariable );
var i : PDFushort;
begin
 inherited Create( v );
     for i:=1 to 7 do
      if Dictionary[ PDFresourcedics[i] ]=nil then
        Dictionary.addEntry( PDFresourcedics[i] ,TPDFdictionary.Create, true);
 mpdftype := mpdfResources;
 images := 0;
 fonts := 0;
end;

procedure TPDFresources.print( stream : TStream );
var d : TPDFdictionary;
    i : PDFuchar;
begin
 PDFwritestring( stream, pdfDictStart );
 PDFwritestring( stream, '/ProcSet ');
 Dictionary.EntryAsArray['ProcSet'].print( stream );
 PDFwritestring( stream, pdfEol );
  for i:=1 to 7 do
   begin
    d := Dictionary[ PDFresourcedics[i] ] as TPDFdictionary;
     if d.count>0 then
      begin
       PDFwritestring( stream, '/%s ', [ PDFresourcedics[i] ]);
       d.print( stream );
       PDFwritestring( stream, pdfEol );
      end;
   end;
 PDFwritestring( stream, pdfDictEnd );
end;

function TPDFresources.isEmpty : PDFbool;
begin
// result := (Dictionary.EntryAsArray['ProcSet'].count<=1);
 result := false;
end;

procedure TPDFresources.SaveToStream( stream : TStream );
begin
//  if Dictionary.EntryAsArray['ProcSet'].count>1 then
   begin
    objpos := stream.Position;
    PDFwritestring( stream, pdfObjStart, [ getObjectNum, getGenerateNum ] );
    print( stream );
    PDFwritestring( stream, pdfObjEnd );
   end;
end;

procedure TPDFresources.addResource( res : TPDFobject; dest : TPDFrestype );
begin
 case dest of
//  rtExtGState  : TPDFdictionary( Dictionary['ExtGState'] )...
//  rtColorSpace : TPDFdictionary( Dictionary['ColorSpace
//  rtPattern    : TPDFdictionary( Dictionary['Pattern
//  rtShading    : TPDFdictionary( Dictionary['Shading
  rtXObject    :  begin
                     if Dictionary['XObject']=nil then Dictionary.addEntry('XObject', TPDFdictionary.Create() );
                   TPDFimage(res).ID := TPDFdictionary( Dictionary['XObject'] ).Count+1;
                    case res.getType of
                     mpdfImage : begin
                                   case TPDFimage(res).imgtype of
                                    0 : addProcSet( pImageB );
                                    1 : addProcSet( pImageC );
                                    2 : addProcSet( pImageI );
                                   end;
                                  TPDFdictionary( Dictionary['XObject'] ).AddEntry( Format('Im%d',[ TPDFxobject(res).ID ]), TPDFobjref.Create( res ) );
                                 end;
                     mpdfForm  : TPDFdictionary( Dictionary['XObject'] ).AddEntry( Format('mtpl%d',[ TPDFxobject(res).ID ]), TPDFobjref.Create( res ) );
                     end;
                  end;
  rtFont       :  begin
                    addProcSet( pText );
                    TPDFdictionary( Dictionary['Font'] ).AddEntry( Format('F%d',[ TPDFfont(res).fid ]), TPDFobjref.Create( res ) );
                  end;
//  rtProperties : TPDFdictionary( Dictionary['Properties
 end;
end;

function TPDFresources.getResource( from : TPDFrestype; var count : PDFint ) : TPDFobjarray;
begin
end;

procedure TPDFresources.addProcSet( t : TPDFprocedure );
var a : TPDFarray;
    i : PDFlong;
begin
 a := Dictionary['ProcSet'] as TPDFarray;
 i := a.count-1;
  while i>=0 do
   if (a.item[i] as TPDFbasevar).asString=PDFprocsetnames[t] then break
       else dec(i);

 if i<0 then
  a.push( TPDFbasevar.Create(PDFprocsetnames[t],vtName) );
end;

function TPDFresources.copyFrom( from : TPDFvariable ) : PDFbool;
var i,j,k : PDFuint;
    v : TPDFvariable;
    sd,d : TPDFdictionary;
begin
 //copy all entries :) -> just copy dictionaries
{  with Dictionary do
   begin
    addEntry('ProcSet', TPDFarray.Create( [TPDFbasevar.Create('PDF',vtName)] ) );
     for i:=1 to 7 do
      addEntry( PDFresourcedics[i] ,TPDFdictionary.Create);
   end;
}
//resources moga byc zapisane w pdf'ie albo jako oddzielny obiekt albo jako dictionary zapisanyw miejscu gdzie jest on wykorzystywany :) ! sic
 case from.getType of
  mpdfDictionary : v := TPDFdictionary(from).EntryAsArray['ProcSet'];
  mpdfObject,
  mpdfResources  : v := TPDFobject(from).Dictionary.EntryAsArray['ProcSet'];
 end;
  with Dictionary.EntryAsArray['ProcSet'] do
   begin
    Clear;
     for i:=0 to TPDFarray(v).Count-1 do
      Push( TPDFbasevar.Create( TPDFbasevar( TPDFarray(v)[i] ).asString , vtName ) );
    end;

 // :) reszta
 case from.getType of
  mpdfDictionary : v := from;
  mpdfObject,
  mpdfResources  : v := TPDFobject(from).Dictionary;
 end;
  for i:=1 to 7 do                                          //po wszytkich dictionaries
   begin
    d := TPDFdictionary( Dictionary[ PDFresourcedics[i] ] );
    sd := TPDFdictionary( TPDFDictionary(v)[ PDFresourcedics[i] ] );
     if sd<>nil then 
      sd.CopyTo( d );
   end
end;

destructor TPDFresources.Destroy;
begin
 inherited;
end;
{****************************************************** TPDFresources ***********}


{****************************************************** TPDFpages ***********}
constructor TPDFpages.Create( owner : TPDFobject );
begin
 inherited Create;
  with Dictionary do
   begin
     addEntry('Type',TPDFbasevar.Create('Pages',vtName) );
      if owner<>nil then
       if owner is TPDFpages then addEntry('Parent',TPDFobjref.Create( owner ) );
     addEntry('Kids',TPDFarray.Create() );
     addEntry('Count',0);
   end;
end;

//procedure TPDFpages.SaveToStream( s : TStream );
procedure TPDFpages.SaveToStream( s : TStream );
var i : integer;
begin
 i:= 1;
// inherited SaveToStream( s );
 inherited;
end;

destructor TPDFpages.destroy;
begin
 inherited;
end;
{****************************************************** TPDFpages ***********}

{****************************************************** TPDFpage ***********}
constructor TPDFpage.Create( pages : TPDFpages = nil );
begin
 inherited Create;
 mpdftype := mpdfPage;
 canvas := TPDFcanvas.Create;
  with Dictionary do
   begin
    addEntry('Type',TPDFbasevar.Create('Page',vtName) );
    addEntry('Parent',TPDFobjref.Create( pages ) );
    addEntry('MediaBox',TPDFrect.Create );
(*    addEntry('MediaBox',TPDFarray.Create( [ TPDFbasevar.Create(0),
                                            TPDFbasevar.Create(0),
                                            TPDFbasevar.Create(0),
                                            TPDFbasevar.Create(0) ] )  ); *)
    addEntry('Contents', TPDFarray.Create );
   end;
end;

constructor TPDFpage.Create( obj : TPDFvariable  );
begin
 inherited Create( obj );
 mpdftype := mpdfPage;
 canvas := TPDFcanvas.Create;
end;

function TPDFpage.Clone : TPDFvariable;
var p : TPDFpage;
begin
 p := TPDFpage.Create( objd.Clone );
 result := p;
end;

//procedure TPDFpage.SaveToStream( stream : TStream);
procedure TPDFpage.SaveToStream( stream : TStream);
var a : TPDFarray;
{$IFDEF USE_SIZE_OPTIMALIZATION}
    rs,r : TPDFvariable;
    parent : TPDFpages;
{$ENDIF}
begin
  a := Dictionary.EntryAsArray['MediaBox'];
   if a.isEmpty then
    Dictionary.deleteEntry( 'MediaBox' );

{$IFDEF USE_SIZE_OPTIMALIZATION}
(*  parent := TPDFpages( TPDFobjref(Dictionary['Parent']).v );
  rs := Dictionary['MediaBox'];
  r := parent.Dictionary['MediaBox'];
   if (r<>nil)and(rs<>nil) then
    if TPDFrect(r).Equals( TPDFrect(rs) ) or TPDFrect(rs).Zerofill then
     Dictionary.deleteEntry( 'MediaBox' );
  rs := Dictionary['Rotate'];
  r := parent.Dictionary['Rotate'];
   if (r<>nil)and(rs<>nil) then
    if (TPDFbasevar(r).asInt=TPDFbasevar(rs).asInt) or (TPDFbasevar(rs).asInt=0) then
     Dictionary.deleteEntry('Rotate');
*)
//     Dictionary.deleteEntry('Rotate');
//     Dictionary.deleteEntry( 'MediaBox' );

{$ELSE}
  Dictionary.addEntry('MediaBox',mediabox);
   if rotate<>0 then Dictionary.AddEntry('Rotate',rotate);
{$ENDIF}
  //czy wogole ustawiono jakies wymiary ?! (bo mozna je przeciez dziedziczyc)

  //czy wykorzystano moja kanwe
//  if (parent<>nil)and(canvas.stream.Size>0) then
  if (canvas.ID<>0)and(canvas.stream.Size>0) then // taki warunek wystarczy  (jesli kanwa wybrana -> dodana o xref -> poniewaz zapis jest po reorganizaji to ID>=1
   Dictionary.EntryAsArray['Contents'].push( TPDFobjref.Create( canvas ) );
 inherited;
end;


procedure TPDFpage.setSize( width, height : PDFuint );
begin
 with Dictionary.EntryAsArray['MediaBox'] do
  begin
   TPDFbasevar( Item[0] ).asInt := 0;
   TPDFbasevar( Item[1] ).asInt := 0;
   TPDFbasevar( Item[2] ).asInt := width;
   TPDFbasevar( Item[3] ).asInt := height;
  end;
end;

function TPDFpage.getWidth : PDFuint;
var mb : TPDFarray;
begin
 mb := Dictionary.EntryAsArray['MediaBox']; // nie moze nie istniec
 result := TPDFbasevar(mb[2]).asInt-TPDFbasevar(mb[0]).asInt;
end;

function TPDFpage.getHeight : PDFuint;
var mb : TPDFarray;
begin
 mb := Dictionary.EntryAsArray['MediaBox']; // nie moze nie istniec
 result := TPDFbasevar(mb[3]).asInt-TPDFbasevar(mb[1]).asInt;
end;

procedure TPDFpage.setResources( res : TPDFvariable );
begin
 case res.getType of
  mpdfDictionary : Dictionary['Resources'] := res;
  mpdfObject,
  mpdfResources  : Dictionary.EntryAsObjref['Resources'] := TPDFObjref.Create( TPDFobject(res) );
 end;
end;

function TPDFpage.getResources : TPDFvariable;
var p : TPDFvariable;
begin
 result := nil;
  if getObject( Dictionary, 'Resources', p ) then result := p;
// p := Dictionary['Resources'];
//  if p<>nil then result := p as TPDFresources;
end;

function TPDFpage.setFont( f : TPDFfontid ) : TPDFfontid;
begin
 result := font;
 font := f;
end;

procedure TPDFpage.setCanvas( canvas : TPDFcanvas );
begin
  if canvas=nil then exit;
 self.canvas := canvas;
 Dictionary.EntryAsArray['Contents'].push( TPDFobjref.Create(canvas) );
// Dictionary.EntryAsObjref['Contents'] := TPDFobjref.Create(canvas);
end;

procedure TPDFpage.assignCanvas( canvas : TPDFcanvas );
var bv : TPDFvariable;
begin
//  if canvas.ID>0 then
 bv := Dictionary['Contents'];
 if not ( bv is TPDFarray ) then
  begin
   bv := TPDFbasevar( Dictionary.clearEntry('Contents') );
   Dictionary['Contents'] := TPDFarray.Create( [bv,TPDFobjref.Create(canvas)] );
  end else
       TPDFarray( bv ).push( TPDFobjref.Create(canvas) );
end;

function TPDFpage.getCanvas : TPDFcanvas;
begin
 canvas.setFont( font );
 result := canvas;
end;

destructor TPDFpage.Destroy;
begin
  if canvas.ID=0 then // to znaczy ze strona nie zostala dodana do zadnego pliku pdf
   canvas.Destroy;
 inherited;
end;
{****************************************************** TPDFpage ***********}

{****************************************************** TPDFcatalog ***********}
constructor TPDFcatalog.Create;
begin
 inherited;
 mpdftype := mpdfCatalog;
 pagelayout := plSinglePage;
 pagemode := pmUseNone;
 outlines := nil;
  with Dictionary do
   begin
    addEntry('Type', TPDFbasevar.Create('Catalog',vtName) );
    addEntry('Pages', TPDFobjref.Create() );
   end;
end;

destructor TPDFcatalog.Destroy;
begin
 inherited;
end;
{****************************************************** TPDFcatalog ***********}

end.



