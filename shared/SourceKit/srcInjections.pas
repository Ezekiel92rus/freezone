unit srcInjections;
{$mode delphi}
interface

type srcBaseInjection = class
protected
  _patch_addr:pointer;                  //����� ����� � �����, �� �������� ���� �������� �� ������
  _ret_addr:pointer;                    //�����, ���� ���������� ��������� ����� ���������� ������
  _length:cardinal;                     //����� ����, �������� �����������
  _payload_addr:pointer;                //����� �������, ������� ���� �����������

  _code:array of byte;                  //����� � �������� ������
  _code_addr:pointer;

  _src_cut:array of byte;               //����� � ����������� ������������
  _src_cut_addr:pointer;

  _need_overwrite:boolean;              //��������� �������� ������� ���������� ��� ������ ��� ���
  _exec_srccode_in_end:boolean;         //��������� ������������ ��� �� ���� ������ ��� �����

  _is_active:boolean;
  _is_ok:boolean;

//  _remapable:boolean;


  function _SrcInit():boolean;
  function _AssembleInit(args:array of cardinal):boolean; virtual;

  //��������� ��� ��������
  function _WritePayloadCall(pos: pointer; args:array of cardinal): pointer; virtual;
  function _WriteReturnJmp(addr:pointer):pointer;
  function _WriteSrcJmp(addr:pointer):pointer;
  function _WriteCodeJmp(addr:pointer):pointer;

  //������� ������ ������ ���� ������ payload
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; virtual;

  //������� ���� ������ � ����� ����������� ����� ������� ������� payload'a ����������
  function _GetSavedInStackBytesCount():cardinal; virtual;

  //��������� ����� ������
  function _WriteRegisterArgs(pos:pointer; args:array of cardinal): pointer; virtual;
  function _WriteInjectionFinal(pos:pointer):pointer; virtual;

public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false);
  destructor Destroy(); override;
  function IsActive():boolean;
  function Enable():boolean;
  procedure Disable();
  function GetSignature():string;
end;

type srcCleanupInjection = class (srcBaseInjection)
  protected
  function _AssembleInit({%H-}args:array of cardinal):boolean; override;
  public
  constructor Create(addr:pointer; payload:pointer; count:cardinal);
  destructor Destroy; override;

end;

type srcInjectionWithConditionalJump = class (srcBaseInjection)
protected
  _jump_addr:pointer;
  _jump_type:word;
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; override;
  function _WritePayloadCall(pos:pointer; args:array of cardinal):pointer; override;
  function _GetSavedInStackBytesCount():cardinal; override;  
public
  constructor Create(addr:pointer; payload:pointer {function (...):boolean; stdcall;} ; count:cardinal; args:array of cardinal; jump_addr:pointer; jump_type:word; exec_src_in_end:boolean=true; overwritten:boolean=false);
end;

type srcEAXReturnerInjection = class (srcBaseInjection)
  //����������: ������� ������� �������
  protected
  _popcnt_from_stack:cardinal; //������� ���� ����� �� ����� ����� ���������� ��������
  function _WritePayloadCall(pos:pointer; args:array of cardinal):pointer; override;
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; override;
  function _GetSavedInStackBytesCount():cardinal; override;   
  public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;


type srcECXReturnerInjection = class (srcBaseInjection)
  protected
  _popcnt_from_stack:cardinal; //������� ���� ����� �� ����� ����� ���������� ��������
  function _WritePayloadCall(pos:pointer; args:array of cardinal):pointer; override;
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; override;
  function _GetSavedInStackBytesCount():cardinal; override;   
  public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

const
  JUMP_IF_TRUE  :     byte = $84;
  JUMP_IF_FALSE :     byte = $85;

implementation
uses Windows, sysutils, srcBase;

{ srcBaseInjection }

procedure srcBaseInjection.Disable;
begin
  if (not self._is_ok) or (not self._is_active) then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': already was disabled');
    exit;
  end;
  SrcKit.CopyASM(self._src_cut_addr, self._patch_addr, self._length);
  self._is_active:=false;
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': disabled.');
end;

