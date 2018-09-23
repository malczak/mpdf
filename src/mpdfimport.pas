(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                               mpdimport.pas
********************************************************
 unit description :            reading/decompressing and
                                    decrypting pdf files
********************************************************
 bugs :                                              ---
********************************************************
 other :
        14. XII. 2005 - TPDFimport -> TPDFimporter :)
        08. VII. 2005 -  first release
        21. XI. 2005 -  last update
********************************************************
 todo :
        -- obiekty tworzone sa takiego typu jaki maja
            one w plik czyli /Page -> TPDFpage
********************************************************)
unit mpdfimport;

interface
uses Classes,SysUtils,Dialogs,rc4md5,
     mpdfbase, mpdfvars, mpdfdoc, mpdfencrypt, mpdffonts, mpdfxobj, mpdffile, mpdfgraphics,
     zlibex;

{$IFDEF VER130}
 const
    soCurrent = soFromCurrent;
{$ENDIF}

type
  xrefentry = record
                offset,
                gennum : longword;
              end;

  TPDFimporter = class(TPDFbasevar)
               protected

                rc4key : string;
                strm : TFileStream;
                terminator : string;

                ido : TPDFobjid;
                idos : array of TPDFobjref;

                c : string[2];
                function readChar : char;
                function EOLN : boolean;
                function readLn_r : string;
                function readLn_l : string;
                function readWord( size : PDFuint=0 ) : string;
                function readValue : string;

                procedure readArray( aobj : TPDFarray );
                function readObject( pos : PDFuint ) : string;
                function scanDictionary( ename : string; var pos : PDFlong ) : boolean;
                procedure readDictionary( pos : PDFuint ); overload;
                procedure readDictionary( obj : TPDFobject ); overload;
                procedure readDictionary( obj : TPDFdictionary ); overload;
                procedure readStream( pos : PDFuint ); overload;
                procedure readStream( obj : TPDFstream ); overload;
                procedure readXRefTable;

                function isPdfFile( var linear : longint) : boolean;
                procedure findXRefTable;

                procedure storeObjRef( const bv : TPDFvariable );

                procedure d40bit(  userpass : string=''; ownerpass : string='' );
                procedure d128bit(  userpass : string=''; ownerpass : string='' );
                
               public
                outpdf : TPDFfile;
                removeMetadata,
                rebuildResources  : boolean;
                procedure rebuildPages;
                procedure Decrypt( userpass : string=''; ownerpass : string='' );
                procedure Import( fname : string ); virtual;
                function PagesCount : PDFuint; 
                function PDF : TPDFfile;
                constructor Create();
               end;

 TPDFtemplate = class( TPDFimporter )
                public
                  procedure copyContentsArray( var xform : TPDFxform; ca : TPDFarray );
                  function ImportPage( pno : PDFuint ) : TPDFxobject;
                public
                  tpls : TPDFarray;
                  constructor Create();
                  procedure MakeTemplate( fname : string );
                end;
var

  del,
  called :integer;

implementation

const
 restricted = [ char($0a), char($0d), ' ' ];

type
        TFA = class(TPDFfile) //internal use class to make all TPDFfile protected fields visible
                public
                 property pdftype_   : PDFushort read pdftype write pdftype;
                 property binary_    : PDFbool read binary write binary;
                 property catalog_   : TPDFcatalog read catalog write catalog;
                 property resources_ : TPDFresources read resources write resources;
                 property pages_     : TPDFpages read pages write pages;
                 property page_      : TPDFpagearray read page write page;
                 property fonts_     : TPDFcontainer read fonts write fonts;
                 property images_    : TPDFcontainer read images write images;
                 property xref_      : TPDFxreftable read xref write xref;
                 property trailer_   : TPDFtrailer read trailer write trailer;
                 property encrypted_ : PDFbool read encrypted write encrypted;
                 property encrypt_   : TPDFencryption read encrypt write encrypt;
                 procedure rp( po : TPDFobject );
                 constructor Create(); Overload;
                end;

constructor TFA.Create();
begin
// inherited Create();
 fname := md5( PDFnow );

 inherited Create( fname, fmCreate );

 catalog := nil;
 pages := nil;
 xref    := TPDFxreftable.Create;
 trailer := nil;
 resources := nil;

 info := TPDFinfo.Create;
 fonts := TPDFcontainer.Create;
 images := TPDFcontainer.Create;

 binary := false;
 encrypted := false;
 encrypt := nil;
 pdftype := 3;
 spage := nil;
 SetLength(page,0);
end;

procedure TFA.rp( po : TPDFobject );
var j : PDFuint;
    p : TPDFpage;
begin
 j := length( page );
 SetLength( page, j+1 );
 page[ j ] := TPDFpage( po );
 p := page[j];
 RegisterObject( p.GetCanvas );
end;


//**************************************************************** TPDFimporter
constructor TPDFimporter.Create();
begin
 inherited Create();
 mpdftype := mpdfImporter;
 removeMetadata := false;
 rebuildResources := false;
end;

function TPDFimporter.PDF : TPDFfile;
begin
 result := outpdf;
// outpdf := nil;
end;

function TPDFimporter.PagesCount : PDFuint;
begin
 result := outpdf.PagesCount;
end;

function TPDFimporter.readChar : char;
begin
 c[1] := c[2];
 strm.Read(c[2],1);
 result := c[2];
end;

function TPDFimporter.EOLN : boolean;
begin
  if length(terminator)=1 then
   result := ( terminator[1] = c[2] )
    else
       result := ( terminator = String(c) );
 result := result or ( (byte(c[1]) and byte(c[2]) = byte('>')) );
 result := result or ( (byte(c[1]) and byte(c[2]) = byte('<')) );
 result := result or ( ']' = c[2] );
 result := result or ( '[' = c[2] );
end;

function TPDFimporter.readLn_r : string;
var c : char;
begin
   result := '';
   c := #0;
    repeat
     c := readChar;
       if not (c in restricted) then
        result := result+c;
    until ( EOLN ) and ( result<>'');
end;

