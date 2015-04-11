{$A8,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N+,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}
{$MINSTACKSIZE $00004000}
{$MAXSTACKSIZE $00100000}
{$IMAGEBASE $00400000}
{$APPTYPE GUI}
{$WARN SYMBOL_DEPRECATED ON}
{$WARN SYMBOL_LIBRARY ON}
{$WARN SYMBOL_PLATFORM ON}
{$WARN UNIT_LIBRARY ON}
{$WARN UNIT_PLATFORM ON}
{$WARN UNIT_DEPRECATED ON}
{$WARN HRESULT_COMPAT ON}
{$WARN HIDING_MEMBER ON}
{$WARN HIDDEN_VIRTUAL ON}
{$WARN GARBAGE ON}
{$WARN BOUNDS_ERROR ON}
{$WARN ZERO_NIL_COMPAT ON}
{$WARN STRING_CONST_TRUNCED ON}
{$WARN FOR_LOOP_VAR_VARPAR ON}
{$WARN TYPED_CONST_VARPAR ON}
{$WARN ASG_TO_TYPED_CONST ON}
{$WARN CASE_LABEL_RANGE ON}
{$WARN FOR_VARIABLE ON}
{$WARN CONSTRUCTING_ABSTRACT ON}
{$WARN COMPARISON_FALSE ON}
{$WARN COMPARISON_TRUE ON}
{$WARN COMPARING_SIGNED_UNSIGNED ON}
{$WARN COMBINING_SIGNED_UNSIGNED ON}
{$WARN UNSUPPORTED_CONSTRUCT ON}
{$WARN FILE_OPEN ON}
{$WARN FILE_OPEN_UNITSRC ON}
{$WARN BAD_GLOBAL_SYMBOL ON}
{$WARN DUPLICATE_CTOR_DTOR ON}
{$WARN INVALID_DIRECTIVE ON}
{$WARN PACKAGE_NO_LINK ON}
{$WARN PACKAGED_THREADVAR ON}
{$WARN IMPLICIT_IMPORT ON}
{$WARN HPPEMIT_IGNORED ON}
{$WARN NO_RETVAL ON}
{$WARN USE_BEFORE_DEF ON}
{$WARN FOR_LOOP_VAR_UNDEF ON}
{$WARN UNIT_NAME_MISMATCH ON}
{$WARN NO_CFG_FILE_FOUND ON}
{$WARN MESSAGE_DIRECTIVE ON}
{$WARN IMPLICIT_VARIANTS ON}
{$WARN UNICODE_TO_LOCALE ON}
{$WARN LOCALE_TO_UNICODE ON}
{$WARN IMAGEBASE_MULTIPLE ON}
{$WARN SUSPICIOUS_TYPECAST ON}
{$WARN PRIVATE_PROPACCESSOR ON}
{$WARN UNSAFE_TYPE ON}
{$WARN UNSAFE_CODE ON}
{$WARN UNSAFE_CAST ON}
unit Unit1;

interface

uses
  SysUtils, Types, Classes, Variants, QTypes, QGraphics, QControls, QForms,
  QDialogs, QStdCtrls;

type
  {объявляем тип "одно измерение"}
  oneSampleInfo = record
    adc           : Integer;    {данные с АЦП}
    chanel        : byte;       {номер кананла}
    counter       : int64;    {показания счетчика}
    error         : Boolean;    {флаг ошибки}
  end;
  TForm1 = class(TForm)
    lIndecator: TLabel;
    lReply: TLabel;
    dlgSaveRawData: TSaveDialog;
    btnGetDataFromCounter: TButton;
    btnSaveRaw: TButton;
    btnGetNPackages: TButton;
    edtPackageAmount: TEdit;
    lpackagesGot: TLabel;
    btnGetHyst: TButton;
    btnSaveDecodedDataToFile: TButton;
    btnSvHyst: TButton;
    btnClrHyst: TButton;
    btnSvIRF: TButton;
    btnShowCWA: TButton;
    btnGetDataSmart: TButton;
    edtSamplesAmount: TEdit;
    edtTestFrom: TEdit;
    edtTestAmount: TEdit;
    btnGetSamples: TButton;
    btnMemOver: TButton;
    btnWindowOffset: TButton;
    cbOutputType: TCheckBox;
    btnMakeBinary: TButton;
    saveCalibrationBtn: TButton;
    lengthEdt: TEdit;
    GoBtn: TButton;
    progresLb: TLabel;
    resetBtn: TButton;
    loadCalBtn: TButton;
    Label1: TLabel;
    progressTotalBtn: TLabel;
    OpenDialog: TOpenDialog;
    browse: TButton;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnGetDataFromCounterClick(Sender: TObject);
    procedure btnSaveRawClick(Sender: TObject);
    procedure btnGetNPackagesClick(Sender: TObject);
    procedure btnGetHystClick(Sender: TObject);
    procedure btnSaveDecodedDataToFileClick(Sender: TObject);
    procedure btnSvHystClick(Sender: TObject);
    procedure btnClrHystClick(Sender: TObject);
    procedure btnSvIRFClick(Sender: TObject);
    procedure btnShowCWAClick(Sender: TObject);
    procedure btnGetDataSmartClick(Sender: TObject);
    procedure btnGetSamplesClick(Sender: TObject);
    procedure btnMemOverClick(Sender: TObject);
    procedure btnWindowOffsetClick(Sender: TObject);
    procedure btnMakeBinaryClick(Sender: TObject);
    procedure saveCalibrationBtnClick(Sender: TObject);
    procedure GoBtnClick(Sender: TObject);
    procedure loadCalBtnClick(Sender: TObject);
    procedure browseClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  GAP_DATA_AVAILBALE = 100;
  DATA_TO_COUNTER_MAX = 100;
  READ_OFFSET=110;
  DATA_FROM_COUNTER_MAX = 16400;
  N_MAX  =1000;
  HYST_MAX=4096;
  ONE_TIME_SAMPLES = 2048; //we can't change it, its just all memory in BRAM
  CHANEL_AMOUNT = 3;
  HYS_IRF_LENGTH = 1000;
  QELIZABETH_MAX = ONE_TIME_SAMPLES * N_MAX; //(1000) myltiply N_MAX(max amount of packages (DEPRECATED 2047 structures in 1 package)) 2048NOW
