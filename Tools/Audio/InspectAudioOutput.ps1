param([string]$OutputPath = '')
$ErrorActionPreference = 'Stop'
# Read-only Core Audio inspection. No setter or muting operation is invoked.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public static class BlackwebAudioReadOnly {
 [ComImport,Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class DeviceEnumerator {}
 [ComImport,Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IEnum {
  int EnumAudioEndpoints(int flow,int state,out IntPtr devices);
  int GetDefaultAudioEndpoint(int flow,int role,out IDevice device);
 }
 [ComImport,Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IDevice {
  int Activate(ref Guid iid,int context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)]out object obj);
  int OpenPropertyStore(int access,out IntPtr properties);
  int GetId([MarshalAs(UnmanagedType.LPWStr)]out string id);
  int GetState(out int state);
 }
 [ComImport,Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IEndpointVolume {
  int Register(IntPtr callback); int Unregister(IntPtr callback); int GetChannelCount(out uint count);
  int SetMasterDb(float value,IntPtr context); int SetMasterScalar(float value,IntPtr context);
  int GetMasterDb(out float value); int GetMasterScalar(out float value);
  int SetChannelDb(uint channel,float value,IntPtr context); int SetChannelScalar(uint channel,float value,IntPtr context);
  int GetChannelDb(uint channel,out float value); int GetChannelScalar(uint channel,out float value);
  int SetMute([MarshalAs(UnmanagedType.Bool)]bool value,IntPtr context);
  int GetMute([MarshalAs(UnmanagedType.Bool)]out bool muted);
 }
 [ComImport,Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessionManager {
  int GetAudioSessionControl(IntPtr guid,uint flags,out IntPtr control); int GetSimpleAudioVolume(IntPtr guid,uint flags,out IntPtr volume);
  int GetSessionEnumerator(out ISessions sessions);
 }
 [ComImport,Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessions {
  int GetCount(out int count); int GetSession(int index,[MarshalAs(UnmanagedType.IUnknown)]out object session);
 }
 [ComImport,Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessionControl {
  int GetState(out int state); int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)]out string name);
  int SetDisplayName(string name,IntPtr context); int GetIconPath(out IntPtr path); int SetIconPath(string path,IntPtr context);
  int GetGroupingParam(out Guid grouping); int SetGroupingParam(ref Guid grouping,IntPtr context);
  int Register(IntPtr callback); int Unregister(IntPtr callback);
  int GetSessionIdentifier(out IntPtr id); int GetSessionInstanceIdentifier(out IntPtr id);
  int GetProcessId(out uint pid);
 }
 [ComImport,Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISimpleVolume {
  int SetMasterVolume(float volume,IntPtr context); int GetMasterVolume(out float volume);
  int SetMute([MarshalAs(UnmanagedType.Bool)]bool mute,IntPtr context); int GetMute([MarshalAs(UnmanagedType.Bool)]out bool mute);
 }
 public static Dictionary<string,object> Read() {
  IEnum enumerator=(IEnum)new DeviceEnumerator(); IDevice device;
  Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0,1,out device));
  string id; device.GetId(out id);
  Guid volumeId=typeof(IEndpointVolume).GUID; object endpointObject;
  Marshal.ThrowExceptionForHR(device.Activate(ref volumeId,23,IntPtr.Zero,out endpointObject));
  IEndpointVolume volume=(IEndpointVolume)endpointObject; float scalar,db; bool muted;
  volume.GetMasterScalar(out scalar); volume.GetMasterDb(out db); volume.GetMute(out muted);
  var result=new Dictionary<string,object>{{"endpoint_id",id},{"endpoint_volume_scalar",scalar},{"endpoint_volume_db",db},{"endpoint_muted",muted},{"read_only",true}};
  Guid managerId=typeof(ISessionManager).GUID; object managerObject;
  Marshal.ThrowExceptionForHR(device.Activate(ref managerId,23,IntPtr.Zero,out managerObject));
  ISessions sessions; ((ISessionManager)managerObject).GetSessionEnumerator(out sessions); int count; sessions.GetCount(out count);
  var rows=new List<object>();
  for(int i=0;i<count;i++) {
   object session; sessions.GetSession(i,out session); var control=(ISessionControl)session;
   uint pid; string name; int state; control.GetProcessId(out pid); control.GetDisplayName(out name); control.GetState(out state);
   float gain; bool mute; var simple=(ISimpleVolume)session; simple.GetMasterVolume(out gain); simple.GetMute(out mute);
   rows.Add(new Dictionary<string,object>{{"process_id",pid},{"display_name",name},{"state",state},{"volume_scalar",gain},{"muted",mute}});
   Marshal.ReleaseComObject(session);
  }
  result["sessions"]=rows; Marshal.ReleaseComObject(sessions); Marshal.ReleaseComObject(managerObject); Marshal.ReleaseComObject(endpointObject); Marshal.ReleaseComObject(device); Marshal.ReleaseComObject(enumerator); return result;
 }
}
'@
$report = [BlackwebAudioReadOnly]::Read()
$report['observed_at_utc'] = [DateTime]::UtcNow.ToString('o')
$json = $report | ConvertTo-Json -Depth 5
if ($OutputPath) { [IO.File]::WriteAllText($OutputPath, $json) }
$json
