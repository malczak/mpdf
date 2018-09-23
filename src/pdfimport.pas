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
        08. VII. 2005 -  first release
        21. XI. 2005 -  last update
********************************************************)
unit pdfimport;

interface
uses
  Classes,SysUtils,Dialogs,
  pdffile,pdfbasetypes, pdfvars, pdfdoc, pdfprocs, pdfbase, pdfstrings, pdfencrypt, pdffonts, pdfimages,
  rc4md5{, ZLIBEX};

const
  {$IFDEF VER130}
   soCurrent = soFromCurrent;
  {$ENDIF}

type

  xrefentry = record
                offset,
                gennum : longword;
              end;

  TPDFimport = class(TPDFfile)
               protected
                rc4key : string;
                strm : TFileStream;
                terminator : string;

                ido : TPDFobjid;
                //idos : TPDFarray;
                //idos : array of TPDFobjref;
                idos : array of TPDFobjref;

                c : string[2]; //buffor wczytywania znakow
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
               public
                removeMetadata,
                rebuildResources  : boolean;
                procedure rebuildPages;
                procedure addResource( obj : TPDFobject; rtype : TPDFrestype );
                procedure Decrypt( userpass : string=''; ownerpass : string='' );
                procedure Import( fname : string ); virtual;
                procedure Save; override;
                constructor Create( fname : string ); overload;
               end;
var

  del,
  called :integer;

implementation

const
 restricted = [ char($0a), char($0d), ' ' ];


constructor TPDFimport.Create( fname : string );
begin
 inherited Create( fname );
 removeMetadata := false;
 rebuildResources := false;
end;

function TPDFimport.readChar : char;
begin
 c[1] := c[2];
 strm.Read(c[2],1);
 result := c[2];
end;

function TPDFimport.EOLN : boolean;
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

function TPDFimport.readLn_r : string;
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

function TPDfimport.readLn_l : string;
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

function TPDFimport.readWord( size : PDFuint ) : string;
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

function TPDFimport.readValue : string;
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

function TPDFimport.isPdfFile( var linear : longint) : boolean;
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

procedure TPDFimport.findXRefTable;
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

procedure TPDFimport.storeObjRef( const bv : TPDFvariable );
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

procedure TPDFimport.readArray( aobj : TPDFarray );
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

function TPDFimport.scanDictionary( ename : string; var pos : PDFlong ) : boolean;
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

procedure TPDFimport.readDictionary( obj : TPDFdictionary );
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

procedure TPDFimport.readDictionary( obj : TPDFobject );
begin
 readDictionary( TPDFdictionary( obj.Dictionary ) );
end;

procedure TPDFimport.readDictionary( pos : PDFuint );
begin
 readDictionary( TPDFobject( xref[ pos ] ) );
end;

function TPDFimport.readObject( pos : PDFuint ) : string;
var strmpos,p1,p2 : int64;
    s : string;
    o : xrefentry;
    obj : TPDFobject;
    bv : TPDFvariable;
begin
   result := '';
   obj := xref[ pos ];
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
           xref[ pos ] := TPDFobject.Create;
           TPDFobject( xref[pos] ).setObjectId( o.offset, o.gennum );
           readDictionary( pos );
            bv := TPDFbasevar( TPDFobject( xref[pos] ).Dictionary['Type'] );
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
               TPDFobject(obj).setVariable( TPDFobject(xref[pos]).Dictionary );
               TPDFobject(xref[pos]).setVariable( nil );
               TPDFstream(obj).Dictionary.addEntry('StrmPos' , 1.0*strm.Position );
               xref[pos] := obj;

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
                            end;
                   //strawdz co tu jest :D
                  obj.setObjectId( o.offset, o.gennum );
                  obj.setVariable( bv );
                 end;
      end;
   strm.Seek( strmpos, soFromBeginning );
end;


procedure TPDFimport.readStream( pos : PDFuint );
var s : TPDFstream;
begin
 s := TPDFstream( xref[ pos ] );
 readStream( s );
end;

procedure TPDFimport.readStream( obj : TPDFstream );
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
      xref.Delete( TPDFobject(len) );
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

