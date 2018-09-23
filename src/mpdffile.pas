(*******************************************************
            _____ ____ ______
   __  __  |     \    \   ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |     | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| ()  |  __|  web    : www.malczak.info
/__/    \____|  |_____/__|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                                mpdffile.pas
********************************************************
 unit description :                    pdf stream object
********************************************************
 bugs :                                              ---
********************************************************
 other :
********************************************************
 todo :
        - zrobic tak zeby TPDFfile tylko sluzyl jako
          buffor dla calosci pliku (mniej w pamieci bo
          strumienie beda zapisywane na dysku)
********************************************************)
unit mpdffile;
(*
2.I.2007
 - rozpoczecie praca nad biblioteka mPDF w postaci zarowno
 komponentow wizualnych (designtime) jak i nie wizualnych
 - totalne przebudowanie :)
        + TPDFobject nie dziedziczy juz po TPDFvariable ale po TPDFdictionary - done
        + nie ma juz rozroznienia na _.print(TStream) i _.SaveToStream(TStream) - done - undone
        + TPDFtrailer nie dziedziczy juz po TPDFobject ale po TPDFdictionary - done - undone
25.IV.2006
 - dodane odkodowywanie RC128bit, inne poprawki
21.XI.2005
 - lekkie poprawki
1.VII.2005
 - zmiany w pdfvars.pas
12.IV.2005
 - set USE_SIZE_OPTIMALIZATION to optimalize size of produced pdf files
11.IV.2005
 - set USE_BORLAND_VARIANT to work with 'Variant' type by default this
   code works with my variant type defined in file 'pdfvars.pas'
2.IV.2005
 - first pdf file
*)

//{$DEFINE USE_SIZE_OPTIMALIZATION}


interface
uses sysutils, classes, windows, rc4md5,
     mpdfbase, mpdfvars, mpdfdoc, mpdfencrypt, mpdffonts, mpdfxobj, mpdfgraphics;

{$IFDEF USE_SIZE_OPTIMALIZATION}
 {$DEFINE USO}
{$ENDIF}

{$IFDEF USE_BORLAND_VARIANT}
 {$MESSAGE 'Borland variants in use'}
 {$DEFINE UBV}
{$ENDIF}

{$IFNDEF USE_BORLAND_VARIANT}
 //{$MESSAGE 'MPDF variants in use'}
{$ENDIF}


type
 TPDFfile = class( TFileStream )
            protected
             fname     : string[32]; 
             pdftype   : byte;
             binary    : boolean;

             catalog   : TPDFcatalog;
             resources : TPDFresources;

             pages     : TPDFpages;       //pdf pages object
             page      : TPDFpagearray;   //array of pages

             fonts     : TPDFcontainer;  //all fonts registered in document
             images    : TPDFcontainer;

             xref      : TPDFxreftable; /// ---> jest blad jesli cos ulega pominieciu to zapisuje dobra ilosc wierszy ale podaje ilosc wierszy wszystkich ( tych zapisanych powiekszownych o te pominiete ) egh juz chyba zrobione
             trailer   : TPDFtrailer;
             spage     : TPDFpage;

             encrypted : PDFbool;
             encrypt   : TPDFencryption;

             h_canvas,
             f_canvas  : PDFuint; // object indirect ref. to header/footer canvas 1


            public
             info    : TPDFinfo;


             //header/footer support
             header,
             footer : TPDFCanvasFunction;
             //**
              property PDFCatalog : TPDFcatalog read catalog;
              property PDFresources : TPDFresources read resources;
              property PDFxref : TPDFxreftable read xref;
             //**
             procedure setHeader( header : TPDFcanvas );
             procedure setFooter( footer : TPDFcanvas );
             //page routines
             procedure addResource( res : TPDFobject; rtype : TPDFrestype );
             function addPage( page : TPDFpage; pos : PDFint = -1 ) : PDFuint; overload;
             function addPage( addCanvas : boolean = true; pos : PDFint = -1 ): TPDFpage; overload; //adds and selects new page
             function setCanvas( canvas : TPDFcanvas = nil ) : TPDFcanvas;      //adds/creates canvas to currently selected page
             function getCanvas : TPDFcanvas;                                   //returns canvas of selected page
             function pagesCount : PDFuint;                                     //return total number of pages
             procedure setSizes( w, h : PDFuint );                              //sets size of page for all pages
             //fonts :)
             function selectFont( fid : TPDFfontID ) : TPDFfontID;  overload;
             function selectFont( f : TPDFfont ) : TPDFfontID;      overload;
             function selectFont( fn : TPDFfonts ) : TPDFfontID;    overload;
             function registerFont( f : TPDFfont ) : TPDFfontID; overload;
             function registerFont( fn : TPDFfonts ) : TPDFfontID; overload;
             function replaceFont( fid : TPDFfontid; f : TPDFfont ) : TPDFfontid; overload;
             function replaceFont( fid : TPDFfontid; fn : TPDFfonts ) : TPDFfontid; overload;
             function getFont( fid : TPDFfontid ) : TPDFfont;
             //images :)
             procedure registerImage( var img : TPDFxobject );  overload;
             function registerImage( fname : string ) : TPDFxobject;  overload;
             function getImage( imgid : TPDFimageID ) : TPDFimage;