function TPDFimporter.readLn_l : string;
var c : char;
begin
   result := '';
   c := #0;
    repeat
     c := readChar;
     strm.Seek(-2,soCurrent);
       if not (c in restricted) then
         result := c + result;
    until ( EOLN ) and ( result<>'');
end;

function TPDFimporter.readWord( size : PDFuint ) : string;
var c : char;
    brakets : word;
    s : string;
begin
   s := '';

    repeat      //[rzeczytaj wszystkie znaki #10,#13,#32 przed wlasciwym slowem
     strm.Read(c,1);
    until not (c in restricted );
   strm.Seek(-1,soCurrent);

   repeat
     c := readChar;

      if c in restricted then continue;

      case c of
       '/' : begin //this char can seperate two strings !!
              if s<>'' then
               begin
                strm.Seek(-1,soCurrent);
                break;
               end;
              s := s + c;
             end;
       '(' : begin  // string begin
              if s <> '' then
               begin
                strm.Seek(-1,soCurrent);
                break;
               end;

               while c<>')' do
                begin
                 s := s + c;
                 c := readChar;
                  while c='\' do
                   begin
                    c := readChar;
                    s := s+'\'+c;
                    c := readChar;
                   end;
                end;
               s := s + ')';
               break;
             end;  // string end

       '<' : begin  // hexstring begin or '<<'
              if s <> '' then
               begin
                strm.Seek(-1,soCurrent);
                break;
               end;

              c := readChar;

               if c='<' then
                begin
                 s := '<<';
                 break;
                end;

               while c<>'>' do
                begin
                 s := s + c;
                 c := readChar;
                  while c='\' do
                   begin
                    c := readChar;
                    s := s+'\'+c;
                    c := readChar;
                   end;
                end;
               s := '<' + s + '>';
               break;
             end;  // hexstring end or '<<'

       '[',        //array [/] begin
       ']' : begin
              if s <> '' then
               begin
                strm.Seek(-1,soCurrent);
                break;
               end;

              s := c;
              break;
             end; //array [/] end       ]

       '>' : begin
              if s <> '' then
               begin
                strm.Seek(-1,soCurrent);
                break;
               end;

              c := readChar;

               if c='>' then
                begin
                 s := '>>';
                 break;
                end;
               s := '>'+c;
             end;

        else s := s + c;

      end;
   until ( ( EOLN or (c=' ') )and(size=0) ) or ( (size>0)and(length(s)=size) );;
 result := s;
end;

function TPDFimporter.readValue : string;
var s1,s2 : string;
    c : char;
    pos : int64;
begin
 pos := strm.Position;
 s1 := readWord;
 s2 := readWord;
 c := readChar;
  if c = 'R' then
   begin  //indirect object
    ido := (StrToInt(s2) shl 16) + StrToInt(s1);
    result := 'ido';
    Inc(called);
   end else
     begin //entry or regular (direct) value
       strm.Seek( pos, soFromBeginning );
       result := readWord;
      end;
end;

function TPDFimporter.isPdfFile( var linear : longint) : boolean;
var buffer : string;
begin
 buffer := '        ';
 terminator := '  ';
 strm.Read( buffer[1], 8);
 result := ( Copy(buffer,1,5)='%PDF-' );
 strm.Read( terminator[1], 2 );
  if terminator <> String(Char($0A)+Char($0D)) then
   SetLength(terminator,1);
  //check if file is linearized pdf
 SetLength( buffer, 1024-strm.Position );
 strm.Read( buffer[1], length(buffer) );
 linear := Pos('Linearized', buffer );
  if linear > 0 then
   begin
     while not (buffer[1] in ['0'..'9'] ) do
      Delete( buffer, 1, 1 );
    linear := StrToInt( Copy( buffer, 1, Pos(' ',buffer)-1 ) )-1;
   end else linear := -1;
 SetLength(buffer,0);
end;

procedure TPDFimporter.findXRefTable;
var s : string;
    c : char;
begin
 strm.Seek( 0, soFromEnd	);
 s := '';
  repeat
   strm.Read( c, 1 );
   strm.Seek( -2, soCurrent );
    if (c in [ '%', 'E', 'O', 'F' ] ) then
     s := c + s;
  until s='%%EOF';
 strm.Seek( StrToInt( readLn_l ), soFromBeginning  );
end;

procedure TPDFimporter.storeObjRef( const bv : TPDFvariable );
var last : word;
    obj : TPDFobject;
begin
  if bv<>nil then
   begin
    last := Length( idos );
    SetLength( idos, last+1 );
    idos[ last ] := TPDFobjref( bv );
   end;
end;

procedure TPDFimporter.readArray( aobj : TPDFarray );
var s : string;
    bv : TPDFvariable;
    objr : TPDFobjref;
begin
  if ReadWord='[' then
   while true do
    begin
     s := readValue;
        if s='[' then
         begin
          strm.Seek(-1,soCurrent);
          bv := TPDFarray.Create;
          readArray( TPDFarray(bv) );
         end else
                begin
                  if s=']' then break;
                  if s = 'ido' then
                    begin
                      bv := TPDFobjref.Create( TPDFobject( Pointer(ido) ) );
                      storeObjRef( bv );
//                      bv := TPDFobjref.Create( TPDFobject( Pointer(ido) ) );
//                      idos.push( bv );
                    end else
                         bv := TPDFbasevar.Create(s,vtDefStr);
                end;
     aobj.push( bv );
     bv := nil;
    end;
end;

function TPDFimporter.scanDictionary( ename : string; var pos : PDFlong ) : boolean;
var s : string;
    i  : int64;
    entry : string;
    bv : TPDFvariable;
    objr : TPDFobjref;
begin
 i := strm.Position;

   if readWord( 2 ) <> '<<' then raise Exception.Create('Dictionary parsing error'); //dictionary start '<<'

 ename := '/'+ename;
 pos := 0;
 result := false;

  repeat
   s := readWord;

   if CompareStr( s, ename )=0 then
    begin
     pos := strm.Position;
     result := true;
     break;
    end;

  until CompareStr( s, '>>')=0;

 strm.Seek(i,soFromBeginning);
end;

procedure TPDFimporter.readDictionary( obj : TPDFdictionary );
var s : string;
    i  : int64;
    entry : string;
    bv : TPDFvariable;
    objr : TPDFobjref;
