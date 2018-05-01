#ifndef _SYSMSGS_H_
#define _SYSMSGS_H_

#include "windows.h"

#pragma pack(push, 1)

typedef void* FZSysmsgPayloadWriter;
typedef void* FZSysMsgSender;

//��� ����������, �������������� � ����������� �� ������� �����   
typedef DWORD FZArchiveCompressionType;
    const FZArchiveCompressionType FZ_COMPRESSION_NO_COMPRESSION = 0;    //���������� ���, ���� �� ������� �� ����
    const FZArchiveCompressionType FZ_COMPRESSION_LZO_COMPRESSION = 1;   //���� ���� ������������� LZO-������������
    const FZArchiveCompressionType FZ_COMPRESSION_CAB_COMPRESSION = 2;   //���� ���� ����������� �������� MAKECAB �� ������� Windows   

//���������� ������, � ������� ������ ���������� ������� ����
typedef DWORD FZModdingPolicy;

    //������� �� DLL ���� ����� ���������� � ����� �����. �������������� ��������� �� ������������.
    const FZModdingPolicy FZ_MODDING_ANYTIME = 0;
    
    //������� �� DLL ���� ������ ���������� ������ � �������� �������� � ������� (�.�. ��� ������������� ������������� ������������ ��������� ����� ������)
    //������ ��� �����, �� ��������� �������� �������
    const FZModdingPolicy FZ_MODDING_WHEN_CONNECTING = 1;
    
    //������� �� DLL ���� ������ ���������� ������ ����� ������ �� � ��������� �������� (�.�. ���� ���� �� ������� ��� ���� - ��� ����� ����� ���������� ����������)
    //��������������� ���������� �� ������������, ��� ��� �������� �� ��������� � ������ ������������� ��������
    //������ � ����: � ������ ������ ����� ����� ����� ���� �� ������ ������! � ���� ������ ��������������� ����������� � ������� ������� ����������� �� �����!
    const FZModdingPolicy FZ_MODDING_WHEN_NOT_CONNECTING = 2;

//��������� ������������ �����
struct FZFileDownloadInfo
{
    //��� ����� (������ � �����) �� �������, �� �������� �� ������ ���� ��������
    char* filename;
    //URL, � �������� ����� ������������� �������� �����
    char* url;
    //����������� ����� CRC32 ��� ����� (� ������������� ����)
    DWORD crc32;
    //������������ ��� ����������
    FZArchiveCompressionType compression;
    //���������, ��������� ������������ �� ����� �������
    char* progress_msg;
    //���������, ��������� ������������ ��� ������������� ������ �� ����� �������
    char* error_already_has_dl_msg;
};

//��������� ���������� ������� � �������
struct FZReconnectInetAddrData
{
    //IPv4-����� ������� (��������, 127.0.0.1)
    char* ip;
    //���� �������
    DWORD port;
};

typedef DWORD FZMapLoadingFlags;
    const FZMapLoadingFlags FZ_MAPLOAD_MANDATORY_RECONNECT = 1; //������������ ��������� ����� �������� ��������� ��������� �����

//��������� �������� �������� db-������ � ������
struct FZMapInfo
{
    //��������� �����
    FZFileDownloadInfo fileinfo;
    //IP-����� � ���� ��� ���������� ����� ���������� �������. ���� IP ������, �� ��������� ���������� ������������� ������� ����� �� ���, �� ����� ������� ��������� ����������.
    FZReconnectInetAddrData reconnect_addr;
    //������������� ��� ����������� ����� (��������, mp_pool)
    char* mapname;
    //������ ����������� ����� (������ 1.0)
    char* mapver;
    //�������� xml-����� � ��������������� ��������� � ��������� ����� (nil, ���� ����� �� ���������)
    char* xmlname;
    //����� ��� ��������� ������������ ���������� �����
    FZMapLoadingFlags flags;
};

typedef DWORD FZDllModFunResult;
    const FZDllModFunResult FZ_DLL_MOD_FUN_SUCCESS_LOCK = 0;    //��� ������� ����������, ��������� �������� ������� �� name_lock
    const FZDllModFunResult FZ_DLL_MOD_FUN_SUCCESS_NOLOCK = 1;  //�����, ������ ������� (� �������������� name_lock) ���� �� ����
    const FZDllModFunResult FZ_DLL_MOD_FUN_FAILURE = 2;         //������ �������� ����

typedef FZDllModFunResult (__stdcall *FZDllModFun) (char* procarg1, char* procarg2);
    
//��������� �������� �������� DLL-���� ����������� ProcessClientModDll
struct FZDllDownloadInfo
{
    //��������� ����� ��� dll ����
    FZFileDownloadInfo fileinfo;

    //��� ��������� � dll ����, ������� ������ ���� �������; ������ ����� ��� FZDllModFun
    char* procname;

    //��������� ��� �������� � ���������
    char* procarg1;
    char* procarg2;

    //�������� ������� ��� ����������� DLL - ����������� ����� ���, ��� �������� ���������� � ������� ����
    char* dsign;

    //IP-����� � ���� ��� ����������. ���� IP �������, �� ��������� ���������� ������������� ������� ����� �� ���, �� ����� ������� ��������� ����������.
    FZReconnectInetAddrData reconnect_addr;

    //��������� ������� ��������� ����
    FZModdingPolicy modding_policy;

    //�������� ��� �������� � ��������� -fzmod.
    //���� �������� nil - ������ �� �����������.
    //���� �������� ��������� � ������� � ��������� ������ - ��� ��������� ��� �������������, ������� ������������
    //���� �������� �� ��������� � ��������� � ��������� ������ - ���������� ���������� ������
    //���� � ��������� ������ ��������� ��� - ���������� ��������� ����.
    char* name_lock;