type
  TCustomBinary = record
    chanel : word;
    bin  : Int64;
  end;
  FileOfCustomBinary = File of TCustomBinary;
var
  Form1: TForm1;
   hystReady, connectionFlag:Boolean;
  dataFromC : array [0..DATA_FROM_COUNTER_MAX] of Byte;
  dataToC   : array [0..DATA_TO_COUNTER_MAX]   of Byte;
  answerLength, msgLength, nextFreeSlot : Cardinal;
  origin, originEnd: array[0..2] of Integer;
  K : array [0..2] of Double;
  qElizabeth : array [0..QELIZABETH_MAX] OF oneSampleInfo;
  HistogramIRF1, histogramIRF2: array [0 .. HYS_IRF_LENGTH] of Integer;
  hyst : array [0..(CHANEL_AMOUNT-1),0..HYST_MAX] of Cardinal;
  rdIndex  :Integer  = 0;
  wrIndex, memOverflowFlag:Integer;
  globalFilePrefix:String;
  goIsEnabled:Boolean = false;
function connectToCounter : Boolean;
procedure testConnection;
function getDataFromCounter(initialAddr:Integer = 0; dataBlock:Integer = 16383) : Boolean;
function getCurrWrAddrA : Integer;
function getMemoryOverflowFlag : Boolean;
function dataAvailableQuery(wr:Integer; rd:Integer) : Boolean;
procedure myDataDecoder(packageSize: Integer = 8188);
procedure myDataDecoder64 (packageSize: Integer = 16383);
procedure getNPackages(n: Integer);
procedure getHyst;
procedure getCalibration(ch:Byte);
procedure getIRFFromAailableData;
procedure getDataSmart(n:Integer);
procedure getSpecSamples(start_sample:integer; amount_to_read:integer);
procedure getSpecSamples64(startSample:integer; amountToRead: integer);
procedure rdIndexInc(n:Integer);
procedure rdIndexInc64(n: Integer);
procedure clearAll;
function setWindowOffset(startCount:Integer; stopCount:Integer): Boolean;
function setWindowFlag:Boolean;
function Power(base: Cardinal; power: Cardinal):Cardinal;
procedure generateAndSaveData( var f : File);
procedure generateAndSaveDataText ( var f : TextFile);
function pow(power: Integer):int64;
function checkIfRawDataAvailable():Boolean;
procedure saveSessionToFile(sessionNumber : Integer);
procedure clearBram();
procedure tryToLoadCalibration(custom:Boolean);
procedure saveSessionToTextFile(sessionNumber : Integer);

implementation

uses
  uFTDIFunctions;

{$R *.xfm}

function Power(base: Cardinal; power: Cardinal):Cardinal;
var    S , i: Cardinal;
  begin
    S:=1;
    for i:= 1 to Power do
    S:=S*base;
    Result:= S;
  end;
function setWindowFlag :Boolean;
 var  CReply : string;
  begin
// settng WidowFlag if we are in colibration mode (all devices ae actvive
  CReply:='';
  dataToC[0]:=$0A;
  dataToC[1]:=$C0;//1100 0000
  msgLength:=2;
  Result:=True;
    if PB_SendCommandToDevice(MyDevNumber,1, dataToC,dataFromC, msgLength, answerLength, CReply) <> PB_Data then
    begin
    ShowMessage('PB_SendCommandToDevice != PB_Data');
    Result:=False;
    end;
  end;

function setWindowOffset(startCount:Integer; stopCount:Integer): Boolean;
  var CReply :string;
  startCountLSB, startCountMSB,stopCountLSB,stopCountMSB:Cardinal;
