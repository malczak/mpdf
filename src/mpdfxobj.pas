(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                                mpdfxobj.pas
********************************************************
 unit description :                          pdf XObject
********************************************************
 bugs :                                              ---
********************************************************
 other :                                             ---
        2.IV.2005 - first graphics objects (Chapter 4)
        2.VI.2005 - all rebuild ( pdf XObject images )
                    currently only *.jpg
 JPG/JPEG file description from :
 http://www.funducode.com/freec/Fileformats/jpegformat.htm
        4.VI.2005 - *.png files : without masks only in
                 device color space ( no color pallete )
 PNG sprecification : RFC 2048
********************************************************)
unit mpdfxobj;
//{$define HAS_JPEG}

interface
uses windows, graphics, sysutils, classes, {$IFDEF HAS_JPEG}jpeg, {$ENDIF} ExtCtrls, wmfemf,
     mpdfbase, mpdfvars;

type
 TPDFXobject = class( TPDFstream )
                ID : PDFuint;
                transform : TPDFmatrix;
                procedure loadIdentity;
                constructor Create; overload;
                destructor Destroy; override;
               end;

 TPDFxform = class( TPDFXobject )
             protected
               function CopyContents( cs : TPDFarray ) : PDFbool;
             public
               procedure FormPage( p : TPDFobject );
               constructor Create; overload;
               destructor Destroy; override;
             end;

 TPDFimage = class( TPDFXobject )
              imgtype   : PDFushort;  //0 - monochromatic, 1 - color, 2 - indexed, 3 - vector (wmf.emf) 'no longer supported'
              k         : real;
              property iid : PDFuint read ID write ID;
              constructor Create; overload;
              destructor Destroy; override;
             end;

 tRGB = record
          r,g,b : byte;
        end;

function loadJPG ( fname : string ): TPDFxobject;
function loadJPG2( fname : string ): TPDFxobject;
function loadPNG ( fname : string; pdf : TFileStream ): TPDFxobject;
function loadWMF ( fname : string ): TPDFxobject;

function loadBMP ( fname : string ): TPDFxobject;
function loadGIF ( fname : string ): TPDFxobject;

implementation
uses mpdfdoc, mpdfgraphics, mpdffile;

//*********************************************************************************  XObject
constructor TPDFxobject.Create;
begin
 inherited Create;
 transform := TPDFmatrix.Create;
 Dictionary.addEntry('Type',TPDFbasevar.Create('XObject',vtName));
 Dictionary.addEntry('Subtype',TPDFbasevar.Create('',vtName));
 mpdftype := mpdfXobject;
end;

procedure TPDFxobject.loadIdentity;
begin
 transform.make( Dictionary.EntryAsInt['Width'], 0, 0, Dictionary.EntryAsInt['Height'], 0, 0 );
end;

destructor TPDFxobject.Destroy;
begin
 transform.Destroy;
 inherited;
end;

//*********************************************************************************  Form

constructor TPDFxform.Create;
begin
 inherited Create;
 mpdftype := mpdfForm; // tymczasowo -> dorobic obiekt dla Form a tutaj wstawis mpdfXObject
 TPDFbasevar( Dictionary['Subtype'] ).asString := 'Form';
  with Dictionary do
   begin
    addEntry('FormType',TPDFbasevar.Create(1) );
    addEntry('BBox', TPDFrect.Create(0,0,1,1) );
    addEntry('Resources',TPDFresources.Create);
   end;
end;

function TPDFxform.CopyContents( cs : TPDFarray ) : PDFbool;
begin
(*
 1. for i:=0 to TPDFarray( c ).count-1 do
                     xform.CopyFrom( TPDFstream( TPDFobjref( TPDFarray( c )[i] ).v ), 0 );
 3. rozpakuyj,. skopjuj i spakuj 
 *)
end;