//             function imageFromStream( stream : TStream ) : TPDFimage;
             procedure deleteObject( obj : TPDFobject );
             procedure deleteObjectID( obj : TPDFobject );
             procedure registerObject( obj : TPDFobject ); virtual;

             function selectPage( p : TPDFpage=nil ) : TPDFpage;  overload;
             function selectPage( p : PDFuint=0 ) : TPDFpage; overload;
             procedure removePages( out p : TPDFpagearray );

             procedure setProtection( user_pass : string = ''; owner_pass : string = ''; protection : TProtection = ePrint );
             
             procedure Save( fname : string ); virtual;
             constructor Create(); overload;
             destructor Destroy; override;
            end;

implementation

//********************************************************************* TPDFfile
constructor TPDFfile.Create();
begin
 fname := md5( PDFnow );

 inherited Create( fname, fmCreate );

 catalog := TPDFcatalog.Create;
 pages := TPDFpages.Create;
 xref    := TPDFxreftable.Create;
 trailer := TPDFtrailer.Create;
 resources := TPDFresources.Create;

 catalog.Dictionary.EntryAsObjref['Pages'].v := pages;
 pages.Dictionary.EntryAsObjref['Resources'] := TPDFobjref.Create(resources);

 info := TPDFinfo.Create;
 fonts := TPDFcontainer.Create;
 images := TPDFcontainer.Create;

 binary := false;
 encrypted := false;
 encrypt := nil;
 pdftype := 3;
 spage := nil;

 xref.push( catalog );
 xref.push( pages );
end;

destructor TPDFfile.Destroy;
begin
 FileClose( self.Handle );
 DeleteFile( PChar( String(self.fname) ) );
// catalog.Destroy;
 trailer.Destroy;
 xref.Destroy;
 fonts.Destroy;
 images.Destroy;
 inherited;
end;

procedure TPDFfile.setProtection( user_pass : string; owner_pass : string; protection : TProtection );
begin
 if encrypt=nil then
  begin
   encrypt := TPDFencryption.Create( user_pass, owner_pass, protection );
   encrypted := true;
  end;
end;

procedure TPDFfile.registerObject( obj : TPDFobject );
begin
 xref.push( obj );
end;

procedure TPDFfile.deleteObjectID( obj : TPDFobject );
begin
 xref.Delete( obj );
end;

procedure TPDFfile.deleteObject( obj : TPDFobject );
begin
 xref.DeleteByPtr( obj );
end;

//******************************** header/footer routines
procedure TPDFfile.setHeader( header : TPDFcanvas );
begin
  if not header.isEmpty then
   begin
    xref.push( header );
    h_canvas := xref.count-1;
   end;
end;

procedure TPDFfile.setFooter( footer : TPDFcanvas );
begin
  if not footer.isEmpty then
   begin
    xref.push( footer );
    f_canvas := xref.count-1;
   end;
end;

//******************************** page routines
procedure TPDFfile.addResource( res : TPDFobject; rtype : TPDFrestype );
var bv : TPDFvariable;
    r : TPDFdictionary;
