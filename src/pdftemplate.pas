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
        08. VII. 2005 -  first release
        21. XI. 2005 -  last update
********************************************************)
unit pdftemplate;
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
uses Classes,SysUtils,Dialogs,rc4md5,
     mpdfbase, mpdfvars, mpdfdoc, mpdfencrypt, mpdffonts, mpdfxobj, mpdffile, mpdfinport;

type
 TPDFXobject = class( TPDFStream )
  constructor Create;
 end;

 TPDFtemplate = class( TPDFimport )
 public
        function ImportPage( pno : PDFuint ) : TPDFtplID;
 end;

implementation

constructor TPDFXobject.Create;
begin
 inherited Create;
  with Dictionary do
   begin
    addEntry('Type',TPDFbasevar.Create('XObject',vtName));
    addEntry('Subtype',TPDFbasevar.Create('Form',vtName));
    addEntry('FormType',TPDFbasevar.Create(1) );
    addEntry('BBox', TPDFarray.Create );
    addEntry('Resources',TPDFresources.Create);
   end;
end;

function TPDFtemplate.ImportPage( pno : PDFuint ) : TPDFtplID;
var xform : TPDFxobject;
    p  : TPDFpage;
    c  : TPDFvariable;
begin
 result := 0;
    if pno>=pages.Dictionary.EntryAsInt['Count'] then exit;

 xform := TPDFXobject.Create;
 p := page[pno];

 c := p.Dictionary['Contents'];
   if c is TPDFobjref then c := TPDFobjref( c ).v;

 if c is TPDFarray then
   begin
    c := TPDFobjref( TPDFarray(c)[0] ).v;
     xform.stream.CopyFrom( TPDFstream(c).stream, 0 );
   end else
           if c is TPDFstream then
                xform.stream.CopyFrom( TPDFstream(c).stream, 0 );

// if p.getCanvas
// xform.stream.Copy

 xref.Push( xform );
end;

end.