procedure TPDFxform.FormPage( p : TPDFobject );
var c : TPDFobjref; //canvas(y)
    r : TPDFvariable; //resources
    s : PDFbool;
begin
  if p.getType<>mpdfPage then exit;
 r := p.Dictionary['Resources'];
 c := p.Dictionary.EntryAsObjref['Contents'];
 s := false;
 //sprawdz jaki typ contents ma strona
  case c.v.GetType of
   mpdfArray    : //sprawa troszke trudniejsza :) bo najpierw trzeba sprawdzic jakie filtry sa wykorzystane w kanwach, wykorzystac mozna tylko te FlateDecode, rozpakowac -> zlaczyc :) i po sprawie
                 begin
                  s := CopyContents( TPDFarray( c.v ) ); //proba skopiowania :)!
                 end;
   mpdfStream,
   mpdfObject   : //sprawa prosta
                 begin
                  CopyFrom( TPDFcontents( c.v ), 0 );
                  Dictionary.exchangeEntry('Resources', r );
                  s := true;
                 end;
  end;

   if s then
    begin
     p.Dictionary.clearEntry('Resources');
     p.Dictionary.deleteEntry('Contents');
    end;
 
end;

destructor TPDFxform.Destroy;
begin
 inherited
end;


//*********************************************************************************  Image

constructor TPDFimage.create;
begin
 inherited Create;
 mpdftype := mpdfImage;
 TPDFbasevar( Dictionary['Subtype'] ).asString := 'Image';
  with Dictionary do
   begin
    addEntry('Width',TPDFbasevar.Create(0) );
    addEntry('Height',TPDFbasevar.Create(0) );
   end;
end;


destructor TPDFimage.Destroy;
begin
 inherited;
end;




function loadJPG( fname : string ): TPDFxobject;
var
 strm : TFileStream;
 buffer : PDFuint;
 bpc    : PDFushort;
 w,h    : PDFuint;
 cs     : PDFushort;
 b1,b2  : PDFushort;
 pos    : PDFulong;
 size   : PDFuint;
 img    : TPDFimage;
begin
 img := TPDFimage.Create;
 strm := TFileStream.Create( fname, 0 );
 strm.Read( buffer, 2 );
  if buffer = $D8FF then
   begin
    strm.Read( buffer, 2 );
     while buffer<>$DAFF do
      begin
        pos := strm.Position;
         strm.Read( b2, 1 );
         strm.Read( b1, 1 );
         size := ( b2 shl 8 ) or b1;
          if ( buffer=$C0FF ) or ( buffer=$C1FF ) or ( buffer=$c2FF ) or ( buffer = $c3FF ) then
           begin
            strm.Read( bpc, 1 );
             strm.Read( b2, 1 );
             strm.Read( b1, 1 );
            h := ( b2 shl 8 ) or b1;
             strm.Read( b2, 1 );
             strm.Read( b1, 1 );
            w := ( b2 shl 8 ) or b1;
            strm.Read(  cs, 1 );
              if bpc = 0 then bpc := 8;
           end;
       strm.Seek( pos + size  , soFromBeginning );
       strm.Read( buffer, 2 );
      end;
    strm.Read( buffer, 2 ); // chunk length

     with img.Dictionary do
      begin
        EntryAsArray['Filter'].push( TPDFbasevar.Create('DCTDecode',vtName) );
        EntryAsInt['Width'] := w;
        EntryAsInt['Height'] := h;
        AddEntry('BitsPerComponent', TPDFbasevar.Create( bpc ) );
         case cs of
          1 : AddEntry('ColorSpace', TPDFbasevar.Create( 'DeviceGray', vtName ) );
          3 : AddEntry('ColorSpace', TPDFbasevar.Create( 'DeviceRGB', vtName ) );
          4 :  begin
                AddEntry('ColorSpace', TPDFbasevar.Create( 'DeviceCMYK', vtName ) );
                AddEntry('Decode', TPDFbasevar.Create( '[1.0 0.0 1.0 0.0 1.0 0.0 1.0 0.0]', vtDefStr ) );
               end;
         end;
      end;
        TPDFimage(img).imgtype := 0; //gray scale
         if cs > 1 then TPDFimage(img).imgtype := 1;
    img.stream.CopyFrom( strm, 0 );
   end;
 strm.Free;
 result := img;
