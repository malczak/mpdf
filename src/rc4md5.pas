unit rc4md5;
//***************************   06.07.2005
//author : Mateusz Malczak
//bibliography :
//     md5 ~ rfc1321 - "The MD5 Message-Digest Algorithm"
//     rc4 ~ "Liczby losowe a kryptografia", Pawel Dabrowski,
//         ~ http://www.cebrasoft.co.uk/encryption/rc4.htm



interface

function rc4( intxt : string; key : string ) : string;
function rc4w( intxt : widestring; key : string ) : widestring;
function md5( intxt : string ) : string;

implementation

//********************************************************** RC4
function rc4w( intxt : widestring; key : string ) : widestring;
var
  rc4table : array [0..255] of byte;
  buf : byte;
  i,j,
  len,p : longword;
  outtxt : widestring;
  intxtb,
  keyb    : array of byte;
begin
 outtxt := '';
  //copy input
 j := length(intxt);
 SetLength( intxtb, j );
  for i:=0 to j-1 do
   intxtb[i] := byte( intxt[i+1] );

 //repeat key if nessesary
 j := length(key);
 SetLength( keyb, 255 );
  for i:=0 to 255 do
   keyb[i] := byte( key[ (i mod j)+1 ] );

 //init rc4 table
  for i:=0 to 255 do
   rc4table[i] := i;

 j:= 0;
  for i:=0 to 255 do
  begin
   buf := keyb[i];
   j := ( j + rc4table[i] + buf ) and $FF;
    //swap bytes (using xor technique)
   buf := rc4table[ i ];
   rc4table[ i ] := rc4table[ j ];
   rc4table[ j ] := buf;
  end;

 len := length( intxtb );
 i := 0;
 j := 0;
  for p := 0 to len-1 do
   begin
    i := ( i + 1 ) and $FF;
    buf := rc4table[ i ];
    j := ( j + buf ) and $FF;
     //swap bytes (using xor technique
    rc4table[ i ] := rc4table[ j ];
    rc4table[ j ] := buf;
    buf := (rc4table[i]+rc4table[j]) and $FF;
//    outtxt := outtxt + char( rc4table[ buf ] xor intxtb[p] );
    outtxt := outtxt + char( intxtb[p] xor rc4table[ buf ] );
   end;
 result := outtxt;
end;

function rc4( intxt : string; key : string ) : string;
var
  rc4table : array [0..255] of byte;
  buf : byte;
  i,j : longword;
  len,p : longword;
  outtxt : string;
  intxtb,
  keyb    : array of byte;
begin
 outtxt := '';
  //copy input
 j := length(intxt);
 SetLength( intxtb, j );
  for i:=0 to j-1 do
   intxtb[i] := byte( intxt[i+1] );

 //repeat key if nessesary
 j := length(key);
 SetLength( keyb, 255 );
  for i:=0 to 255 do
   keyb[i] := byte( key[ (i mod j)+1 ] );

 //init rc4 table
  for i:=0 to 255 do
   rc4table[i] := i;

 j:= 0;
  for i:=0 to 255 do
  begin
   buf := keyb[i];
   j := ( j + rc4table[i] + buf ) and $FF;
    //swap bytes (using xor technique)
   buf := rc4table[ i ];
   rc4table[ i ] := rc4table[ j ];
   rc4table[ j ] := buf;
  end;

 len := length( intxtb );
 i := 0;
 j := 0;
  for p := 0 to len-1 do
   begin
    i := ( i + 1 ) and $FF;
    buf := rc4table[ i ];
    j := ( j + buf ) and $FF;
     //swap bytes (using xor technique
    rc4table[ i ] := rc4table[ j ];
    rc4table[ j ] := buf;
    buf := (rc4table[i]+rc4table[j]) and $FF;
//    outtxt := outtxt + char( rc4table[ buf ] xor intxtb[p] );
    outtxt := outtxt + char( intxtb[p] xor rc4table[ buf ] );
   end;
 result := outtxt;