begin
   if readWord( 2 ) <> '<<' then raise Exception.Create('Dictionary parsing error'); //dictionary start '<<'

   while true do
   begin
    s := readValue; // entry
     if s='>>' then break;
    entry := Copy(s,2,Length(s)-1);
    i := strm.Position;
    s := readValue; //entry's value

      if s='[' then //array
       begin
        strm.Seek(i,soFromBeginning);
        bv := TPDFarray.Create;
        readArray( TPDFarray(bv) );
       end else
            if s='<<' then
             begin
              strm.Seek(i,soFromBeginning);
              bv := TPDFdictionary.Create;
              readDictionary( TPDFdictionary(bv) );
             end else
              if s[1]='/' then
                bv := TPDFbasevar.Create( Copy(s,2,Length(s)-1), vtName )
                 else
                    if s = 'ido' then
                     begin
                      bv := TPDFobjref.Create( TPDFobject( Pointer(ido) ) );
                      storeObjRef( bv );
//                      bv := TPDFobjref.Create( TPDFobject( Pointer(ido) ) );
//                      idos.push( bv );
                     end else
                        bv := TPDFbasevar.Create( s,vtDefStr);
    obj.addEntry( entry, bv, true );
    bv := nil;
   end;
end;

procedure TPDFimporter.readDictionary( obj : TPDFobject );
begin
 readDictionary( TPDFdictionary( obj.Dictionary ) );
end;

procedure TPDFimporter.readDictionary( pos : PDFuint );
begin
 readDictionary( TPDFobject( TFA(outpdf).xref_[ pos ] ) );
end;

function TPDFimporter.readObject( pos : PDFuint ) : string;
var strmpos,p1,p2 : int64;
    s : string;
    o : xrefentry;
    obj : TPDFobject;
    bv : TPDFvariable;
begin
   result := '';
   obj := TFA(outpdf).xref_[ pos ];
    if obj = nil then exit;
   strmpos := strm.Position;
   //wszystko od 'obj' do 'endobj' wczytac do strumienia
   strm.Seek( obj.objpos, soFromBeginning );
   o.offset := StrToInt( readWord );
   o.gennum := StrToInt( readWord );
    if readWord = 'obj' then //odczyt obiektu
     begin
       //sprawdz czy to aby nie jest 'dictionary'
       p1 := strm.Position;
       s := readWord(2);
       strm.Seek( p1, soFromBeginning );
        if s='<<' then  //wszytaj object's dictionary a po nim sprawdz czy nie ma przypadkiem strumienia
         begin
           TFA(outpdf).xref_[ pos ] := TPDFobject.Create;
           TPDFobject( TFA(outpdf).xref_[pos] ).setObjectId( o.offset, o.gennum );
           readDictionary( pos );
            bv := TPDFbasevar( TPDFobject( TFA(outpdf).xref_[pos] ).Dictionary['Type'] );
             if bv<>nil then result := TPDFbasevar(bv).asString;
           //proboj wczytac strumien
           p1 := strm.Position;
           s := readWord;
           strm.Seek( p1, soFromBeginning );
            if s = 'stream' then
             begin
               //:) to musze jakos kuffa zmienic
               obj := TPDFstream.Create;
               obj.setObjectId( o.offset, o.gennum );
               TPDFobject(obj).setVariable( TPDFobject(TFA(outpdf).xref_[pos]).Dictionary );
               TPDFobject(TFA(outpdf).xref_[pos]).setVariable( nil );
               TPDFstream(obj).Dictionary.addEntry('StrmPos' , 1.0*strm.Position );
               TFA(outpdf).xref_[pos] := obj;

               Inc(del);
//               readStream( pos );
             end;
           //sprawdz czy strumien
         end else
                 begin //kurwa tutaj sie zawiesilem ?! choc moze zadziala
                  p1 := strm.Position;
                   if ReadChar = '[' then
                    begin
                     strm.Seek( -1, soCurrent );
                     bv := TPDFarray.Create;
                     readArray( TPDFarray(bv) );
                    end  else
                            begin
                                 repeat
                                  p2 := strm.Position;
                                  s := readLn_r
                                 until s = 'endobj';
                              p2 := (p2-p1);
                              SetLength( s, p2 );
                              strm.Seek( p1, soFromBeginning );
                              strm.Read( s[1], p2 );
                              bv := TPDFbasevar.Create(s,vtDefStr);
                              SetLength(s,0);
                            end;
                   //strawdz co tu jest :D
                  obj.setObjectId( o.offset, o.gennum );
                  obj.setVariable( bv );
                 end;
      end;
   strm.Seek( strmpos, soFromBeginning );
end;


procedure TPDFimporter.readStream( pos : PDFuint );
var s : TPDFstream;
begin
 s := TPDFstream( TFA(outpdf).xref_[ pos ] );
 readStream( s );
end;

procedure TPDFimporter.readStream( obj : TPDFstream );
var len : TPDFvariable;
    todel : TPDFvariable;
    l : longword;
    s : string;
begin
 if readWord = 'stream' then
  begin
   if c[2] = char($0d) then readChar; // po stream moze byc : CRLF lub LF (zadne inne zakonczenie)

   len := TPDFbasevar( obj.Dictionary['Length'] );
    if len = nil then exit;
    if len is TPDFobjref then
     begin
      len := TPDFobjref(len).v;
      TFA(outpdf).xref_.Delete( TPDFobject(len) );
      s := TPDFbasevar( TPDFobject(len).getVariable ).asString;
      len := obj.Dictionary.clearEntry('Length');
      FreeAndNil( TPDFobjref(len).v );
      FreeAndNil( len );
       l:=1;
        while s[l] in ['0'..'9'] do
         inc(l);
      l := StrToInt( Copy(s,1,l-1) );
      obj.Dictionary['Length'] := TPDFbasevar.Create( PDFint( l ) );
     end else
            begin
              s := TPDFbasevar(len).asString;
              l := StrToInt( s );
              TPDFbasevar(len).asInt := l;
              TPDFbasevar(len).vartype := vtInt;
            end;

   obj.stream.CopyFrom( strm, l );
