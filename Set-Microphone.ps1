$ProgressPreference = 'SilentlyContinue'
$raw = $env:LEVEL
if ([string]::IsNullOrWhiteSpace($raw)) { $raw = '100' }
$percent = 0
if (-not [int]::TryParse($raw.Trim(), [ref]$percent) -or $percent -lt 10 -or $percent -gt 300) {
  Write-Host 'Need a whole number from 10 to 300.'
  exit 1
}
$src = @'
using System;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorCom {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceEnumerator {
  int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
  int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
}
[Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceCollection {
  int GetCount(out int count);
  int Item(int index, out IMMDevice device);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDevice {
  int Activate(ref Guid iid, int clsCtx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
  int OpenPropertyStore(int access, out IPropertyStore store);
  int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
  int GetState(out int state);
}
[Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPropertyStore {
  int GetCount(out int count);
  int GetAt(int i, out PropertyKey key);
  int GetValue(ref PropertyKey key, out PropVariant value);
}
[StructLayout(LayoutKind.Sequential)]
public struct PropertyKey { public Guid fmtid; public int pid; }
[StructLayout(LayoutKind.Explicit)]
public struct PropVariant {
  [FieldOffset(0)] public ushort vt;
  [FieldOffset(8)] public IntPtr ptr;
}
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioEndpointVolume {
  int RegisterControlChangeNotify(IntPtr p);
  int UnregisterControlChangeNotify(IntPtr p);
  int GetChannelCount(out uint count);
  int SetMasterVolumeLevel(float level, ref Guid ctx);
  int SetMasterVolumeLevelScalar(float level, ref Guid ctx);
  int GetMasterVolumeLevel(out float level);
  int GetMasterVolumeLevelScalar(out float level);
  int SetChannelVolumeLevel(uint channel, float level, ref Guid ctx);
  int SetChannelVolumeLevelScalar(uint channel, float level, ref Guid ctx);
  int GetChannelVolumeLevel(uint channel, out float level);
  int GetChannelVolumeLevelScalar(uint channel, out float level);
  int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid ctx);
  int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
  int GetVolumeStepInfo(out uint step, out uint stepCount);
  int VolumeStepUp(ref Guid ctx);
  int VolumeStepDown(ref Guid ctx);
  int QueryHardwareSupport(out uint support);
  int GetVolumeRange(out float min, out float max, out float step);
}
[Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPolicyConfig {
  int GetMixFormat();
  int GetDeviceFormat();
  int ResetDeviceFormat();
  int SetDeviceFormat();
  int GetProcessingPeriod();
  int SetProcessingPeriod();
  int GetShareMode();
  int SetShareMode();
  int GetPropertyValue();
  int SetPropertyValue();
  int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
  int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string id, int visible);
}
[ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
class PolicyConfigClient {}
public static class MicApply {
  static bool HardwareMic(string name) {
    if (string.IsNullOrEmpty(name)) return false;
    string n = name.ToLowerInvariant();
    if (n.Contains("voicemeeter") || n.Contains("vb-audio") || n.Contains("cable")) return false;
    return n.Contains("microphone") || n.Contains("mic ");
  }
  static string NameOf(IMMDevice dev) {
    IPropertyStore store;
    dev.OpenPropertyStore(0, out store);
    PropertyKey key = new PropertyKey();
    key.fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0");
    key.pid = 14;
    PropVariant val;
    store.GetValue(ref key, out val);
    if (val.ptr == IntPtr.Zero) return "";
    return Marshal.PtrToStringUni(val.ptr);
  }
  static string WriteChain(int percent, string deviceId) {
    string guid = deviceId;
    int dot = deviceId.LastIndexOf('.');
    if (dot >= 0 && dot + 1 < deviceId.Length) guid = deviceId.Substring(dot + 1).Trim('{', '}');
    string path = @"C:\Program Files\EqualizerAPO\config\config.txt";
    if (!File.Exists(path)) return "Voice processing: Equalizer APO is not installed.";
    string text = "# Playback is untouched.\r\n";
    string voice = "Voice processing: off.";
    if (percent >= 201) {
      double t = (percent - 200) / 100.0;
      int vad = (int)Math.Round(78 + 8 * t);
      int grace = (int)Math.Round(400 + 80 * t);
      double threshold = -6.0 - 4.0 * t;
      text = "Device: " + guid + "\r\n"
        + "Filter: ON HP Fc 120 Hz\r\n"
        + "VSTPlugin: Library \"C:\\Program Files\\EqualizerAPO\\VSTPlugins\\rnnoise_stereo.dll\" \"VAD Threshold\" " + vad.ToString(CultureInfo.InvariantCulture) + " \"VAD Grace Period\" " + grace.ToString(CultureInfo.InvariantCulture) + " \"Retroactive VAD Grace Period\" 0\r\n"
        + "VSTPlugin: Library \"C:\\Program Files\\EqualizerAPO\\VSTPlugins\\reagate-standalone.dll\" Thresh -36 Attack 50 Hold 40 Release 180\r\n"
        + "VSTPlugin: Library \"C:\\Program Files\\EqualizerAPO\\VSTPlugins\\LoudMax64.dll\" Threshold " + threshold.ToString("0.0", CultureInfo.InvariantCulture) + " Output -1\r\n";
      voice = "Voice processing: strong RNNoise " + vad.ToString(CultureInfo.InvariantCulture) + ", click gate, leveler " + threshold.ToString("0.0", CultureInfo.InvariantCulture) + " dB.";
    } else if (percent >= 101) {
      text = "Device: " + guid + "\r\n"
        + "Filter: ON HP Fc 80 Hz\r\n"
        + "VSTPlugin: Library \"C:\\Program Files\\EqualizerAPO\\VSTPlugins\\rnnoise_stereo.dll\" \"VAD Threshold\" 60 \"VAD Grace Period\" 250 \"Retroactive VAD Grace Period\" 0\r\n"
        + "VSTPlugin: Library \"C:\\Program Files\\EqualizerAPO\\VSTPlugins\\LoudMax64.dll\" Threshold -3 Output -1\r\n";
      voice = "Voice processing: RNNoise, peak limiter -1 dB.";
    }
    File.WriteAllText(path, text);
    return voice;
  }
  public static string Run(int percent) {
    var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
    IMMDeviceCollection col;
    en.EnumAudioEndpoints(1, 1, out col);
    int n; col.GetCount(out n);
    IMMDevice chosen = null;
    string chosenName = "";
    string chosenId = "";
    IMMDevice def;
    if (en.GetDefaultAudioEndpoint(1, 2, out def) == 0) {
      string name = NameOf(def);
      if (HardwareMic(name)) { chosen = def; chosenName = name; def.GetId(out chosenId); }
    }
    if (chosen == null) {
      for (int i = 0; i < n; i++) {
        IMMDevice dev; col.Item(i, out dev);
        string name = NameOf(dev);
        if (!HardwareMic(name)) continue;
        chosen = dev; chosenName = name; dev.GetId(out chosenId); break;
      }
    }
    if (chosen == null) return "No hardware microphone is active.";
    var policy = (IPolicyConfig)new PolicyConfigClient();
    for (int role = 0; role <= 2; role++) policy.SetDefaultEndpoint(chosenId, role);
    Guid volId = typeof(IAudioEndpointVolume).GUID;
    object volObj;
    chosen.Activate(ref volId, 23, IntPtr.Zero, out volObj);
    var vol = (IAudioEndpointVolume)volObj;
    Guid empty = Guid.Empty;
    vol.SetMute(false, ref empty);
    float min, max, step;
    vol.GetVolumeRange(out min, out max, out step);
    double db = percent <= 100
      ? -8.0 + (percent - 10) / 90.0 * 20.0
      : percent <= 200
        ? 12.0 + (percent - 100) / 100.0 * 16.0
        : 28.0 + (percent - 200) / 100.0 * 2.0;
    bool clamped = false;
    if (db < min) { db = min; clamped = true; }
    if (db > max) { db = max; clamped = true; }
    int hr = vol.SetMasterVolumeLevel((float)db, ref empty);
    if (hr != 0) return "The microphone rejected " + percent + "%.";
    bool mute; float now;
    vol.GetMute(out mute);
    vol.GetMasterVolumeLevel(out now);
    string voice = WriteChain(percent, chosenId);
    string line = "Microphone: " + chosenName
      + "\r\nLevel: " + percent + "% (" + now.ToString("0.0") + " dB)"
      + "\r\nMute: " + (mute ? "on" : "off")
      + "\r\n" + voice;
    if (clamped) line += "\r\nThis microphone stops at " + now.ToString("0.0") + " dB.";
    return line;
  }
}
'@
Add-Type -TypeDefinition $src
Write-Output ([MicApply]::Run($percent))