end;

//********************************************************** MD5
const
  HEX : array[0..15] of char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
  bA = 0;
  bB = 1;
  bC = 2;
  bD = 3;
  bCount = 4;
  bCount1 = 5;

  md5padding : array[0..63] of byte = (
   $80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  );

  S11 = 7;
  S12 = 12;
  S13 = 17;
  S14 = 22;
  S21 = 5;
  S22 = 9;
  S23 = 14;
  S24 = 20;
  S31 = 4;
  S32 = 11;
  S33 = 16;
  S34 = 23;
  S41 = 6;
  S42 = 10;
  S43 = 15;
  S44 = 21;

function F( x, y, z : longword ) : longword;
begin
result := ( ( x and y ) or ( (not x ) and z ) );
end;
function G( x, y, z : longword ) : longword;
begin
result := ( ( x and z ) or ( y and ( not z ) ) );
end;
function H( x, y, z : longword ) : longword;
begin
result := ( x xor y xor z );
end;
function I( x, y, z : longword ) : longword;
begin
result := ( y xor ( x or ( not z ) ) );
end;

procedure rotate_left( var x : longword; n : byte );
begin
 x := ( x shl n ) or ( x shr ( 32-n ) );
end;

  // a = b + ((a + F(b,c,d) + X[k] + T[i]) <<< s). */
procedure FF( var a : longword; b,c,d, xk : longword; s : byte; ti : longword );
begin
 a := a + F(b,c,d) + xk + ti;
 rotate_left( a, s );
 a := a + b;
end;
  // a = b + ((a + G(b,c,d) + X[k] + T[i]) <<< s). */
procedure GG( var a : longword; b,c,d, xk : longword; s : byte; ti : longword );
begin
 a := a + G(b,c,d) + xk + ti;
 rotate_left( a, s );
 a := a + b;
end;
  // a = b + ((a + H(b,c,d) + X[k] + T[i]) <<< s). */
procedure HH( var a : longword; b,c,d, xk : longword; s : byte; ti : longword );
begin
 a := a + H(b,c,d) + xk + ti;
 rotate_left( a, s );
 a := a + b;
end;
  // a = b + ((a + I(b,c,d) + X[k] + T[i]) <<< s). */
procedure II( var a : longword; b,c,d, xk : longword; s : byte; ti : longword );
begin
 a := a + I(b,c,d) + xk + ti;
 rotate_left( a, s );
 a := a + b;
end;