//   obj.Dictionary.addEntry('Length', TPDFbasevar.Create(obj.stream.Size), true );
  end;
end;

procedure TPDFimporter.readXRefTable;
var s        : string;
    c        : char;
    i, all,
    beg      : word;
    xr       : xrefentry;
    obj      : TPDFobject;
    first    : boolean;
    xrefend  : boolean;
    prev     : PDFlong;
begin
 xrefend := false;

  repeat

    if  readLn_r <> 'xref' then raise Exception.Create('Not a xref table entry');

     repeat

      try
        s := readWord;
         if s = 'trailer' then break;
        beg := StrToInt( s );
        all := StrToInt( readWord );
        i := TFA(outpdf).xref_.Count;
  //       if (( beg<>0 ) and ( xref.count<beg ))or( beg or xref.count =0 )  then
         if ( (beg+all)>TFA(outpdf).xref_.count )or( beg or TFA(outpdf).xref_.count =0 )  then
          TFA(outpdf).xref_.setLength( beg+all );
        for i:=beg to beg+all-1 do
         begin
          xr.offset := StrToInt64( readWord );
          xr.gennum := StrToInt64( readWord );
           if readWord[1]='n' then
            if TFA(outpdf).xref_[i-1]=nil then
             begin
               obj := TPDFobject.Create(nil);
               obj.objpos := xr.offset;
               TFA(outpdf).xref_[i-1] := obj;
             end;
         end;
      except
       MessageDlg('Error reading xref table',mtError,[mbOK],0);
      end;

     until false;

   xrefend := not scanDictionary( 'Prev', prev );

     if TFA(outpdf).trailer_ = nil then
      begin
        TFA(outpdf).trailer_ := TPDFtrailer.Create;
{        readDictionary( TFA(outpdf).trailer_.Dictionary);
        TFA(outpdf).encrypted_ := TFA(outpdf).trailer_.Dictionary['Encrypt'] <> nil;
          if xrefend=false then TFA(outpdf).trailer_.Dictionary.deleteEntry('Prev');}
        readDictionary( TFA(outpdf).trailer_);
        TFA(outpdf).encrypted_ := TFA(outpdf).trailer_['Encrypt'] <> nil;
          if xrefend=false then TFA(outpdf).trailer_.deleteEntry('Prev');
      end;

    if xrefend = false then
     begin
        strm.Seek( prev, soFromBeginning );
        strm.Seek( StrToInt(readWord), soFromBeginning );
     end;


 until xrefend = true;

end;
(*
procedure TPDFimporter.addResource( obj : TPDFobject; rtype : TPDFrestype );
var r : TPDFvariable;
begin
// if resources<>nil then
//  resources.addResource( obj, rtype )
//   else
     if spage<>nil then
     begin
      r := spage.Dictionary['Resources'];
        if r=nil then exit;
      if r is TPDFobjref then
       //if r.getType = mpdfObjref then
        r := TPDFdictionary( TPDFobject(TPDFobjref(r).v).Dictionary );
         case obj.getType of
//          mpdfXObject,
          mpdfImage   : TPDFdictionary( TPDFdictionary(r)['XObject'] ).AddEntry( Format('mIm%d',[ TPDFimage(obj).ID ]), TPDFobjref.Create( obj ) );
          mpdfForm    : begin
                         if TPDFdictionary(r)['XObject']=nil then TPDFdictionary(r).addEntry('XObject', TPDFdictionary.Create );
                          TPDFdictionary( TPDFdictionary(r)['XObject'] ).AddEntry( Format('mtpl%d',[ TPDFimage(obj).ID ]), TPDFobjref.Create( obj ) );
                        end;
          mpdfFont    : TPDFdictionary( TPDFdictionary(r)['Font'] ).AddEntry( Format('mF%d',[ TPDFfont(obj).fid ]), TPDFobjref.Create( obj ) );
       end;
     end;
end;
*)

{procedure TPDFimporter.Decrypt( userpass : string; ownerpass : string );
var i : word;
    fid : string;
    ep  : word;
    encrypt : TPDFobject;
    up,
    o,
    u,
    s    : string;
    p    : longword;
    myup : string;

     function getString( s : string ) : string;
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

begin
 if not TFA(outpdf).encrypted_ then exit;
  encrypt := TPDFobjref(TFA(outpdf).trailer_.Dictionary['Encrypt']).v;

  fid := TPDFbasevar( TPDFarray( TFA(outpdf).trailer_.Dictionary.EntryAsArray['ID'] )[0] ).asString;
  i := Pos('<',fid)+1;
  fid := Copy(fid,i,Pos('>',fid)-i);
  fid := Pack( fid );

    if length(userpass)>0 then up := Copy( userpass+String(pdfpadding), 1, 32 ) else
     up := String( pdfpadding );

   p := StrToInt(  TPDFbasevar(encrypt.Dictionary['P']).asString );
   s := chr(p)+chr(p shr 8)+chr(p shr 16)+chr(p shr 24);
   o := getString( TPDFbasevar(encrypt.Dictionary['O']).asString );
   s  := up+o+s+fid;
   s := md5(s);
   rc4key := pack(s);
   rc4key := copy( rc4key, 1, 5 );
//   rc4key := copy( rc4key, 1, 16 );
   u  := getString( TPDFbasevar(encrypt.Dictionary['U']).asString );
   myup := rc4( String( pdfpadding ), rc4key );
    if CompareStr( myup, u ) = 0 then
     begin
      i := 0;
        while i < TFA(outpdf).xref_.count-1 do
         begin
           if TFA(outpdf).xref_[i] is TPDFstream then
              begin
               s := TPDFstream(TFA(outpdf).xref_[i]).stream.DataString;
               TPDFstream(TFA(outpdf).xref_[i]).stream.size := 0;
                try
                 myup := rc4key + Format('%.1s%.1s%.1s%.1s%.1s',[ Char(TPDFstream(TFA(outpdf).xref_[i]).getObjectNum),Char(TPDFstream(TFA(outpdf).xref_[i]).getObjectNum shr 8),
                                                                  Char(TPDFstream(TFA(outpdf).xref_[i]).getObjectNum shr 16),Char(TPDFstream(TFA(outpdf).xref_[i]).getGenerateNum),
                                                                  Char(TPDFstream(TFA(outpdf).xref_[i]).getGenerateNum shr 8) ] );
                 myup := copy( pack( md5( myup ) ), 1, 10 );
//                 myup := copy( pack( md5( myup ) ), 1, 32 );
                 s := rc4(s,myup);
                  if TPDFstream(TFA(outpdf).xref_[i]).Dictionary['Filter']<>nil then
                   begin
//                    s := ZDecompressStr(s);
//                    TPDFstream( TFA(outpdf).xref_[i] ).Dictionary.deleteEntry('Filter');
                   end;
                  TPDFstream(TFA(outpdf).xref_[i]).stream.WriteString( s );
                except
                 TPDFstream(TFA(outpdf).xref_[i]).stream.WriteString( rc4(s,myup) );
                end
             end;
          inc(i);
         end;
     TFA(outpdf).encrypted_ := false;
     TFA(outpdf).trailer_.Dictionary.deleteEntry('Encrypt');
     TFA(outpdf).xref_.Delete( encrypt );
     FreeAndNil( encrypt );
    end;
end;}