begin
 if resources=nil then
  begin
    if spage=nil then raise Exception.Create('Cannot add resource : no page selected');
   bv := spage.Dictionary['Resources'];
    if bv=nil then raise Exception.Create('Cannot add resource : page dont have resources');
      case bv.getType of
        mpdfDictionary : begin
                          bv := TPDFresources.Create(bv);
                          TPDFresources( bv ).addResource( res, rtype );
                          spage.Dictionary.exchangeEntry('Resources', bv );
                         end;
        mpdfObjref : TPDFresources( TPDFobjref(bv).v ).addResource( res, rtype );
        mpdfResources : TPDFresources( bv ).addResource( res, rtype );
      end;
 (*   if bv is TPDFobjref then r := TPDFdictionary( TPDFobjref(bv).v.Dictionary ) else
     if bv is TPDFobject then r := TPDFdictionary( TPDFobject(bv).Dictionary ) else
      r := TPDFdictionary( bv );
     case rtype of
    //  rtExtGState  : TPDFdictionary( Dictionary['ExtGState'] )...
    //  rtColorSpace : TPDFdictionary( Dictionary['ColorSpace
    //  rtPattern    : TPDFdictionary( Dictionary['Pattern
    //  rtShading    : TPDFdictionary( Dictionary['Shading
      rtXObject    :  begin
                          if r['XObject']=nil then r.addEntry('XObject', TPDFdictionary.Create );
                           with TPDFdictionary( r['XObject'] ) do
                             begin
                              TPDFimage(res).ID := Count+1;
                              AddEntry( Format('Im%d',[ TPDFxobject(res).ID ]), TPDFobjref.Create( res ) );
                             end;
                      end;
      rtFont       :  begin
                        if r['Font']=nil then r.addEntry('Font', TPDFdictionary.Create );
                          with TPDFdictionary( r['Font'] ) do
                           begin
                             TPDFfont(res).fid := Count+1;
                             AddEntry( Format('F%d',[ TPDFfont(res).fid ]), TPDFobjref.Create( res ) );
                           end;
                      end;
    //  rtProperties : TPDFdictionary( Dictionary['Properties

     end;*)
  end else resources.addResource( res, rtype );
end;

function TPDFfile.PagesCount : PDFuint;
begin
 result := Length(page)//pages.Dictionary.EntryAsInt['Count'];
end;

function TPDFfile.setCanvas( canvas : TPDFcanvas ) : TPDFcanvas;
var c : TPDFcanvas;
begin
 if spage=nil then exit;
  if canvas = nil then
    c := TPDFcanvas.Create else c := canvas;
 c.setSizes( spage.getWidth, spage.getHeight );
// spage.Dictionary.EntryAsObjref['Contents'] := TPDFobjref.Create(c);
 spage.setCanvas( c );
  if canvas = nil then xref.push( c );
 result := c;
end;

function TPDFfile.getCanvas : TPDFcanvas;
begin
  if spage<>nil then
 result := spage.getCanvas;
end;

procedure TPDFfile.setSizes( w, h : PDFuint );
begin
 pages.Dictionary.addEntry( 'MediaBox', TPDFrect.Create(0,0,w,h), true );
end;

function TPDFfile.addPage( page : TPDFpage; pos : PDFint ) : PDFuint;
var pc : TPDFbasevar;
    v : Integer;
begin
 result := 0;
 spage := page;
  if page=nil then exit;
  if fonts.Selected<>nil then
   spage.setFont( TPDFfont(fonts.Selected).fid );

   //dodaj resources
  if resources<>nil then
   if page.Dictionary['Resources'] = nil then
    page.Dictionary.addEntry( 'Resources', TPDFobjref.Create(resources) );
 pc := pages.Dictionary['Count'] as TPDFbasevar;
 v := pc.asInt;
 SetLength( self.page, v+1 );

 self.page[ v ] := spage;
 pages.Dictionary.EntryAsArray['Kids'].push( TPDFobjref.Create(spage) );

 Inc(v);
 pc.asInt := v;
 spage.PageNo := v;

 xref.Push( spage );
 xref.Push( spage.getCanvas );

  if h_canvas >0 then spage.assignCanvas( TPDFcanvas( xref.Item[h_canvas] ) )
   else
     if Assigned( header ) then header( self, spage.getCanvas, spage.PageNo );

  if f_canvas >0 then spage.assignCanvas( TPDFcanvas( xref.Item[f_canvas] ) )
   else
     if Assigned( footer ) then footer( self, spage.getCanvas, spage.PageNo );

 result := v-1;
end;

function TPDFfile.addPage( addCanvas : boolean; pos : PDFint ) : TPDFpage;
var pc : TPDFbasevar;
    v  : PDFint;
