unit uFTDIFunctions;

interface

uses
  Windows, SysUtils, StdCtrls, ComCtrls, ExtCtrls, Dialogs ;

type
  FT_Device_Info_Node = record
    Flags         : Dword;
    DeviceType    : Dword;
    ID            : DWord;
    LocID         : DWord;
    SerialNumber  : array [0..15] of Char;
    Description   : array [0..63] of Char;
    DeviceHandle  : DWord;
  end;
  PFTDeviceInfo = ^FT_Device_Info_Node;

  PicoBlazeInfo = record                   {in use}
    PB_FTNodeIndex : integer;
    PB_TabIndex : integer;
    PB_Address : byte;
    PB_ID : array [0..3] of byte;
  end;
  PPicoBlazeInfo = ^PicoBlazeInfo;        {in use}

  PicoReplyType = (PB_Failed, PB_NoReply, PB_Illegal, PB_Notification, PB_Data, PB_OK);

const
  FT_In_Buffer_Index = $FFFF;
  FT_Out_Buffer_Index = $FFFF;
    FT_OK = 0;
  FT_DLL_Name = 'FTD2XX.DLL';
  //standard & debug Picoblase commands
  SetMemWIncComm	= $00;    //writes data to IO with address increment (addr+data)
  SetMemConstComm	= $01;    //writes all data to a fixed address (addr+data)
  Set16RegComm	= $02;      //sets a 16-bit register, MSB @ addr+1, then LSB @ addr (addr+data)
  GetMemWIncComm	= $03;	  //reads data from IO with address increment (addr+qty)
  GetMemConstComm	= $04;    //reads data from a fixed address (addr+qty)
  DoSPIExchComm	= $05;      //transmits all data to SPI & sends reply
  WriteFlashComm = $06;     //transmits start address in SPI flash, must be sent before WriteFlashData command
  ReadFlashComm = $07;      //transmits start address and byte qty (up to 256), recieves data from SPI flash
  WriteFlashData = $08;     //transmits proper quantity of flash data (up to 1 page)
  GetDeviceID	= $0E;        //returnes: PCB index, Hardvare version, Software version, Serial number
  DoEchoComm = $0F;         //returnes all sent data
var
   FTDevInfo : array [0..15] of FT_Device_Info_Node;
   ProgDevNum, FTDevFound, DevNumber, MyDevNumber : integer;
   ProgPBAddr : byte;
   FTDevConnected : array [0..15] of boolean;
   PB_LogEnabled,PB_FullLogView, PB_ErrorShow, PB_ThroughCOM : boolean;
   {FT_NodeTree : TTreeView;}
   {PBFirstReply: TLabel;}
   Lister : TMemo;
   FT_In_Buffer,FT_In_Buffer1 : Array[0..FT_In_Buffer_Index] of Byte;
    FT_Out_Buffer,FT_Out_Buffer1 : Array[0..FT_Out_Buffer_Index] of Byte;

   FlashTimer : TTimer;
   FlashProgr : TProgressBar;
   FlashSave : TSaveDialog;
   FTBaudRate : integer = 3000000;

function ByteArrToString (var InData : array of byte; DatLength, StartIndex : integer) : string;
function TextToBytes (InString : string; var Data : array of byte; var DataQty : cardinal) : boolean;//получаем строку и переводим ее в байты учитываем ,.
procedure CodeDataArray  (ChannAddr : byte; var DataIn, DataOut : array of byte; var InLength,OutLength : cardinal); // big procedure that
//code data to apropriate format for sending to PB. rturns data out

procedure FTDSetInit;    {in use; zero out FTDevConnected and FTDevFound}
procedure GetFTDIDeviceInfo ;  {in use; loads data to array FTDevinfo; FTDevFound:=q [0;15], -1 FT error, -2 q>16}
function ConnectToFTDevice (devNum : integer) : boolean;        {in use; FT connection deep checking, FTDevConncentd(devNum):=true}
function DisconnectFTDevice (devNum : integer) : boolean;        {in use;}
procedure DisconnectAllFTDev;   {in use; desconnects all FT devices from dev(0) to FTDevFound-1}
function TestIfProperFTDevice (devNum : integer) : boolean;  //почему-то была закоментирована, проверяет .description(devNum)?= FT2
function TestIfPicoBlazePresent (FTNum,PBNum : integer; var PBInfo : array of byte) : boolean; //то же закоментирована, отправляет команду getDevId и отвечает тру если
//ответ пришел и длина = 4 байта, и ложь если ответ не пришел или длина не равна 4 байта
function SearchForAllPicoblaze(var st: string )  : boolean;   {in use; gets a lable as a link and returns true if smth
and falce if smth else}
function GetIndexBySerial (var SerialNumber  : array of Char) : integer;
function PB_FTDataExcange (DevNum : integer;var DataTo,DataFrom : array of byte; QtyTo : cardinal; var QtyFrom : cardinal) : boolean;
function PB_SendCommandToDevice (DevNum : integer; ChannAddr : byte; var OutputArray, InputArray : array of byte;
                             var QtyTo,QtyFrom : cardinal; var StrFrom : string) : PicoReplyType;   // sends command and returns reply codes and reply record
procedure StartFlashProgram (Filename : string; DevNum : integer; PBAddr : byte);
procedure StartFlashVerify (Filename : string; DevNum : integer; PBAddr : byte);
procedure StartFlashRead (DevNum : integer; PBAddr : byte);
function AddFlashPrepare (Filename : string;DevNum : integer; PBAddr : byte; StartAddr : cardinal) : boolean;
//function DefineFLASHType (DevNum : integer; Addr : byte; var FlashLen : cardinal; var FType : FLASH_Type) : boolean;
//function FlashErase (DevNum : integer; Addr : byte; FType : FLASH_Type; StartAddr,Size : cardinal) : boolean;
//function GetFlashState (DevNum : integer; Addr : byte; var state : byte): boolean;
//function ReadFPGAData  (Filename : string; var DataArray : array of byte; var DataQty : cardinal) : boolean;
//procedure ConvertToUfpFile (Filename : string; var DataArray : array of byte;DataQty : integer);
function GetFlashData (var DataArray : array of byte; var DataPointer,DataQty : cardinal) : boolean;
//function SendFlashPage  : boolean;
procedure FlashTimerDo;
function FT_PARALLEL_PORT_READ (QtyFrom: cardinal; FT_Parallel_Handle : DWORD;var DataIn: array of byte ):boolean;
function FT_PARALLEL_PORT_CLEAR_BUFFER (FT_Parallel_Handle : DWORD;var qtt: integer):boolean;


procedure CloseLogFile;

implementation

{uses COMFunctions;}

Type FT_Result = Integer;
     TFlashState = (NOP,Erasing,Writing,Verifying,Reading,ErasingAdd,WritingAdd,VerifyingAdd,PreReadingAdd,ReadingAdd);
     FLASH_Type = (AT25F1024A,AT25FS040);
     EEByte = record
            adress : word;
            data : byte;
              end;