begin
  //settingg startCount to Window
    CReply:='';
    startCountLSB:=startCount mod 256;
    startCountMSB:=startCount div 256;
    //создаем строку для отправки: 0С.00.50   (Запрос на установку окна)
    dataToC[0]:=$0C;
    dataToC[1]:=startCountMSB;
    dataToC[2]:=startCountLSB;
    msgLength:=3;
    Result:=True;
    if PB_SendCommandToDevice(MyDevNumber,1, dataToC,dataFromC, msgLength, answerLength, CReply) <> PB_Data then
    begin
    ShowMessage('PB_SendCommandToDevice != PB_Data');
    Result:=False;
    end;
  //setting stopCount to Window
    CReply:='';
    stopCountLSB:=stopCount mod 256;
    stopCountMSB:=stopCount div 256;
    dataToC[0]:=$0B;
    dataToC[1]:=stopCountMSB;
    dataToC[2]:=stopCountLSB;
    msgLength:=3;
    Result:=True;
    if PB_SendCommandToDevice(MyDevNumber,1, dataToC,dataFromC, msgLength, answerLength, CReply) <> PB_Data then
    begin
    ShowMessage('PB_SendCommandToDevice != PB_Data');
    Result:=False;
    end;

end;

procedure clearAll;
var j,i : integer;
begin
  wrIndex:=0;
  rdIndex:=0;
  for i:= 0 to (CHANEL_AMOUNT-1) do
    for j:= 0 to HYST_MAX do
    hyst[i,j]:=0;
  for i:= 0 to HYS_IRF_LENGTH do
  begin
    histogramIRF1[i]:=0;
    histogramIRF2[i]:=0;
  end;
  for i:=0 to QELIZABETH_MAX do
  begin
    qElizabeth[i].ADC:=0;
    qElizabeth[i].chanel:=0;
    qElizabeth[i].counter:=0;
  end;
  for i:= 0 to 2 do
  begin
  K[i]:=0;
  origin[i]:=0;
  originEnd[i]:=0;
  end;
  nextFreeSlot:=0;
end;

procedure rdIndexInc(n:Integer);
var newIndex : integer;
begin
  rdIndex:= rdIndex+n;
  if rdIndex > 2047 then rdIndex:=(rdIndex+1)mod 2048;
end;

procedure rdIndexInc64(n: Integer);
var newIndex :integer;
begin
  rdIndex:=rdIndex+n;
  if rdIndex>2047 then rdIndex:=rdIndex mod 2048;
end;

procedure getDataSmart(n:Integer);
var i, currWrAddrA,ahead:integer;
begin
  i:=0;
  while i<n do
  begin
    wrIndex:=getCurrWrAddrA;
    if wrIndex>rdIndex then
    ahead:=wrIndex-rdIndex
    else
    ahead:=(wrIndex-rdIndex+2047);
    if ahead<READ_OFFSET then Continue;
    if n-i<ahead-10 then
    begin
    getSpecSamples64(rdIndex, n-i);
    rdIndexInc(n-i);
    i:=n;
    end
    else
    begin
    getSpecSamples64(rdIndex, ahead-10);
    rdIndexInc(ahead-10);
    i:=i+ahead-10;
    end;
    Form1.progresLb.Caption:=intToStr(i)+'/'+intToStr(n);                                         //TdDo: Доделать
  end;
end;

procedure getSpecSamples64(startSample:integer; amountToRead: integer);
var firstPart, secondPart :Integer;
begin
  if ((startSample>2047) or (startSample<0) or (amountToRead>2048)) then
  ShowMessage('incorrect input in getspecsamples64');
  if amountToRead+startSample > ONE_TIME_SAMPLES then
    begin
    firstPart:=ONE_TIME_SAMPLES - startSample;
    secondPart:=amountToRead-firstPart;
    getDataFromCounter(startSample*8,firstPart*8);
    myDataDecoder64(firstPart*8);
    getDataFromCounter(0,secondPart*8);
    myDataDecoder64(secondPart*8);
    end
  else
    begin
    getDataFromCounter(startSample*8, amountToRead*8);
    myDataDecoder64(amountToRead*8);
    end;
end;

procedure getSpecSamples64NoSaving(startSample:integer; amountToRead: integer);
var firstPart, secondPart :Integer;
begin
  if ((startSample>2047) or (startSample<0) or (amountToRead>2048)) then
  ShowMessage('incorrect input in getspecsamples64');
  if amountToRead+startSample > ONE_TIME_SAMPLES then
    begin
    firstPart:=ONE_TIME_SAMPLES - startSample;
    secondPart:=amountToRead-firstPart;
    getDataFromCounter(startSample*8,firstPart*8);
    getDataFromCounter(0,secondPart*8);
    end
  else
    begin
    getDataFromCounter(startSample*8, amountToRead*8);
    end;
end;

procedure getSpecSamples(start_sample:integer; amount_to_read:integer);
var firstPart, secondPart : Integer;
begin
  if ((start_sample>2047) or (start_sample<0) or (amount_to_read>2047)) then
  ShowMessage('inccorrect input in getSpecSamples');
  if start_sample = 0 then inc(start_sample);
  if amount_to_read + start_sample > ONE_TIME_SAMPLES then
    begin
    firstPart:=ONE_TIME_SAMPLES - start_sample+1;
    secondPart:=amount_to_read-firstPart;
    getDataFromCounter(start_sample*4-4, firstPart*4+3);
    myDataDecoder(firstPart*4);
    getDataFromCounter(1*4-4, secondPart*4+3);
    myDataDecoder(secondPart*4);
    end
  else
    begin
    getDataFromCounter(start_sample*4-4, amount_to_read*4+3);
    myDataDecoder(amount_to_read*4);
    end;

