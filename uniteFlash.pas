unit uniteFlash;

interface

uses
  Windows, SysUtils, StdCtrls, ComCtrls, ExtCtrls, Dialogs ;


var
  FlashProgData : array of byte;
  CurrPage, ReadPage : array [0..255] of byte;
  FLDataQty, PageStartAddr: integer;
  CurrSector, CurrAddr, StartIndex : integer;
  BaseAddAddr : cardinal;



function fPrepareDataStep : boolean;
function fFlashBulkErase : boolean;
function fWriteFrimwareStep :boolean;
function fProgFlashPage25 : boolean;
function fReadFPGAData  (Filename : string; var DataArray : array of byte; var DataQty : integer) : boolean;
procedure fSwapBits (var bb : byte);
function fPrepMainFLPage : boolean;
function fWritEnCmd : boolean;

implementation

uses uFTDIFunctions;
const
  MaxAddFlashCap = $4000;    //16k
  WREN = $06;               //Set Write Enable Latch
  PROG = $02;             //Program Data into Memory Array
  FillBuf =$84;
  ProgWErase = $83;
  BuffCompare = $60;
  WriteFlashComm = $06;     //transmits start address in SPI flash, must be sent before WriteFlashData command
  ReadFlashComm = $07;      //transmits start address and byte qty (up to 256), recieves data from SPI flash
  CurrEraseComm = $C7;
  CurrFlashSize = $100000;
  CurrSectorSize = $10000;
  FlPageSize = 256;

function fReadFPGAData  (Filename : string; var DataArray : array of byte; var DataQty : integer) : boolean;
var FL : TextFile;
    FileExt,str,str1 : string;
    Ch1,Ch2 : char;
    q,len : integer;
    a : byte;
begin
  result:=false;
  try
    AssignFile(FL,Filename);
  except
  //  Memo1.Text:=Memo1.Text+'File '+Filename+' not found!'+chr($0D)+Chr($0A);
    exit;
  end;
  Reset(FL);
  FileExt:=ExtractFileExt(Filename);
  if (FileExt<>'.ufp') then
  begin
  //  Form1.Memo1.Text:=Form1.Memo1.Text+FileExt+' is not a valid exttnsion!'+chr($0D)+Chr($0A);
    CloseFile(FL);
    exit;
  end;
  DataQty:=0;
  len:=Length(DataArray);
  while not EOF(FL) do
    begin
      ReadLn(FL,str);
      for q:=0 to (Length(str) div 2)-1 do
        begin
          str1:='$'+str[2*q+1]+str[2*q+2];
          try
            a:=StrToInt(str1);
          except
    //        Form1.Memo1.Text:=Form1.Memo1.Text+'Illegal hex coding '+str1+' in byte $'+IntToHex(DataQty,5)+chr($0D)+Chr($0A);
            CloseFile(FL);
            exit;
          end;
          fSwapBits(a);
          DataArray[DataQty]:=a;
          DataQty:=DataQty+1;
          if DataQty>len then
            begin
      //        Form1.Memo1.Text:=Form1.Memo1.Text+'File is too long!';
              CloseFile(FL);
              exit;
            end;
        end;
      end;
  CloseFile(FL);
    result:=true;
end;

procedure fSwapBits (var bb : byte);
var q : integer;
    a,z : byte;
begin
  z:=0;
  for q:=0 to 7 do
    begin
      a:=bb mod 2;
      z:=z*2+a;
      bb:=bb div 2;
    end;
  bb:=z;
end;

function fFlashBulkErase : boolean;     //this should erase every thingle byte. i will connect it to specific button...
var QtyTo,QtyFrom : cardinal;
    StartSec : integer;
    str1 : string;
begin
  result:=false;
  FT_Out_Buffer[0]:=DoSPIExchComm;
  FT_Out_Buffer[1]:=WREN;
  QtyTo:=2;
  if PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str1)=PB_Data then //send WREN command
    begin
      FT_Out_Buffer[0]:=DoSPIExchComm;
      FT_Out_Buffer[1]:=CurrEraseComm;
      QtyTo:=2;
      if PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str1)=PB_Data then
        result:=true;
    end;