procedure TPDFimport.readXRefTable;
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
        i := xref.Count;
  //       if (( beg<>0 ) and ( xref.count<beg ))or( beg or xref.count =0 )  then
         if ( (beg+all)>xref.count )or( beg or xref.count =0 )  then
          xref.setLength( beg+all );
        for i:=beg to beg+all-1 do
         begin
          xr.offset := StrToInt64( readWord );
          xr.gennum := StrToInt64( readWord );
           if readWord[1]='n' then
            if xref[i-1]=nil then
             begin
               obj := TPDFobject.Create(nil);
               obj.objpos := xr.offset;
               xref[i-1] := obj;
             end;
         end;
      except
       MessageDlg('Error reading xref table',mtError,[mbOK],0);
      end;

     until false;

   xrefend := not scanDictionary( 'Prev', prev );

     if trailer = nil then
      begin
        trailer := TPDFtrailer.Create;
        readDictionary( trailer.Dictionary);
        encrypted := trailer.Dictionary['Encrypt'] <> nil;
          if xrefend=false then trailer.Dictionary.deleteEntry('Prev');
      end;

    if xrefend = false then
     begin
        strm.Seek( prev, soFromBeginning );
        strm.Seek( StrToInt(readWord), soFromBeginning );
     end;


 until xrefend = true;

end;

procedure TPDFimport.addResource( obj : TPDFobject; rtype : TPDFrestype );
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
         r := TPDFdictionary( TPDFobject(TPDFobjref(r).v).Dictionary );
         case rtype of
          rtXObject    : TPDFdictionary( TPDFdictionary(r)['XObject'] ).AddEntry( Format('mIm%d',[ TPDFimage(obj).iid ]), TPDFobjref.Create( obj ) );
          rtFont       : TPDFdictionary( TPDFdictionary(r)['Font'] ).AddEntry( Format('mF%d',[ TPDFfont(obj).fid ]), TPDFobjref.Create( obj ) );
       end;
     end;
end;


procedure TPDFimport.Decrypt( userpass : string; ownerpass : string );
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
 if not encrypted then exit;
  encrypt := TPDFobjref(Trailer.Dictionary['Encrypt']).v;

  fid := TPDFbasevar( TPDFarray( Trailer.Dictionary.EntryAsArray['ID'] )[0] ).asString;
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
        while i < xref.count-1 do
         begin
           if xref[i] is TPDFstream then
              begin
               s := TPDFstream(xref[i]).stream.DataString;
               TPDFstream(xref[i]).stream.size := 0;
                try
                 myup := rc4key + Format('%.1s%.1s%.1s%.1s%.1s',[ Char(TPDFstream(xref[i]).getObjectNum),Char(TPDFstream(xref[i]).getObjectNum shr 8),
                                                                  Char(TPDFstream(xref[i]).getObjectNum shr 16),Char(TPDFstream(xref[i]).getGenerateNum),
                                                                  Char(TPDFstream(xref[i]).getGenerateNum shr 8) ] );
                 myup := copy( pack( md5( myup ) ), 1, 10 );
//                 myup := copy( pack( md5( myup ) ), 1, 32 );
                 s := rc4(s,myup);
                  if TPDFstream(xref[i]).Dictionary['Filter']<>nil then
                   begin
//                    s := ZDecompressStr(s);
//                    TPDFstream( xref[i] ).Dictionary.deleteEntry('Filter');
                   end;
                  TPDFstream(xref[i]).stream.WriteString( s );
                except
                 TPDFstream(xref[i]).stream.WriteString( rc4(s,myup) );
                end
             end;
          inc(i);
         end;
     encrypted := false;
     trailer.Dictionary.deleteEntry('Encrypt');
     xref.Delete( encrypt );
     FreeAndNil( encrypt );
    end;
end;

procedure TPDFimport.Import( fname : string );
var i,j,k    : PDFuint;
    linear   : longint;
    pos      : int64;
    todel,bv : TPDFvariable;
    objtype  : string;
    sido,
    sidol    : ^TPDFobjref;