    //������, ��������� ��� ����������� �������������� ����
    char* incompatible_mod_message;

    //������, ��������� ��� ���������� ���� ����� ����������� (���� ������� FZ_MODDING_WHEN_NOT_CONNECTING)
    char* mod_is_applying_message;
};

//��������� ��������� ����� ��� ���������� � ������ �����������
struct FZClientVotingElement
{
    //������������� ��� ����� (��������, mp_pool). � ������ ���� nil - ������������ ������� ������ ����!
    //������������� ���������� nil ������ ��������� � ������
    char* mapname;
    //������ �����
    char* mapver;
    //�������������� �������� �����; ���� nil, ����� ����������� ��������� ������ ������������ �������������� ����������� �� �������
    char* description;
};

//��������� ���������� ���� � ������, ��������� ��� �����������, ������������ � ProcessClientVotingMaplist
struct FZClientVotingMapList
{
  //��������� �� ������ �� FZClientVotingElement. ������ ������� ������� �������� ��������� ����� �����,
  //������� ��������� �������� � ������ ����, ��������� ��� �����������
  FZClientVotingElement* maps;

  //����� ��������� � ������� maps
  DWORD count;

  //������������� ���� ����, ��� �������� ��������� �������� ������ ����. � ������ ������� ��� ���� ���������� � � game_GameState.m_type
  DWORD gametype;

  //�������� ��������, ����������, ������� ���� �� ������� ���� ���������� �������, ������ ���� � ������ �������.
  DWORD was_sent;
};

#pragma pack(pop)

typedef DWORD FZSysmsgsCommonFlags;
    const FZSysmsgsCommonFlags FZ_SYSMSGS_ENABLE_LOGS = 1; // �������� ����������� ����� �� �������
    const FZSysmsgsCommonFlags FZ_SYSMSGS_PATCH_UI_PROGRESSBAR = 2; // �������� ������� ������������ � �� (��� ����������� ����������� �������� ��������)
    const FZSysmsgsCommonFlags FZ_SYSMSGS_PATCH_VERTEX_BUFFER = 4; // �������� ���������� �������-������ � �� (���� ��� ������ �� ������� ������)
    const FZSysmsgsCommonFlags FZ_SYSMSGS_FLAGS_ALL_ENABLED = 0xFFFFFFFF;



typedef void(__stdcall *FZSysMsgSendCallback) (void* msg, unsigned int len, void* userdata);
typedef bool(__stdcall *FZSysMsgsInit)();
typedef bool(__stdcall *FZSysMsgsFlags)(FZSysmsgsCommonFlags);
typedef void(__stdcall *FZSysMsgsSendSysMessage)(void*, void*, FZSysMsgSendCallback, void*);
typedef bool(__stdcall *FZSysMsgsFree)();


struct SFreeZoneProcedures 
{
    FZSysMsgsInit init_proc;
    FZSysMsgsFree free_proc;
    FZSysMsgsFlags flags_proc;
    FZSysMsgsSendSysMessage send_proc;
    void* process_client_mod;
};

class CFreeZoneFeatures
{
    HMODULE _handle;
    SFreeZoneProcedures _procedures;

public:
    CFreeZoneFeatures()
    {       
        ZeroMemory(&_procedures, sizeof(_procedures));
        _handle = LoadLibrary("sysmsgs.dll");  
        if (_handle != nullptr)
        {
            _procedures.init_proc = (FZSysMsgsInit) GetProcAddress(_handle, "FZSysMsgsInit");
            _procedures.free_proc = (FZSysMsgsFree) GetProcAddress(_handle, "FZSysMsgsFree");
            _procedures.flags_proc = (FZSysMsgsFlags) GetProcAddress(_handle, "FZSysMsgsSetCommonSysmsgsFlags");
            _procedures.send_proc = (FZSysMsgsSendSysMessage) GetProcAddress(_handle, "FZSysMsgsSendSysMessage");
            _procedures.process_client_mod = GetProcAddress(_handle, "FZSysMsgsProcessClientModDll");
        }

        if (_procedures.init_proc!=nullptr)
        {
            _procedures.init_proc();
        }

        if (_procedures.flags_proc!=nullptr)
        {
            _procedures.flags_proc(FZ_SYSMSGS_ENABLE_LOGS | FZ_SYSMSGS_PATCH_UI_PROGRESSBAR);
        }
    }

    void SendModDownloadMessage(char* mod_name, char* mod_params, FZSysMsgSendCallback cb, void* userdata)
    {
        FZDllDownloadInfo info = {};
        info.fileinfo.error_already_has_dl_msg = "Download is in progress already";
        info.fileinfo.progress_msg = "Downloading mod, please wait";
        info.incompatible_mod_message = "The server uses incompatible mod, try to restart the game";
        info.mod_is_applying_message = "Mod is applying, please wait";
        info.name_lock = mod_name;
        info.procarg1 = mod_name;
        info.procarg2 = mod_params;
        info.procname = "ModLoad";

        if (_procedures.send_proc != nullptr && _procedures.process_client_mod != nullptr)
        {
            _procedures.send_proc(_procedures.process_client_mod, &info, cb, userdata);
        }
    }

    ~CFreeZoneFeatures()
    {
        if (_handle != nullptr)
        {
            if (_procedures.free_proc != nullptr)
            {
                _procedures.free_proc();
            }
            FreeLibrary(_handle);
        }
    }
};

#endif