function srcBaseInjection.Enable:boolean;
begin

  result:=false;
  if (not self._is_ok) then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': isok = false, cannot enable', true);
    exit;
  end;

  if self._is_active then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': already active, cannot enable!');
    exit;
  end;

  if (self._length<5) then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': not enough bytes to write jump, cannot enable!', true);
    self._is_ok:=false;
    exit;
  end;

  srcKit.nop_code(self._patch_addr, self._length);
  //���� ������� ��������� ��������� ��� ������ - �� ����� ����� �� ���, ����� - �� ����� � ���� �����
  if (self._need_overwrite) or self._exec_srccode_in_end then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': patching to _code done');
    if srcKit.WriteCall(self._patch_addr, self._code_addr, false)=nil then exit;
  end else begin
    if srcKit.WriteCall(self._patch_addr, self._src_cut_addr, false)=nil then exit;
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': pacthing to _src_cut done');
  end;
  self._is_active:=true;
  result:=true;
end;

constructor srcBaseInjection.Create(addr, payload: pointer;
  count: cardinal; args:array of cardinal; exec_src_in_end, overwritten: boolean);
begin
  //TODO:������� ��������������� ������������ ����� ����, ��������� ��� ���������� ������ �� ���������� ������ (������ �� ������������� ����������)
  self._patch_addr:=addr;
  self._length:=count;
  self._ret_addr:=pointer(cardinal(addr)+count);
  self._payload_addr:=payload;
  self._need_overwrite:=overwritten;
  self._exec_srccode_in_end:=exec_src_in_end;

  if srcKit.Get.IsDebug then begin
    srcKit.Get.DbgLog('new injection '+GetSignature+' (payload: '+inttohex(cardinal(payload), 8) +')');
    srcKit.Get.DbgLog('injection '+GetSignature+
                      ': length='+inttostr(self._length)+
                      ', overwrite='+booltostr(self._need_overwrite, true)+
                      ', in end='+booltostr(self._exec_srccode_in_end, true));
  end;


  _is_ok:= self._SrcInit() and self._AssembleInit(args);

  self._is_active:=false;

  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': initialization finished, isok = '+booltostr(self._is_ok, true));
  srcKit.Get.RegisterInjection(self);
end;

function srcBaseInjection.IsActive: boolean;
begin
  result:=self._is_active;
end;

function srcBaseInjection._SrcInit: boolean;
begin
  //������� ����� � ���������� ������������ �����
  result:=false;

  setlength(self._src_cut, self._length+6);                   //�� �������� ��� �������

  _src_cut_addr:=@(self._src_cut[0]);
  srcKit.Get().MakeExecutable(_src_cut_addr, length(self._src_cut));

  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': srcbuf = '+inttohex(cardinal(_src_cut_addr), 8));
  if not srcKit.CopyASM(self._patch_addr, @self._src_cut[0], self._length) then exit; //�������� ������������ ���
  
  if self._exec_srccode_in_end then begin
    if self._WriteReturnJmp(@(self._src_cut[self._length])) = nil then exit;
  end else begin
    if self._WriteCodeJmp(@(self._src_cut[self._length])) = nil then exit;
  end;
  result:=true;
end;

function srcBaseInjection._AssembleInit(args:array of cardinal):boolean;
var
  sz:cardinal;
  pos:pointer;
begin
  result:=false;
  //TODO: ������� ����������� ����, ��� ������, ����� �������� ������� (��������� ���� ���-> ������������������ ����������, ���� �������� � �������� ����������)
  //������ ������ - �������� ����� � ����� ������

  //��������� ��������� ������ ������
  sz:=_GetPayloadCallerProjectedSize(args);   


  setlength(self._code, sz);
  srcKit.MakeExecutable(@self._code[0], sz);
  _code_addr:=@(self._code[0]);
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': codebuf='+inttohex(cardinal(_code_addr),8));

  pos:=_code_addr;
  //�������� ��� ������

  //TODO:��������� � ���, ��� ����� ���������� payload � ������ ���������

  pos:=self._WritePayloadCall(pos, args);
  if pos = nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': payload not written!', true);
    exit;
  end;


  pos:=self._WriteInjectionFinal(pos);
  if pos = nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': final not written!', true);
    exit;
  end;
  result:=true;