const

  //service digits
  StartSymbol = $FD;
  StopSymbol = $FE;
  ShiftSymbol = $FF;
  //Configuration flash commands
  WREN = $06;               //Set Write Enable Latch
  RDSR = $05;               //Read Status Register
  //RDDAT = $03;            //Read Data from Memory Array
  PROG = $02;             //Program Data into Memory Array
  ERASE =$62;               //Erase All Sectors in Memory Array
  AltERASE = $60;
  BlockErase = $52;
  SectorErase = $20;
  RDID = $15;               //Read Manufacturer and Product ID
  AltRDID = $9F;

  FlashPageSize = 256;
  FTDITimeout = 50;
  MaxAddFlashCap = $4000;    //16k

  PB_OKReplyCode	= $DA;
  PB_LengthMisErr = $E0;     //data length mismatch
  PB_ChecksumMisErr = $E1;	  //cheksm mismatch
  PB_CommAbsentErr	= $E2;	  //command with code recieved is absent
  PB_OutOfMemErr	= $E3;	    //adress goes over $FF thrue writing or reading
  PB_TooLittleErr = $E4;	    //too little data sent
  PB_DataFormatErr	= $E5;	  //improper data for specified command
  PB_ParamAbsentErr	= $E6;	  //requested parameter is undefined
  PB_MethForbidErr = $E7;	  //method of parameter is not available

var
    RootNode : TTreeNode;
    TimeoutLimit : int64;
    FlashState : TFlashState;
    CurrFlashSize,FlDataQty,CurrFlashIndex,CurrSectorSize,StartFlashAddr,StopFlashAddr,CurrFlashAddr,EraseSize : cardinal;
    //StartFlashAddr,StopFlashAddr,CurrFlashAddr - in Flash address space, CurrFlashIndex - data array index
    VeryErrCounter,PageCounter,MaxPages : integer;
    CurrEraseComm : byte;
    CurrFlashType : FLASH_Type;
    DatArray : array of byte;
    LogFile : TextFile;
    MaxAddAddr,MinAddAddr,MinSector,MaxSector,CurrSector : word;
    BaseAddAddr,AddDataQty,CurrBlockSize : cardinal;
    FlashProgData : array [0..MaxAddFlashCap-1] of EEByte;
    AddPgToErase, AddPgToWrite, IsWritingAdd, CurrPageDone : boolean;
    ProgressData : real;

function FT_CreateDeviceInfoList(NumDevs:Pointer):FT_Result; stdcall; External FT_DLL_Name name 'FT_CreateDeviceInfoList';
function FT_GetDeviceInfoList(pFT_Device_Info_List:Pointer; NumDevs:Pointer):FT_Result; stdcall; External FT_DLL_Name name 'FT_GetDeviceInfoList';
function FT_Open(Index:Integer; ftHandle:Pointer):FT_Result; stdcall; External FT_DLL_Name name 'FT_Open';
function FT_Close(ftHandle:Dword):FT_Result; stdcall; External FT_DLL_Name name 'FT_Close';
function FT_Read(ftHandle:Dword; FTInBuf:Pointer; BufferSize:LongInt; ResultPtr:Pointer):FT_Result; stdcall; External FT_DLL_Name name 'FT_Read';
function FT_GetQueueStatus(ftHandle:Dword; RxBytes:Pointer):FT_Result; stdcall; External FT_DLL_Name name 'FT_GetQueueStatus';
function FT_Write(ftHandle:Dword; FTOutBuf:Pointer; BufferSize:LongInt; ResultPtr:Pointer):FT_Result; stdcall; External FT_DLL_Name name 'FT_Write';
function FT_SetChars(ftHandle:Dword; EventChar,EventCharEnabled,ErrorChar,ErrorCharEnabled:Byte):FT_Result; stdcall; External FT_DLL_Name name 'FT_SetChars';
function FT_SetBaudRate(ftHandle:Dword; BaudRate:DWord):FT_Result; stdcall; External FT_DLL_Name name 'FT_SetBaudRate';
function FT_Purge(ftHandle:Dword; Mask:Dword):FT_Result; stdcall; External FT_DLL_Name name 'FT_Purge';
function FT_SetDataCharacteristics(ftHandle:Dword; WordLength,StopBits,Parity:Byte):FT_Result; stdcall; External FT_DLL_Name name 'FT_SetDataCharacteristics';
function FT_SetTimeouts(ftHandle:Dword; ReadTimeout,WriteTimeout:Dword):FT_Result; stdcall; External FT_DLL_Name name 'FT_SetTimeouts';
function FT_SetUSBParameters(ftHandle:Dword; InSize,OutSize:Dword):FT_Result; stdcall; External FT_DLL_Name name 'FT_SetUSBParameters';

procedure CodeDataArray  (ChannAddr : byte; var DataIn, DataOut : array of byte; var InLength,OutLength : cardinal);
var I,MaxOut : integer;
    bb : byte;
begin
  OutLength:=2;
  MaxOut:=Length(DataOut);
  bb:=ChannAddr;
  DataOut[0]:=StartSymbol;
  DataOut[1]:=ChannAddr;
  for I := 0 to InLength - 1 do
   begin
     if DataIn[I]<StartSymbol then
       begin
         DataOut[OutLength]:=DataIn[I];
         OutLength:=OutLength+1;
         if OutLength>=MaxOut then
           exit;
       end
     else
       begin
         DataOut[OutLength]:=ShiftSymbol;
         DataOut[OutLength+1]:=DataIn[I]-StartSymbol;
         OutLength:=OutLength+2;
       end;
     bb:=bb xor DataIn[I];
   end;
 if bb<StartSymbol then
   begin
     DataOut[OutLength]:=bb;
     OutLength:=OutLength+1;
   end
 else
   begin
     DataOut[OutLength]:=ShiftSymbol;
     DataOut[OutLength+1]:=bb-StartSymbol;
     OutLength:=OutLength+2;
   end;
  DataOut[OutLength]:=StopSymbol;
  OutLength:=OutLength+1;
end;

function DecodeDataArray  (var DataIn,DataOut : array of byte; var InLength,OutLength : cardinal) : boolean;
var I,a : integer;
    bb : byte;
    MaxLen : cardinal;
begin
  MaxLen:=Length(DataOut);
  OutLength:=0;
  I:=1;
  bb:=0;
  result:=false;
  if (DataIn[0]<>StartSymbol) or (DataIn[InLength-1]<>StopSymbol) then
    begin
      if InLength>MaxLen then
        InLength:=MaxLen;
      OutLength:=InLength;
      for a := 0 to InLength - 1 do
        DataOut[a]:=DataIn[a];
      exit;
    end;
  while I<InLength-1 do
    begin
      if OutLength>=MaxLen then
        exit;
      if DataIn[I]=ShiftSymbol then
        begin
          DataOut[OutLength]:=DataIn[I+1]+StartSymbol;
          I:=I+1;
        end
      else
        DataOut[OutLength]:=DataIn[I];
      I:=I+1;
      bb:=bb xor DataOut[OutLength];
      OutLength:=OutLength+1;
    end;
  result:=(bb=0);
  OutLength:=OutLength-1;
