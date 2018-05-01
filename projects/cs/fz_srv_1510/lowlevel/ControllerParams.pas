unit ControllerParams;
{$mode delphi}
interface
uses Clients;

type
FZControllerParams = record
  ccs_present:boolean;
  sign:cardinal;
  base:cardinal;
  ver:string;
  SACE_status:boolean; //������������ �� sv_onlysace
  SACE_check_native_func:function (id:ClientID):boolean; stdcall; //����� "������" ������� �������� ������ �� SACE
end;

FZUACPlayerInfo = packed record
  dwSize:cardinal;
  dwCheatFlags:cardinal;
  bOutdated:cardinal;
  bFullscreen:cardinal;
  Reserved:array[0..23] of cardinal;
end;
pFZUACPlayerInfo=^FZUACPlayerInfo;

FZGetUACPlayerInfo_fun = function (szHash_MD5:PChar; lpPlayerInfo:pFZUACPlayerInfo):boolean;stdcall;

FZControllerMgr = class
    _params:FZControllerParams;
    function _GetSignature(var signature:cardinal; var base_addr:cardinal):boolean;
  public
    constructor Create();
    function GetParams:FZControllerParams;
    class function Get():FZControllerMgr;
    class function IsSACE3APIPresent():boolean; stdcall;
end;

implementation
uses LogMgr, SysUtils, Windows, basedefs, srcBase;
var
  instance:FZControllerMgr = nil;
  sace3_checker:FZGetUACPlayerInfo_fun= nil;

{ FZControllerMgr }

function CheckSACE_ccs513002(id:ClientID):boolean; stdcall;
var
  addr:cardinal;
  tbl:cardinal;
begin
  addr:=FZControllerMgr.Get.GetParams.base-$50000+$2b79;
  tbl:= FZControllerMgr.Get.GetParams.base-$50000+$398F;
  //FZLogMgr.Get.Write(inttohex(addr,8));
  asm
    pushad
      mov eax, addr
      mov ebx, tbl
      push id
      push [ebx]
      call eax

      mov eax, [eax+$70]
      test eax, eax
      je @nosace
      mov @result, 1
      jmp @finish
      @nosace:
      mov @result, 0
      @finish:
    popad
  end;
end;


function CheckSACE_ccs513003(id:ClientID):boolean; stdcall;
var
  addr:cardinal;
  tbl:cardinal;
begin
  addr:=FZControllerMgr.Get.GetParams.base-$50000+$2b31;
  tbl:= FZControllerMgr.Get.GetParams.base-$50000+$3947;
  //FZLogMgr.Get.Write(inttohex(addr,8));
  asm
    pushad
      mov eax, addr
      mov ebx, tbl
      push id
      push [ebx]
      call eax

      mov eax, [eax+$70]
      test eax, eax
      je @nosace
      mov @result, 1
      jmp @finish
      @nosace:
      mov @result, 0
      @finish:
    popad
  end;
end;


function CheckSACE_ccs514(id:ClientID):boolean; stdcall;
var
  addr:cardinal;
  tbl:cardinal;
begin
  addr:=FZControllerMgr.Get.GetParams.base-$50000+$2961;
  tbl:= FZControllerMgr.Get.GetParams.base-$50000+$3889;
  //FZLogMgr.Get.Write(inttohex(addr,8));
  asm
    pushad
      mov eax, addr
      mov ebx, tbl
      push id
      push [ebx]
      call eax

      mov eax, [eax+$70]
      test eax, eax
      je @nosace
      mov @result, 1
      jmp @finish
      @nosace:
      mov @result, 0
      @finish:
    popad
  end;
end;

class function FZControllerMgr.IsSACE3APIPresent():boolean; stdcall;
begin
  result:=(GetProcAddress(xrAPI, 'GetUACPlayerInfo')<>nil);
end;