end;

destructor srcBaseInjection.Destroy;
begin
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': Destroying.');
  self.Disable;
  setlength(self._src_cut, 0);
  setlength(self._code, 0);
  inherited;
end;

function srcBaseInjection._WriteCodeJmp(addr: pointer): pointer;
begin
  result:=srcKit.WriteMemCall(addr, @self._code_addr, false);
end;

function srcBaseInjection._WritePayloadCall(pos: pointer; args:array of cardinal): pointer;
begin
  result:=srcKit.WriteSaveRegisters(pos);

  if result<>nil then result:=self._WriteRegisterArgs(result, args);
  if result<>nil then result:=srcKit.WriteMemCall(result, @self._payload_addr, true);

  if result<>nil then result:=srcKit.WriteLoadRegisters(result);
end;

function srcBaseInjection._WriteReturnJmp(addr: pointer): pointer;
begin
  result:=srcKit.WriteMemCall(addr, @self._ret_addr, false);
end;

function srcBaseInjection._WriteSrcJmp(addr: pointer): pointer;
begin
  result:=srcKit.WriteMemCall(addr, @self._src_cut_addr, false);
end;

function srcBaseInjection._WriteRegisterArgs(pos: pointer; args:array of cardinal): pointer;
var
  i:integer;
  tmp:cardinal;
  tmpw:smallint;
  tmpi:integer;
  esp_add:cardinal;
begin
  esp_add:=0; //���� � ���� ����� ���������� ��������� �� ����� - ����� ������� �������� ��������������� �������� �������� 
  for i:=high(args) downto low(args) do begin
    srcKit.Get.DbgLog(inttohex(args[i],8));
    //�������, �� ��������� �� ���� �������� � �������
    if (args[i] and $0F000000)=0 then begin
      //� ������� � ���������� �� ��������
      tmp:=(args[i]+$32767) shr 29;
      PByte(pos)^:=PUSH_EAX+tmp;
      pos:=PAnsiChar(pos)+1;

      //���������/��������� �������� ��������� �� �������� (+/-32767 max)
      tmpw:=(args[i] and $FFFF);
      tmpi:=tmpw;
      srcKit.Get.DbgLog('tmpw='+inttostr(tmpw));
      if (tmp{%H-}{%H-}=PUSH_ESP-PUSH_EAX) then tmpi:=tmpi{%H-}+_GetSavedInStackBytesCount()+esp_add;
      srcKit.Get.DbgLog('tmpi='+inttostr(tmpi));
      if tmpi<>0 then begin
        //add [esp], XXXXX
        PCardinal(pos)^:=$240481; //������� 3 �����, � �� 4!!! �� ������� �����
        pos:=PAnsiChar(pos)+3;
        PCardinal(pos)^:=tmpi;
        pos:=PAnsiChar(pos)+4;
      end;
      esp_add:=esp_add+4;

    end else if (args[i] and F_RMEM)<>0 then begin
      //push [reg+offset]
      tmp:=args[i] shr 29;
      if (args[i] and $F0000000)<>(F_PUSH_ESP-F_MEMOFFSET) then begin
        srcKit.Get.DbgLog('not esp');
        PWord(pos)^:=$B0FF+(tmp shl 8);
        pos:=PAnsiChar(pos)+2;
        PCardinal(pos)^:= (args[i] and $00FFFFFF)-$800000;
        pos:=PAnsiChar(pos)+4;
        esp_add:=esp_add+4;

      end else begin
        srcKit.Get.DbgLog('esp');
        PCardinal(pos)^:=$0024B4FF;
        pos:=PAnsiChar(pos)+3;
        PCardinal(pos)^:= (args[i] and $00FFFFFF)-$800000+_GetSavedInStackBytesCount()+esp_add; //�� �������� ��� pushad
        pos:=PAnsiChar(pos)+4;
        esp_add:=esp_add+4;
      end;

    end else if (args[i] and (F_PUSHCONST-F_MEMOFFSET))<>0 then begin
      //push const
      pos:=srcKit.WritePushDword(pos, args[i]-F_PUSHCONST);
      esp_add:=esp_add+4;
    end;

  end;
  result:=pos;