procedure TPDFimporter.d40bit(  userpass : string; ownerpass : string );
var i : word;
    fid : string;
    ep  : word;
    encrypt : TPDFobject;
    up,
    o,
    u,
    s    : string;
    p    : longword;
    myup : string;
begin
  encrypt := TPDFobjref(TFA(outpdf).Trailer['Encrypt']).v;
//  encrypt := TPDFobjref(TFA(outpdf).Trailer.Dictionary['Encrypt']).v;

//  fid := TPDFbasevar( TPDFarray( TFA(outpdf).Trailer.Dictionary.EntryAsArray['ID'] )[0] ).asString;
  fid := TPDFbasevar( TPDFarray( TFA(outpdf).Trailer.EntryAsArray['ID'] )[0] ).asString;
  i := Pos('<',fid)+1;
  fid := Copy(fid,i,Pos('>',fid)-i);
  fid := PDFpack( fid );

    if length(userpass)>0 then up := Copy( userpass+String(pdfpadding), 1, 32 ) else
     up := String( pdfpadding );

   p := StrToInt(  TPDFbasevar(encrypt.Dictionary['P']).asString )  ;
   s := chr(p)+chr(p shr 8)+chr(p shr 16)+chr(p shr 24);
   o := PDFgetstring( TPDFbasevar(encrypt.Dictionary['O']).asString );
   s := up+o+s+fid;
   rc4key := PDFpack( md5(s) );
   rc4key := copy( rc4key, 1, 5 );
   u  := PDFgetstring( TPDFbasevar(encrypt.Dictionary['U']).asString );
   myup := rc4( String( pdfpadding ), rc4key );
    if CompareStr( myup, u ) = 0 then
     begin
      i := 0;
        while i < TFA(outpdf).xref.count-1 do
         begin
           if TFA(outpdf).xref[i] is TPDFstream then    // nie sa rozkodowywane teksty np z 'Outlines'
              begin
               s := TPDFstream(TFA(outpdf).xref[i]).stream.DataString;
               TPDFstream(TFA(outpdf).xref[i]).stream.size := 0;
                try
                 myup := rc4key + Format('%.1s%.1s%.1s%.1s%.1s',[ Char(TPDFstream(TFA(outpdf).xref[i]).getObjectNum),Char(TPDFstream(TFA(outpdf).xref[i]).getObjectNum shr 8),
                                                                  Char(TPDFstream(TFA(outpdf).xref[i]).getObjectNum shr 16),Char(TPDFstream(TFA(outpdf).xref[i]).getGenerateNum),
                                                                  Char(TPDFstream(TFA(outpdf).xref[i]).getGenerateNum shr 8) ] );
                 myup := copy( PDFpack( md5( myup ) ), 1, 10 );
//                 myup := copy( pack( md5( myup ) ), 1, 32 );
                 s := rc4(s,myup);
                  if TPDFstream(TFA(outpdf).xref[i]).Dictionary['Filter']<>nil then
                   begin
//                    s := ZDecompressStr(s);
//                    TPDFstream( xref[i] ).Dictionary.deleteEntry('Filter');
                   end;
                  TPDFstream(TFA(outpdf).xref[i]).stream.WriteString( s );
                except
                 TPDFstream(TFA(outpdf).xref[i]).stream.WriteString( rc4(s,myup) );
                end
             end;
          inc(i);
         end;
     TFA(outpdf).encrypted := false;
//     TFA(outpdf).trailer.Dictionary.deleteEntry('Encrypt');
     TFA(outpdf).trailer.deleteEntry('Encrypt');
     TFA(outpdf).xref.Delete( encrypt );
     FreeAndNil( encrypt );
    end else raise Exception.Create('Unknown encryption method');
end;

procedure TPDFimporter.d128bit(  userpass : string; ownerpass : string );
var i : word;
    fid : string;
    ep  : word;
    encrypt : TPDFobject;
    up,
    o,
    u,
    s    : string;
    p    : longword;
    myup : string;
begin
  encrypt := TPDFobjref(TFA(outpdf).Trailer['Encrypt']).v;
//  encrypt := TPDFobjref(TFA(outpdf).Trailer.Dictionary['Encrypt']).v;

