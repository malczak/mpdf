(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                               mpdffonts.pas
********************************************************
 unit description :                    pdf fonts support
********************************************************
 bugs :                                              ---
********************************************************
 other :
        till XII.2005 - only standart Font1 fonttypes
        2.IV.2005  - first fonts objects (Chapter 5)
********************************************************)
unit mpdffonts;

interface
uses windows, graphics, mpdfbase, mpdfvars;

type
 TPDFfonts      = ( pdfTRoman, pdfTBold, pdfTItalic, pdfTBoldItalic, pdfHelvetica,
                    pdfHBold, pdfHOblique, dpfHBoldOblique, pdfCourier, pdfCBold,
                    pdfCOblique, pdfCBoldOblique, pdfSymbol, pdfZapf );

 TPDFfont       = class ( TPDFobject )
                   fid : TPDFfontID;    // starting form 1...N
                   constructor Create;                     overload;
                   constructor Create( font : TPDFfonts ); overload;
                   constructor Create( font : HFONT     ); overload;
                   constructor Create( const font : TFont ); overload;
                   constructor Create( font : string    ); overload;
                   destructor Destroy; override;
                  end;

implementation
const
 pdfFontsStr : array[ TPDFfonts ] of string =
                                    ( 'Times-Roman','Times-Bold','Times-Italic',
                                      'Times-BoldItalic','Helvetica','Helvetica-Bold',
                                      'Helvetica-Oblique','Helvetica-BoldOblique','Courier',
                                      'Courier-Bold','Courier-Oblique','Courier-BoldOblique',
                                      'Symbol','ZapfDingbats' );

constructor TPDFfont.Create;
begin
 inherited;
 fid := 0;
  with Dictionary do
   begin
    addEntry('Type',TPDFbasevar.Create('Font',vtName));
    addEntry('Subtype',TPDFbasevar.Create('',vtName));
    addEntry('BaseFont',TPDFbasevar.Create('',vtName));
   end;
end;

constructor TPDFfont.Create( font : TPDFfonts );
begin
 Create;
  with Dictionary do
   begin
     EntryAsString['Subtype'] := 'Type1';
     EntryAsString['BaseFont'] := pdfFontsStr[ font ];
     addEntry('Encoding',TPDFbasevar.Create('WinAnsiEncoding',vtName));
   end;
end;

constructor TPDFfont.Create( font : HFONT     );
begin
end;

constructor TPDFfont.Create( const font : TFont   );
begin
 Create;
  with Dictionary do
   begin
    EntryAsString['Subtype'] := 'Type1';
    EntryAsString['BaseFont'] := font.Name;
    AddEntry('FirstChar',  0 );
    AddEntry('LastChar',  255 );
   end;
end;

constructor TPDFfont.Create( font : string    );
begin
end;

destructor TPDFfont.Destroy;
begin
 inherited;
end;

end.