end;

function dataAvailableQuery(wr:Integer; rd:Integer) : Boolean;
var difference : integer;
begin
  difference:= wr-rd;
  if (difference > GAP_DATA_AVAILBALE) or not(difference < (GAP_DATA_AVAILBALE-ONE_TIME_SAMPLES))
  then Result:= True
  else Result:=False;
end;

function getMemoryOverflowFlag : Boolean;
var
  CReply :String;
  begin
  CReply:='';
  dataToC[0]:=$13;//$;
    msgLength:=1;
    if PB_SendCommandToDevice(MyDevNumber,1, dataToC,dataFromC, msgLength, answerLength, CReply) <> PB_Data then
    begin
    ShowMessage('PB_SendCommandToDevice != PB_Data');
    Exit;
    end;
    case dataFromc[0] shr 7 of
    0 : Result:= False;
    1 : Result:=True;
    else
    ShowMessage('PB_wrong_MemOverflow_processing');
    end;
  end;

function getCurrWrAddrA : Integer;
var
  CReply: String;
begin
    CReply:='';
    //создаем строку для отправки: 12.20.00.##.##   (запрос на получения пакета длиной ...)
    dataToC[0]:=$13;//$;
    msgLength:=1;
    if PB_SendCommandToDevice(MyDevNumber,1, dataToC,dataFromC, msgLength, answerLength, CReply) <> PB_Data then
    begin
    ShowMessage('PB_SendCommandToDevice != PB_Data');
    Result:=-1;
    end;
    memOverflowFlag:= dataFromc[0] and 128;
    Result:= dataFromC[1]+(dataFromC[0] and 127)*256;
end;

procedure getIRFFromAailableData;
var  Time :array [0..256] of Double;
  i:Integer;
  begin
    i:=0;
    while i <= nextFreeSlot - CHANEL_AMOUNT do
    begin
      if (qElizabeth[i].counter = qElizabeth[i+1].counter) and (qElizabeth[i].counter = qElizabeth[i+2].counter) then
        begin
        Time[qElizabeth[i].chanel]:= (origin[qElizabeth[i].chanel]-qElizabeth[i].ADC)*K[qElizabeth[i].chanel];
        Time[qElizabeth[i+1].chanel]:= (origin[qElizabeth[i+1].chanel]-qElizabeth[i+1].ADC)*K[qElizabeth[i+1].chanel];
        Time[qElizabeth[i+2].chanel]:= (origin[qElizabeth[i+2].chanel]-qElizabeth[i+2].ADC)*K[qElizabeth[i+2].chanel];
        Inc(histogramIRF1[Round((Time[qElizabeth[i].chanel]-Time[qElizabeth[i+1].chanel])*100)+500 ]);
        Inc(histogramIRF2[Round((Time[qElizabeth[i].chanel]-Time[qElizabeth[i+2].chanel])*100)+500 ]);
        end;
        i:=i+1;
    end;
  end;

procedure generateAndSaveData(var f : File);
var tempBuffer: TCustomBinary;
    counter: Int64;
    chanel: Boolean;
    byteBuffer: Byte;
    i,j: Integer;
    analogTime, totalTime: Double;
begin
  i:=0;
  while i<=nextFreeSlot do
  begin
    if (origin[qElizabeth[i].chanel] >= qElizabeth[i].adc)and(originEnd[qElizabeth[i].chanel]<= qElizabeth[i].adc) then
    begin
      analogTime := (origin[qElizabeth[i].chanel]-qElizabeth[i].ADC)*K[qElizabeth[i].chanel]; //got analog time in ns
      totalTime := 12.5*qElizabeth[i].counter + analogTime;
      tempBuffer.bin:=Round(totalTime/0.081);    // time in bins 81ps now
      byteBuffer:=tempBuffer.bin mod 256;
      for  j:=1 to 8 do
      begin
        blockWrite(f,byteBuffer,1);
        tempBuffer.bin:=tempBuffer.bin div 256;
        byteBuffer:= tempBuffer.bin mod 256;
      end;
      tempBuffer.chanel:=qElizabeth[i].chanel;
      byteBuffer:=tempBuffer.chanel mod 256;
      blockWrite(f,byteBuffer,1);
      byteBuffer:=tempBuffer.chanel div 256;
      blockWrite(f,byteBuffer,1);
    end;
    i:=i+1;
  end;
end;

procedure generateAndSaveDataText(var f : TextFile);
var tempBuffer: TCustomBinary;
    i: Integer;
    analogTime, totalTime: Double;