//  fid := TPDFbasevar( TPDFarray( TFA(outpdf).Trailer.Dictionary.EntryAsArray['ID'] )[0] ).asString;
  fid := TPDFbasevar( TPDFarray( TFA(outpdf).Trailer.EntryAsArray['ID'] )[0] ).asString;
  i := Pos('<',fid)+1;
  fid := Copy(fid,i,Pos('>',fid)-i);
  fid := PDFpack( fid );

    if length(userpass)>0 then up := Copy( userpass+String(pdfpadding), 1, 32 ) else
     up := String( pdfpadding );

   p := StrToInt(  TPDFbasevar(encrypt.Dictionary['P']).asString )  ;
   s := chr(p)+chr(p shr 8)+chr(p shr 16)+chr(p shr 24);
   o := PDFgetstring( TPDFbasevar(encrypt.Dictionary['O']).asString );
   rc4key := up+o+s+fid;// + chr($FF)+chr($FF)+chr($FF)+chr($FF); //ten dodatek jak MetaData nie jest kodowane ?!?!
    for i:=1 to 51 do
     rc4key := PDFpack( md5(rc4key) );
   rc4key := copy( rc4key, 1, 16 );
   u  := copy( PDFgetstring( TPDFbasevar(encrypt.Dictionary['U']).asString ), 1, 16 );
    {128bit}
   s := string( pdfpadding ) + fid;
   myup := rc4( PDFpack( md5(s) ), rc4key );
   o := rc4key;
    for i := 1 to 19 do
     begin
       for ep:=1 to length(rc4key) do
        o[ep] := chr( byte(rc4key[ep]) xor byte(i) );
      myup := rc4( myup, o );
     end;
    {128bit}
    if CompareStr( myup, u ) = 0 then
     begin
      i := 0;
        while i < TFA(outpdf).xref.count-1 do
         begin
           if TFA(outpdf).xref[i] is TPDFstream then
              begin
               s := TPDFstream(TFA(outpdf).xref[i]).stream.DataString;
               TPDFstream(TFA(outpdf).xref[i]).stream.size := 0;
                try
                 myup := rc4key + Format('%.1s%.1s%.1s%.1s%.1s',[ Char(TPDFstream(TFA(outpdf).xref[i]).getObjectNum),Char(TPDFstream(TFA(outpdf).xref[i]).getObjectNum shr 8),
                                                                  Char(TPDFstream(TFA(outpdf).xref[i]).getObjectNum shr 16),Char(TPDFstream(TFA(outpdf).xref[i]).getGenerateNum),
                                                                  Char(TPDFstream(TFA(outpdf).xref[i]).getGenerateNum shr 8) ] );
                 myup := copy( PDFpack( md5( myup ) ), 1, 16 );
//                 myup := copy( pack( md5( myup ) ), 1, 32 );
                 s := rc4(s,myup);
                  if TPDFstream(TFA(outpdf).xref[i]).Dictionary['Filter']<>nil then
                   begin
//                    s := ZDecompressStr(s);
//                    TPDFstream( xref[i] ).Dictionary.deleteEntry('Filter');
                   end;
                  TPDFstream(TFA(outpdf).xref[i]).stream.WriteString( s );
                except
                 TPDFstream(TFA(outpdf).xref[i]).stream.WriteString( rc4(s,myup) );
                end
             end;
          inc(i);
         end;
     TFA(outpdf).encrypted := false;
//     TFA(outpdf).trailer.Dictionary.deleteEntry('Encrypt');
     TFA(outpdf).trailer.deleteEntry('Encrypt');
     TFA(outpdf).xref.Delete( encrypt );
     FreeAndNil( encrypt );
    end else raise Exception.Create('Unknown encryption method');
end;

procedure TPDFimporter.Decrypt( userpass : string; ownerpass : string );
var i : word;
    fid : string;
    ep  : word;
    encrypt : TPDFobject;
    up,
    o,
    u,
    s    : string;
    p    : longword;
    myup : string;
begin
 if not TFA(outpdf).encrypted then exit;
//  encrypt := TPDFobjref(TFA(outpdf).Trailer.Dictionary['Encrypt']).v;
  encrypt := TPDFobjref(TFA(outpdf).Trailer['Encrypt']).v;

  if encrypt.Dictionary['Length']<>nil then
   begin
    case TPDFbasevar( encrypt.Dictionary['Length'] ).asInt of
      40 :    d40bit( userpass, ownerpass );
     128 :    d128bit( userpass, ownerpass );
    end;
   end else d40bit( userpass, ownerpass );

end;


procedure TPDFimporter.Import( fname : string );
var i,j,k    : PDFuint;
    linear   : longint;
    pos      : int64;
    todel,bv : TPDFvariable;
    objtype  : string;
    sido,
    sidol    : ^TPDFobjref;
    tmpobj   : TPDFobject;
    o : TFA;
begin
 o := TFA.Create;
 outpdf := o;

 strm := TFileStream.Create( fname, fmOpenRead );

  try
    if not isPdfFile(linear) then raise Exception.Create('Not a PDF file');
   findXrefTable;
   readXRefTable;
   i:=0;
    while i < TFA(outpdf).xref_.count-1 do
     begin
      objtype := readObject( i );

      //************************************ handle special objects
      if objtype = 'Pages' then //w tablicy KIDS sa tez ido do innych obiektow PAGES zatem nalezy to uwzglednic w celu otrzymania prawidlowej kolejnosci stron (wyjsciem jest odtworzenie struktury drzewa)
          begin
             if TPDFobject(TFA(outpdf).xref_[i]).Dictionary['Parent']=nil then
            TFA(outpdf).pages_ := TPDFpages( TFA(outpdf).xref_[i] );
          end
      else
        if objtype = 'Catalog' then
          begin
            TFA(outpdf).catalog_ := TPDFcatalog( TFA(outpdf).xref_[i] )
          end
      else
        if objtype = 'Page' then
          begin
            tmpobj := TPDFpage.Create( TFA(outpdf).xref_[i].clearVariable );;
              //zadbaj o to zeby 'Contents' bylo PDFarray
            bv := tmpobj.Dictionary['Contents'];
              if bv.getType = mpdfObjref then
                 tmpobj.Dictionary.exchangeEntry( 'Contents', TPDFarray.Create( [bv] ) );
            TFA(outpdf).xref_[i] := tmpobj;
          end

       else
        if removeMetadata then
         if objtype = 'Metadata' then
          begin
           todel := TFA(outpdf).xref_[i];
           FreeAndNil( todel );
           TFA(outpdf).xref_.Delete( i );
          end
       else
        if i = linear then //wlasnie odczytano /Linearized
         begin
          todel := TFA(outpdf).xref_[i];
          FreeAndNil( todel );
          TFA(outpdf).xref_.Delete( i );
         end;
      //************************************ handle special objects

      Inc(i);
     end;

     //update IDO objects
    sido := @idos[0];
    sidol := @idos[ Length(idos)-1 ];
     repeat
       i := Word( LongInt( Pointer(sido^.v) ) )-1;
         if i < TFA(outpdf).xref_.Count then   //zrobic tak zeby nie bylo tego bledu
           sido^.v := TFA(outpdf).xref_[ i ];
       Inc( sido );
     until LongWord( Pointer(sido) ) > LongWord( Pointer(sidol) );

    i := 0;
     //po wczytaniu obiektow wczytaj strumienie (dlaczego tak ? bo teraz mozna juz korzystac z indirect objects a nich moga byc trzymane informacje o dlugosci strumieni !)
    while i < TFA(outpdf).xref_.Count-1 do
     begin
       if TFA(outpdf).xref_[i] is TPDFstream then
        begin
          pos := Trunc( TPDFbasevar( TPDFstream(TFA(outpdf).xref_[i]).Dictionary.Entry['StrmPos'] ).asFloat );
          TPDFstream(TFA(outpdf).xref_[i]).Dictionary.deleteEntry('StrmPos');
          strm.Seek( pos, soFromBeginning );