constructor FZControllerMgr.Create;
begin
  if _GetSignature(_params.sign, _params.base) = false then begin
    //������ �������
    _params.ccs_present:=false;
    _params.ver:='UNUSED';
    _params.SACE_status:=false;
    _params.SACE_check_native_func:=nil;
    FZLogMgr.Get.Write('Controlled detection error!', true);
  end else if (_params.base=0) and (_params.sign=0) then begin
    //���������� ���
    _params.ccs_present:=false;
    _params.ver:='UNUSED';
    _params.SACE_status:=false;
    _params.SACE_check_native_func:=nil;
  end else begin
    _params.ccs_present:=true;
    _params.SACE_status:=false;
    _params.SACE_check_native_func:=nil;

    case _params.sign of
      //��� ����������� �������� ������� � ������ ����� ���� ��������� ������� ���������� �� M_CLIENTREADY � M_CL_AUTH ������ M_SECURE_MESSAGE
      //TODO:��������� ��� ������ �����������
      //TODO: ��������, ����� ������� ���� ���������� ������������, � ����������� �� �������� ������?

      //TODO: ��������� ����������� SACE3 �� ����� ��� 
      $6F78: begin _params.ver:='CCS 5.14 JET'; _params.SACE_status:=true; _params.SACE_check_native_func:=@CheckSACE_ccs514; end;
      $7469: begin _params.ver:='CCS 5.13.003 JET'; _params.SACE_status:=true; _params.SACE_check_native_func:=@CheckSACE_ccs513003; end;
      $7509: begin _params.ver:='CCS 5.13.002 JET'; _params.SACE_status:=true; _params.SACE_check_native_func:=@CheckSACE_ccs513002; end;
      $78C9: begin _params.ver:='CCS 5.13.001 JET (26.03.11)'; _params.SACE_status:=true; end;
      $7839: begin _params.ver:='CCS 5.13.001 JET (14.03.11)'; fillchar(pointer(_params.base+$8bf9)^, 12, $90); _params.SACE_status:=true; end;
      $592D: begin _params.ver:='CCS 5.12.34.00 JET' end;
      $5AB1: begin _params.ver:='CCS 5.12.34.01 JET' end;
      $5C06: begin _params.ver:='CCS 5.12.33 AIR'; _params.SACE_status:=true; end;
      $7586: begin _params.ver:='CCS 5.12.31 JET' end;
      else begin
        FZLogMgr.Get.Write('Controller: UNKNOWN VERSION! SIGN = 0x'+inttohex(_params.sign, 4), true);
        _params.ver:='UNKNOWN';
      end;
    end;
  end;
end;

class function FZControllerMgr.Get: FZControllerMgr;
begin
  if instance=nil then begin
    instance:=FZControllerMgr.Create();
  end;
  result:=instance;
end;

function FZControllerMgr.GetParams: FZControllerParams;
begin
  result:=_params;
end;

function FZControllerMgr._GetSignature(var signature:cardinal; var base_addr:cardinal):boolean;
var
  ccs_ptr, temp:cardinal;
  tb:byte;
  res:cardinal;
begin

  try
    //������ ���, � ������� ��������� ����������
    ReadProcessMemory(GetCurrentProcess(), PChar(xrengine+$3ee3d), @temp, 4, res);
    if res<>4 then begin
      result:=false;
      exit;
    end;

    //������ ��������, ������ � ��� ���� ��� � ���������
    if temp = $490c883d then begin //���������� ��� ������ ����
      //�������� � ����, ������ ���� � �����������, � �������� �� ����������� jmp
      ReadProcessMemory(GetCurrentProcess(), PChar(xrEngine+$3ee3c), @tb, 1, res);
      if res<>1 then begin
        result:=false;
        exit;
      end else if tb = $83 then begin
        result:=true;
        signature := 0;
        base_addr := 0;
        exit;
      end
    end;

    //������ ������� �� ������, ��������� ���������, ������� ����� ���������� � �������� ���� ��������� (���������)
    temp:=temp+xrengine+$3ee42;
    ReadProcessMemory(GetCurrentProcess(), PChar(temp), @ccs_ptr, 4, res);
    if res<>4 then begin
      result:=false;
      exit;
    end;
    ccs_ptr:=ccs_ptr+temp+4;

    //�������� ����� ������ ���� ���������� ��� ������; ������� ����� - ����� ������, ������� - ��������� ����������
    signature := (ccs_ptr shl 16) shr 16;
    base_addr := (ccs_ptr shr 16) shl 16;
    result :=true;
  except
    result :=false;
    signature := 0;
    base_addr := 0;
  end;

end;

end.
