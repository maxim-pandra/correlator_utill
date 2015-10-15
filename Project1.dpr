program Project1;

uses
  QForms,
  Unit1 in 'Unit1.pas' {Form1},
  uFTDIFunctions in 'uFTDIFunctions.pas',
  uniteFlash in 'uniteFlash.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