//          readStream( TPDFstream( TFA(outpdf).xref_[i] )  );
(*           if TPDFstream(TFA(outpdf).xref_[i]).Dictionary.Entry['Type']<>nil then
            if TPDFbasevar( TPDFstream(TFA(outpdf).xref_[i]).Dictionary.Entry['Type'] ).asString = 'XObject' then
             begin
          readStream( i  );
             end else      *)
          readStream( i  );
         end;
      inc(i);
     end;


  finally
   strm.Destroy;
   //idos.Destroy;
   SetLength( idos, 0 );
  end;
end;

(*
procedure TPDFimporter.Save;
var buffer : string;
    obj    : TPDFobject;
    i      : word;
    bv     : TPDFvariable;
begin
   i:=0;
  if rebuildResources then
   begin
     resources.addProcSet( pText );
     resources.addProcSet( pImageC );
     resources.addProcSet( pImageB );
     xref.Push( resources )
   end else FreeAndNil( resources );

  if removeMetadata then
    Catalog.Dictionary.deleteEntry('Metadata');

 //calculate trailers ID entry (only time and info entries)
 buffer := PDFnow + info.Author + info.Title + info.Subject + info.Keywords + info.Creator + info.ModDate;
 buffer := md5( buffer );
 trailer.Dictionary.addEntry('ID', TPDFarray.Create([ TPDFbasevar.Create('<'+buffer+'>',vtDefStr), TPDFbasevar.Create('<'+buffer+'>',vtDefStr) ]), true );
   if encrypted then //encryption is now PART of xref object (for object encode simplicity)
    begin
     buffer := TPDFbasevar( TPDFarray(trailer.Dictionary['ID'])[0] ).asString;
     buffer := Copy( buffer, 2, length(buffer)-2 );
     encrypt.Init( buffer );
     xref.push( encrypt );
     trailer.Dictionary.addEntry('Encrypt', TPDFobjref.Create( encrypt ) );
    end;                       
//info obj add as a last object
 bv := trailer.Dictionary['Info'];
 TFA(outpdf).xref_[ TPDFobject( TPDFobjref(bv).v ).getObjectNum-1 ] := info;
 TPDFobjref(bv).v := info;
//header
 PDFwritestring( self,  pdfHeader, [ pdftype ] );
  if binary then PDFwritestring( self, pdfBinary );
//save all objects (with obj num fix)
 xref.SaveObjects( self, encrypt );
//save cross-referance table
 xref.SaveToStream( self );
//trailer
 trailer.Dictionary.AddEntry('Size', TPDFbasevar.Create( xref.SavedCount+1 ), true );
 trailer.Dictionary.AddEntry('Root', TPDFobjref.Create(Catalog), true );
 trailer.xrefpos := xref.objpos;
 trailer.SaveToStream( self );
 PDFwritestring( self, pdfEof );
// MessageBox( 0, PChar('file saved !'), PChar('Save dialog'), MB_OK );
end;
*)
procedure TPDFimporter.rebuildPages;
var
 stack : array of TPDFpages;
 ps   : TPDFpages;
 pref  : TPDFarray;
 i,firstc,
 actualc : PDFulong;
 obj : TPDFobject;
 //resource rebuild
 j,k : PDFuint;
 bv, evalue : TPDFvariable;
 ename : string;
 r : TPDFdictionary;
begin
    if rebuildResources then TFA(outpdf).resources_ := TPDFresources.Create;
 //lecimy po PAGES.KIDS, jak znajdziemy objekt typu PAGES to na stos to co teraz i plum
 ps := TFA(outpdf).pages_; //root pages object
 pref := TFA(outpdf).pages_.Dictionary.EntryAsArray['Kids'];
 firstc := pref.Count;
 actualc := firstc;
 i := 0;

 while (i<firstc) or (length(stack)<>0) do
  begin
   obj := TPDFobjref(pref[i]).v;

    if TPDFbasevar( obj.Dictionary['Type'] ).asString = 'Page' then
     begin
      TFA(outpdf).rp( obj );

       //rebuild resources - start
            if rebuildResources then
             begin
              bv := TPDFpage(obj).Dictionary['Resources'];