end;

function loadJPG2( fname : string ): TPDFxobject;
var
 img    : TPDFimage;
 {$IFDEF HAS_JPEG}
  img : TImage;
  jpg : TJPEGImage;
 {$ELSE}
  jpg : TImage;
 {$ENDIF}
begin
{$IFDEF HAS_JPEG}
 img := TImage.Create( nil );
 jpg := TJPEGImage.Create;
   jpg.LoadFromFile( fname );
 // jpg.Assign( img.Picture.Graphic );
//   jpg.Compress;
   jpg.SaveToStream( self.stream );
   transform.make( jpg.Width, 0, 0, jpg.Height, 0, 0 );
   with img^.Dictionary do
    begin
      EntryAsArray['Filter'].push( TPDFbasevar.Create('DCTDecode',stName) );
      EntryAsInt['Width'] := jpg.Width;
      EntryAsInt['Height'] := jpg.Height;
      AddEntry('BitsPerComponent', TPDFbasevar.Create(8) );
      AddEntry('ColorSpace', TPDFbasevar.Create( 'DeviceRGB', stName ) );
    end;
   img^.imgtype := 1;
   jpg.Free;
   img.Free;
{$ELSE}
 img := TPDFimage.Create;
 jpg := TImage.Create( nil );
 jpg.AutoSize := true;
 jpg.Stretch := false;
 try
  jpg.Picture.LoadFromFile( fname );
   with TPDFimage(img).Dictionary do
    begin
      EntryAsArray['Filter'].push( TPDFbasevar.Create('DCTDecode',vtName) );
      EntryAsInt['Width'] := jpg.Width;
      EntryAsInt['Height'] := jpg.Height;
      AddEntry('BitsPerComponent', TPDFbasevar.Create(8) );
      AddEntry('ColorSpace', TPDFbasevar.Create( 'DeviceRGB', vtName ) );
    end;
   TPDFimage(img).imgtype := 1;
   jpg.Picture.Graphic.SaveToStream( img.stream );
 finally
  jpg.Free;
 end;
{$ENDIF}
 result := img;
end;

function loadPNG ( fname : string; pdf : TFileStream ): TPDFxobject;
type
  bytedLong = record
                case  boolean of
                 true : ( Value : PDFulong; );
                 false : ( b1, b2, b3, b4 : PDFushort );
              end;
const
  header : array [1..8] of byte = ( $89, $50, $4e, $47, $0d, $0a, $1a, $0a );
var
  img    : TPDFimage;
  strm  : TFileStream;
  i     : PDFushort;
  cc,
  pos,
  csize : PDFulong;
  ctype : array [1..4] of char;
  w,h   : PDFulong; // PNG header description
  bd,
  ct,
  c, f,
  im,
  cps    : PDFushort; // cps -> okreslenie koloru 1-index, 3-rgbQuad
  subdic : TPDFdictionary;
  plt    : TPDFstream;

  function readLONG() : PDFulong;
  var p : bytedLong;
  begin
    strm.Read( p.b4, 1 );
    strm.Read( p.b3, 1 );
    strm.Read( p.b2, 1 );
    strm.Read( p.b1, 1 );
    result := p.Value;
  end;

