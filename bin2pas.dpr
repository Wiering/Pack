program bin2pas;

  {$APPTYPE CONSOLE}

  uses
    SysUtils;

  const
    BUF_SIZE = $FFF8;

  var
    InputFile: string;
    OutputFile: string;
    ProcName: string;
    FI: file;
    FO: textfile;
    Buffer: array[0..BUF_SIZE - 1] of Byte;
    i, j, p: Integer;
    NumRead: Integer;

begin
  if ParamCount () < 2 then
  begin
    WriteLn ('syntax: bin2pas input output [name]');
    Halt (1);
  end;

  InputFile := ParamStr (1);
  OutputFile := ParamStr (2);
  if (ParamCount > 2) then
    ProcName := ParamStr (3)
  else
    ProcName := InputFile;
  i := Pos ('.', ProcName);
  if (i >= 0) then
    Delete (ProcName, i, 1);

  AssignFile (FI, InputFile);
  Reset (FI, 1);
  AssignFile (FO, OutputFile);
  ReWrite (FO);

  BlockRead (FI, Buffer, SizeOf (Buffer), NumRead);

  WriteLn (FO, 'procedure ' + ProcName + '; assembler;');
  WriteLn (FO, 'asm');
  for j := 0 to (NumRead + 15) div 16 - 1 do
  begin
    Write (FO, '  db ');
    for i := 0 to 15 do
    begin
      p := j * 16 + i;
      if (p < NumRead) then
      begin
        Write (FO, Ord (Buffer[p]): 3);
        if ((i < 15) and (p + 1 < NumRead)) then
          Write (FO, ',');
      end;
    end;
    WriteLn (FO, '');
  end;
  WriteLn (FO, 'end;');
  CloseFile (FI);
  CloseFile (FO);
end.
