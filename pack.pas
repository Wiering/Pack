program Pack;

  { Pack - Data Packer by Mike Wiering, Nijmegen, The Netherlands }

  uses
    Dos,
    Crt;

  {$I-}

  const
    MAX_SIZE = $10000 - 8;

  type
    BufPtr = ^Buffer;
    Buffer = array[0..MAX_SIZE - 1] of Char;

  var
    Buf1,
    Buf2: BufPtr;
    InputName,
    OutputName: PathStr;
    fInput,
    fOutput: File;
    InputSize,
    OutputSize: LongInt;
    NumRead: Word;


  procedure PackIt;

    type
      Method =
       (mdCopy,     { = 0 }
        mdStore0,   { = 1 }
        mdStoreB,   { = 2 }
        mdStoreW,   { = 3 }
        mdStoreD,   { = 4 }
        mdStoreSP,  { = 5 }
        mdSkip,     { = 6 }

        mdNone);    { = 7 }

    var
      CurPos: Word;
      CurMethod,
      MaxMethod: Method;
      MaxGain: Integer;
      MaxBytes: Word;
      Buf: string;
      BufSize: Byte absolute Buf;
      Progress: string;
      BytesLeft,
      L: LongInt;
      i, j: Word;
      CopyCount,
      CopyStart: Word;

    procedure WriteStr (S: string);
      var
        i: Integer;
    begin
      for i := 1 to Length (S) do
        Buf2^[OutputSize + i - 1] := S[i];
      Inc (OutputSize, Length (S));
    end;

    function WordStr (W: Word): string;
    begin
      WordStr := Chr (Lo (W)) + Chr (Hi (W));
    end;


    procedure CheckStore0;
      var
        Count: Integer;
    begin
      Count := 0;
      while (Buf1^[CurPos + Count] = #0) and (Count < BufSize) do
        Inc (Count);
      if Count > MaxGain + (0) then
      begin
        MaxMethod := mdStore0;
        MaxBytes := Count;
        MaxGain := Count - (0);
      end;
    end;

    procedure CheckStoreSP;
      var
        Count: Integer;
    begin
      Count := 0;
      while (Buf1^[CurPos + Count] = ' ') and (Count < BufSize) do
        Inc (Count);
      if Count > MaxGain + (0) then
      begin
        MaxMethod := mdStoreSP;
        MaxBytes := Count;
        MaxGain := Count - (0);
      end;
    end;

    procedure CheckStoreB;
      var
        Count: Integer;
    begin
      Count := 0;
      while (Buf1^[CurPos + Count] = Buf[1]) and (Count < BufSize) do
        Inc (Count);
      if Count > MaxGain + (1) then
      begin
        MaxMethod := mdStoreB;
        MaxBytes := Count;
        MaxGain := Count - (1);
      end;
    end;

    procedure CheckStoreW;
      var
        Count: Integer;
    begin
      Count := 0;
      while (Buf1^[CurPos + Count] = Buf[1])
        and (Buf1^[CurPos + Count + 1] = Buf[2])
        and (Count < BufSize) do
          Inc (Count, 2);
      if Count > MaxGain + (2) then
      begin
        MaxMethod := mdStoreW;
        MaxBytes := Count;
        MaxGain := Count - (2);
      end;
    end;


    procedure CheckStoreD;
      var
        Count: Integer;
    begin
      Count := 0;
      while (Buf1^[CurPos + Count] = Buf[1])
        and (Buf1^[CurPos + Count + 1] = Buf[2])
        and (Buf1^[CurPos + Count + 2] = Buf[3])
        and (Buf1^[CurPos + Count + 3] = Buf[4])
        and (Count < BufSize) do
          Inc (Count, 4);
      if Count > MaxGain + (4) then
      begin
        MaxMethod := mdStoreD;
        MaxBytes := Count;
        MaxGain := Count - (4);
      end;
    end;


    procedure CheckSkip;
      var
        Count: Integer;
        S: string;
        L: byte absolute S;
    begin
      Count := 0;
      S := '';
      while (Buf1^[CurPos + Count] = Buf[1])
        and ((L <= 2) or (S[L] <> S[L - 1]) or (S[L - 1] <> S[L - 2]))
        and (Count < BufSize) do
        begin
          Inc (Count, 2);
          S := S + Buf1^[CurPos + Count + 3];
        end;
      if Count > MaxGain + (2 + Count div 2) then
      begin
        MaxMethod := mdSkip;
        MaxBytes := Count;
        MaxGain := Count - (2 + Count div 2);
      end;
    end;


    procedure WriteStore0;
    begin
      if MaxBytes <= $1F then
        WriteStr (Chr (Byte (mdStore0) shl 5 + MaxBytes))
      else
        WriteStr (Chr (Byte (mdStore0) shl 5 + 0) + WordStr (MaxBytes));
    end;

    procedure WriteStoreSP;
    begin
      if MaxBytes <= $1F then
        WriteStr (Chr (Byte (mdStoreSP) shl 5 + MaxBytes))
      else
        WriteStr (Chr (Byte (mdStoreSP) shl 5 + 0) + WordStr (MaxBytes));
    end;


    procedure WriteStoreB;
    begin
      if MaxBytes <= $1F then
        WriteStr (Chr (Byte (mdStoreB) shl 5 + MaxBytes) + Buf[1])
      else
        WriteStr (Chr (Byte (mdStoreB) shl 5 + 0) + WordStr (MaxBytes) + Buf[1]);
    end;

    procedure WriteStoreW;
    begin
      if MaxBytes div 2 <= $1F then
        WriteStr (Chr (Byte (mdStoreW) shl 5 + MaxBytes div 2) + Buf[1] + Buf[2])
      else
        WriteStr (Chr (Byte (mdStoreW) shl 5 + 0) + WordStr (MaxBytes div 2) + Buf[1] + Buf[2]);
    end;

    procedure WriteStoreD;
    begin
      if MaxBytes div 4 <= $1F then
        WriteStr (Chr (Byte (mdStoreD) shl 5 + MaxBytes div 4) + Buf[1] + Buf[2] + Buf[3] + Buf[4])
      else
        WriteStr (Chr (Byte (mdStoreD) shl 5 + 0) + WordStr (MaxBytes div 4) + Buf[1] + Buf[2] + Buf[3] + Buf[4]);
    end;

    procedure WriteSkip;
      var
        i: Integer;
    begin
      if MaxBytes div 2 < $1F then
        WriteStr (Chr (Byte (mdSkip) shl 5 + MaxBytes div 2))
      else
        WriteStr (Chr (Byte (mdSkip) shl 5 + 0) + WordStr (MaxBytes div 2));
      WriteStr (Buf[1]);
      for i := 1 to MaxBytes div 2 do
        WriteStr (Buf[i * 2]);
    end;


    procedure JustCopyChar;
      var
        i: Word;
    begin
      if CurMethod <> mdCopy then
      begin
        CopyStart := OutputSize;
        CopyCount := 0;
        WriteStr (Chr (Byte (mdCopy) shl 5));
        CurMethod := mdCopy;
      end;
      if CopyCount = $1F then
      begin
        for i := OutputSize downto CopyStart + 1 do
          Buf2^[i + 2] := Buf2^[i];
        Buf2^[CopyStart] := Chr (Byte (mdCopy) shl 5);
        Inc (OutputSize, 2);
      end;
      WriteStr (Buf[1]);
      Inc (CopyCount);
      if CopyCount > $1F then
      begin
        Buf2^[CopyStart + 1] := Chr (Lo (CopyCount));
        Buf2^[CopyStart + 2] := Chr (Hi (CopyCount));
      end
      else
        Buf2^[CopyStart] := Chr (Byte (mdCopy) shl 5 + CopyCount);
    end;


  begin
    CurPos := 0;
    OutputSize := 0;
    CopyCount := 0;
    CopyStart := $FFFF;

    CurMethod := mdNone;
    repeat
      i := InputSize - CurPos;
      BytesLeft := i;
      j := SizeOf (Buf) - 1;
      if i > j then
        i := j;
      Move (Buf1^[CurPos], Buf[1], i);
      BufSize := i;

      MaxMethod := mdNone;
      MaxGain := 0;
      MaxBytes := 0;

      CheckStore0;
      CheckStoreSP;
      CheckStoreB;
      CheckStoreW;
      CheckStoreD;
      CheckSkip;


      if MaxGain = 0 then
        JustCopyChar
      else
      begin
        case MaxMethod of
          mdStore0:
            WriteStore0;
          mdStoreB:
            WriteStoreB;
          mdStoreW:
            WriteStoreW;
          mdStoreD:
            WriteStoreD;
          mdStoreSP:
            WriteStoreSP;
          mdSkip:
            WriteSkip;

        end;
        CurMethod := MaxMethod;
        Inc (CurPos, MaxBytes - 1);
      end;

      Inc (CurPos);

      FillChar (Progress, SizeOf (Progress), '.');
      Progress[0] := #50;
      L := CurPos;
      j := 100 * L div InputSize;
      for i := 1 to j div 2 do
        Progress[i] := '°';
      L := OutputSize;
      for i := 1 to (100 * L div InputSize) div 2 do
        Progress[i] := 'Û';
      Write (#13, Progress, ' ', j: 3, '%');

    until CurPos >= InputSize;
    Write (#13, Progress, ' ', (100 * L / InputSize): 1:1, '%  ');
  end;


{ ===== UNPACK.INC ======================================================== }

  { Unpack routines - use PACK.EXE to pack data files }

  const
    mdCopy    = 0;
    mdStore0  = 1;
    mdStoreB  = 2;
    mdStoreW  = 3;
    mdStoreD  = 4;
    mdStoreSP = 5;
    mdSkip    = 6;

  type
    ByteArrayPtr = ^ByteArray;
    ByteArray = array[0..$7FFE] of Byte;

  var
    CurBlock: ByteArrayPtr;
    CurPos: Word;
    CurByte: Byte;
    CurMethod: Byte;
    CurCount: Word;
    CurData: LongInt;
    CurDataAr: array[0..3] of Byte absolute CurData;

  procedure Unpack (P: Pointer);
  begin
    CurBlock := P;
    CurPos := 0;
    CurMethod := $FF;
  end;

  function GetNextByte: Byte;
    var
      b: Byte;
  begin
    if CurMethod = $FF then
    begin
      b := CurBlock^[CurPos];
      Inc (CurPos);
      CurMethod := b shr 5;
      CurCount := b and $1F;
      if CurCount = 0 then
      begin
        CurCount := CurBlock^[CurPos] + CurBlock^[CurPos + 1] shl 8;
        Inc (CurPos, 2);
      end;
      case CurMethod of
        mdStoreB,
        mdSkip:
          begin
            CurData := CurBlock^[CurPos];
            Inc (CurPos);
            CurByte := 0;
          end;
        mdStoreW:
          begin
            CurData := CurBlock^[CurPos] + CurBlock^[CurPos + 1] shl 8;
            Inc (CurPos, 2);
            CurByte := 0;
          end;
        mdStoreD:
          begin
            Move (CurBlock^[CurPos], CurData, SizeOf (CurData));
            Inc (CurPos, 4);
            CurByte := 0;
          end;
      end;
    end;
    case CurMethod of
      mdCopy:
        begin
          GetNextByte := CurBlock^[CurPos];
          Inc (CurPos);
        end;
      mdStore0:
        GetNextByte := 0;
      mdStoreSP:
        GetNextByte := Ord (' ');
      mdStoreB:
        GetNextByte := CurData;
      mdStoreW:
        begin
          if CurByte = 0 then
            GetNextByte := CurData and $FF
          else
            GetNextByte := CurData shr 8;
          CurByte := (CurByte + 1) mod 2;
          Inc (CurCount, CurByte);
        end;
      mdStoreD:
        begin
          GetNextByte := CurDataAr[CurByte];
          CurByte := (CurByte + 1) mod 4;
          Inc (CurCount, Byte (CurByte <> 0));
        end;
      mdSkip:
        begin
          if CurByte = 0 then
            GetNextByte := CurData
          else
          begin
            GetNextByte := CurBlock^[CurPos];
            Inc (CurPos);
          end;
          CurByte := (CurByte + 1) mod 2;
          Inc (CurCount, CurByte);
        end;
    end;
    Dec (CurCount);
    if CurCount = 0 then
      CurMethod := $FF;
  end;

{ ========================================================================= }



  var
    i, j: Word;

begin
  if ParamCount < 2 then
  begin
    WriteLn ('Pack 1.0  (C) Copyright 1995, by Mike Wiering, The Netherlands.');
    WriteLn;
    WriteLn ('   pack <inputfile> <outputfile>');
    Halt (1);
  end;
  InputName := ParamStr (1);
  Assign (fInput, InputName);
  Reset (fInput, 1);
  if IOResult <> 0 then
  begin
    WriteLn ('File not found: "', InputName, '".');
    Halt (1);
  end;
  if MemAvail < SizeOf (Buf1^) + SizeOf (Buf2^) then
  begin
    WriteLn ('Out of memory.');
    Halt (1);
  end;
  New (Buf1);
  New (Buf2);
  BlockRead (fInput, Buf1^, SizeOf (Buf1^), NumRead);
  InputSize := NumRead;
  Close (fInput);
  if InputSize = 0 then
  begin
    WriteLn ('Input file empty.');
    Halt (1);
  end;
  PackIt;

  WriteLn;
  WriteLn ('Old size: ', InputSize, '  New size: ', OutputSize,
    '  Gain: ', InputSize - OutputSize, ' (',
    (((InputSize - OutputSize) / InputSize) * 100):1:1, '%)');

  OutputName := ParamStr (2);
  Assign (fOutput, OutputName);
  ReWrite (fOutput, 1);
  BlockWrite (fOutput, Buf2^, OutputSize);
  Close (fOutput);


{
  UnPack (buf2);
  Assign (fOutput, OutputName);
  ReWrite (fOutput, 1);
  for i := 1 to InputSize do
  begin
    j := GetNextByte;
    BlockWrite (fOutput, j, 1);
  end;
  Close (fOutput);
}


  Dispose (Buf2);
  Dispose (Buf1);
end.