end;

function ByteArrToString (var InData : array of byte; DatLength, StartIndex : integer) : string;
var I : integer;
begin
  result:='';
  for I := StartIndex to DatLength - 1 do
    result:=result+IntToHex(InData[I],2)+'.';
end;

procedure SaveDataToLog (str : string; QtyTo,QtyFrom : integer);
begin
  //WriteLN(LogFile,str);
  //WriteLN(LogFile,ByteArrToString(FT_Out_Buffer,QtyTo,0));
  //WriteLN(LogFile,ByteArrToString(FT_In_Buffer,QtyFrom,0));
  //Flush(LogFile);
end;

procedure OpenLogFile;
begin
  //AssignFile(LogFile,'.\Logfile.txt');
 // Rewrite(LogFile);
end;

procedure CloseLogFile;
begin
  try
  FlashState:=NOP;
  //CloseFile(LogFile);
  except

  end;
end;

function TextToBytes (InString : string; var Data : array of byte; var DataQty : cardinal) : boolean;
var q,a,z : integer;
    str : string;
begin
  result:=false;
  z:=0;
  a:=0;
  str:='$';
  for q:=1 to Length(InString) do
    if (InString[q]<>'.') and (InString[q]<>',') then
      begin
        str:=str+InString[q];
        z:=z+1;
        if z>1 then
          begin
            try
              Data[a]:=StrToInt(str); //поддерживает 0x, x, $ для шестнадцати разрядных команд
            except
              //InString.SetFocus;
              exit;
            end;
            z:=0;
            str:='$';
            a:=a+1;
          end;
      end;
  result:=true;
  DataQty:=a;
end;

function DecodeNotification (notif : byte) : string;
begin
  case notif of
  PB_OKReplyCode: result:='OK!';
  PB_LengthMisErr: result:='Length mismatch';
  PB_ChecksumMisErr: result:='Checksum mismatch';
  PB_CommAbsentErr: result:='Command not recognized';
  PB_OutOfMemErr: result:='Out of memory';
  PB_TooLittleErr: result:='Too little data';
  PB_DataFormatErr: result:='Improper data';
  PB_ParamAbsentErr: result:='Parameter not found';
  PB_MethForbidErr: result:='Method is not available';
  else
    result:='Unrecognized: '+IntToHex(notif,2);
  end;
end;

procedure FTDSetInit;
var I : integer;
begin
  FlashState:=NOP;
  for I := 0 to 15 do
    FTDevConnected[I]:=false;
    FTDevFound:=0;
end;

procedure GetFTDIDeviceInfo ;
var q : cardinal;
begin
  FTDevFound:=-1;
  if FT_CreateDeviceInfoList(@q)<>FT_OK then
    exit;
  if q>16 then
    begin
      FTDevFound:=-2;
      exit;
    end;
  if FT_GetDeviceInfoList(@FTDevInfo,@q)<>FT_OK then
    exit;
  FTDevFound:=q;
end;

function ConnectToFTDevice (devNum : integer) : boolean;
begin
  result:=false;
  if FTDevConnected[devNum] then
    begin
      result:=true;           //device is already opened
      exit;
    end;
  if FT_Open(devNum,@FTDevInfo[devNum].DeviceHandle)<>FT_OK then
    exit;
  FTDevConnected[devNum]:=true;
//  if FT_SetDataCharacteristics(FTDevInfo[devNum].DeviceHandle,8,1,0)<>FT_OK then
//    exit;
//  if FT_SetBaudRate(FTDevInfo[devNum].DeviceHandle,FTBaudRate)<>FT_OK then
//    exit;
  if FT_SetChars(FTDevInfo[devNum].DeviceHandle,$FE,1,0,0)<>FT_OK then
    exit;
  if FT_Purge(FTDevInfo[devNum].DeviceHandle,3)<>FT_OK then
    exit;
  result:=true;
end;

function DisconnectFTDevice (devNum : integer) : boolean;
begin
  result:=false;
  if FTDevConnected[devNum] then
    result:=FT_Close(FTDevInfo[devNum].DeviceHandle)=FT_OK;
  FTDevConnected[devNum]:=false;
end;

procedure DisconnectAllFTDev;
var I : integer;
begin
  for I := 0 to FTDevFound - 1 do
    if FTDevConnected[I] then
      DisconnectFTDevice(I);
end;

function TestIfProperFTDevice (devNum : integer) : boolean;
var str : string;
    I : integer;
begin
  result:=false;
  str:='';
  for I := 0 to 2 do
    str:=str+FTDevInfo[devNum].Description[I];
  if (str='FT2') then
  begin
    result:=true;
    exit;
  end;
end;

function TestIfPicoBlazePresent (FTNum,PBNum : integer; var PBInfo : array of byte) : boolean;
var DataOut,DataIn : array [0..7] of byte;
    qtyTo,qtyFrom : cardinal;
    str : string;
    I : integer;
begin
  DataOut[0]:=GetDeviceID;
  qtyTo:=1;
  result:=false;
  if (PB_SendCommandToDevice(FTNum,PBNum,DataOut,DataIn,qtyTo,qtyFrom,str)=PB_Data) and (qtyFrom=4) then
    begin
      result:=true;
      for I := 0 to 3 do
        PBInfo[I]:=DataIn[I];
    end;
end;

function GetIndexBySerial (var SerialNumber  : array of Char) : integer;
var I,q : integer;
    bb : boolean;
begin
  result:=-1;
  for I := 0 to FTDevFound - 1 do
    begin
      bb:=true;
      for q := 0 to 15 do
        if SerialNumber[q]<>FTDevInfo[I].SerialNumber[q] then
          begin
            bb:=false;
            break;
          end;
      if bb then
        begin
          result:=I;
          exit;
        end;
    end;
end;

function SearchForAllPicoblaze(var st: string) : boolean;
var q,I,a : integer;
    SomeNode : TTreeNode;   {Это такой список с плюсиками}
    P : PPicoBlazeInfo;
    PicoID : array [0..3] of byte;