begin
  i:=0;
  while i<=nextFreeSlot do
  begin
    if (origin[qElizabeth[i].chanel] >= qElizabeth[i].adc)and(originEnd[qElizabeth[i].chanel]<= qElizabeth[i].adc) then
    begin
      analogTime := (origin[qElizabeth[i].chanel]-qElizabeth[i].ADC)*K[qElizabeth[i].chanel]; //got analog time in ns
      totalTime := 12.5*qElizabeth[i].counter + analogTime;
      tempBuffer.bin:=Round(totalTime/0.081);    // time in bins 81ps now
      tempBuffer.chanel:=qElizabeth[i].chanel;
      writeln(f,tempBuffer.chanel,' ',tempBuffer.bin:9);
    end;
    i:=i+1;
  end;
end;


procedure getCalibration(ch:Byte);
var counter,i, sum, rightBorderHyst, leftBorderHyst,halfWidth  :Integer;
    halfSum  : Double;
begin
  i:=-1;
  counter:=0;
  while counter<10 do
  begin
    i:=i+1;
    if hyst[ch,i] >= 2 then
    counter:=counter+1
    else
     counter:=0;
  end;
  leftBorderHyst:=i-10;
  //ShowMessage('leftBorderHyst'+intToStr(leftBorderHyst));
  counter:=0;
  i:=4097;
  while counter<10 do
  begin

    i:=i-1;
    if hyst[Ch,i] >= 2 then
    counter:=counter+1
    else counter:=0;
  end;
  rightBorderHyst:=i+10;
  //ShowMessage('rightBorder'+inttostr(rightBorderHyst));
  Sum:=0;
  for i:= leftBorderHyst to rightBorderHyst do
  begin
    sum:=sum+hyst[ch,i];
  end;
  halfSum:=sum/(rightBorderHyst-leftBorderHyst);
  i:=rightBorderHyst;
  origin[ch]:=i;
  while hyst[ch,i]<halfSum do
  begin
    origin[ch]:=i;
    Dec(i);
  end;
  i:=leftBorderHyst;
  originEnd[ch]:=i;
  while hyst[ch,i]< halfSum do
  begin
    originEnd[ch]:=i;
    Inc(i);
  end;
  halfWidth:=origin[ch]-originEnd[ch];
  K[ch]:=12.5/halfWidth;
  ShowMessage('origin, originend'+inttostr(origin[ch])+' '+inttostr(originEnd[ch])+' '+floattostr(K[Ch]));
end;

procedure getNSamples(n: Integer);
var i, currWrAddrA,dataBlock: Integer;
begin
  i:=0;
  nextFreeSlot:=0;
  if n<0 then
    begin
     n:=n*(-1);
     form1.edtSamplesAmount.Text:=IntToStr(n);
     end;
  if n>N_MAX then
    begin
        n:=N_MAX;
        form1.edtSamplesAmount.Text:=IntToStr(n);
    end;

end;

procedure getNPackages(n: Integer);
var i:Integer;
begin
  i:=0;
  nextFreeSlot:=0;
  if N<0 then
    begin
     N:=N*(-1);
     form1.edtPackageAmount.Text:=IntToStr(N);
     end;
  if N>N_MAX then
    begin
        N:=N_MAX;
        form1.edtPackageAmount.Text:=IntToStr(N);
    end;
  while i<N do
  begin
  i:=i+1;
  Form1.lpackagesGot.Caption:=IntToStr(i)+'/'+intToStr(N);
  getDataFromCounter;
  myDataDecoder;
  end;
end;

procedure myDataDecoder64 (packageSize: Integer = 16383);
var i,j :Integer;
begin
  i:=0;
  j:=nextFreeSlot;
  while i<packageSize do //16383 is full memory
    begin
    qElizabeth[j].counter:= dataFromC[i]
                            +dataFromC[i+1]*pow(1)
                            +dataFromC[i+2]*pow(2)
                            +dataFromC[i+3]*pow(3)
                            +dataFromC[i+4]*pow(4)
                            +dataFromC[i+5]*pow(5);
    qElizabeth[j].adc:= dataFromC[i+6]+(dataFromC[i+7]and $0f)*256;
    qElizabeth[j].chanel:= dataFromC[i+7] shr 5;
    if (((dataFromC[i+3] shl 3) shr 7)=$01) then
    qElizabeth[j].error := True else
    qElizabeth[j].error := False;
    i:=i+8;
    j:=j+1;
    end;
nextFreeSlot:=j;
end;

function pow(power: Integer):int64;
var res :int64;
    i:integer;
begin
  res:=1;
  for i:= 1 to power do
  res:=res*256;
  Result:=res;
end;

procedure myDataDecoder(packageSize: Integer = 8188);
var i, j: Integer;
begin
i:= 3;
j:=nextFreeSlot;
while i<(packageSize) do      // 8190 is a package size
  begin
  qElizabeth[j].counter:= dataFromC[i]+ dataFromC[i+1]*256;
  qElizabeth[j].adc:= dataFromC[i+2]+(dataFromC[i+3]and $0f)*256;
  qElizabeth[j].chanel:=dataFromC[i+3] shr 5;
  if (((dataFromC[i+3] shl 3) shr 7)=$01) then
    qElizabeth[j].error := True else
    qElizabeth[j].error := False;
  i:=i+4;
  j:=j+1;
  end;