begin
 FreeAndNil( trailer );
 FreeAndNil( resources );
 binary := true;
 pdftype := 4;
 strm := TFileStream.Create( fname, fmOpenRead );
 
  try
    if not isPdfFile(linear) then raise Exception.Create('Not a PDF file');
   findXrefTable;
   readXRefTable;
   i:=0;
    while i < xref.count-1 do
     begin
      objtype := readObject( i );

      //************************************ handle special objects
      if objtype = 'Pages' then //w tablicy KIDS sa tez ido do innych obiektow PAGES zatem nalezy to uwzglednic w celu otrzymania prawidlowej kolejnosci stron (wyjsciem jest odtworzenie struktury drzewa)
          begin
            if TPDFobject(xref[i]).Dictionary['Parent']=nil then
           pages := TPDFpages( xref[i] );
         end
       else
        if objtype = 'Catalog' then
          catalog := TPDFcatalog( xref[i] )
       else
        if removeMetadata then
         if objtype = 'Metadata' then
          begin
           todel := xref[i];
           FreeAndNil( todel );
           xref.Delete( i );
          end
       else
        if i = linear then //wlasnie odczytano /Linearized
         begin
          todel := xref[i];
          FreeAndNil( todel );
          xref.Delete( i );
         end;
      //************************************ handle special objects

      Inc(i);
     end;

     //update IDO objects
    sido := @idos[0];
    sidol := @idos[ Length(idos)-1 ];
     repeat
       i := Word( LongInt( Pointer(sido^.v) ) )-1;
         if i < xref.Count then   //zrobic tak zeby nie bylo tego bledu
           sido^.v := xref[ i ];
       Inc( sido );
     until LongWord( Pointer(sido) ) > LongWord( Pointer(sidol) );

    i := 0;
     //po wczytaniu obiektow wczytaj strumienie (dlaczego tak ? bo teraz mozna juz korzystac z indirect objects)
    while i < xref.Count-1 do
     begin
       if xref[i] is TPDFstream then
        begin
          pos := Trunc( TPDFbasevar( TPDFstream(xref[i]).Dictionary.Entry['StrmPos'] ).asFloat );
          TPDFstream(xref[i]).Dictionary.deleteEntry('StrmPos');
          strm.Seek( pos, soFromBeginning );
//          readStream( TPDFstream( xref[i] )  );
(*           if TPDFstream(xref[i]).Dictionary.Entry['Type']<>nil then
            if TPDFbasevar( TPDFstream(xref[i]).Dictionary.Entry['Type'] ).asString = 'XObject' then
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

procedure TPDFimport.Save;
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
 xref[ TPDFobject( TPDFobjref(bv).v ).getObjectNum-1 ] := info;
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

procedure TPDFimport.rebuildPages;
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
    if rebuildResources then resources := TPDFresources.Create;
 //lecimy po PAGES.KIDS, jak znajdziemy objekt typu PAGES to na stos to co teraz i plum
 ps := pages; //root pages object
 pref := pages.Dictionary.EntryAsArray['Kids'];
 firstc := pref.Count;
 actualc := firstc;
 i := 0;

 while (i<firstc) or (length(stack)<>0) do
  begin
   obj := TPDFobjref(pref[i]).v;

    if TPDFbasevar( obj.Dictionary['Type'] ).asString = 'Page' then
     begin
      SetLength( page, length(page)+1 );
      page[ length(page)-1 ] := TPDFpage(obj);

       //rebuild resources - start
            if rebuildResources then
             begin
              bv := TPDFpage(obj).Dictionary['Resources'];
//                if bv = nil then raise Exception.Create('PDF parse error (resources=nil)');
               if bv<>nil then
                begin

                 if bv is TPDFobjref then
                  begin
                   xref.Delete( TPDFobjref(bv).v ); //usun z xref
                   r := TPDFdictionary( TPDFobjref(bv).v.clearVariable );
                   FreeAndNil( TPDFobjref(bv).v );
                   TPDFobjref(bv).v := resources;
                  end else
                          begin
                            r := TPDFdictionary( bv );
                            TPDFpage(obj).Dictionary.exchangeEntry('Resources', TPDFobjref.Create( resources ) )
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
                         TPDFdictionary( resources.Dictionary[ PDFresourcedics[j] ] ).addEntry( ename,  evalue, true );
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


end.
