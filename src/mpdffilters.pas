(*******************************************************
            _____ ____ _____
   __  __  |     \    \  ___| mPDF, 2004 - 2005
  /  \/  \ |  O  |    | |__   author : Mateusz Malczak
 /  /\/\  \|  ___| () |  __|  web    : www.malczak.info
/__/    \____|  |_____/_|     mail   : malczak@us.edu.pl

********************************************************
 unit name :                             mpdffilters.pas
********************************************************
 unit description :            filters used in pdf files
********************************************************
 bugs :                                              ---
********************************************************
 other :
        10.XII.2005
         - currently only zlib comresssion (only decoding)
        30.IV.2005
         - first filters objects
        1.VI.2005
         - ZLIB compression based on
           http://www.zlib.net
           and
           'ZLibEx.pas' by base2 technologies
********************************************************)
unit mpdffilters;


interface
uses mpdfbase;
type
//****************************************************** FlateDecode (zlib/deflate)
// bassed on zlib by  Jean-loup Gailly and Mark Adler.
// http://www.zlib.net
TZAlloc = function (opaque: Pointer; items, size: Integer): Pointer;
TZFree  = procedure (opaque, block: Pointer);

Z_Stream       = record
                  next_in       : PDFpchar;
                  avail_in      : PDFlong;
                  total_in      : PDFlong;
                  next_out      : PDFpchar;
                  avail_out     : PDFlong;
                  total_out     : PDFlong;
                  msg           : PDFpchar;
                  state         : Pointer;
                  zalloc        : TZAlloc; //must change
                  zfree         : TZFree; //must change
                  opaque        : Pointer;
                  data_type     : PDFint;
                  adler         : PDFlong;
                  reserved      : PDFlong;
                 end;
Z_Streamp       = ^Z_Stream;

procedure Decode( inbuf : PChar; insize : PDFint; out outbuf : Pointer; out outSize : PDFint );

implementation

//**************************************************** TPDFflatedecode
// using zlib by Jean-loup Gailly and Mark Adler (http://www.zlib.net)
// obj's compiled with Borland C++ Builder 6 :( somehow !?
{$L zlib\deflate.obj}
{$L zlib\trees.obj}
{$L zlib\adler32.obj}


//zlib error messages
const _z_errmsg : array[0..9] of string = ( (''),(''),(''),(''),(''),(''),(''),(''),(''),('') );

function deflateInit_(var strm : Z_Stream; level : integer; ver : PChar; zstrmsize : integer ): integer; external;
function deflateEnd( var strm : Z_Stream ) : integer; external;
function deflate( var strm : Z_Stream; flush : integer ) : integer; external;


{** zlib function implementations **********************************************}
function zcalloc(opaque: Pointer; items, size: Integer): Pointer;
begin
  GetMem(result,items * size);
end;

procedure zcfree(opaque, block: Pointer);
begin
  FreeMem(block);
end;

{** c function implementations **********************************************}
procedure _memset(p: Pointer; b: Byte; count: Integer); cdecl;
begin
  FillChar(p^,count,b);
end;

procedure _memcpy(dest, source: Pointer; count: Integer); cdecl;
begin
  Move(source^,dest^,count);
end;

//procedure TPDFflatedecode.Decode( Inbuf : Pointer; inSize : PDFulong; out outbuf : Pointer; out outSize : PDFulong );
procedure Decode( inbuf : PChar; insize : PDFint; out outbuf : Pointer; out outSize : PDFint );
var s : string;
    zstream  : Z_Stream;
begin
 FillChar( zstream, sizeof( Z_Stream ), 0 );
 outSize := ((inSize + (inSize div 10) + 12) + 255) and not 255;
 GetMem( outbuf, outsize );       //--> remember to free memory :)

 //initiate zstream
 zstream.next_in := Inbuf;
 zstream.avail_in := inSize;
 zstream.next_out := outbuf;
 zstream.avail_out := outSize;

 DeflateInit_( zstream, -1, PChar('1.2.2'), sizeof(Z_Stream) );

  while deflate( zstream, 4 ) <> 1 do
      begin
        Inc(outSize,256);
        ReallocMem(outBuf,outSize);

        zstream.next_out := PChar(Integer(outBuf) + zstream.total_out);
        zstream.avail_out := 256;
      end;

 ReallocMem(outBuf,zstream.total_out);
 outSize := zstream.total_out;

 DeflateEnd( zstream );
// ZCompress( inbuf, insize, Pointer(outbuf), outsize );
//  s:= '111';
end;

end.
