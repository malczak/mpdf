(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                             mpdfencrypt.pas
********************************************************
 unit description :                 pdf files encryption
********************************************************
 bugs :                                              ---
********************************************************
 other :
        10 VII 2005  - standard security model
                       (RC4 40bit encoding)
********************************************************){
}
unit mpdfencrypt;

interface
uses sysutils, rc4md5,
     mpdfbase, mpdfvars;

const
 ePrint  = 1;
 eModify = 2;
 eCopy   = 4;
 eAdd    = 8;

 pdfpadding : array [1..32] of char =
    (Char($28),Char($BF),Char($4E),Char($5E),Char($4E),Char($75),Char($8A),Char($41),
     Char($64),Char($00),Char($4E),Char($56),Char($FF),Char($FA),Char($01),Char($08),
     Char($2E),Char($2E),Char($00),Char($B6),Char($D0),Char($68),Char($3E),Char($80),
     Char($2F),Char($0C),Char($A9),Char($FE),Char($64),Char($53),Char($69),Char($7A));

type
  TProtection = byte;

  TPDFencryption = class( TPDFobject )
                   private
                    up, op : string;
                    p : integer;
                    key : string;
                    procedure init40bit( id : string );
                    procedure init128bit( id : string );
                   public
                    procedure Make( var obj : TPDFobject );
                    procedure Init( id : string );
                    constructor Create( userpass : string = ''; ownerpass : string = ''; p : TProtection = ePrint);
                   end;

implementation

procedure TPDFencryption.Make( var obj : TPDFobject );
var i,encoded : PDFuint;
    bv : TPDFvariable;
    objkey, t  : string;
begin
 objkey := self.key + Format('%.1s%.1s%.1s%.1s%.1s',[ Char(obj.getObjectNum),Char(obj.getObjectNum shr 8),Char(obj.getObjectNum shr 16),Char(obj.getGenerateNum),Char(obj.getGenerateNum shr 8) ] );
 objkey := copy( PDFpack( md5( objkey ) ), 1, 10 );
// objkey := copy( pack( md5( objkey ) ), 1, 32 );

   if obj is TPDFstream then
   begin
         t := TPDFstream(obj).stream.DataString;
         TPDFstream(obj).stream.size := 0;
         TPDFstream(obj).stream.WriteString( rc4(t,objkey) );
   end;

 if obj.Dictionary<>nil then
  if not obj.Dictionary.isEmpty then
  begin
   encoded := obj.Dictionary.Count-1;
    for i:=0 to encoded do
     begin
      bv := obj.Dictionary.EntryArray( i );
       if bv is TPDFbasevar then
        if bv.isEmpty = false then
         if TPDFbasevar(bv).vartype = vtString then
          with TPDFbasevar(bv) do
           begin
            vartype := vtBinStr;
            asString := rc4( asString, objkey );
           end;
     end;
  end;

end;

procedure TPDFencryption.init128bit(id: string);
begin
{TODO}
end;

procedure TPDFencryption.init40bit(id: string);
begin
{TODO}
end;

procedure TPDFencryption.Init( id : string );
var tmp : string;
begin
 tmp := copy( PDFpack( md5(op) ), 1, 5 );
 tmp := rc4( up, tmp );
 {*}Dictionary.AddEntry('O', TPDFbasevar.Create(tmp, vtBinStr) );
 tmp := up + tmp + chr(p)+chr(p shr 8)+chr(p shr 16)+chr(p shr 24) + PDFpack(id);
 tmp := PDFpack( md5( tmp ) );
 key := copy( tmp, 1, 5 );
 tmp := rc4( String(pdfpadding), key );
 {*}Dictionary.AddEntry('U', TPDFbasevar.Create(tmp, vtBinStr) );
end;

constructor TPDFencryption.Create( userpass, ownerpass : string; p : TProtection  );
var tmp : string;
begin
 Inherited Create;
 self.p := Integer( $FFFFFC0 or (p shl 2) );
  up := userpass;
  op := ownerpass;
   if op = '' then
    op := IntToStr(random(400)+100)+'Una'+Char(Random(255))+Char(Random(255))+Char(Random(255))+Char(Random(255))+Char(Random(255))+IntToStr(random(1000)+100)+IntToStr( Round( Now ) );;
  up := Copy( up+String(pdfpadding), 1, 32 );
  op := Copy( op+String(pdfpadding), 1, 32 );
  with Dictionary do
   begin
    AddEntry('Filter', TPDFbasevar.Create('Standard',vtName) );
    AddEntry('V',1); //2
    AddEntry('R',2); //3
    AddEntry('P',TPDFbasevar.Create( PDFint(self.p) ));
    AddEntry('Length', 40);
   end;
end;

end.
