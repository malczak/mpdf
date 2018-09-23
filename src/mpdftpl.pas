(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                                 mpdftpl.pas
********************************************************
 unit description :            reading/decompressing and
                                    decrypting pdf files
********************************************************
 bugs :                                              ---
********************************************************
 other :
        17. XII. 2005 - class moved to mpdfimport file
        08. VII. 2005 -  first release
        21. XI. 2005 -  last update
********************************************************
 todo :
  nie zawsze mozna przebudowac RESOURCES :) wtedy
  nie zrobie tak latwo naszych obiektow
********************************************************)
unit mpdftpl;
(******************************
this class allows to imoprt pdf
file from file and coinvert it
into template pdf file
more : Form XObjects - "PDF Reference" p.263
*****************************)

(******************************************************************************
 TPDFtemplate - class for creating pdf tempates
 (C)2004-2005 by Mateusz Malczak
 http://www.malczak.linuxpl.com
 malczak@us.edu.pl
******************************************************************************)

interface
(*
uses Classes,SysUtils,Dialogs,rc4md5,
     mpdfbase, mpdfvars, mpdfdoc, mpdfencrypt, mpdfgraphics, mpdffonts, mpdfxobj, mpdffile, mpdfimport;

type
 TPDFtemplate = class( TPDFimporter )
                protected
                  function ImportPage( pno : PDFuint ) : TPDFxobject;
                public
                  tpls : TPDFarray;
                  procedure MakeTemplate( fname : string );
                end;
*)
implementation
(*
procedure TPDFtemplate.MakeTemplate( fname : string );
begin
 RemoveMetadata := true;
 Import( fname );
 Decrypt();
 RebuildPages;
end;

function TPDFtemplate.ImportPage( pno : PDFuint ) : TPDFxobject;
var xform : TPDFxform;
    p  : TPDFpage;
    c  : TPDFvariable;
    i : PDFuint;
    mb : TPDFarray;
begin
 result := nil;
//     if pno>=pages.Dictionary.EntryAsInt['Count'] then exit;
     if pno>=outpdf.pagesCount then exit;

 p := outpdf.selectPage( pno );
   if p=nil then exit;
 outpdf.deleteObject( p );

 xform := TPDFxform.Create;

 TPDFobjref( outpdf.pages.Dictionary.EntryAsArray['Kids'][pno] ).v := nil;
 i := pages.Dictionary.EntryAsInt['Count'];
 Dec(i);
 pages.Dictionary.EntryAsInt['Count'] := i;

 c := p.Dictionary['Contents'];
 mb := p.Dictionary.EntryAsArray['MediaBox'];

 DeleteObject( p );

//  if p.Dictionary['MediaBox']=nil then
  // a co jak nie ma MediaBoc, skoro mozna to dzieciczyc to moze to :) byc bardzo rgh.. wysoko

 xform.Dictionary.addEntry('BBox', TPDFarray.Create( mb ) );
 
  if c.getType=mpdfObjref then c := TPDFobjref(c).v;

  case c.getType of
   mpdfArray    : for i:=0 to TPDFarray( c ).count-1 do
                     xform.CopyFrom( TPDFstream( TPDFobjref( TPDFarray( c )[i] ).v ), 0 );
   mpdfStream   : xform.CopyFrom( TPDFstream(c), 0 );
   mpdfObjref   : xform.CopyFrom( TPDFstream( TPDFobjref(c).v ), 0 );
   mpdfContents : xform.CopyFrom( TPDFcontents(c), 0 );
  end;
 xform.addFilter( pfFlateDecode );

// if p.getCanvas
// xform.stream.Copy
 xref.Push( xform );
  if resources<>nil then
   addResource( xform, rtXObject );
 result := xform;
end;
*)
end.