end;

function srcBaseInjection._WriteInjectionFinal(pos: pointer): pointer;
begin
  if (not self._need_overwrite) and self._exec_srccode_in_end then begin
    pos:=self._WriteSrcJmp(pos);
  end else begin
    pos:=self._WriteReturnJmp(pos);
  end;
  result:=pos;
end;

function srcBaseInjection.GetSignature: string;
begin
  result:= self.ClassName+':@'+inttohex(cardinal(self._patch_addr),8);
end;

function srcBaseInjection._GetPayloadCallerProjectedSize(args:array of cardinal): integer;
begin
  result:=1+1+6+1+1+6+8*(high(args)-low(args)+1); //pushad+pushfd+call+popfd+popad+jmp+max_arguments_count
end;

function srcBaseInjection._GetSavedInStackBytesCount: cardinal;
begin
  result:=$24;
end;

{ srcCleanupInjection }
var
  _CleanupCode: array [0..19] of byte;
  _cleanup_instance:srcCleanupInjection = nil;

function srcCleanupInjection._AssembleInit(args:array of cardinal): boolean;
var
  pos:pointer;
const
  sz:cardinal=20;
begin
  result:=false;

  setlength(self._code, sz);
  srcKit.MakeExecutable(@self._code[0], sz);
  _code_addr:=@(_CleanupCode[0]);
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': codebuf='+inttohex(cardinal(_code_addr),8));

  pos:=srcKit.WriteSaveRegisters(self._code_addr);

  pos:=srcKit.WriteCall(pos, self._payload_addr, true);
  if pos=nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': payload not written!', true);
    exit;
  end;

  pos:=srcKit.WriteLoadRegisters(pos);
  pos:=srcKit.WriteCall(pos, self._ret_addr, false);
  if pos=nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': return not written!', true);
    exit;
  end;
  if srcKit.Get.IsDebug() then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': used '+inttostr(cardinal(pos)-cardinal(self._code_addr))+' bytes of code');
  if (cardinal(pos)-cardinal(self._code_addr))>20 then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': code buffer overflow!', true);
    exit;
  end;
  result:=true;
end;

constructor srcCleanupInjection.Create(addr, payload: pointer;
  count: cardinal);
begin
  //����������� ������� �������� ����������� � ���, ��� ����� ����������� �������� ����� � ����� ������ �����������, �� �� ���� ����� ��������� ����� ��������
  //�� ������ �� ������ ��������� � ��������� ������
  //������� �������� - ������ ����������� ������ � ���������� ����������� ������, ��� � ����������� � ������ ������

  //������ ������ ������ ����������� � ������������ ����������!
  if _cleanup_instance<>nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': failed to create second cleanup!', true);
    exit;
  end;

  //����� - �������� ��� ������ ������ ����������� ����� ����� ������, ��� ��� ��� ��������� � ����������� ���������� ������; ����� ���������� ���� ������ � ����������� ������� ���������� � ���� ������ ������
  inherited Create(addr, payload, count, [], false, false);

  _cleanup_instance := self;
end;

destructor srcCleanupInjection.Destroy;
begin
  _cleanup_instance:=nil;
  inherited;
end;

{ srcInjectionWithConditionalJumpInTheEnd }

constructor srcInjectionWithConditionalJump.Create(addr,
  payload: pointer; count: cardinal; args: array of cardinal;
  jump_addr: pointer; jump_type:word; exec_src_in_end:boolean; overwritten: boolean);
begin
  self._jump_addr:=jump_addr;
  self._jump_type:=jump_type;
  inherited Create(addr,payload,count,args,exec_src_in_end,overwritten);
end;

function srcInjectionWithConditionalJump._GetPayloadCallerProjectedSize(
  args: array of cardinal): integer;
begin
  result:=1+6+1+2+6+6+6+8*(high(args)-low(args)+1); //pushad+call+popad+test+jne+jmp_cond+jmp+max_arguments_count
end;

function srcInjectionWithConditionalJump._GetSavedInStackBytesCount: cardinal;
begin
  result:=$20;
end;

