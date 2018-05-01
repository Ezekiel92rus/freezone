unit Voting;
{$mode delphi}
interface
uses Packets, Clients, Games, xrstrings, misc_stuff;

function PatchVoteCommandsArrayPtrAtAddr(addr:pointer; offset:cardinal):boolean; stdcall;
function IsVoteEarlyFail(game:pgame_sv_mp; agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
function IsVoteEarlySuccess({%H-}game:pgame_sv_mp; agreed, {%H-}against_explicit, total_clients:cardinal):boolean; stdcall;
function IsVoteSuccess(agreed, against_explicit, total_clients:cardinal):boolean; stdcall;

procedure OnVoteStart(game:pgame_sv_mp; senderid:ClientID; VoteCommand:PChar; resVoteCommand:PChar); stdcall;

function CanSafeStartVoting({%H-}game:pgame_sv_mp; p:pNET_Packet; sender_id:ClientID):boolean; stdcall;
function CarefullyComparePlayerNames(name1:PChar; name2:PChar):cardinal; stdcall;

function IterateAndComparePlayersNames(it_begin:ppIClient; it_end:ppIClient; newname:PChar; client:pIClient):ppIClient; stdcall;
function OnVoteStartIncorrectPlayerName(game:pgame_sv_mp): boolean; stdcall;
function OnVote({%H-}game:pgame_sv_mp; sender_id:ClientID; {%H-}status:boolean):boolean; stdcall;


//TODO: ��������
//TODO: �������� ����� ���������� ����������� ��� ������� �� �������
implementation
uses srcBase, LogMgr, math, sysutils, console, CommonHelper, TranslationMgr, ConfigCache, PureServer, Players, dynamic_caster, basedefs, chat, Servers, MapList, HackProcessor;
var
  votecommands:array of _votecommands;


procedure AddVoteCommand(name:PAnsiChar; command:PAnsiChar; mask:cardinal); stdcall;
var
  i:integer;
begin
  i:=length(votecommands);
  SetLength(votecommands, i+1);
  votecommands[i].name:=name;
  votecommands[i].command:=command;
  votecommands[i].flag:=mask;
end;

function PatchVoteCommandsArrayPtrAtAddr(addr:pointer; offset:cardinal):boolean;stdcall;
var
  new_addr:cardinal;
begin
  if length(votecommands)=0 then begin
    AddVoteCommand('restart', 'g_restart', $2);
    AddVoteCommand('restart_fast', 'g_restart_fast', $4);
    AddVoteCommand('kick', 'sv_kick', $8);
    AddVoteCommand('ban', 'sv_banplayer', $10);
    AddVoteCommand('changemap', 'sv_changelevel', $20);
    AddVoteCommand('changeweather', 'sv_setenvtime', $40);
    AddVoteCommand('changegametype', 'sv_changegametype', $80);

    AddVoteCommand('fraglimit', 'sv_fraglimit', $100);
    AddVoteCommand('timelimit', 'sv_timelimit', $200);

    AddVoteCommand(nil, nil, $0); //terminator
  end;

  new_addr:=cardinal(@(votecommands[0]))+offset;
  result:=srcKit.CopyBuf(@new_addr, addr, sizeof(pointer))
end;

function CheckPlayerAllowedStartVoting(pl:pointer; pcardinal_id:pointer; pbool_flag:pointer):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  cld:=dynamic_cast(pl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cld<>nil then begin
    pboolean(pbool_flag)^:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).IsAllowedStartingVoting();
    if not pboolean(pbool_flag)^ then begin
      SendChatMessageByFreezone(GetPureServer(), pcardinal(pcardinal_id)^, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_start_voting'));
    end;
  end else begin
    pboolean(pbool_flag)^:=false;
  end;
end;

function CanSafeStartVoting(game:pgame_sv_mp; p:pNET_Packet; sender_id:ClientID):boolean; stdcall;
var
  pVoteStr:PAnsiChar;
  i:integer;
  args:array[0..5] of string;
  args_cnt:integer;
  tmpstr, logstr:string;
const
  BannedSymbols:string = '%';
  MAX_VOTE_STRING_SIZE: integer = 200;

begin
  result:=true;
  ForEachClientDo(CheckPlayerAllowedStartVoting, OneIDSearcher, @sender_id.id, @result);
  if not result then begin
    FZLogMgr.Get.Write('Player '+inttostr(sender_id.id)+' denied to start voting.', FZ_LOG_IMPORTANT_INFO);
    exit;
  end;

  result:=false;
  pVoteStr:=@p.B.data[p.r_pos];

  //������ �� ����� ���� ������� 1024 ��������. �� ������������ ����������� ������� ������ ;)
  //[bug] � ����������� game_sv_mp::OnVoteStart ���� ������� ����������� �� 256 ��������! ����� - ������������ ������ � �����
  //TODO:��������� ���� ��������, ����� ����������, ������������ ���� $ (� ���� ��???)
  i:=0;
  while (pVoteStr[i]<>chr(0)) and (i<MAX_VOTE_STRING_SIZE) do begin
    if pos(pVoteStr[i], BannedSymbols)<>0 then begin
      pVoteStr[i]:='_';
    end;
    i:=i+1;
  end;

  if i<MAX_VOTE_STRING_SIZE then begin
    //�������� ������ ����������
    i:=0;
    tmpstr:=trim(pVoteStr);
    logstr:='';
    while (i<length(args)-1) and FZCommonHelper.GetNextParam(tmpstr, args[i], ' ') do begin
       logstr:=logstr+', arg'+inttostr(i)+': '+args[i];
       tmpstr:=trim(tmpstr);
      i:=i+1;
    end;

    if i<length(args)-1 then begin
      //��������� �������� �� ����������� ��-�� ���������� ������� �� �����, ��������� ��������
      args[i]:=trim(tmpstr);
      logstr:=logstr+', arg'+inttostr(i)+': '+args[i];
      i:=i+1;
    end;
    args_cnt:=i;
    FZLogMgr.Get.Write('VoteStart'+logstr, FZ_LOG_DBG);

    //�������� �� ������������
    if (args[0]='kick') then begin
      //���� (��� �����) ��������� ��������, �� �������������
      result := (length(args[1]) > 0);
    end else if (args[0]='ban') then begin
      //���� (��� �����) ��������� �������� (�� �������������) � ���� �����
      result:=(length(args[1])>0) and (args_cnt > 2) and (strtointdef(args[args_cnt-1], -1)>=0);
    end else if (args[0]='fraglimit') or (args[0]='timelimit') then begin
      //���� �������� ��������
      result := strtointdef(args[1], -1) >= 0;
    end else if (args[0]='changeweather') then begin
      //��� ��������� ���������, ������ �������������!
      result:= ((args[1]='clear')  and (args[2]='9:00'))  or
               ((args[1]='cloudy') and (args[2]='13:00')) or
               (((args[1]='nigth') or (args[1]='night'))  and (args[2]='01:00')) or
               ((args[1]='rain')   and (args[2]='16:00'));
    end else if (args[0]='changemap') then begin
      //��� ��������� ���������, ������ �������������!
      //���������, ���� �� ����� ����� �� �������
      result:=(length(args[1])>0) and (length(args[2])>0) and IsMapPresent(args[1], args[2], game.base_game_sv_GameState.base_game_GameState.m_type);
    end else if (args[0]='changegametype') then begin
      //���� ��������� ��������, �� �������������
      result:= (args[1]='dm') or (args[1]='deathmatch') or (args[1]='tdm') or (args[1]='teamdeathmatch') or (args[1]='ah') or (args[1]='artefacthunt') or (args[1]='cta') or (args[1]='capturetheartefact');
    end else if (args[0]='restart') or (args[0]='restart_fast') then begin
      //��� ����������
      result:=true;
    end else if (length(args[0])>0) and (args[0][1]='$') then begin
      result:=true;
    end
  end;

  if result then begin
    FZLogMgr.Get.Write(GenerateMessageForClientId(sender_id.id, ' is starting voting "'+pVoteStr+'"'), FZ_LOG_IMPORTANT_INFO);
  end else begin
    BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(sender_id.id, ' is denied to start voting (parameters not parsed)'));
  end;
end;

function IsVoteEarlySuccess(game:pgame_sv_mp; agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
begin
  result:=false;
  if not FZConfigCache.Get.GetDataCopy.allow_early_success_in_vote then exit;
  result:= (agreed/total_clients)>=c_sv_vote_quota.value^;
  if result then FZLogMgr.Get.Write('Vote Early Success! Agreed '+inttostr(floor(100*agreed/total_clients))+'% of players', FZ_LOG_IMPORTANT_INFO);
end;

function IsVoteEarlyFail(game:pgame_sv_mp; agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
begin
  //��������� �����������, ����� ��� ������������� ������
  result:=false;
  if not FZConfigCache.Get.GetDataCopy.allow_early_fail_in_vote then exit;

  if (agreed=0) and (game.fz_vote_started_by_admin=0) then begin //��������� - �� ������, ���� ����������� ����� ������;
    result:=true;
    FZLogMgr.Get.Write('Voting Early Fail - no agreed participants!', FZ_LOG_IMPORTANT_INFO);
  end else if ((agreed+against_explicit)>=total_clients) and (agreed/total_clients<c_sv_vote_quota.value^) then begin
    result:=true;
    FZLogMgr.Get.Write('Voting Early Fail - all participants voted!', FZ_LOG_IMPORTANT_INFO);
  end else if (total_clients-against_explicit)/total_clients<c_sv_vote_quota.value^ then begin
    result:=true;
    FZLogMgr.Get.Write('Voting Early Fail - '+inttostr(floor(100*against_explicit/total_clients))+'% of players disagreed!', FZ_LOG_IMPORTANT_INFO);
  end;
end;

function IsVoteSuccess(agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
begin
  if (total_clients=0) or ((agreed=0) and (against_explicit=0)) then begin
    result:=false;
    FZLogMgr.Get.Write('Voting Failed - No participants', FZ_LOG_IMPORTANT_INFO);
    exit;
  end;

  if c_sv_vote_participants.value^<>0 then begin
    result:=(agreed/(against_explicit+agreed))>=c_sv_vote_quota.value^;
  end else begin
    result:=(agreed/total_clients)>=c_sv_vote_quota.value^;
  end;

  if result then begin
    FZLogMgr.Get.Write('Voting Successfull - '+inttostr(floor(100*agreed/total_clients))+'% agreed, '+inttostr(floor(100*against_explicit/total_clients))+'% disagreed, '+inttostr(floor(100*(total_clients-against_explicit-agreed)/total_clients))+'% not voted', FZ_LOG_IMPORTANT_INFO );
  end else begin
    FZLogMgr.Get.Write('Voting Failed - '+inttostr(floor(100*agreed/total_clients))+'% agreed, '+inttostr(floor(100*against_explicit/total_clients))+'% disagreed, '+inttostr(floor(100*(total_clients-against_explicit-agreed)/total_clients))+'% not voted', FZ_LOG_IMPORTANT_INFO );
  end;
end;

function CarefullyComparePlayerNames(name1:PAnsiChar; name2:PAnsiChar):cardinal; stdcall;
var
  tmp_name_1, tmp_name_2:string;
begin
  tmp_name_1:=trim(lowercase(name1));
  tmp_name_2:=trim(lowercase(name2));
  if (tmp_name_1=tmp_name_2) then
    result:=1
  else
    result:=0;
end;

function OnPlayerStartVote(pl:pointer; {%H-}id_ptr:pointer; pbyte_res_ptr:pointer):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  if (pIClient(pl).flags and ICLIENT_FLAG_LOCAL) >0 then
    PByte(pbyte_res_ptr)^:=1
  else begin
    PByte(pbyte_res_ptr)^:=0;
    cld:=dynamic_cast(pl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
    if cld<>nil then begin
      FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).OnVoteStarted();
    end;
  end;
end;


procedure OnVoteStart(game:pgame_sv_mp; senderid:ClientID; VoteCommand:PAnsiChar; resVoteCommand:PAnsiChar); stdcall;
var
  total_command, console_command, arg1, arg2, descr, name, par:string;
  time:cardinal;
begin
  if game.m_bVotingReal then begin
    if game.m_pVoteCommand.p_ = nil then begin
      //�������� �� ������ ��
      assign_string(@game.m_voting_string, 'Ooops! Something gone wrong...');
      assign_string(@game.m_pVoteCommand, 'deadbeef');
      FZLogMgr.Get.Write('Running voting with unitialized m_pVoteCommand!', FZ_LOG_ERROR);
      exit;
    end;
    
    total_command:=get_string_value(@game.m_pVoteCommand);
    if not FZCommonHelper.GetNextParam(total_command, console_command, ' ') then begin
      console_command:=total_command;
      total_command:='';
    end;
    total_command:=trim(total_command);

    if console_command='sv_banplayer' then begin
      //�� ��� �� ����������� �������� � onlysace
      //������ �����������: cl_votestart ban PlayerName onlysace
      FZCommonHelper.GetNextParam(total_command, arg1, ' '); //������ ������
      arg2:=trim(total_command);                             //����� ����
      //������������ ����� ���� �� ���������� :)
      time:=strtointdef(arg2, 0);
      time:=BanTimeFromMinToSec(time);

      //��������� ������ ����������� - ��� ����� ��� � �������� �������� �� ����� ������� ����
      name:=VoteCommand;
      name:=trim(name);
      FZCommonHelper.GetLastParam(name, par, ' ');
      name:=trim(name);
      FZCommonHelper.GetNextParam(name, descr, ' ');
      name:=trim(name);

      //����������� ���� � ���������� �� �� ������ ������� � ���������
      descr:='ban '+name+' '+arg2+' '+FZTranslationMgr.Get.TranslateSingle('minutes');
      console_command:='sv_banplayer '+ arg1 +' ' + inttostr(time);

      assign_string(@game.m_pVoteCommand, PAnsiChar(console_command));
      assign_string(@game.m_voting_string, PAnsiChar(descr));
    end else begin
      descr:= FZTranslationMgr.Get.Translate_NoSpaces(resVoteCommand);
      assign_string(@game.m_voting_string, PAnsiChar(descr));
    end;

  end else begin
    //��� ������ ������ ��� �����-���� �������, ������������ � $
    VoteCommand:=PAnsiChar(cardinal(VoteCommand)+1);
    assign_string(@game.m_voting_string, VoteCommand);
  end;

  game.fz_vote_started_by_admin:=0;
  ForEachClientDo(OnPlayerStartVote, OneIDSearcher, @senderid.id, @game.fz_vote_started_by_admin);

  FZLogMgr.Get.Write('Voting "'+get_string_value(@game.m_voting_string)+'" is started', FZ_LOG_INFO);
end;


function IterateAndComparePlayersNames(it_begin:ppIClient; it_end:ppIClient; newname:PAnsiChar; client:pIClient):ppIClient; stdcall;
var
  newname_s:string;
  player_name:string;
begin
  //�������� �� ��, ��� �� ��� �� ������� ������ � ����� newname
  newname_s:=trim(lowercase(newname));
  while it_begin<>it_end do begin
    if (client<>it_begin^) then begin
      player_name:= get_string_value(@it_begin^.name);
      player_name:=trim(lowercase(player_name));
      if player_name=newname_s then break;
    end;
    it_begin:=pointer(cardinal(it_begin)+sizeof(it_begin));
  end;

  result:= it_begin;
end;

function OnVoteStartIncorrectPlayerName(game:pgame_sv_mp): boolean; stdcall;
begin
  //��� ����� ������������ ��� ��� ����/����
  //���� ���������, ��� ��������� �������� � ������ ����������� - ������� true
  //�� � ��� ������ false...
  FZLogMgr.Get.Write('Voting not started - player id not found by name!', FZ_LOG_ERROR);
  game.m_bVotingActive:=false;
  result:=false;
end;

function OnPlayerVotes(pl:pointer; id:pointer; canvote:pointer):boolean; stdcall;
var
  pld:pxrClientData;
begin
  result:=false;
  pld:=dynamic_cast(pl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  pboolean(canvote)^:=false;

  if pld<>nil then begin
    FZPlayerStateAdditionalInfo(pld.ps.FZBuffer).OnVote();  
    pboolean(canvote)^:= not FZPlayerStateAdditionalInfo(pld.ps.FZBuffer).IsPlayerVoteMuted();
    if not pboolean(canvote)^ then begin
      SendChatMessageByFreezone(GetPureServer(), pcardinal(id)^, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_vote'));
    end;
  end;
end;

function OnVote(game:pgame_sv_mp; sender_id:ClientID; status:boolean):boolean; stdcall;
begin
  result:=false;
  ForEachClientDo(OnPlayerVotes, OneIDSearcher, @sender_id.id, @result);
end;

end.