begin
 img := TPDFimage.Create;
 plt := nil;
 
 strm := TFileStream.Create( fname, 0 );
  while strm.Position < 8 do
   begin
    strm.Read( i, 1 );
     if header[ Byte(strm.Position) ] <> i then
      begin
       i := $00;
       break;
      end;
   end;

  if i <> $00 then
   begin
    pos := strm.Position;
    csize := readLONG();
    strm.Read( ctype, 4 );
     if  String( ctype ) = 'IHDR' then
      begin
       w := readLong;
       h := readLong;
       strm.Read( bd, 1 );
       strm.Read( ct, 1 );
       strm.Read( c, 1 );
       strm.Read( f, 1 );
       strm.Read( im, 1 );
      end;
     TPDFimage(img).imgtype := 0;
     cps := 1;
      if ( ct = 2 ) or ( ct = 6 )then
       begin
        TPDFimage(img).imgtype := 1;
        cps := 3;
       end else
           if ct = 3 then TPDFimage(img).imgtype := 2;


    subdic := TPDFdictionary.Create;
     with subdic do
      begin
         AddEntry('Predictor',15);
         AddEntry('Colors', cps );
         AddEntry('BitsPerComponent', bd );
         AddEntry('Columns',w);
      end;

     with img.Dictionary do
       begin
         EntryAsArray['Filter'].push( TPDFbasevar.Create('FlateDecode',vtName) );
         EntryAsInt['Width'] := w;
         EntryAsInt['Height'] := h;
         AddEntry('BitsPerComponent', TPDFbasevar.Create(bd) );
          case ct of
           0 : AddEntry('ColorSpace', TPDFbasevar.Create( 'DeviceGray', vtName ) );
           2,
           6 : AddEntry('ColorSpace', TPDFbasevar.Create( 'DeviceRGB', vtName ) );
           3 : begin
                plt := TPDFstream.Create;
                AddEntry('ColorSpace', TPDFarray.Create( [ TPDFbasevar.Create('Indexed',vtName),
                                                           TPDFbasevar.Create('DeviceRGB',vtName),
                                                           TPDFbasevar.Create(255),
                                                           TPDFobjref.Create(plt)
                                                         ]) );
               end; 
          end;

         AddEntry('DecodeParms', subdic );
       end;


      while String( ctype ) <> 'IEND' do
       begin
        pos := strm.Seek( pos + csize + 12, soFromBeginning );
        csize := readLONG();
        strm.Read( ctype, 4 );
          if  String( ctype ) = 'PLTE' then  // image palette
           begin
            plt.stream.CopyFrom( strm, csize );
            plt.addFilter( pfFlateDecode );
            TPDFfile( pdf ).registerObject( plt );
           end
         else
          if  String( ctype ) = 'tRNS' then  // image transparency
           begin
           end
         else
          if  String( ctype ) = 'IDAT' then  // image data
            img.stream.CopyFrom( strm, csize );

       end;

   end;

 strm.Free;
 result := img;
end;

function loadWMF ( fname : string ): TPDFxobject;
var plik       : file;
    wmf        : WMFheader;
    rsize      : DWORD;
    funcparams : WORD;
    fpos       : LONG;
    Params,
    ib, iw,
    v1,v2      : word;
    word_tab   : ^word;
    r,g,b      : byte;
    res        : real;
    img        : TPDFxform;
begin
 img := TPDFxform.Create;
 AssignFile( plik, fname );
 Reset( plik, 1 );
 BlockRead( plik, rsize, sizeof( DWORD ) );
 Seek( plik, 0 );
 res := 1.0;
  if rsize = PMkey then //WMF has placeable preheader
   begin
    BlockRead( plik, wmf.Placeable, sizeof( wmf.Placeable ) );
    //res := 1440 / wmf.Placeable.Inch;
    //580 830]
    res := 1440 / wmf.Placeable.Inch * (580/830);
    wmf.PreHeader := 1;
    Seek( plik, 22 );
   end;


 BlockRead( plik, wmf, 18 );

  if wmf.NumOfObject > 0 then
   begin
     fpos := FilePos( plik );
     BlockRead( plik, rsize, sizeof( DWORD ) );
     BlockRead( plik, funcparams, sizeof( WORD ) );
      while not ( ( rsize=$0003 ) and ( FuncParams=$0000 ) ) do
