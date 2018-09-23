(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                            mpdfgraphics.pas
********************************************************
 unit description :          page contents (page canvas)
********************************************************
 bugs :                                              ---
********************************************************
 other :
15.XII.2005
 - vector image (wmf ect.) now stored as XForm objects
2.IV.2005
 - first pdf document objects (pdf objects skeleton)
********************************************************)
unit mpdfgraphics;

interface
uses sysutils,classes,
     mpdfbase,mpdfvars,mpdffilters,mpdfxobj,mpdffonts;


const
//pdf line caps
pdfButtCup   = 0;
pdfRoundCup  = 1;
pdfSquareCap = 2;
pdfLineCaps  = [ pdfButtCup, pdfRoundCup, pdfSquareCap ];
//pdf line joins
pdfMiterJoin = 0;
pdfRoundJoin = 1;
pdfBevelJoin = 2;
pdfLineJoins = [ pdfMiterJoin, pdfRoundJoin, pdfBevelJoin ];
//text rendering modes

type
TPDFTextRendering = ( trmFill, trmStroke, trmFillStroke, trmInvisible, trmFillClip, trmStrokeClip, trmFillStrokeClip, trmClip );

TPDFtextsettings = record
                    fid    : TPDFfontid;
                    crops  : TPDFpoint;
                    chrSpace,        {Tc}
                    wrdSpace,        {Tw}
                    rise   : PDFint; {Ts}
                    scale,           {Tz}
                    leading,         {TL}
                    size   : PDFuint;{Tf}
                    render : TPDFTextRendering; {Tr}
                   end;