end;

function fPrepareDataStep : boolean;
begin
  result:=false;
  SetLength(FlashProgData,CurrFlashSize);
  if not fReadFPGAData('Untitled.ufp',FlashProgData,FlDataQty) then
   exit;
   // Form1.Memo1.Text:=Form1.Memo1.Text+'Read data from '+Filename+chr($0D)+Chr($0A)
    //Form1.Memo1.Text:=Form1.Memo1.Text+'Faild to read from '+Filename+chr($0D)+Chr($0A);
  PageStartAddr:=0;
  CurrSector:=0;
  CurrAddr:=0;
  StartIndex:=0;
  BaseAddAddr:=0;
  ProgDevNum:=MyDevNumber;
  ProgPBAddr:=1;
  result:=true;
end;

function fWriteFrimwareStep :boolean;
var PageNotLast : boolean;
  QtyToT, QtyFromT : cardinal;
  strT:String;
begin
  result:=false;
  PageNotLast := true;
  fPrepMainFLPage;
  FT_Out_Buffer[0]:=DoSPIExchComm;
  FT_Out_Buffer[1]:=WREN;
  QtyToT:=2;
  PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyToT,QtyFromT,strT);
  while (PageNotLast) do
  begin
    if (not fProgFlashPage25) then
    begin
     // Form1.Memo1.Text:=Form1.Memo1.Text+'page writing failed. Address '+CurrAddr+' '+Filename+chr($0D)+Chr($0A);
      exit;
    end;

    if PageNotLast = false then
    begin
      //Form1.Memo1.Text:=Form1.Memo1.Text+'Last page was somehow written'+Filename+chr($0D)+Chr($0A);
      result:=true;
      exit;
    end;

    PageNotLast := fPrepMainFLPage;
    //sleep may be for page to be properly writen...
  end;
  fProgFlashPage25;
end;

function fPrepMainFLPage : boolean;  //false if last page
var I : integer;
begin
  result:=true;
  for I:=0 to FlPageSize-1 do
    begin
      if (StartIndex+I)<FLDataQty then
        CurrPage[I]:=FlashProgData[StartIndex+I]
      else
        begin
          CurrPage[I]:=$FF;
          result:=false;
        end;
    end;
  StartIndex:=StartIndex+FlPageSize;
  CurrAddr:=CurrAddr+FlPageSize;
end;

function fProgFlashPage25 : boolean;
var q : integer;
    QtyTo,QtyFrom : cardinal;
    str : string;
    PBRes : PicoReplyType;
begin
  result:=false;
  if not fWritEnCmd then exit;
  FT_Out_Buffer[0]:=WriteFlashComm;
  FT_Out_Buffer[1]:=(FlPageSize+4) mod 256;
  FT_Out_Buffer[2]:=(FlPageSize+4) div 256;
  FT_Out_Buffer[3]:=PROG;
  FT_Out_Buffer[4]:=(CurrAddr-256) div $10000;
  FT_Out_Buffer[5]:=((CurrAddr-256) mod $10000) div $100;
  FT_Out_Buffer[6]:=(CurrAddr-256) mod $100;
  for q := 0 to FlPageSize-1 do
    FT_Out_Buffer[q+7]:=CurrPage[q];
  QtyTo:=FlPageSize+7;
  QtyFrom:=3;
  PBRes:=PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str);
  //if PBRes<>PB_OK then exit; ////
  Sleep(50);
  FT_Out_Buffer[0]:=DoSPIExchComm;
  FT_Out_Buffer[1]:=WREN;
  QtyTo:=2;
  PBRes:=PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str);
  //if PBRes<>PB_OK then exit; ////
  result:=true;
end;

function fWritEnCmd : boolean;
var QtyTo,QtyFrom : cardinal;
    str1 : string;
begin
  FT_Out_Buffer[0]:=DoSPIExchComm;
  FT_Out_Buffer[1]:=WREN;
  QtyTo:=2;
  result:=PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str1)=PB_Data;
end;

end.