nextFreeSlot:=j;
end;

// this function should decode data with correct handeling of the first poore  byte. now, i feel a kind of an uncertance about
// such approach
procedure myDataDectoerFull(packageSize: Integer = 8191);
var i,j: Integer;
begin
  i:=0;
  j:=nextFreeSlot;
  while i<(packageSize) do
  begin
    qElizabeth[j].counter:= dataFromC[i]+dataFromC[i+1]*256;
    qElizabeth[j].adc:= dataFromC[i+2]+(dataFromC[i+3]and $0f)*256;
    qElizabeth[j].chanel:= dataFromC[i+3] shr 5;
    if (((dataFromC[i+3] shl 3) shr 7)=$01) then
      qElizabeth[j].error := True else
      qElizabeth[j].error := False;
    i:=i+4;
    j:=j+1;
  end;
end;

function getDataFromCounter(initialAddr:Integer = 0; dataBlock:Integer = 16383):Boolean;
var    i     : integer;
  CReply   : string;
  begin
    for i:=0 to DATA_TO_COUNTER_MAX do dataToC[i]:=0;
    for i:=0 to DATA_FROM_COUNTER_MAX do dataFromC[i]:=0;
    CReply:='';
    //создаем строку для отправки: 12.20.00.##.##   (запрос на получения пакета длиной ...)
    dataToC[0]:=$12;//$;
    dataToC[1]:=(initialAddr div 256)+$40;
    //dataToC[1]:=$20;
    dataToC[2]:=(initialAddr mod 256);
    //dataToC[2]:=$00;
    dataToC[3]:=dataBlock div 256;
    //dataToC[3]:=$1F;
    dataToC[4]:=dataBlock mod 256;
    //dataToC[4]:=$FF;   //нужно пытаться заменить $FF00(7936) на $FFFE (8190 ячеек памяти)
    msgLength:=5;
    Result:=True;
    if PB_SendCommandToDevice(MyDevNumber,1, dataToC,dataFromC, msgLength, answerLength, CReply) <> PB_Data then
    begin
    ShowMessage('PB_SendCommandToDevice != PB_Data');
    Result:=False;
    end;
  end;

  procedure TForm1.FormCreate(Sender: TObject);
var i:integer;
begin
nextFreeSlot:=0;
MyDevNumber:=0;
for i:= 0 to HYST_MAX do
begin
  hyst[0,i]:=0;
  hyst[1,i]:=0;
  hyst[2,i]:=0;
end;
for i:= 0 to HYS_IRF_LENGTH do
begin
  HistogramIRF1[i]:=0;
  histogramIRF2[i]:=0;
end;
for i:= 0 to DATA_FROM_COUNTER_MAX do dataFromC[i]:=0;
connectionFlag:=connectToCounter();
if (not connectionFlag) then ShowMessage('Faild connection to Counter while starting program');
tryToLoadCalibration(false);
end;

procedure testConnection();
  begin
     if (connectionFlag=False) then connectionFlag := connectToCounter();
     if (connectionFlag=False) then ShowMessage('connection Error, check if Device connected');
  end;

function connectToCounter():Boolean; //
var i :Integer;
    msgLength, answerLength : Cardinal;
    dataToPb, dataFromPb: array [0..50] of Byte;
    pbReply,st: string;
begin
  FTDSetInit;
  SearchForAllPicoblaze(st);
  Form1.lIndecator.Caption := st+' '+IntToStr(FTDevFound)+' FT devices found';
  ConnectToFTDevice(MyDevNumber);
  dataToPb[0]:= $0F;
  dataToPb[1]:= $FF;
  dataToPb[2]:= $EE;
  msgLength:=3;
  for i:= 0 to 50 do dataFromC[i]:=0;
  if PB_SendCommandToDevice(MyDevNumber,1, dataToPb,dataFromPb, msgLength, answerLength, pbReply) = PB_Data then
  begin
    Form1.lReply.Caption:=ByteArrToString(dataFromPb, answerLength, 0);
    Result:=True;
  end
  else
  begin
    Form1.lReply.Caption:='error ocured s="'+pbReply+'"';
    Result:=False;
  end;
end;


procedure TForm1.btnGetDataFromCounterClick(Sender: TObject);
var i:integer;
begin
//for i:=0 to DATA_TO_COUNTER_MAX do dataToC[i]:=0;
//CReply:='';
testConnection;
getDataFromCounter;
Form1.btnGetHyst.Enabled:=True;
end;

procedure TForm1.btnSaveRawClick(Sender: TObject);
var f: TextFile;
  i:Integer;
begin
if dlgSaveRawData.Execute then
  begin
    AssignFile(f,dlgSaveRawData.FileName);
    Rewrite(f);
  end
  else
  ShowMessage('Faild while creating a file for raw data');
for i:=0 to   (answerLength-1) do
  Writeln(f,intToHex(dataFromC[i],2));
CloseFile(f);
end;