TPDFcontents    =  class ( TPDFstream ) // ~~~~> pobierajac canvas dla strony automatycznie powinno byc tutaj zaznaczone jaka czcionke aktualnie wybrano
                   protected
                        width,
                        height  : PDFuint;
                        ttype   : array[1..2] of char;
                        txtoper : TPDFtextsettings;
                        buffer  : string;
                        buflen  : PDFuint;
                   public
                    //basic instructions
                  //special graphics states
                  procedure pushMatrix;                                         {q}
                  procedure popMatrix;                                          {Q}
                  procedure setMatrix( a,b,c,d,e,f : PDFreal );                 {cm}
                  procedure renderImage( img : TPDFxobject );                   {Do}
                  //general graphics states
                  procedure setLineWidth( w : PDFint );                         {w}
                  procedure setLineCap( c : PDFint );                           {J}
                  procedure setLineJoin( j : PDFint );                          {j}
                  procedure setMiterLimit( ml : PDFint);                        {M}
                  procedure setDashPattern( da : array of PDFuchar;
                                            dp : PDFuchar);                      {d}
                  //procedure setRenderIntent(...)                                {ri}
                  //procedure setFlastness(...)                                   {i}
                  //procedure setExtGState(...)                                   {gs}

                  //path contructing
                  procedure MoveTo(x,y : PDFint);                               {m}
                  procedure LineTo(x,y : PDFint);                               {l}
                  procedure Bezier( x1,y1,x2,y2,x3,y3 : PDFint);                {c}
                  procedure BezierEnd( x2,y2,x3,y3 : PDFint );                  {v}
                  procedure BezierBegin( x1,y1,x3,y3 : PDFint);                 {y}
                  procedure lineClose();                                        {h}
                  procedure Rectangle( x,y,w,h : PDFint );                      {re}
                  procedure Line( x1,y1,x2,y2 : PDFint );                       {~~}
                  procedure Ellipse( x1,y1,x2,y2 : PDFint );                    {~~}

                  //path painting
                  procedure pStroke();                                          {S}
                  procedure pCloseStroke();                                     {s}
                  procedure pFill();                                            {f}
                  procedure pFillEO();                                          {f*}
                  procedure pFillStroke();                                      {B}
                  procedure pFillStrokeEO();                                    {B*}
                  procedure pCloseFillStroke();                                 {b}
                  procedure pCloseFillStrokeEO();                               {b*}
                  procedure pEnd();                                             {n}

                  //clipping paths
                  procedure pClip();                                            {W}
                  procedure pClipEO();                                          {W*}

                  //text
                  procedure textType( t : TPDFvartypes );                       {~~}
                  procedure textOut( x,y : PDFint; text : string ); overload;   {~~}
                  procedure textOut( x,y,s : PDFint; text : string ); overload; {~~}

                  procedure beginText();                                        {BT}
                  procedure textOut( text : string ); overload;                 {Tj}
                  procedure endText();                                          {ET}

                  procedure textLine( str : string );                           {~~}
                  procedure flushText();                                        {~~}
                  procedure setFontSize( size : PDFuint );                      {Tf}
                  procedure setCharSpacing( c : PDFint );                       {Tc}
                  procedure setWordSpacing( w : PDFint );                       {Tw}
                  procedure setScaling( s : PDFuint);                           {Tz}
                  procedure setLeading( l : PDFuint);                           {TL}
                  procedure setRenderMode( trm : TPDFTextRendering);            {Tr}
                  procedure setTextRise( r : PDFint );                          {Ts}
                   (*
                  //text
                  procedure nextLine()                                          {T*}
                  procedure nextLine(x,y)                                       {Td}
                  procedure nextLineL(x,y)                                      {TD}
                  procedure setTextMatrix(a,b,c,d,e,f)                          {Tm}

                  procedure brTextOut(...)                                      {'}
                  procedure frmtTextOut(...)                                    {''}
                  procedure arrayTextOut(...)                                   {TJ}
                  *)
                        procedure setFillColor( r,g,b : PDFushort );   { deviceRGB, deviceGray}
                        procedure setStrokeColor( r,g,b : PDFushort );
                        function setFont( f : TPDFfontid ) : TPDFfontid;
                        procedure setSizes( width, height : PDFuint );

                        constructor Create;
                   end;

TPDFcanvas      = TPDFcontents;

TPDFCanvasFunction = procedure ( Sender : TObject; PDFCanvas : TPDFcontents; pageno : word ) of object;

implementation
const
  PDFtextredner    : array[ TPDFTextRendering ] of char = ( '0','1','2','3','4','5','6','7' );

{****************************************************** TPDFcontents ***********}
constructor TPDFcontents.Create;
begin
 inherited Create;
 mpdftype := mpdfContents;
 ttype[1] := '(';
 ttype[2] := ')';
 width := 0;
 height := 0;
 stream := TStringStream.Create('');
 txtoper.size := 10;
  with Dictionary do
   begin
    //add other entries for content stream (p.112)
   end;
   //tmp solution
  //PDFwritestring( stream, '1 w'+pdfEol+'150 10 m'+pdfEol+'160 200 l'+pdfEol+'S' );
end;

function TPDFcontents.setFont( f : TPDFfontid ) : TPDFfontid;
begin
 result := txtoper.fid;
 txtoper.fid := f;
end;

procedure TPDFcontents.setSizes( width, height : PDFuint );
begin
 self.width := width;
 self.height := height;
end;

procedure TPDFcontents.pushMatrix;
begin
 stream.WriteString('q ');
end;

procedure TPDFcontents.popMatrix;
begin
 stream.WriteString('Q ');
end;

procedure TPDFcontents.setMatrix( a,b,c,d,e,f : PDFreal );
begin
 stream.WriteString( Format('%g %g %g %g %g %g cm ',[a,b,c,d,e,f]) );
end;

procedure TPDFcontents.renderImage( img : TPDFxobject );
var t : TPDFmatrix;
begin
 t := img.transform;
  if t<>nil then
         stream.WriteString( Format('q %g %g %g %g %g %g cm ',[ t.mA, t.mB, t.mC, t.mD, t.mE, t.mF ] ) );

  case img.getType of
   mpdfForm : stream.WriteString( Format('/mtpl%d Do ',[ TPDFimage(img).iid ] ) ); //raster image (call indirect object);
   mpdfImage : begin
//                 if TPDFimage(img).imgtype <3 then
                     stream.WriteString( Format('/Im%d Do ',[ TPDFimage(img).iid ] ) ) //raster image (call indirect object)
  //                    else stream.CopyFrom( TPDFimage(img).stream, 0 ); //vector image (copy img data)
               end;
  end;

  if t<>nil then
   stream.WriteString('Q ');
end;

procedure TPDFcontents.setLineWidth( w : PDFint );
begin
 stream.WriteString( Format('%d w ',[w]) );
end;

procedure TPDFcontents.setLineCap( c : PDFint );
begin
 if c in pdfLineCaps then
  stream.WriteString( Format('%d J ',[c]) );
end;

procedure TPDFcontents.setLineJoin( j : PDFint );
begin
 if j in pdfLineJoins then
  stream.WriteString( Format('%d j ',[j]) );
end;

procedure TPDFcontents.setMiterLimit( ml : PDFint);
begin
 stream.WriteString( Format('%d M ',[ml]) );
end;

procedure TPDFcontents.setDashPattern( da : array of PDFuchar; dp : PDFuchar);
var l : PDFuint;
    dap,last : ^PDFuchar;
begin
 last := @da[ Length( da )-1 ];
 dap := @da[0];
 with stream do
  begin
   WriteString( Format('[%d',[dap^]) );
   inc(dap);
    while not (Longint(pointer(dap))>Longint(Pointer(last))) do
     begin
      WriteString( Format(' %d',[dap^]) );
      inc(dap);
     end;
   WriteString( Format('] %d d ',[dp]) );
  end;
end;

procedure TPDFcontents.moveTo( x,y  : PDFint );
begin
 stream.WriteString( Format('%d %d m ',[x,y]) );
end;

procedure TPDFcontents.Line( x1,y1,x2,y2 : PDFint );
begin
 stream.WriteString( Format('%d %d m %d %d l S ',[x1,y1,x2,y2]) );
end;

procedure TPDFcontents.Bezier( x1,y1,x2,y2,x3,y3 : PDFint);
begin
 stream.WriteString( Format('%d %d %d %d %d %d c ',[x1,y1,x2,y2,x3,y3]) );
end;

procedure TPDFcontents.BezierEnd( x2,y2,x3,y3 : PDFint );
begin
 stream.WriteString( Format('%d %d %d %d v ',[x2,y2,x3,y3]) );
end;

procedure TPDFcontents.BezierBegin( x1,y1,x3,y3 : PDFint);
begin
 stream.WriteString( Format('%d %d %d %d y ',[x1,y1,x3,y3]) );
end;

procedure TPDFcontents.lineClose();
begin
 stream.WriteString('h ');
end;

procedure TPDFcontents.Rectangle( x,y,w,h : PDFint );
begin
 stream.WriteString( Format('%d %d %d %d re S ',[x,y,w,h]) );
end;

procedure TPDFcontents.lineTo( x,y  : PDFint );
begin
 stream.WriteString( Format('%d %d l ',[x,y]) );
end;

procedure TPDFcontents.ellipse( x1,y1,x2,y2 : PDFint );
var x, y, cx,cy,cx1,cy1,cx2,cy2,rx,ry,w, h, i, e1, e2, e : PDFint;
    r,dfi,b,_2pi : PDFreal;
begin
 _2pi := PI * 2;
 w := x2-x1;
  if w=0 then exit;
 h := y2-y1;
  if h=0 then exit;
 e1 := w shr 1;
 x := x1 + e1;
 e2 := h shr 1;
 y := y1 + e2;

 b :=  4 * (1-Cos(pi/12)) / (3*Sin( pi/12));

 stream.WriteString( Format('%d %d m ',[x+e1,y+0]) );
 for i:=1 to 12 do
  begin
   dfi := i * (2 * PI / 12);
//   cx := x+round( e1*(2-cos(PI/8)) * cos( dfi-pi/8)  );
//   cy := y+round( e2*(2-cos(PI/8)) * sin( dfi-pi/8)  );
//   cx1 := x+round( e1*(2-cos(PI/8)) * cos( dfi-3*pi/16)  );
//   cy1 := y+round( e2*(2-cos(PI/8)) * sin( dfi-3*pi/16)  );
//   cx2 := x+round( e1*(2-cos(PI/8)) * cos( dfi-pi/16)  );
//   cy2 := y+round( e2*(2-cos(PI/8)) * sin( dfi-pi/16)  );
   cx2 := x+round( e1*cos( dfi ) );
   cy2 := y+round( e2*sin( dfi ) );

   cx1 := cx2+round( e1*b*sin( dfi )  );
   cy1 := cy2-round( e2*b*cos( dfi )  );
   rx := cx2-round( e1*b*sin( dfi )  );
   ry := cy2+round( e2*b*cos( dfi )  );
   stream.WriteString( Format('%d %d %d %d %d %d c ',[cx1,cy1,cx2,cy2,rx,ry]) );
//  stream.WriteString( Format('%d %d %d %d v ',[cx,cy,rx,ry]) );

  end;
{
 dfi := (360/36)*PI/180;;
 r := e2;
 rx := x;
 ry := y + e2;
 stream.WriteString( Format('%d %d m ',[rx,ry]) );
  for i:=1 to 35 do
   begin
    r := e2 + e * abs(sin( i*dfi*h ));
    rx := round(x + r * sin(i*dfi) );
    ry := round(y + r * cos(i*dfi) );
    stream.WriteString( Format('%d %d l ',[rx,ry]) );
   end;            }
 stream.WriteString('S ');
end;

procedure TPDFcontents.pStroke();
begin
 stream.WriteString('S ');
end;

procedure TPDFcontents.pCloseStroke();
begin
 stream.WriteString('s ');
end;

procedure TPDFcontents.pFill();
begin
 stream.WriteString('f ');
end;

procedure TPDFcontents.pFillEO();
begin
 stream.WriteString('f* ');
end;

procedure TPDFcontents.pFillStroke();
begin
 stream.WriteString('B ');
end;

procedure TPDFcontents.pFillStrokeEO();
begin
 stream.WriteString('B* ');
end;

procedure TPDFcontents.pCloseFillStroke();
begin
 stream.WriteString('b ');
end;

procedure TPDFcontents.pCloseFillStrokeEO();
begin
 stream.WriteString('b* ');
end;

procedure TPDFcontents.pEnd();
begin
 stream.WriteString('n ');
end;

procedure TPDFcontents.pClip;
begin
 stream.WriteString('W ');
end;

procedure TPDFcontents.pClipEO;
begin
 stream.WriteString('W* ');
end;

procedure TPDFcontents.textType( t : TPDFvartypes );
begin
 if t = vtHexStr then
  begin
   ttype[1] := '<';
   ttype[2] := '>';
  end else
     begin
       ttype[1] := '(';
       ttype[2] := ')';
     end;
end;

procedure TPDFcontents.textOut( x,y : PDFint; text : string );
begin
 stream.WriteString( Format('BT /F%d %d Tf %d %d Td %s%s%s Tj ET ',[ self.txtoper.fid, self.txtoper.size, x, y, ttype[1], text, ttype[2] ]) );
end;

procedure TPDFcontents.textOut( x,y,s : PDFint; text : string );
begin
 stream.WriteString( Format('BT /F%d %d Tf %d %d Td %s%s%s Tj ET ',[ self.txtoper.fid, s, x, y, ttype[1], text, ttype[2] ]) );
end;

procedure TPDFcontents.beginText();
begin
 stream.WriteString('BT ');
end;

procedure TPDFcontents.textOut( text : string );
begin
 stream.WriteString( Format('%s%s%s Tj ',[ ttype[1],text,ttype[2] ]) );
end;

procedure TPDFcontents.endText();
begin
 stream.WriteString('ET ');
end;

procedure TPDFcontents.textLine( str : string );
begin
  if buflen  + length( str ) > width then
   {zapisz do strumienia}
 buffer := buffer + str;
end;

procedure TPDFcontents.flushText();
begin
 if buflen>0 then {zapisz do strumienia}
  buflen := 0;
end;

procedure TPDFcontents.setFontSize( size : PDFuint );
begin
 txtoper.size := size;
end;

procedure TPDFcontents.setCharSpacing( c : PDFint );
begin
 txtoper.chrSpace := c;
end;

procedure TPDFcontents.setWordSpacing( w : PDFint );
begin
 txtoper.wrdSpace := w;
end;

procedure TPDFcontents.setScaling( s : PDFuint);
begin
 txtoper.scale := s;
end;

procedure TPDFcontents.setLeading( l : PDFuint);
begin
 txtoper.leading := l;
end;

procedure TPDFcontents.setRenderMode( trm : TPDFTextRendering);
begin
 txtoper.render := trm;
end;

procedure TPDFcontents.setTextRise( r : PDFint );
begin
 txtoper.rise := r;
end;

procedure TPDFcontents.setFillColor( r,g,b : PDFushort );
begin
  if (r=g)and(r=b)and(b=g) then stream.WriteString( Format('%g g ',[ r / $FF ]) ) else
   stream.WriteString( Format('%g %g %g rg ',[ r / $FF, g / $FF, b / $FF ] ) );
end;

procedure TPDFcontents.setStrokeColor( r,g,b : PDFushort );
begin
  if (r=g)and(r=b)and(b=g) then stream.WriteString( Format('%g g ',[ r / $FF ]) ) else
   stream.WriteString( Format('%g %g %g RG ',[ r / $FF, g / $FF, b / $FF ] ) );
end;
{****************************************************** TPDFcontents ***********}






end.