function md5( intxt : string ) : string;
var //***MD5_CTX***//
     buffer : array [0..5] of longword; //state and count
     block  : array [0..63] of byte;    //buffer
    //***MD5_CTX***//
    bits : array[0..7] of byte;
    partlen,index : longword;
    i, j : byte;
    tmp : array of byte;

     procedure transform;
     var a,b,c,d : longword;
         X : array [0..15] of longword;
         i : byte;
     begin
      //4*8 -> 32 bit length variables
      j := 0;
       for i:=0 to 15 do
        begin
         x[ i ] := block[j] or ( block[j+1] shl 8 ) or (block[j+2] shl 16) or (block[j+3] shl 24);
         inc( j, 4 );
        end;

      a := buffer[bA];
      b := buffer[bB];
      c := buffer[bC];
      d := buffer[bD];
      //* Round 1 *//
      FF (a, b, c, d, x[ 0], S11, $d76aa478); //* 1 */
      FF (d, a, b, c, x[ 1], S12, $e8c7b756); //* 2 */
      FF (c, d, a, b, x[ 2], S13, $242070db); //* 3 */
      FF (b, c, d, a, x[ 3], S14, $c1bdceee); //* 4 */
      FF (a, b, c, d, x[ 4], S11, $f57c0faf); //* 5 */
      FF (d, a, b, c, x[ 5], S12, $4787c62a); //* 6 */
      FF (c, d, a, b, x[ 6], S13, $a8304613); //* 7 */
      FF (b, c, d, a, x[ 7], S14, $fd469501); //* 8 */
      FF (a, b, c, d, x[ 8], S11, $698098d8); //* 9 */
      FF (d, a, b, c, x[ 9], S12, $8b44f7af); //* 10 */
      FF (c, d, a, b, x[10], S13, $ffff5bb1); //* 11 */
      FF (b, c, d, a, x[11], S14, $895cd7be); //* 12 */
      FF (a, b, c, d, x[12], S11, $6b901122); //* 13 */
      FF (d, a, b, c, x[13], S12, $fd987193); //* 14 */
      FF (c, d, a, b, x[14], S13, $a679438e); //* 15 */
      FF (b, c, d, a, x[15], S14, $49b40821); //* 16 */

     //* Round 2 */
      GG (a, b, c, d, x[ 1], S21, $f61e2562); //* 17 */
      GG (d, a, b, c, x[ 6], S22, $c040b340); //* 18 */
      GG (c, d, a, b, x[11], S23, $265e5a51); //* 19 */
      GG (b, c, d, a, x[ 0], S24, $e9b6c7aa); //* 20 */
      GG (a, b, c, d, x[ 5], S21, $d62f105d); //* 21 */
      GG (d, a, b, c, x[10], S22,  $2441453); //* 22 */
      GG (c, d, a, b, x[15], S23, $d8a1e681); //* 23 */
      GG (b, c, d, a, x[ 4], S24, $e7d3fbc8); //* 24 */
      GG (a, b, c, d, x[ 9], S21, $21e1cde6); //* 25 */
      GG (d, a, b, c, x[14], S22, $c33707d6); //* 26 */
      GG (c, d, a, b, x[ 3], S23, $f4d50d87); //* 27 */
      GG (b, c, d, a, x[ 8], S24, $455a14ed); //* 28 */
      GG (a, b, c, d, x[13], S21, $a9e3e905); //* 29 */
      GG (d, a, b, c, x[ 2], S22, $fcefa3f8); //* 30 */
      GG (c, d, a, b, x[ 7], S23, $676f02d9); //* 31 */
      GG (b, c, d, a, x[12], S24, $8d2a4c8a); //* 32 */

      //* Round 3 */
      HH (a, b, c, d, x[ 5], S31, $fffa3942); //* 33 */
      HH (d, a, b, c, x[ 8], S32, $8771f681); //* 34 */
      HH (c, d, a, b, x[11], S33, $6d9d6122); //* 35 */
      HH (b, c, d, a, x[14], S34, $fde5380c); //* 36 */
      HH (a, b, c, d, x[ 1], S31, $a4beea44); //* 37 */
      HH (d, a, b, c, x[ 4], S32, $4bdecfa9); //* 38 */
      HH (c, d, a, b, x[ 7], S33, $f6bb4b60); //* 39 */
      HH (b, c, d, a, x[10], S34, $bebfbc70); //* 40 */
      HH (a, b, c, d, x[13], S31, $289b7ec6); //* 41 */
      HH (d, a, b, c, x[ 0], S32, $eaa127fa); //* 42 */
      HH (c, d, a, b, x[ 3], S33, $d4ef3085); //* 43 */
      HH (b, c, d, a, x[ 6], S34,  $4881d05); //* 44 */
      HH (a, b, c, d, x[ 9], S31, $d9d4d039); //* 45 */
      HH (d, a, b, c, x[12], S32, $e6db99e5); //* 46 */
      HH (c, d, a, b, x[15], S33, $1fa27cf8); //* 47 */
      HH (b, c, d, a, x[ 2], S34, $c4ac5665); //* 48 */

      //* Round 4 */
      II (a, b, c, d, x[ 0], S41, $f4292244); //* 49 */
      II (d, a, b, c, x[ 7], S42, $432aff97); //* 50 */
      II (c, d, a, b, x[14], S43, $ab9423a7); //* 51 */
      II (b, c, d, a, x[ 5], S44, $fc93a039); //* 52 */
      II (a, b, c, d, x[12], S41, $655b59c3); //* 53 */
      II (d, a, b, c, x[ 3], S42, $8f0ccc92); //* 54 */
      II (c, d, a, b, x[10], S43, $ffeff47d); //* 55 */
      II (b, c, d, a, x[ 1], S44, $85845dd1); //* 56 */
      II (a, b, c, d, x[ 8], S41, $6fa87e4f); //* 57 */
      II (d, a, b, c, x[15], S42, $fe2ce6e0); //* 58 */
      II (c, d, a, b, x[ 6], S43, $a3014314); //* 59 */
      II (b, c, d, a, x[13], S44, $4e0811a1); //* 60 */
      II (a, b, c, d, x[ 4], S41, $f7537e82); //* 61 */
      II (d, a, b, c, x[11], S42, $bd3af235); //* 62 */
      II (c, d, a, b, x[ 2], S43, $2ad7d2bb); //* 63 */
      II (b, c, d, a, x[ 9], S44, $eb86d391); //* 64 */

      buffer[bA] := buffer[bA] + a;
      buffer[bB] := buffer[bB] + b;
      buffer[bC] := buffer[bC] + c;
      buffer[bD] := buffer[bD] + d;
     end;

     procedure update( input : array of byte; len : longword ); //?!//
     var i : longword;
     begin
      index := ( buffer[bCount] shr 3 ) and $3f; // ( buffer[4]/8 ) * 63
      inc( buffer[bCount], len shl 3 );
       if buffer[bCount] < (len shl 3) then
        Inc( buffer[bCount1] ) else Inc( buffer[bCount1], len shr 29 );

      partlen := 64 - index;
       if len >= partLen then
        begin
         Move( input, block[index], partLen ); //??//
         transform;
         i := partLen;
          while i + 63 < len do
           begin
             Move( input[i], block, 64 ); //??//
             transform;
             inc( i, 64 );
           end;
        end
         else i := 0;
      Move( input[i], block[ index ], len - i ); //??//
     end;


