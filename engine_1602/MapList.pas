unit MapList;

{$mode delphi}
{$I _pathes.inc}

interface
uses xrstrings, Vector;

type
SGameWeathers = record
  m_weather_name:shared_str;
  m_start_time:shared_str;
end;
pSGameWeathers = ^SGameWeathers;

SGameTypeMaps_SMapItm = record
	map_name:shared_str;
  map_ver:shared_str;
end;
pSGameTypeMaps_SMapItm=^SGameTypeMaps_SMapItm;

SGameTypeMaps = record
  m_game_type_name:shared_str;
  m_game_type_id:cardinal; {EGameIDs}
  m_map_names:xr_vector;{SGameTypeMaps_SMapItm}
end;
pSGameTypeMaps = ^SGameTypeMaps;

CMapListHelper = record
  m_storage:xr_vector; {SGameTypeMaps}
  m_weathers:xr_vector; {SGameWeathers}
end;
pCMapListHelper=^CMapListHelper;


function Init():boolean; stdcall;
function GetMapList():pCMapListHelper; stdcall;
procedure LoadMapList(); stdcall;
function IsMapPresent(mapname:string; mapver:string; gametype_id:cardinal):boolean; stdcall;
function IsWeatherPresent(weathername:string; weathertime:string):boolean; stdcall;

implementation
uses basedefs, srcCalls, strutils, sysutils;
var
  g_pMapListHelper:pCMapListHelper;
  CMapListHelper__Load:srcBaseFunction;

function GetMapList():pCMapListHelper; stdcall;
begin
  result:=g_pMapListHelper;
end;

procedure LoadMapList(); stdcall;
begin
  CMapListHelper__Load.Call([g_pMapListHelper]);
end;

function IsWeatherPresent(weathername:string; weathertime:string):boolean; stdcall;
var
  i:integer;
  helper:pCMapListHelper;
  gWeathers:pSGameWeathers;
begin
  result:=false;

  helper:=GetMapList();
  if helper.m_weathers.start = nil then begin
    LoadMapList();
  end;

  gWeathers:=helper.m_weathers.start;
  if gWeathers = nil then exit;

  weathername:=lowercase(trim(weathername));
  weathertime:=lowercase(trim(weathertime));

  for i:=0 to items_count_in_vector(@helper.m_weathers, sizeof(SGameWeathers))-1 do begin
    gWeathers:=get_item_from_vector(@helper.m_weathers, i, sizeof(SGameWeathers));
    if (gWeathers<>nil) and (lowercase(trim(get_string_value(@gWeathers.m_start_time))) = weathertime) and (lowercase(trim(get_string_value(@gWeathers.m_weather_name))) = weathername) then begin
      result:=true;
      break;
    end;
  end;
end;

function IsMapPresent(mapname:string; mapver:string; gametype_id:cardinal):boolean; stdcall;
var
  i:integer;
  helper:pCMapListHelper;
  gtMaps:pSGameTypeMaps;
  pMapItm:pSGameTypeMaps_SMapItm;
begin
  result:=false;

  helper:=GetMapList();
  if helper.m_storage.start = nil then begin
    LoadMapList();
  end;

  gtMaps:=nil;
  for i:=0 to items_count_in_vector(@helper.m_storage, sizeof(SGameTypeMaps))-1 do begin
    gtMaps:=get_item_from_vector(@helper.m_storage, i, sizeof(SGameTypeMaps));
    if gtMaps.m_game_type_id = gametype_id then break;
    gtMaps:=nil;
  end;

  if gtMaps<>nil then begin
    for i:=0 to items_count_in_vector(@gtMaps.m_map_names, sizeof(SGameTypeMaps_SMapItm))-1 do begin
      pMapItm:=get_item_from_vector(@gtMaps.m_map_names, i, sizeof(SGameTypeMaps_SMapItm));
      if (get_string_value(@pMapItm.map_name)=mapname) and (get_string_value(@pMapItm.map_ver)=mapver) then begin
        result:=true;
        break;
      end;
    end;
  end;
end;

function Init():boolean; stdcall;
begin
  if xrGameDllType()=XRGAME_1602 then begin
    g_pMapListHelper:=pointer(xrGame+$651fc8);
    CMapListHelper__Load := srcECXCallFunction.Create(pointer(xrGame+$4b2860),[vtPointer], 'Load', 'CMapListHelper');
  end;
  result:=true;
end;

end.

