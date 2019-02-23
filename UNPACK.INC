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