begin
  result:=false;
  {FT_NodeTree.Items.Clear;  parts of priveous implimentation}
  QueryPerformanceFrequency(TimeoutLimit);    {WINDOWS standart function; TimeoutLimit: int64 это системный высокочастотный таймер
  использовался в прошлых программах, в этой то же в функции pb_ft_data exchange}
  TimeoutLimit:=TimeoutLimit div FTDITimeout;      {еще какая то фигня с таймаутами}
  DisconnectAllFTDev;     {дисконектит от фт девайсы от 0 до FTDevFound-1}
  GetFTDIDeviceInfo;       {фактически конектимся заново}
  if FTDevFound<=0 then
    exit;
  {RootNode:=FT_NodeTree.Items.Add(nil,'FTDI devices found');}
  for q := 0 to FTDevFound - 1 do
    begin
      if TestIfProperFTDevice(q) then
        begin
          {SomeNode:=FT_NodeTree.Items.AddChildObject(RootNode,FTDevInfo[q].Description+':'+FTDevInfo[q].SerialNumber+' at '+
                                                 IntToHex(FTDevInfo[q].LocID,4),@FTDevInfo[q]); }
          if ConnectToFTDevice(q) then
          for I := 1 to 15 do
              if TestIfPicoBlazePresent(q,I,PicoID) then
                begin
                  {if q>0
                  then if(FTDevInfo[q].Description=' LAPlatform B') and
                         (FTDevInfo[q-1].Description=' LAPlatform A') then
                         ConnectToFTDevice(q-1); }
                  New(P);
                  result:=true;
                  P^.PB_FTNodeIndex:=q;
                  P^.PB_TabIndex:=-1;
                  P^.PB_Address:=I;
                  for a := 0 to 3 do
                    P^.PB_ID[a]:=PicoID[a];
                  st:='';
                  st:=st+ByteArrToString(P^.PB_ID,4,0);
                  MyDevNumber:=q;
                  {FT_NodeTree.Items.AddChildObject(SomeNode,ByteArrToString(PicoID,4,0),P);  }
                end;
          DevNumber:=q;
          DisconnectFTDevice(q);

        end;
    end;
end;

function PB_FTDataExcange (DevNum : integer;var DataTo,DataFrom : array of byte; QtyTo : cardinal; var QtyFrom : cardinal) : boolean;
Var I : Integer;
    qty,qty1 : cardinal;
    Tim1,Tim2 : int64;
begin
  QtyFrom:=0;
  result:=false;
  if DevNum<0 then
    exit;
  if not FTDevConnected[devNum] then
    exit;
  if FT_Write(FTDevInfo[DevNum].DeviceHandle,@DataTo,QtyTo,@qty)<>FT_OK then
    exit;
  QueryPerformanceCounter(Tim1);
  repeat
    FT_GetQueueStatus(FTDevInfo[DevNum].DeviceHandle,@qty);
    if qty>0 then
      begin
        FT_Read(FTDevInfo[DevNum].DeviceHandle,@FT_In_Buffer1,qty,@qty1);
        for I := 0 to qty1 - 1 do
          DataFrom[QtyFrom+I]:=FT_In_Buffer1[I];
        QtyFrom:=QtyFrom+qty1;
        if DataFrom[QtyFrom-1]=StopSymbol then
          break;
        QueryPerformanceCounter(Tim1);
      end;
    QueryPerformanceCounter(Tim2);
    if (Tim2-Tim1)>TimeoutLimit then
      break;
  until false;
  result:=true;
end;



function PB_SendCommandToDevice (DevNum : integer; ChannAddr : byte; var OutputArray, InputArray : array of byte;
                             var QtyTo,QtyFrom : cardinal; var StrFrom : string) : PicoReplyType;
var q: integer;
    a,z : cardinal;
    StrTo : string;
    rr : boolean;
begin
  CodeDataArray(ChannAddr,OutputArray,FT_Out_Buffer1,QtyTo,a);
  z:=QtyFrom;
  if PB_FullLogView then
    StrTo:=ByteArrToString(FT_Out_Buffer1,a,0)
  else
    StrTo:=IntToHex(ChannAddr,2)+': '+ByteArrToString(OutputArray,QtyTo,0);
  {if PB_ThroughCOM then
    rr:=PB_COMExcange(DevNum,FT_Out_Buffer1,FT_In_Buffer,a,z)
  else}
    rr:=PB_FTDataExcange(DevNum,FT_Out_Buffer1,FT_In_Buffer,a,z);
    if rr then
    begin
      QtyFrom:=z;
      if z=0 then
        begin
          result:=PB_NoReply;
          StrFrom:='No reply';
//          if PB_ErrorShow and (not PB_LogEnabled) then
//            begin
//              Lister.Text:=Lister.Text+'To->'+StrTo+chr($0D)+Chr($0A);
//              Lister.Text:=Lister.Text+StrFrom+chr($0D)+Chr($0A);
//            end;
        end
      else
        begin
          if z<4 then
            begin
              if (z=3)and (FT_In_Buffer[0]= (FT_In_Buffer[1] xor $FF)) then
                begin
                  result:=PB_Notification;
                  StrFrom:=DecodeNotification(FT_In_Buffer[0]);
                  if FT_In_Buffer[0]=PB_OKReplyCode then
                    result:=PB_OK;
                end
              else
                begin
                  result:=PB_Illegal;
                  for q := 0 to z - 1 do
                    InputArray[q]:=FT_In_Buffer[q];
                  StrFrom:='Illegal '+ByteArrToString(FT_In_Buffer,QtyFrom,0);
//                  if PB_ErrorShow and (not PB_LogEnabled) then
//                    begin
//                      Lister.Text:=Lister.Text+'To->'+StrTo+chr($0D)+Chr($0A);
//                      Lister.Text:=Lister.Text+StrFrom+chr($0D)+Chr($0A);
//                    end;
                end;
            end
          else
            begin
              if not DecodeDataArray(FT_In_Buffer,InputArray,z,QtyFrom) then
                begin
                  result:=PB_Illegal;
                  QtyFrom:=z;
                  StrFrom:='Illegal '+ByteArrToString(FT_In_Buffer,QtyFrom,0);
//                  if PB_ErrorShow and (not PB_LogEnabled) then
//                    begin
//                      Lister.Text:=Lister.Text+'To->'+StrTo+chr($0D)+Chr($0A);
//                      Lister.Text:=Lister.Text+StrFrom+chr($0D)+Chr($0A);
//                    end;
                end
              else
                begin
                  result:=PB_Data;
                  if PB_FullLogView then
                    StrFrom:=ByteArrToString(FT_In_Buffer,z,0)
                  else
                    StrFrom:=IntToHex(ChannAddr,2)+': '+ByteArrToString(InputArray,QtyFrom,0)
                end;
            end;
        end;
    end
  else
    begin
      result:=PB_Failed;
      StrFrom:='Failed';
//      if PB_ErrorShow and (not PB_LogEnabled) then
//        begin
//          Lister.Text:=Lister.Text+'To->'+StrTo+chr($0D)+Chr($0A);
//          Lister.Text:=Lister.Text+StrFrom+chr($0D)+Chr($0A);
//        end;
    end;
  if PB_LogEnabled then
    begin
      Lister.Text:=Lister.Text+'To->'+StrTo+chr($0D)+Chr($0A);
      Lister.Text:=Lister.Text+'From<-'+StrFrom+chr($0D)+Chr($0A);
    end;
end;

function DefineFLASHType (DevNum : integer; Addr : byte) : boolean;
var QtyTo,QtyFrom : cardinal;
    str,str1 : string;