begin
//initialize
 //init A,B,C,D buffer
 buffer[bA] := $67452301;
 buffer[bB] := $efcdab89;
 buffer[bC] := $98badcfe;
 buffer[bD] := $10325476;
 // number of bits, modulo 2^64 (lsb first)
 buffer[bCount] := 0;
 buffer[bCount1] := 0;

 SetLength( tmp, length(intxt) );
       for i:=1 to length(intxt) do
        tmp[i-1] := byte( intxt[i] );
 update( tmp, length(intxt) );
 SetLength( tmp, 0 );

  //* Save number of bits */
      j := 0;
       for i:=0 to 1 do
        begin
         bits[  j  ] :=  buffer[bCount + i]         and $ff;
         bits[ j+1 ] := (buffer[bCount + i] shr 8)  and $ff;
         bits[ j+2 ] := (buffer[bCount + i] shr 16) and $ff;
         bits[ j+3 ] := (buffer[bCount + i] shr 24) and $ff;
         inc( j, 4 );
        end;

  //* Pad out to 56 mod 64.
 index := ( buffer[bCount] shr 3 ) and $3f;
  if index < 56 then
   partlen := 56 - index else partlen := 120 - index;
  update( md5padding, partlen );

  update ( bits, 8);

  result := '';
  for i:=0 to 3 do
   begin
     j := buffer[bA+i] and $ff;
     result := result + HEX[ (j shr 4 ) and $0f ] + HEX[ j and $0f ];
     j := (buffer[bA+i] shr 8)  and $ff;
     result := result + HEX[ (j shr 4 ) and $0f ] + HEX[ j and $0f ];
     j := (buffer[bA+i] shr 16)  and $ff;
     result := result + HEX[ (j shr 4 ) and $0f ] + HEX[ j and $0f ];
     j := (buffer[bA+i] shr 24)  and $ff;
     result := result + HEX[ (j shr 4 ) and $0f ] + HEX[ j and $0f ];
  end;

end;


end.