begin
 spage := TPDFpage.Create( pages );
  if fonts.Selected<>nil then
   spage.setFont( TPDFfont(fonts.Selected).fid );
 pc := pages.Dictionary['Count'] as TPDFbasevar;
 v := pc.asInt;
 SetLength( page, v+1 );

 page[ v ] := spage;
 pages.Dictionary.EntryAsArray['Kids'].push( TPDFobjref.Create(spage) );

 Inc(v);
 pc.asInt := v;
 spage.PageNo := v;

 xref.push( spage );
  xref.Push( spage.getCanvas);
//  if addCanvas then
//   setCanvas;

  if h_canvas >0 then spage.assignCanvas( TPDFcanvas( xref.Item[h_canvas] ) )
   else
     if Assigned( header ) then header( self, spage.getCanvas, spage.PageNo );

  if f_canvas >0 then spage.assignCanvas( TPDFcanvas( xref.Item[f_canvas] ) )
   else
     if Assigned( footer ) then footer( self, spage.getCanvas, spage.PageNo );

 result := spage;
end;

function TPDFfile.selectPage( p : TPDFpage ) : TPDFpage;
begin
  if p<>nil then spage := p;
 result := spage;
end;

function TPDFfile.selectPage( p : PDFuint=0 ) : TPDFpage;
begin
result := nil;
  if p<Length(page) then
   begin
    spage := page[p];
    result := spage;
   end;
end;

procedure TPDFfile.removePages( out p : TPDFpagearray );
var i : integer;
begin
  if Length(p)>0 then exit;
 SetLength( p,Length(page) );
 i := Length(page)-1;
  repeat
   p[i] := page[i];
   Dec(i);
  until i<0;
 TPDFbasevar( pages.Dictionary['Count'] ).asInt := 0;
 pages.Dictionary.EntryAsArray['Kids'].Clear;
(*  for i:=0 to Length(page)-1 do
 result := nil;
  if pos>Length(page)-1 then exit;
 p := page[pos];
 xref.DeleteByPtr( p );
   if getObject( TPDFpage(obj).Dictionary, 'Parent', v ) then
     Dec_( TPDFpages(v).Dictionary['Count'] );
 j := Length(page)-1;
 repeat
 page[i] := page[i+1];
 Inc(i);
 until i>=j;
 SetLength(page,j);*)
 end;
//******************************** page routines

//******************************** fonts routines
function TPDFfile.registerFont( f : TPDFfont ) : TPDFfontID;
begin
 result := 0;
 f.fid := fonts.push( f )+1;
 addResource( f, rtFont );
// resources.addResource( f, rtFont );
 xref.Push( f );
 result := f.fid;
end;

function TPDFfile.registerFont( fn : TPDFfonts ) : TPDFfontID;
var f : TPDFfont;
begin
 result := 0;
 f := TPDFfont.Create( fn );
 f.fid := fonts.push( f )+1;
// resources.addResource( f, rtFont );
 addResource( f, rtFont );
 xref.Push( f );
 result := f.fid;
end;

function TPDFfile.selectFont( fid : TPDFfontID ) : TPDFfontID;
begin
 result := 0;
  if fonts.select( fid ) then
   result := TPDFfont( fonts.Selected ).fid;
end;

function TPDFfile.selectFont( f : TPDFfont ) : TPDFfontID;
begin
 result := registerFont( f );
  if result>0 then
    fonts.select( result-1 );
end;

function TPDFfile.selectFont( fn : TPDFfonts ) : TPDFfontID;
var f : TPDFfont;
begin
 result := registerFont( fn );
  if result>0 then
   fonts.select( result-1 )
end;

function TPDFfile.replaceFont( fid : TPDFfontid; f : TPDFfont ) : TPDFfontid;
var fold : TPDFfont;
    obj1, obj2 : TPDFobject;
begin
 fold := TPDFfont( fonts.item[ fid-1 ] );
 f.fid := fid;
 obj1 := fold; obj2 := f;
 xref.Exchange( obj1, obj2 );
 fonts.item[ fid-1 ] := f;
 TPDFdictionary( resources.Dictionary['Font'] ).EntryAsObjref[ Format('F%d',[ f.fid ]) ].v := f;
 FreeAndNil( obj1 );
 result := f.fid;
end;

function TPDFfile.replaceFont( fid : TPDFfontid; fn : TPDFfonts ) : TPDFfontid;
var fold, f : TPDFfont;
    obj1, obj2 : TPDFobject;
begin
  if resources=nil then exit;
 f := TPDFfont.Create( fn );
 result := replaceFont( fid, f );
end;