begin
  result:=false;
  str:='FLASH is undefined';
  CurrFlashSize:=0;
  FT_Out_Buffer[0]:=DoSPIExchComm;
  FT_Out_Buffer[1]:=RDID;
  FT_Out_Buffer[2]:=0;
  FT_Out_Buffer[3]:=0;
  QtyTo:=4;
  if PB_SendCommandToDevice(DevNum,Addr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str1)=PB_Data then
    begin
      if (QtyFrom=3) and (FT_In_Buffer[1]=$1F) and (FT_In_Buffer[2]=$60) then
        begin
          result:=true;
          CurrFlashType:=AT25F1024A;
          CurrFlashSize:=$20000;
          CurrSectorSize:=$8000;
          CurrBlockSize:=$8000;
          str:='AT25F1024A is found';
        end
      else
        begin
          FT_Out_Buffer[1]:=AltRDID;
          FT_Out_Buffer[4]:=0;
          QtyTo:=5;
          if PB_SendCommandToDevice(DevNum,Addr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str1)=PB_Data then
            begin
              if (QtyFrom=4) and (FT_In_Buffer[1]=$1F) and (FT_In_Buffer[2]=$66) and (FT_In_Buffer[3]=$04)  then
                begin
                  result:=true;
                  CurrFlashType:=AT25FS040;
                  CurrFlashSize:=$80000;
                  CurrSectorSize:=$10000;
                  CurrBlockSize:=$1000;
                  str:='AT25FS040 is found';
                end;
            end;
        end;
    end;
  str:=IntToStr(Addr)+'@'+IntToStr(DevNum)+': '+str;
  Lister.Text:=Lister.Text+str+chr($0D)+Chr($0A);
end;

function FlashSectorErase : boolean;     //Стирает блок/сектор (в зависимости от кода команды CurrEraseComm)
var QtyTo,QtyFrom : cardinal;            //содержащий CurrFlashAddr, который после операции увеличивается на EraseSize
    str1 : string;
begin
  result:=false;
  FT_Out_Buffer[0]:=DoSPIExchComm;
  FT_Out_Buffer[1]:=WREN;
  QtyTo:=2;
  if PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str1)=PB_Data then
    begin
      FT_Out_Buffer[0]:=DoSPIExchComm;
      FT_Out_Buffer[1]:=CurrEraseComm;
      FT_Out_Buffer[2]:=CurrFlashAddr div $10000;
      FT_Out_Buffer[3]:=(CurrFlashAddr mod $10000) div $100;
      FT_Out_Buffer[4]:=(CurrFlashAddr mod $100);
      QtyTo:=5;
      QtyFrom:=11;
      if PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str1)=PB_Data then
        result:=true;
    end;
  CurrFlashAddr:=CurrFlashAddr+EraseSize;
  if not result then
    FlashState:=NOP;
end;

procedure FlashErase (StartAddr,Size : cardinal);
var q,a : cardinal;
    str,str1 : string;
begin
  FlashState:=Erasing;
  CurrFlashAddr:=StartAddr;    //for erasing
  q:=StartAddr div CurrSectorSize;
  a:=(StartAddr+Size) div CurrSectorSize;
  MaxPages:=a-q+1;
  PageCounter:=0;
  CurrEraseComm:=BlockErase;
  EraseSize:=CurrSectorSize;
  FlashTimer.Interval:=300;
  FlashTimer.Enabled:=true;
end;

function GetFlashState (var state : byte): boolean;
var DataTo,DataFrom : array [0..7] of byte;
    QtyTo,QtyFrom : cardinal;
    str1 : string;
begin
  result:=false;
  DataTo[0]:=DoSPIExchComm;
  DataTo[1]:=RDSR;
  DataTo[2]:=0;
  QtyTo:=3;
  QtyFrom:=10;
  if PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,DataTo,DataFrom,QtyTo,QtyFrom,str1)=PB_Data then
    if QtyFrom=2 then
      begin
        state:=DataFrom[1];
        result:=true;
      end;
  if not result then
    Lister.Text:=Lister.Text+IntToStr(ProgPBAddr)+'@'+IntToStr(ProgDevNum)+': Status request failed'+chr($0D)+Chr($0A);
end;

procedure SwapBits (var bb : byte);
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

function ReadFPGAData  (Filename : string; var DataArray : array of byte; var DataQty : cardinal) : boolean;
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
    Lister.Text:=Lister.Text+'File '+Filename+' not found!'+chr($0D)+Chr($0A);
    exit;
  end;
  Reset(FL);
  FileExt:=ExtractFileExt(Filename);
  if (FileExt<>'.ufp') then
  begin
    Lister.Text:=Lister.Text+FileExt+' is not a valid exttnsion!'+chr($0D)+Chr($0A);
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
            Lister.Text:=Lister.Text+'Illegal hex coding '+str1+' in byte $'+IntToHex(DataQty,5)+chr($0D)+Chr($0A);
            CloseFile(FL);
            exit;
          end;
          SwapBits(a);
          DataArray[DataQty]:=a;
          DataQty:=DataQty+1;
          if DataQty>len then
            begin
              Lister.Text:=Lister.Text+'File is too long!';
              CloseFile(FL);
              exit;
            end;
        end;
      end;
  CloseFile(FL);
  if (DataQty mod 4)<>0 then
    Lister.Text:=Lister.Text+'Byte quantity mus be a multiple of 4!'+chr($0D)+Chr($0A)
  else
    result:=true;
end;

procedure ConvertToUfpFile (Filename : string; var DataArray : array of byte;DataQty : integer);
var FL : TextFile;
    str : string;
    q,a,z,I : integer;
    bb : byte;
begin
  AssignFile(FL,Filename);
  Rewrite(FL);
  z:=0;
  for I := 0 to (DataQty div 16)-1 do
    begin
      str:='';
      a:=DataQty-z;
      if a<=0 then
        break;
      if a>16 then
        a:=16;
      for q := 0 to a-1 do
        begin
          bb:=DataArray[z];
          SwapBits(bb);
          str:=str+IntToHex(bb,2);
          z:=z+1;
        end;
      WriteLn(FL,str);
    end;
  CloseFile(FL);
end;

function GenStringDecode (InStr : string; var MemRec : EEByte) : boolean;
var str : string;
    q : integer;
    sw : boolean;
begin
  str:='';
  sw:=false;
  result:=false;
  for q:=1 to Length(InStr) do
    if InStr[q]=':' then
      begin
        sw:=true;
        try
          MemRec.Adress:=StrToInt('$'+str);
        except
          exit;
        end;
        str:='';
      end
    else
      str:=str+InStr[q];
    if not sw then
      exit;
    try
      MemRec.Data:=StrToInt('$'+str);
    except
      exit;
    end;
  result:=true;
end;

function ReadGenFile (Filename : string; var DataQty : cardinal) : boolean;
var fl : TextFile;
    q : integer;
    str : string;