//      while ( rsize<>$0000 ) and ( FuncParams>$0003 ) do
       begin
//       pf^.Params := FuncParams shr 8;
//       pf^.FuncId := FuncParams and $FF;
        case FuncParams and $FF of
         Polyline and $FF :
               begin  // polyline
                BlockRead( plik, Params, sizeof(WORD) );
                //first point
                BlockRead( plik, v1, sizeof(WORD) );
                BlockRead( plik, v2, sizeof(WORD) );
                img.stream.WriteString( Format('%.2f %.2f m ',[v1*res,v2*res]) );
                iw := 2;
                 while iw < Params shl 1 do
                  begin
                   BlockRead( plik, v1, sizeof(WORD) );
                   BlockRead( plik, v2, sizeof(WORD) );
                   img.stream.WriteString( Format('%.2f %.2f l ',[v1*res,v2*res]) );
                   Inc( iw,2 );
                  end;
                img.stream.WriteString( 'S ' );
               end;
         CreateBrushIndirect and $FF :
               begin
                //hatch
                BlockRead( plik, v1, sizeof(WORD) );
                //color (now in deviceRGB ? egh...)
                BlockRead( plik, r, sizeof(byte) );
                BlockRead( plik, g, sizeof(byte) );
                BlockRead( plik, b, sizeof(byte) );
                 if (r=g)and(r=b)and(b=g) then img.stream.WriteString( Format('%g g ',[ r / $FF ]) ) else
                        img.stream.WriteString( Format('%g %g %g rg ',[ r / $FF, g / $FF, b / $FF ] ) );
                BlockRead( plik, r, sizeof(byte) );
                //style
                BlockRead( plik, v1, sizeof(WORD) );
               end;
         Polygon and $FF :
               begin  // polygon
                BlockRead( plik, Params, sizeof(WORD) );
                //readin points
//                SetLength( word_tab, i );
//                GetMem( word_tab, i );
//                BlockRead( plik, word_tab^, i );
                //first point
                BlockRead( plik, v1, sizeof(WORD) );
                BlockRead( plik, v2, sizeof(WORD) );
                img.stream.WriteString( Format('%.2f %.2f m ',[v1*res,v2*res]) );
                iw := 2;
                 while iw < Params shl 1 do
                  begin
                   BlockRead( plik, v1, sizeof(WORD) );
                   BlockRead( plik, v2, sizeof(WORD) );
                   img.stream.WriteString( Format('%.2f %.2f l ',[v1*res,v2*res]) );
//                   img^.stream.WriteString( Format('%d %d l ',[word_tab[iw],word_tab[iw+1]]) );
                   Inc( iw,2 );
                  end;
                img.stream.WriteString( 'f ' );
//                SetLength(word_tab,0);
//                FreeMem( word_tab, i );
               end;

         end;
        Seek( plik, fpos + rsize shl 1 );
        fpos := FilePos( plik );
        BlockRead( plik, rsize, sizeof( DWORD ) );
        BlockRead( plik, funcparams, sizeof( WORD ) );
       end;
   end;

// if  wmf.PreHeader = 1 then
//   TPDFrect( TPDFxform( img ).Dictionary.EntryAsArray['BBox'] ).setCoords( wmf.Placeable.Left,wmf.Placeable.Bottom,wmf.Placeable.Right,wmf.Placeable.Top );

   TPDFrect( TPDFxform( img ).Dictionary.EntryAsArray['BBox'] ).setCoords( 0,0,1000,1000 );

 CloseFile( plik );
 result := img;
end;

function loadBMP ( fname : string ): TPDFxobject;
var plik       : file;

begin
 AssignFile( plik, fname );
 Reset( plik, 1 );
 CloseFile( plik );
end;

function loadGIF ( fname : string ): TPDFxobject;
begin
end;

end.
