unit GamePersistent;

{$mode delphi}
{$I _pathes.inc}

interface
uses BaseClasses, MainMenu;

type
  IGamePersistent_params = packed record
    m_game_or_spawn:array [0..255] of char;
    m_game_type:array [0..255] of char;
    m_alife:array [0..255] of char;
    m_new_or_load:array [0..255] of char;
    m_e_game_type:cardinal;
  end;

  IGamePersistent = packed record
    base_DLL_Pure:DLL_Pure;
    base_pureAppStart:pureAppStart;
    base_pureAppEnd:pureAppEnd;
    base_pureAppActivate:pureAppActivate;
    base_pureAppDeactivate:pureAppDeactivate;
    base_pureFrame:pureFrame;
    params:IGamePersistent_params;
    unknown:array[0..$43] of byte;
    m_pMainMenu:pIMainMenu;
  end;
  pIGamePersistent=^IGamePersistent;
  ppIGamePersistent=^pIGamePersistent;

var
  g_ppGamePersistent:ppIGamePersistent;

function Init():boolean; stdcall;

implementation
uses basedefs;

function Init():boolean; stdcall;
begin
  result:=false;
  if not InitSymbol(g_ppGamePersistent, xrEngine, '?g_pGamePersistent@@3PAVIGame_Persistent@@A') then exit;
  result:=true;
end;

end.