begin
  result:=false;
  AssignFile(fl,Filename);
  Reset(fl);
  q:=0;
  MaxAddAddr:=0;
  MinAddAddr:=MaxAddFlashCap;
  While not EOF(fl) do
    begin
      ReadLn(fl,str);
      if not GenStringDecode(str,FlashProgData[q]) then
        begin
          Lister.Text:=Lister.Text+'Wrong file format! Error in string '+IntToStr(q)+' = '+str;
          CloseFile(fl);
          exit;
        end;
      if FlashProgData[q].Adress>=MaxAddFlashCap then
        begin
          Lister.Text:=Lister.Text+'Too large FLASH adress = $'+IntToHex(FlashProgData[q].Adress,4)+'!';
          CloseFile(fl);
          exit;
        end;
      q:=q+1;
      if FlashProgData[q].Adress>MaxAddAddr then
        MaxAddAddr:=FlashProgData[q].Adress;
      if FlashProgData[q].Adress<MinAddAddr then
        MinAddAddr:=FlashProgData[q].Adress;
      if q>MaxAddFlashCap then
        begin
          Lister.Text:=Lister.Text+'Too long data file!';
          CloseFile(fl);
          exit;
        end;
    end;                        //all data are loaded from file
  DataQty:=q;
  CloseFile(fl);
  result:=true;
end;

procedure StartAddSectorProc;
begin
  CurrFlashAddr:=CurrSector*CurrBlockSize;
  CurrFlashIndex:=0;
  StopFlashAddr:=(CurrSector+1)*CurrBlockSize;
end;

function AddFlashPrepare (Filename : string;DevNum : integer; PBAddr : byte; StartAddr : cardinal) : boolean;
begin
  result:=false;
  if FlashState<>NOP then
    begin
      Lister.Text:=Lister.Text+'Some FLASH operation is already in progress!';
      exit;
    end;
  if not DefineFLASHType(DevNum,PBAddr) then
    exit;
  if ReadGenFile(Filename,AddDataQty) then
    Lister.Text:=Lister.Text+'Read data from '+Filename+chr($0D)+Chr($0A)
  else
    exit;
  BaseAddAddr:=StartAddr;
  if (BaseAddAddr+MaxAddAddr)>=CurrFlashSize then
    begin
      Lister.Text:=Lister.Text+'Addres is outside the FLASH!';
      exit;
    end;
  MinSector:=(BaseAddAddr+MinAddAddr) div CurrBlockSize;
  MaxSector:=(BaseAddAddr+MaxAddAddr) div CurrBlockSize;
  CurrSector:=MinSector;
  SetLength(DatArray,CurrBlockSize);
  ProgDevNum:=DevNum;
  ProgPBAddr:=PBAddr;
  if CurrFlashType=AT25F1024A then
    CurrEraseComm:=BlockErase
  else
    CurrEraseComm:=SectorErase;
  EraseSize:=CurrBlockSize;
  AddPgToErase:=false;
  AddPgToWrite:=false;
  StartAddSectorProc;
  FlashTimer.Interval:=20;
  FlashTimer.Enabled:=true;
  IsWritingAdd:=false;
  FlashState:=PreReadingAdd;
  result:=true;
end;

function GetFlashData (var DataArray : array of byte; var DataPointer,DataQty : cardinal) : boolean;
var DataLength,RepLen,q : cardinal;
    str : string;                       //reads DataQty bytes from address DataPointer into DataArray
    ExRes : PicoReplyType;
    I : integer;
begin
  result:=false;
  if DataQty=0 then
    exit;
  FT_Out_Buffer[0]:=ReadFlashComm;
  FT_Out_Buffer[1]:=DataPointer div $10000;
  FT_Out_Buffer[2]:=(DataPointer mod $10000) div $100;
  FT_Out_Buffer[3]:=DataPointer mod $100;
  q:=DataQty mod 256;
  FT_Out_Buffer[4]:=q;
  DataLength:=5;
  ExRes:=PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,DataArray,DataLength,RepLen,str);
  if q=0 then
    q:=256;
  result:=(ExRes=PB_Data) and (RepLen = q);
  if result then
    DataQty:=q
  else
    Lister.Text:=Lister.Text+'Flash reading failed!  '+IntToStr(RepLen)+'  '+IntToStr(Ord(ExRes))+chr($0D)+Chr($0A);
end;

procedure TestAddFlashData;
var I : integer;
    bFlash, bData : byte;
    CAddr,MinAddr,MaxAddr : cardinal;
begin
  MinAddr:=CurrSector*CurrBlockSize;       //absolute addresses
  MaxAddr:=MinAddr+CurrBlockSize;
  for I := 0 to AddDataQty - 1 do
    begin
      CAddr:=FlashProgData[I].adress+BaseAddAddr;
      if (CAddr>=MinAddr)and (CAddr<MaxAddr) then    //only iside the current sector/page
        begin
          bFlash:=DatArray[CAddr-MinAddr];
          bData:=FlashProgData[I].data;
          if bFlash<>bData then
            begin
              AddPgToWrite:=true;
              IsWritingAdd:=true;
              DatArray[CAddr-MinAddr]:=bData;
            end;
          if (bData and (not bFlash))<>0 then
            AddPgToErase:=true;
        end;
    end;        //formed new flash block
end;

function GetAddFlashSector : boolean;
var I,q : integer;
    z : cardinal;
begin
  result:=false;
  CurrPageDone:=false;
  for I := 0 to 7 do
    begin
      z:=(CurrSector+1)*CurrBlockSize-CurrFlashAddr;
      if not GetFlashData(FT_In_Buffer,CurrFlashAddr,z) then
        exit;
      for q := 0 to z - 1 do
        DatArray[CurrFlashIndex+q]:=FT_In_Buffer[q];
      CurrFlashIndex:=CurrFlashIndex+z;
      CurrFlashAddr:=CurrFlashAddr+z;
      if (CurrFlashAddr mod CurrBlockSize)=0 then      //current sector is read
        begin
          TestAddFlashData;
          CurrPageDone:=true;
        end;
    end;
  result:=true;
end;

procedure PrepareFlashVerify;
begin
  FlashState:=Verifying;      //start autoverifying
  FlashTimer.Interval:=20;
  CurrFlashAddr:=StartFlashAddr;
  CurrFlashIndex:=0;
  VeryErrCounter:=0;
end;

function SendFlashPage : boolean;        //записывает страницу памяти, содержащую CurrFlashAddr
var QtyTo,QtyFrom,a,z : cardinal;        //данными, содержащимися в DatArray начиная с CurrFlashIndex
    q : integer;                         //к-во: до конца страницы или до StopFlashAddr
    str : string;                        //затем CurrFlashIndex и CurrFlashAddr увеличиваются на к-во