function srcInjectionWithConditionalJump._WritePayloadCall(
  pos: pointer; args: array of cardinal): pointer;
begin
  result:=srcKit.WriteSaveOnlyGeneralRegisters(pos);

  if result<>nil then result:=self._WriteRegisterArgs(result, args);
  if result<>nil then result:=srcKit.WriteMemCall(result, @self._payload_addr, true);
  if result<>nil then result:=srcKit.WriteTestReg(result, TEST_AL_AL);
  if result<>nil then result:=srcKit.WriteLoadOnlyGeneralRegisters(result);
  if result<>nil then result:=srcKit.WriteMemConditionalJump(result,@self._jump_addr, _jump_type);
end;

{ srcEAXReturnerInjection }

constructor srcEAXReturnerInjection.Create(addr, payload: pointer;
  count: cardinal; args: array of cardinal; exec_src_in_end,
  overwritten: boolean; popcnt: cardinal);
begin
  self._popcnt_from_stack:=popcnt;
  inherited Create(addr, payload, count, args, exec_src_in_end, overwritten);
end;

function srcEAXReturnerInjection._GetPayloadCallerProjectedSize(
  args: array of cardinal): integer;
begin
  result:=6+6+6+6+6+8*(high(args)-low(args)+1); //push_regs+call+pop_regs+jmp+add_esp+max_arguments_count
end;

function srcEAXReturnerInjection._GetSavedInStackBytesCount: cardinal;
begin
  result:=$18;
end;

function srcEAXReturnerInjection._WritePayloadCall(pos: pointer;
  args: array of cardinal): pointer;
begin

  //��������� ��� ��������, ����� EAX
  (PByte(pos))^:=PUSH_ECX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EDX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EBX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EBP;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_ESI;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EDI;
  pos:=pointer(cardinal(pos)+1);

  pos:=self._WriteRegisterArgs(pos, args);
  if pos<>nil then pos:=srcKit.WriteMemCall(pos, @self._payload_addr, true);

  //��������������� ����������� ��������
  (PByte(pos))^:=POP_EDI;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_ESI;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_EBP;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_EBX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_EDX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_ECX;
  pos:=pointer(cardinal(pos)+1);

  //������� ������ �� �����
  pos:=srcKit.WriteAddESPDword(pos, _popcnt_from_stack);

  result:=pos;

end;

{ srcECXReturnerInjection }

function srcECXReturnerInjection._GetPayloadCallerProjectedSize(
  args: array of cardinal): integer;
begin
  result:=6+6+6+6+6+8*(high(args)-low(args)+1)+2; //push_regs+call+pop_regs+jmp+add_esp+max_arguments_count +swap
end;

function srcECXReturnerInjection._GetSavedInStackBytesCount: cardinal;
begin
  result:=$18;
end;

function srcECXReturnerInjection._WritePayloadCall(pos: pointer;
  args: array of cardinal): pointer;
begin
  //��������� ��� ��������, ����� ECX
  (PByte(pos))^:=PUSH_EAX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EDX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EBX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EBP;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_ESI;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=PUSH_EDI;
  pos:=pointer(cardinal(pos)+1);

  pos:=self._WriteRegisterArgs(pos, args);
  if pos<>nil then pos:=srcKit.WriteMemCall(pos, @self._payload_addr, true);
  (PByte(pos))^:=PUSH_EAX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_ECX;
  pos:=pointer(cardinal(pos)+1);

  //��������������� ����������� ��������
  (PByte(pos))^:=POP_EDI;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_ESI;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_EBP;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_EBX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_EDX;
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=POP_EAX;
  pos:=pointer(cardinal(pos)+1);

  //������� ������ �� �����
  pos:=srcKit.WriteAddESPDword(pos, _popcnt_from_stack);

  result:=pos;
end;

constructor srcECXReturnerInjection.Create(addr, payload: pointer;
  count: cardinal; args: array of cardinal; exec_src_in_end,
  overwritten: boolean; popcnt: cardinal);
begin
  self._popcnt_from_stack:=popcnt;
  inherited Create(addr, payload, count, args, exec_src_in_end, overwritten);
end;

end.