function TPDFfile.getFont( fid : TPDFfontid ) : TPDFfont;
begin
 result := nil;
  if fid < fonts.count then
   result := TPDFfont( fonts[ fid-1 ] );
end;
//******************************** fonts routines

//******************************** images routines
procedure TPDFfile.registerImage( var img : TPDFxobject );
begin
 binary := true;
 img.ID := images.push( img )+1;
  //??
  if resources<>nil then
    if resources.Dictionary['XObject']<>nil then
     begin
       img.ID := img.ID + TPDFdictionary( resources.Dictionary['XObject'] ).Count;
     end;
// resources.addResource( img, rtXObject );
 addResource( img, rtXObject );
 xref.Push( img );
end;

function TPDFfile.registerImage( fname : string ) : TPDFxobject;
var img : TPDFxobject;
    ext : string[6];
begin
// img := TPDFimage.Create;
// img.k := 72;
 ext := LowerCase( ExtractFileExt( fname ) );
  if (ext='.jpg')or(ext='.jpeg') then
     img := loadJPG( fname )
 else
  if (ext='.png') then
     img := loadPNG( fname, self )
 else
  if (ext='.gif') then
     img := loadGIF( fname )
 else
  if (ext='.bmp') then
     img := loadBMP( fname )
 else
  if (ext='.wmf') then
//   img := TPDFxform.Create;
   img := loadWMF( fname );

 registerImage( img );

 result := img;
end;

function TPDFfile.getImage( imgid : TPDFimageID ) : TPDFimage;
begin
 result := nil;
  if imgid < images.count then
   result := TPDFimage( images[ imgid-1 ] );
end;
//******************************** images routines

procedure TPDFfile.Save( fname : string );
var buffer   : string;
    obj      : TPDFobject;
    i        : word;
    savefile : TFileStream;
begin
(*    resources.addProcSet( pText );
     resources.addProcSet( pImageC );
     resources.addProcSet( pImageB );
    Catalog.Dictionary.deleteEntry('Metadata');
  *)
  //nalezaloby wyczyscic
//xref.push( catalog );    // usunac jezeli plik jest importowany
//xref.push( pages );      // usunac jezeli plik jest importowany
  if resources<>nil then
   xref.push( resources );
 //calculate trailers ID entry (only time and info entries)
 buffer := PDFnow + info.Author + info.Title + info.Subject + info.Keywords + info.Creator + info.ModDate;
 buffer := md5( buffer );
// trailer.Dictionary.addEntry('ID', TPDFarray.Create([ TPDFbasevar.Create('<'+buffer+'>',vtDefStr), TPDFbasevar.Create('<'+buffer+'>',vtDefStr) ]) );
 trailer.addEntry('ID', TPDFarray.Create([ TPDFbasevar.Create('<'+buffer+'>',vtDefStr), TPDFbasevar.Create('<'+buffer+'>',vtDefStr) ]) );
   if encrypted then //encryption is now PART of xref object (for object encode simplicity)
    begin
     encrypt.Init( buffer );
     xref.push( encrypt );
//     trailer.Dictionary.addEntry('Encrypt', TPDFobjref.Create( encrypt ) );
     trailer.addEntry('Encrypt', TPDFobjref.Create( encrypt ) );
    end;
//info obj add as a last object
 xref.push( info );
//header
 PDFwritestring( self,  pdfHeader, [ pdftype ] );
  if binary then PDFwritestring( self, pdfBinary );
//save all objects (with obj num fix)
 xref.SaveObjects( self, encrypt );
//save cross-referance table
 xref.SaveToStream( self );
// xref.print( self );
//trailer
{ trailer.Dictionary.EntryAsInt['Size'] := xref.SavedCount+1;
 trailer.Dictionary.EntryAsObjref['Info'].v := Info;
 trailer.Dictionary.EntryAsObjref['Root'].v := Catalog;     }
 trailer.EntryAsInt['Size'] := xref.SavedCount+1;
 trailer.EntryAsObjref['Info'].v := Info;
 trailer.EntryAsObjref['Root'].v := Catalog;
 trailer.xrefpos := xref.objpos;
 trailer.SaveToStream( self );
{ trailer.print( self );}
 PDFwritestring( self, pdfEof );
// MessageBox( 0, PChar('file saved !'), PChar('Save dialog'), MB_OK );

//zapis pod wskazany plik :)
 savefile := TFileStream.Create( fname, fmCreate );
 savefile.CopyFrom( self, 0 );
 savefile.Destroy;
end;


begin
 Randomize;

end.