begin
  result:=false;
  if (FlashState<>Writing) and (FlashState<>WritingAdd) then
    begin
      Lister.Text:=Lister.Text+'Illegal flash writing call!';
      exit;
    end;
  z:=((CurrFlashAddr div FlashPageSize)+1)*FlashPageSize;  //first address at the next page
  if z>StopFlashAddr then
    a:=StopFlashAddr-CurrFlashAddr
  else
    a:=z-CurrFlashAddr;
  FT_Out_Buffer[0]:=DoSPIExchComm;
  FT_Out_Buffer[1]:=WREN;
  QtyTo:=2;
  if not (PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str)=PB_Data) then
    exit;
  FT_Out_Buffer[0]:=WriteFlashComm;
  FT_Out_Buffer[2]:=(a+4) div 256;
  FT_Out_Buffer[1]:=(a+4) mod 256;
  FT_Out_Buffer[3]:=PROG;
  FT_Out_Buffer[4]:=CurrFlashAddr div $10000;
  FT_Out_Buffer[5]:=(CurrFlashAddr mod $10000) div $100;
  FT_Out_Buffer[6]:=CurrFlashAddr mod $100;
  for q := 0 to a-1 do
    FT_Out_Buffer[q+7]:=DatArray[CurrFlashIndex+q];
  QtyTo:=a+7;
  QtyFrom:=3;
  if (PB_SendCommandToDevice(ProgDevNum,ProgPBAddr,FT_Out_Buffer,FT_In_Buffer,QtyTo,QtyFrom,str)=PB_OK) then
    begin
      result:=true;
      CurrFlashAddr:=CurrFlashAddr+a;
      CurrFlashIndex:=CurrFlashIndex+a;
    end;
  if not result then
    FlashState:=NOP;
end;

function FT_PARALLEL_PORT_READ (QtyFrom: cardinal; FT_Parallel_Handle : DWORD;var DataIn: array of byte ):boolean;//(var DataIn: array of byte; QtyFrom: cardinal):boolean;
var
   Read_result:integer;
   qty,q,tim,Total,I:cardinal;
   FT_IO_Status: FT_Result;
   buffer: array [0..FT_In_Buffer_Index] of byte;
   Inta: integer;
begin
Inta :=  FT_SetUSBParameters(FT_Parallel_Handle,64000,4096);
If Inta = FT_OK then
begin
  tim:=0;
  Total:=0;
  repeat
    q:= FT_GetQueueStatus(FT_Parallel_Handle,@qty);
    If q <> FT_OK then
    begin
      //FT_Error_Report('FT_GetQueueStatus',q);
      break;
    end
    else
    begin
      if qty>0 then
        begin
          FT_IO_Status := FT_Read(FT_Parallel_Handle,@buffer,qty,@Read_Result);
          If FT_IO_Status <> FT_OK then
          begin
            // FT_Error_Report('FT_Read',FT_IO_Status);
            break;
          end
          else
          begin
          tim:=0;
          if Total<QtyFrom-1 then
            begin
//            AttArray[AttQty]:=qty;  //
//            AttQty:=AttQty+1;       //
              for I := 0 to qty - 1 do
                begin
                  if ((Total+I)<QtyFrom-1) then
                    DataIn[Total+I]:=buffer[I];
//                QtyFrom:=QtyFrom+1;
///                  if DataIn[I]=$FE then
   //                                                                                                                                                                                                                                                 exit;
                end;
           Total:=Total+I;

//            if (QtyFrom+qty =2)and (DataOut[0]<>StartSymbol) and (DataOut[0]=(DataOut[1] xor $FF)) then
//              begin
//                result:=true;
//                exit;
//              end;
            end;
          end;
        end;
    tim:=tim+1;
    if tim>250000 then
      begin
        Result := FALSE;
        break;
      end;
    end;
  until (Total>=QtyFrom);
   Result := (Read_Result=Total);
end;
end;

function FT_PARALLEL_PORT_CLEAR_BUFFER (FT_Parallel_Handle : DWORD;var qtt: integer):boolean;
var
   Read_result:integer;
   qty,q:cardinal;
   FT_IO_Status: FT_Result;
   buffer: array [0..FT_In_Buffer_Index] of byte;
begin
  qty:=0;
  q:= FT_GetQueueStatus(FT_Parallel_Handle,@qty);
  If q <> FT_OK then
  begin
    Result:=false;
  end
  else
  begin
  qtt:=qty;
    if qty>0 then
      begin
        FT_IO_Status := FT_Read(FT_Parallel_Handle,@buffer,qty,@Read_Result);
        If FT_IO_Status <> FT_OK then
          Result:=false
        else
          Result:=false;
      end
     else
        Result:=true;
  end;
end;

function PrepareDataTo (Filename : string; DevNum : integer; PBAddr : byte; StartAddr : cardinal) : boolean;
begin
  result:=false;
  if FlashState<>NOP then
    begin
      Lister.Text:=Lister.Text+'Some FLASH operation is already in progress!';
      exit;
    end;
  if not DefineFLASHType(DevNum,PBAddr) then
    exit;
  OpenLogFile;  //
  SetLength(DatArray,CurrFlashSize);
  if ReadFPGAData(Filename,DatArray,FlDataQty) then
    Lister.Text:=Lister.Text+'Read data from '+Filename+chr($0D)+Chr($0A)
  else
    exit;
  StartFlashAddr:=StartAddr;
  CurrFlashAddr:=StartAddr;
  CurrFlashIndex:=0;
  StopFlashAddr:=StartAddr+FlDataQty;
  ProgDevNum:=DevNum;
  ProgPBAddr:=PBAddr;
  result:=true;
end;

function PrepareDataFrom (DevNum : integer; PBAddr : byte; StartAddr : cardinal) : boolean;
begin
  result:=false;
  if FlashState<>NOP then
    begin
      Lister.Text:=Lister.Text+'Some FLASH operation is already in progress!';
      exit;
    end;
  if not DefineFLASHType(DevNum,PBAddr) then
    exit;
  OpenLogFile;  //
  SetLength(DatArray,CurrFlashSize);
  StartFlashAddr:=StartAddr;
  CurrFlashAddr:=StartAddr;
  CurrFlashIndex:=0;
  StopFlashAddr:=StartAddr+CurrFlashSize;
  ProgDevNum:=DevNum;
  ProgPBAddr:=PBAddr;
  result:=true;
end;

procedure StartFlashProgram (Filename : string; DevNum : integer; PBAddr : byte);
begin
  if not PrepareDataTo(Filename,DevNum,PBAddr,0) then
    exit;
  FlashErase(0,FlDataQty);
end;

function VerifyFlashData : boolean;
var I,q : integer;              //comparing up to 8 pages (2kB) from address CurrFlashAddr with
    z : cardinal;               //data in DatArray from  CurrFlashIndex position