//                if bv = nil then raise Exception.Create('PDF parse error (resources=nil)');
               if bv<>nil then
                begin

                 if bv is TPDFobjref then
                  begin
                   TFA(outpdf).xref_.Delete( TPDFobjref(bv).v ); //usun z xref
                   r := TPDFdictionary( TPDFobjref(bv).v.clearVariable );
                   FreeAndNil( TPDFobjref(bv).v );
                   TPDFobjref(bv).v := TFA(outpdf).resources_;
                  end else
                          begin
                            r := TPDFdictionary( bv );
                            TPDFpage(obj).Dictionary.exchangeEntry('Resources', TPDFobjref.Create( TFA(outpdf).resources_ ) )
                          end;

                  for j:=1 to 7 do               // resource types
                    begin
                      bv := r[ PDFresourcedics[j] ];
                       if bv = nil then continue;
                       if TPDFdictionary( bv ).Count=0 then continue;
                      k := 0;
                       while k < TPDFdictionary( bv ).Count do
                        begin
                         evalue := TPDFdictionary( bv ).clearEntry( k, ename );
                         TPDFdictionary( TFA(outpdf).resources_.Dictionary[ PDFresourcedics[j] ] ).addEntry( ename,  evalue, true );
                         Inc(k);
                        end;
                   end;
                  FreeAndNil( r ); //usun stary obiekt z zasobami dla strony

                end //bv = nil
              end; //rebuilResources
       //rebuild resources - stop

     end

    else

     begin  //jak nie PAGE to PAGES
      ps.objpos := i+1;
      SetLength( stack, length(stack)+1 );
      stack[ length(stack)-1 ] := TPDFpages( ps );
      ps := TPDFpages(obj);
      i := 0;
      pref := ps.Dictionary.EntryAsArray['Kids'];
      actualc := pref.Count;
      continue;
     end;

   inc( i );
      while (length(stack)>0) and (i>=actualc) do
          begin
            ps := stack[ length(stack)-1 ];
            SetLength( stack, Length(stack)-1 );
            i := ps.objpos;
            pref := ps.Dictionary.EntryAsArray['Kids'];
            actualc := pref.Count;
          end;
  end;
end;

//**************************************************************** TPDFtemplate

constructor TPDFtemplate.Create();
begin
 inherited;
 mpdftype := mpdfTemplate;
end;

procedure TPDFtemplate.MakeTemplate( fname : string );
begin
 RemoveMetadata := true;
// RebuildResources := true;
 Import( fname );
 Decrypt();
 RebuildPages;
    if TFA(outpdf).resources_ = nil then
     TFA(outpdf).resources_ := TPDFresources.Create;
end;

procedure TPDFtemplate.copyContentsArray( var xform : TPDFxform; ca : TPDFarray );
var cidx, i : PDFuint;
    filters : TPDFvariable;
    fname : string;
    s : string;
    ss : TStringStream;
    error : PDFbool;
    c : TPDFcontents;
begin
 error := false;
 ss := TStringStream.Create('');
  for cidx:=0 to ca.count-1 do
   begin
    c := TPDFcontents( TPDFobjref( ca[cidx] ).v );

//                     xform.CopyFrom( TPDFstream( TPDFobjref( TPDFarray( c )[i] ).v ), 0 );

     filters := c.Dictionary.EntryAsArray['Filter'];
      if filters<>nil then
       begin
        error := true;
                 if filters.getType=mpdfArray then
                  if TPDFarray( filters ).Count = 1 then
                   filters := TPDFarray(filters)[0];
         if TPDFbasevar( filters ).asString = 'FlateDecode' then
          begin
            error := false;
             ss.Size := 0;
             ss.CopyFrom( c.stream, 0 );
             SetLength(s, c.stream.Size );
             s := ss.DataString;
             s := ZDecompressStr(s);
             xform.stream.WriteString( s );
             SetLength(s,0);
          end;
       end else
             xform.stream.CopyFrom( c.stream, 0 );
    TFA(outpdf).deleteObject( c );
    c.Destroy;
   end;
    if error then
      xform.stream.size := 0;
 ss.Destroy;
end;

function TPDFtemplate.ImportPage( pno : PDFuint ) : TPDFxobject;
var xform : TPDFxform;
    p  : TPDFpage;
    c,r  : TPDFvariable; //page contents, resources
    i : PDFuint;
    mb : TPDFarray;
    single : PDFbool;
begin
 result := nil;
//     if pno>=pages.Dictionary.EntryAsInt['Count'] then exit;
     if pno>=outpdf.pagesCount then exit;

 p := outpdf.selectPage( pno );
   if p=nil then exit;

 TPDFobjref( TFA(outpdf).pages_.Dictionary.EntryAsArray['Kids'][pno] ).v := nil;
 i := TFA(outpdf).pages_.Dictionary.EntryAsInt['Count'];
 Dec(i);
 TFA(outpdf).pages_.Dictionary.EntryAsInt['Count'] := i;
// Dec_( TFA(outpdf).pages_.Dictionary['Count'] );
// outpdf.deleteObject( p );
 outpdf.deleteObject( p );

 xform := TPDFxform.Create;

 mb := p.Dictionary.EntryAsArray['MediaBox'];
//  if p.Dictionary['MediaBox']=nil then
  // a co jak nie ma MediaBoc, skoro mozna to dzieciczyc to moze to :) byc bardzo rgh.. wysoko
         if mb<>nil then
           TPDFrect( xform.Dictionary['BBox'] ).setCoords( 0,0, TPDFbasevar(mb[2]).asInt, TPDFbasevar(mb[3]).asInt );

 c := p.Dictionary.clearEntry('Contents');
  if c.getType=mpdfObjref then c := TPDFobjref(c).v;

 single := true;
  case c.getType of
   mpdfArray    : if TPDFarray(c).Count>1 then
                   begin
                    single := false;
                    copyContentsArray( xform, TPDFarray(c) );
                   end else c := TPDFobjref( TPDFarray(c)[0] ).v;
   mpdfObjref   : c := TPDFobjref(c).v;
   mpdfStream,
   mpdfContents : c := TPDFstream(c);
    else raise Exception.Create('Unexpected contents object');
  end;

   if single then
    begin
     xform.CopyFrom( TPDFstream( c ), 0 );
     // kopjuj typ kopresji
      if TPDFstream(c).Dictionary['Filter']<>nil then
     xform.Dictionary.exchangeEntry( 'Filters', TPDFstream(c).Dictionary.clearEntry('Filters') );
     TFA(outpdf).deleteObject( TPDFstream(c) );
     c.Destroy;
    end;

  if xform.Dictionary.EntryAsArray['Filter'].Count=0 then
   xform.addFilter( pfFlateDecode );

 getObject( p.Dictionary, 'Resources', r );
 TPDFresources( xform.Dictionary['Resources'] ).copyFrom( r );

 p.Destroy;
// if p.getCanvas
// xform.stream.Copy
 TFA(outpdf).xref_.Push( xform );
 TFA(outpdf).addResource( xform, rtXObject );
 result := xform;
end;


end.