procedure TForm1.btnGetNPackagesClick(Sender: TObject);
var n: Integer;
begin
//for i:=0 to DATA_TO_COUNTER_MAX do dataToC[i]:=0;
//CReply:='';
testConnection;
  try n:=StrToInt(edtPackageAmount.Text);
    except
    ShowMessage('you have to write number');
    form1.edtPackageAmount.SetFocus;
    end;
getNPackages(n);
Form1.btnGetHyst.Enabled:=True;
end;

procedure getHyst;
var i:Integer;
begin
i:=0;
  while i<nextFreeSlot do
  begin;
    if qElizabeth[i].chanel=0 then inc(hyst[0,qElizabeth[i].adc]) else
    if qElizabeth[i].chanel=1 then inc(hyst[1,qElizabeth[i].adc]) else
    if qElizabeth[i].chanel=2 then inc(hyst[2,qElizabeth[i].adc]);
    i:=i+1;
  end;
  hystReady:=True;
end;
procedure TForm1.btnGetHystClick(Sender: TObject);
var i:Integer;
begin
getHyst;
end;

procedure TForm1.btnSaveDecodedDataToFileClick(Sender: TObject);
var
  fTxt: TextFile;
  i: Cardinal;
begin
if ( not dlgSaveRawData.Execute ) then Exit;
  AssignFile(fTxt, dlgSaveRawData.FileName);
  Rewrite(fTxt);
  i:=0;
  while i<nextFreeSlot do
  begin
    Writeln(fTxt,qElizabeth[i].chanel:3,' ',qElizabeth[i].ADC:4,' ',qElizabeth[i].counter:10);
    i:=i+1;
  end;
  closeFile(fTxt);
end;

procedure TForm1.btnSvHystClick(Sender: TObject);
var f:TextFile;
    i:Integer;
begin
  if (not dlgSaveRawData.Execute) then Exit;
  AssignFile(f,dlgSaveRawData.FileName);
  Rewrite(f);
  for i:=0 to HYST_MAX do
  begin
    Writeln(f,i,' ',hyst[0,i]:4,' ' ,hyst[1,i]:4,' ',hyst[2,i]:4);
  end;
  CloseFile(f);
end;

procedure TForm1.btnClrHystClick(Sender: TObject);
var i: Integer;
begin
for i:=1 to HYST_MAX do
begin
  hyst[0,i]:=0;
  hyst[1,i]:=0;
  hyst[2,i]:=0;
end;
hystReady:=False;
end;

procedure TForm1.btnSvIRFClick(Sender: TObject);
var f:TextFile;
    i:Integer;
begin
if (not dlgSaveRawData.Execute) then Exit;
  AssignFile(f,dlgSaveRawData.FileName);
  Rewrite(f);
  if nextFreeSlot = 0 then
  begin
    ShowMessage(' no raw data');
    Exit;
  end;
  if hystReady=False then
  begin
    ShowMessage('no hyst in memory');
    Exit;
  end;
  getCalibration(0);
  getCalibration(1);
  getCalibration(2);
  getIRFFromAailableData;
  for i:=0 to HYS_IRF_LENGTH do
  begin
    write(f,i:3);
    write(f,histogramIRF1[i]:8);
    Writeln(f,histogramIRF2[i]:8);
  end;

  CloseFile(f);
end;

procedure TForm1.btnShowCWAClick(Sender: TObject);
begin
Form1.lIndecator.Caption:=IntToStr(getCurrWrAddrA);
end;

procedure TForm1.btnMemOverClick(Sender: TObject);
begin
Form1.lIndecator.Caption:=BoolToStr(getMemoryOverflowFlag, True);
end;

procedure TForm1.btnGetDataSmartClick(Sender: TObject);
var n: Integer;
begin
testConnection;
  try n:=StrToInt(edtSamplesAmount.Text);
    except
    ShowMessage('you have to write number');
    form1.edtSamplesAmount.SetFocus;
    end;
getDataSmart(n);
Form1.btnGetHyst.Enabled:=True;
end;

procedure TForm1.btnGetSamplesClick(Sender: TObject);
var startSample,amountToRead : Integer;
begin
startSample:=  StrToInt(edtTestFrom.Text);
amountToRead:= StrToInt(edtTestAmount.Text);

getSpecSamples(startSample,amountToRead);
end;

procedure TForm1.btnWindowOffsetClick(Sender: TObject);
var startOffset, stopOffset : Cardinal;
begin
//получаем отступы...
try
  startOffset := StrToInt(edtTestFrom.Text);
except
  ShowMessage('you have to write number (startWindowOffset)');
  form1.edtTestFrom.SetFocus;
  Exit;
end;

try
  stopOffset := StrToInt(edtTestAmount.Text);
except
  ShowMessage('you have to write number (stopWindowOffset)');
  form1.edtTestAmount.SetFocus;
  Exit;
end;


if startOffset >= stopOffset then
  begin
    ShowMessage('start is greater than stop witch is wrong');
    edtTestFrom.SetFocus;
    Exit;
  end;

//проверяем полученные данные  (тут нужно удостовериться что данные оказались меньше 16 бит)
if ((startOffset div Power(2,16)) >0) then
    ShowMessage('startOffset is out of bound');