begin
  result:=false;
  for I := 0 to 7 do
    begin
      z:=StopFlashAddr-CurrFlashAddr;
      result:=GetFlashData(FT_In_Buffer,CurrFlashAddr,z);
      if result then
        begin
          for q := 0 to z - 1 do
            begin
              if FT_In_Buffer[q]<>DatArray[CurrFlashIndex+q] then
                begin
                  VeryErrCounter:=VeryErrCounter+1;
                  if VeryErrCounter<20 then
                    Lister.Text:=Lister.Text+'Address $'+IntToHex(CurrFlashIndex+q,6)+':  $'+ IntToHex(FT_In_Buffer[q],2)+
                           '<>$'+IntToHex(DatArray[CurrFlashIndex+q],2)+chr($0D)+Chr($0A);
                end;
           end;
        end
      else
        exit;
      CurrFlashIndex:=CurrFlashIndex+z;
      CurrFlashAddr:=CurrFlashAddr+z;
      if CurrFlashAddr>=StopFlashAddr then
        break;
    end;
end;

function ReadFlashData : boolean;
var I,q : integer;                //reads up to 8 pages (2kB) from CurrFlashAddr to StopFlashAddr
    z : cardinal;                 //then increments CurrFlashAddr
begin
  for I := 0 to 7 do
    begin
      z:=StopFlashAddr-CurrFlashAddr;
      result:=GetFlashData(FT_In_Buffer,CurrFlashAddr,z);
      if result then
        begin
          for q := 0 to z - 1 do
            DatArray[CurrFlashIndex+q]:=FT_In_Buffer[q];
          CurrFlashIndex:=CurrFlashIndex+z;
          CurrFlashAddr:=CurrFlashAddr+z;
          if CurrFlashAddr>=StopFlashAddr then
            break;
        end
      else
        exit;
    end;
end;

procedure StartFlashVerify (Filename : string; DevNum : integer; PBAddr : byte);
begin
  if not PrepareDataTo(Filename,DevNum,PBAddr,0) then
    exit;
  PrepareFlashVerify;
  FlashTimer.Enabled:=true;
end;

procedure StartFlashRead (DevNum : integer; PBAddr : byte);
begin
  PrepareDataFrom(DevNum,PBAddr,0);
  FlashState:=Reading;
  FlashTimer.Interval:=20;
  FlashTimer.Enabled:=true;
end;

procedure FlashTimerDo;
var FLState : byte;
    Succ : boolean;
    str : string;
begin
  FlashTimer.Enabled:=false;
  str:='';
  if not GetFlashState(FLState) then
    begin
      FlashState:=NOP;
      exit;
    end;
  if (FLState and 1)<>0 then
    begin
      FlashTimer.Enabled:=true;
      exit;
    end;
  case FlashState of
  Erasing:
    begin
      Succ:=FlashSectorErase;
      PageCounter:=PageCounter+1;
      ProgressData:=PageCounter/MaxPages;
      if PageCounter=MaxPages then
        begin
          str:='Flash erasing done';
          FlashState:=Writing;
          FlashTimer.Interval:=36;
          ProgressData:=0;
          CurrFlashAddr:=StartFlashAddr;
        end
      else
        begin
          if Succ then
            str:='Erasing sector '
          else
            str:='Erasing failed at sector ';
          str:=str+IntToStr(PageCounter-1);
        end;
    end;
  Writing:
    begin
      Succ:=SendFlashPage;
      if StopFlashAddr=CurrFlashAddr then
        begin
          PrepareFlashVerify;
          str:='FLASH programming done. Verifying starting.';
        end;
      ProgressData:=(CurrFlashAddr-StartFlashAddr)/(StopFlashAddr-StartFlashAddr);
    end;
  Reading:
    begin
      Succ:=ReadFlashData;
      ProgressData:=(CurrFlashAddr-StartFlashAddr)/(StopFlashAddr-StartFlashAddr);
      if CurrFlashAddr=StopFlashAddr then
        begin
          ProgressData:=0;
          FlashState:=NOP;
          if FlashSave.Execute then
            begin
              ConvertToUfpFile(FlashSave.FileName,DatArray,CurrFlashSize);
              str:='Data saved to '+FlashSave.FileName;
            end
          else
            str:='Saving cancelled';
        end;
    end;
  Verifying:
    begin
      Succ:=VerifyFlashData;
      ProgressData:=(CurrFlashAddr-StartFlashAddr)/(StopFlashAddr-StartFlashAddr);
      if CurrFlashAddr=StopFlashAddr then
        begin
          if VeryErrCounter=0 then
            Lister.Text:=Lister.Text+'Verification succeded!'+chr($0D)+Chr($0A);
          ProgressData:=0;
          FlashState:=NOP;
        end;
    end;
  ErasingAdd:
    begin;
      Succ:=FlashSectorErase;
      FlashState:=WritingAdd;   //writing 1 sector per time
      str:='Sector '+IntToStr(CurrSector) +' was erased';
    end;
  WritingAdd:
    begin
      Succ:=SendFlashPage;
      if CurrFlashAddr=StopFlashAddr then
        begin                  //current sector is written
          if CurrSector<MaxSector then
            begin              //next sector
              CurrSector:=CurrSector+1;
              StartAddSectorProc;
              FlashState:=PreReadingAdd;  //back to reading initial flash content
              str:='Sector '+IntToStr(CurrSector) +' was written';
            end
          else
            begin
              CurrSector:=MinSector;    //to verifying
              StartAddSectorProc;
              FlashState:=ReadingAdd;
            end;
        end;
    end;
  PreReadingAdd:
    begin
      Succ:=GetAddFlashSector;
      if CurrPageDone then
        begin
          if AddPgToWrite then
            begin
              StartAddSectorProc;
              if AddPgToErase then
                FlashSectorErase;
             FlashState:=WritingAdd;
             StartAddSectorProc;
            end
          else
            begin
             if CurrSector<MaxSector then
               begin
                 CurrSector:=CurrSector+1;
                 StartAddSectorProc;
               end
             else
               begin
                 if IsWritingAdd then
                   begin
                     CurrSector:=MinSector;
                     StartAddSectorProc;
                     FlashState:=ReadingAdd;
                   end
                 else
                   begin
                     str:='Additional memory is compatible';
                     FlashState:=NOP;
                   end;
               end;
            end;
        end;
    end;
  ReadingAdd:
    begin
      Succ:=GetAddFlashSector;
      if CurrPageDone then
        begin
          if AddPgToWrite then
            str:='Additional memory error in sector '+IntToStr(CurrSector);
          if CurrSector<MaxSector then
            begin
              CurrSector:=CurrSector+1;
              StartAddSectorProc;
            end
          else
            begin
              str:='Additional memory verification completed';
              FlashState:=NOP;
            end;
        end;
    end;
  end;
  FlashTimer.Enabled:=(Succ and (FlashState<>NOP));
  if str<>'' then
    Lister.Text:=Lister.Text+str+chr($0D)+Chr($0A);
  FlashProgr.Position:=Round((FlashProgr.Max-FlashProgr.Min)*ProgressData+FlashProgr.Min);
  if not Succ then
    FlashState:=NOP;
end;

end.