if stopOffset div Power(2,16) >0 then
    ShowMessage('stopOffset is out of bound');

//инициализируем требуемое окно
setWindowOffset(startOffset, stopOffset);
//включаем режим работы окно
setWindowFlag;
end;

procedure calculateCalibrationInfo();
begin
checkIfRawDataAvailable;
getHyst;
getCalibration(0);
getCalibration(1);
getCalibration(2);
end;

function checkIfRawDataAvailable():Boolean;
begin
if nextFreeSlot = 0 then
  begin
    ShowMessage(' no raw data');
    Exit;
  end;
Result:=true;
end;

procedure TForm1.btnMakeBinaryClick(Sender: TObject);
var     fBin: File;
        fTxt: TextFile;
begin
  if nextFreeSlot = 0 then
  begin
    ShowMessage(' no raw data');
    Exit;
  end;
  if hystReady=False then
  begin
    ShowMessage('no hyst in memory');
    Exit;
  end;
  getCalibration(0);
  getCalibration(1);
  getCalibration(2);
  if (cbOutputType.Checked = True) then
  begin
    if(not dlgSaveRawData.Execute) then Exit;
    AssignFile(fTxt,dlgSaveRawData.FileName);
    Rewrite(fTxt);
    generateAndSaveDataText(fTxt);
    CloseFile(fTxt);
  end
    else
  begin
    if (not dlgSaveRawData.Execute) then Exit;
    AssignFile(fBin,dlgSaveRawData.FileName);
    Rewrite(fBin,1);
    generateAndSaveData(fBin);
    CloseFile(fBin);
  end;
end;

procedure TForm1.saveCalibrationBtnClick(Sender: TObject);
var i : Integer;
f: TextFile;
begin
if (not dlgSaveRawData.Execute) then Exit;
AssignFile(f,dlgSaveRawData.FileName);
Rewrite(f);
calculateCalibrationInfo();
for i:= 0 to 2 do
  begin
  writeln(f,originEnd[i]);
  writeln(f,origin[i]);
  writeln(f,K[i]);
  end;
CloseFile(f);
end;

procedure TForm1.GoBtnClick(Sender: TObject);
var n,i : Integer;
begin
  testConnection;
  try
    n:=StrToInt(lengthEdt.Text);
  except
    ShowMessage('you have to write number');
    form1.edtPackageAmount.SetFocus;
  end;
  clearBram;
  for i:=1 to n do
  begin
    getDataSmart(5000);
    Form1.progressTotalBtn.Caption:=intToStr(i)+'/'+intToStr(n);
    saveSessionToTextFile(i);  //saveSessionToFile(i);
    nextFreeSlot:=0;
  end;
end;

procedure clearBram();
var ahead: integer;
begin
  wrIndex:=getCurrWrAddrA;
  if wrIndex>rdIndex then
    ahead:=wrIndex-rdIndex
  else
    ahead:=(wrIndex-rdIndex+2047);
  getSpecSamples64NoSaving(rdIndex, ahead-1);
end;

procedure saveSessionToFile(sessionNumber : Integer);
var f:  File;
name: String;
begin
  name:=globalFilePrefix+intToStr(sessionNumber);
  AssignFile(f,name);
  Rewrite(f,1);
  if nextFreeSlot = 0 then
  begin
    ShowMessage(' no raw data');
    Exit;
  end;
  generateAndSaveData(f);
  CloseFile(f);
end;

procedure saveSessionToTextFile(sessionNumber : Integer);
var f: TextFile;
name: String;
begin
  name:=globalFilePrefix+intToStr(sessionNumber);
  AssignFile(f,name);
  Rewrite(f);
  if nextFreeSlot = 0 then
  begin
    ShowMessage(' no raw data');
    Exit;
  end;
  generateAndSaveDataText(f);
  CloseFile(f);

end;



procedure tryToLoadCalibration(custom:Boolean);
var f :textFile;
i:integer;
begin
if (custom = true) then
begin
  if (not Form1.OpenDialog.Execute) then Exit;
  AssignFile(f,Form1.OpenDialog.FileName);
  reset(f);
  for i:= 0 to 2 do
  begin
    readln(f,originEnd[i]);
    readln(f,origin[i]);
    readln(f,K[i]);
  end;
  close(f);
end
else
begin
  AssignFile(f,'.\calibration.cfg');
  try
  reset(f);
  except
  showMessage('unable to find calibration.cfg please make sure it is exist');
  exit;
  end;
  for i:= 0 to 2 do
  begin
    readln(f,originEnd[i]);
    readln(f,origin[i]);
    readln(f,K[i]);
  end;
  close(f);
end;
end;

procedure TForm1.loadCalBtnClick(Sender: TObject);
begin
tryToLoadCalibration(true);
end;

procedure TForm1.browseClick(Sender: TObject);
begin
  if (not dlgSaveRawData.Execute) then Exit;
  globalFilePrefix:=dlgSaveRawData.FileName;
  GoBtn.Enabled:=true;
end;

end.
