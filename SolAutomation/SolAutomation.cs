using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using MelonLoader;
using ModSettingsMenu;
using UnityEngine;
using UnityEngine.UI;

[assembly: MelonInfo(typeof(SolMDRGAutomation.SolAutomationMod), "Sol Automation", "0.2.0", "Sol")]
[assembly: MelonGame("IncontinentCell", "My Dystopian Robot Girlfriend")]

namespace SolMDRGAutomation;

public sealed class SolAutomationMod : MelonMod
{
    private const string ModId = "solAutomation";
    private MelonPreferences_Category _prefs;
    private MelonPreferences_Entry<bool> _streamSkip;
    private readonly FishingAutomation _fishing = new();
    private readonly StreamingAutomation _streaming = new();

    public override void OnInitializeMelon()
    {
        MelonLogger.Msg($"Sol Automation 0.2.0 | MDRG {Application.version}");

        _prefs = MelonPreferences.CreateCategory("SolAutomation");
        _streamSkip = _prefs.CreateEntry("StreamingAutoSkip", false);

        try
        {
            MSM.RegisterMod(ModId, "Sol Automation");
            MSM.AddCheckbox(
                ModId,
                PanelSide.LeftPanel,
                "Pular streaming automaticamente",
                () => _streamSkip.Value,
                (Action<bool>)(value =>
                {
                    _streamSkip.Value = value;
                    _prefs.SaveToFile(true);
                    if (!value) _streaming.Stop();
                }),
                "Acelera apenas cenas sexuais durante streaming e para no limite seguro de 10% de fome/energia."
            );
        }
        catch (Exception ex)
        {
            MelonLogger.Warning($"Mod Settings Menu indisponível: {ex.Message}");
        }
    }

    public override void OnUpdate()
    {
        _fishing.Update();

        if (_fishing.IsMinigameActive && Input.GetKeyDown(KeyCode.P))
            _fishing.Toggle();

        _streaming.Enabled = _streamSkip.Value;
        _streaming.Update();
    }

    public override void OnGUI()
    {
        if (!_fishing.IsMinigameActive) return;

        const float width = 250f;
        const float height = 44f;
        var rect = new Rect(Screen.width - width - 20f, 20f, width, height);
        string text = _fishing.Enabled ? "AUTO PESCA [P]: ON" : "AUTO PESCA [P]: OFF";

        if (GUI.Button(rect, text))
            _fishing.Toggle();
    }

    public override void OnDeinitializeMelon()
    {
        _streaming.Stop();
    }
}

internal sealed class StreamingAutomation
{
    private const float MinResource = 0.10f;
    private const float GuardResource = 0.115f;
    private const float MaxFastForward = 20f;

    public bool Enabled;
    private bool _fast;
    private float _oldScale = 1f;
    private float _nextScan;
    private bool _streamingCached;
    private object _gameVariables;
    private object _brain;

    public void Update()
    {
        if (!Enabled)
        {
            Stop();
            return;
        }

        if (Time.unscaledTime >= _nextScan)
        {
            _gameVariables = ReflectionUtil.FindGameVariables();
            _brain = ReflectionUtil.FindModelBrain();
            _streamingCached = ReflectionUtil.DetectStreaming(_gameVariables);
            _nextScan = Time.unscaledTime + 0.35f;
        }

        if (_gameVariables == null || _brain == null || !_streamingCached || !ReflectionUtil.IsSexScene(_brain))
        {
            Stop();
            return;
        }

        bool hasStamina = ReflectionUtil.TryReadFloat(_gameVariables, out float stamina, "_stamina", "stamina", "Stamina");
        bool hasSatiation = ReflectionUtil.TryReadFloat(_gameVariables, out float satiation, "_satiation", "satiation", "Satiation");
        bool hasCum = ReflectionUtil.TryReadFloat(_gameVariables, out float currentCum, "CurrentCum", "currentCum");

        if (hasCum && currentCum < 5f)
        {
            Stop();
            return;
        }

        if ((hasStamina && stamina <= GuardResource) || (hasSatiation && satiation <= GuardResource))
        {
            EmergencyFloor(_gameVariables, stamina, satiation, hasStamina, hasSatiation);
            Stop();
            return;
        }

        Start();
    }

    private void Start()
    {
        if (!_fast)
        {
            _oldScale = Time.timeScale;
            _fast = true;
            MelonLogger.Msg("Streaming: avanço automático ON.");
        }

        Time.timeScale = MaxFastForward;
    }

    public void Stop()
    {
        if (!_fast) return;
        Time.timeScale = Mathf.Max(0.01f, _oldScale);
        _fast = false;
        MelonLogger.Msg("Streaming: avanço automático encerrado.");
    }

    private static void EmergencyFloor(object vars, float stamina, float satiation, bool hasStamina, bool hasSatiation)
    {
        // Só corrige um eventual overshoot de frame do fast-forward.
        if (hasStamina && stamina < MinResource)
            ReflectionUtil.TryWriteFloat(vars, MinResource, "_stamina", "stamina", "Stamina");
        if (hasSatiation && satiation < MinResource)
            ReflectionUtil.TryWriteFloat(vars, MinResource, "_satiation", "satiation", "Satiation");
    }
}

internal sealed class FishingAutomation
{
    public bool Enabled { get; private set; }
    public bool IsMinigameActive => _roots.Count > 0;

    private readonly List<MonoBehaviour> _roots = new();
    private float _nextScan;
    private float _nextContinue;
    private float _lastSeen;

    public void Toggle()
    {
        Enabled = !Enabled;
        MelonLogger.Msg($"Auto pesca: {(Enabled ? "ON" : "OFF")}");
    }

    public void Update()
    {
        if (Time.unscaledTime >= _nextScan)
        {
            Scan();
            _nextScan = Time.unscaledTime + 0.20f;
        }

        if (IsMinigameActive)
            _lastSeen = Time.unscaledTime;
        else if (Time.unscaledTime - _lastSeen > 2.5f)
            Enabled = false;

        if (!Enabled || !IsMinigameActive) return;

        foreach (var root in _roots.ToArray())
        {
            if (root == null) continue;
            TrackFish(root);
            PerfectProgress(root);
            TryInvokePerfectMethods(root);
        }

        if (Time.unscaledTime >= _nextContinue)
        {
            ClickContinueButtons();
            _nextContinue = Time.unscaledTime + 0.30f;
        }
    }

    private void Scan()
    {
        _roots.Clear();

        foreach (var b in Resources.FindObjectsOfTypeAll<MonoBehaviour>())
        {
            if (b == null || b.gameObject == null || !b.gameObject.activeInHierarchy) continue;

            string id = $"{b.GetType().FullName} {b.name} {b.gameObject.name} {ReflectionUtil.TransformPath(b.transform)}".ToLowerInvariant();
            if (!id.Contains("fish")) continue;

            bool likely = id.Contains("minigame") || id.Contains("reel") || id.Contains("catch");
            if (!likely)
            {
                likely = ReflectionUtil.GetReadableMembers(b.GetType()).Any(m =>
                {
                    string n = m.Name.ToLowerInvariant();
                    return n.Contains("catchprogress") || n.Contains("fishprogress") ||
                           n.Contains("reelprogress") || n.Contains("captureprogress");
                });
            }

            if (likely) _roots.Add(b);
        }
    }

    private static void TrackFish(MonoBehaviour root)
    {
        Transform fish = null;
        Transform bar = null;

        foreach (var t in ReflectionUtil.Descendants(root.transform))
        {
            string n = t.name?.ToLowerInvariant() ?? "";
            if (fish == null && n.Contains("fish") && !n.Contains("bar") && !n.Contains("button"))
                fish = t;

            if (bar == null && (n.Contains("white") || n.Contains("catchbar") || n.Contains("catch_bar") ||
                                n.Contains("reelzone") || n.Contains("reel_zone") || n == "bar"))
                bar = t;
        }

        if (fish == null || bar == null) return;

        try
        {
            var fr = fish as RectTransform;
            var br = bar as RectTransform;
            if (fr != null && br != null)
            {
                var p = br.anchoredPosition;
                p.y = fr.anchoredPosition.y;
                br.anchoredPosition = p;
            }
            else
            {
                var p = bar.localPosition;
                p.y = fish.localPosition.y;
                bar.localPosition = p;
            }
        }
        catch { }
    }

    private static void PerfectProgress(object root)
    {
        foreach (var m in ReflectionUtil.GetReadableMembers(root.GetType()))
        {
            string n = m.Name.ToLowerInvariant();
            bool target = n == "progress" || n.Contains("catchprogress") || n.Contains("fishprogress") ||
                          n.Contains("reelprogress") || n.Contains("captureprogress") || n.Contains("successprogress");
            if (!target) continue;

            object value;
            try { value = ReflectionUtil.ReadMember(root, m); }
            catch { continue; }

            if (value is Slider s)
            {
                try { s.value = s.maxValue; } catch { }
                continue;
            }

            if (value is Image img)
            {
                try { img.fillAmount = 1f; } catch { }
                continue;
            }

            if (!ReflectionUtil.TryConvertFloat(value, out float f)) continue;
            float targetValue = f <= 1.5f ? 1f : (f <= 100f ? 100f : f);
            ReflectionUtil.TryWriteMemberFloat(root, m, targetValue);
        }
    }

    private static void TryInvokePerfectMethods(object root)
    {
        var methods = root.GetType().GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
        foreach (var method in methods)
        {
            if (method.GetParameters().Length != 0) continue;
            string n = method.Name.ToLowerInvariant();
            if (!(n.Contains("perfect") && (n.Contains("click") || n.Contains("hit") || n.Contains("catch")))) continue;

            try { method.Invoke(root, null); }
            catch { }
        }
    }

    private static void ClickContinueButtons()
    {
        foreach (var button in Resources.FindObjectsOfTypeAll<Button>())
        {
            if (button == null || button.gameObject == null || !button.gameObject.activeInHierarchy || !button.interactable)
                continue;

            string text = ReflectionUtil.ButtonText(button);
            string id = $"{button.name} {text} {ReflectionUtil.TransformPath(button.transform)}".ToLowerInvariant();

            if (!id.Contains("fish")) continue;
            if (id.Contains("exit") || id.Contains("leave") || id.Contains("quit") || id.Contains("cancel")) continue;

            if (id.Contains("cast") || id.Contains("again") || id.Contains("continue") || id.Contains("retry"))
            {
                try { button.onClick.Invoke(); } catch { }
            }
        }
    }
}

internal static class ReflectionUtil
{
    private const BindingFlags Flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static;

    public static IEnumerable<MemberInfo> GetReadableMembers(System.Type type)
    {
        foreach (var f in type.GetFields(Flags)) yield return f;
        foreach (var p in type.GetProperties(Flags))
            if (p.CanRead && p.GetIndexParameters().Length == 0) yield return p;
    }

    public static object ReadMember(object target, MemberInfo member)
    {
        if (member is FieldInfo f) return f.GetValue(f.IsStatic ? null : target);
        if (member is PropertyInfo p) return p.GetValue((p.GetMethod?.IsStatic ?? false) ? null : target);
        return null;
    }

    public static object FindGameVariables()
    {
        foreach (var b in Resources.FindObjectsOfTypeAll<MonoBehaviour>())
        {
            if (b == null) continue;
            string typeName = b.GetType().FullName?.ToLowerInvariant() ?? "";
            if (!typeName.EndsWith("gamescript") && !typeName.Contains(".gamescript")) continue;

            if (TryReadObject(b, out object vars, "GameVariables", "gameVariables") && vars != null)
                return vars;
        }
        return null;
    }

    public static object FindModelBrain()
    {
        foreach (var b in Resources.FindObjectsOfTypeAll<MonoBehaviour>())
        {
            if (b == null) continue;
            string n = b.GetType().FullName?.ToLowerInvariant() ?? "";
            if (n.Contains("modelbrain")) return b;
        }
        return null;
    }

    public static bool IsSexScene(object brain)
    {
        if (!TryReadObject(brain, out object state, "CurrentState", "currentState") || state == null) return false;
        string n = state.GetType().FullName?.ToLowerInvariant() ?? "";
        return n.Contains("fuck") || n.Contains("cowgirl") || n.Contains("shower") ||
               n.Contains("missionary") || n.Contains("doggy") || n.Contains("blowjob") ||
               n.Contains("sex");
    }

    public static bool DetectStreaming(object vars)
    {
        if (vars != null)
        {
            foreach (var m in GetReadableMembers(vars.GetType()))
            {
                string n = m.Name.ToLowerInvariant();
                if (!(n.Contains("stream") || n.Contains("cocktwitch"))) continue;
                object v;
                try { v = ReadMember(vars, m); } catch { continue; }
                if (v is bool b && b) return true;
            }
        }

        foreach (var b in Resources.FindObjectsOfTypeAll<MonoBehaviour>())
        {
            if (b == null || b.gameObject == null || !b.gameObject.activeInHierarchy) continue;
            string id = $"{b.GetType().FullName} {b.name} {b.gameObject.name} {TransformPath(b.transform)}".ToLowerInvariant();
            if (id.Contains("cocktwitch") || id.Contains("streaming") || id.Contains("streamcontroller"))
                return true;
        }
        return false;
    }

    public static bool TryReadObject(object target, out object value, params string[] names)
    {
        value = null;
        if (target == null) return false;

        foreach (var m in GetReadableMembers(target.GetType()))
        {
            if (!names.Any(n => string.Equals(n, m.Name, StringComparison.OrdinalIgnoreCase))) continue;
            try
            {
                value = ReadMember(target, m);
                return true;
            }
            catch { }
        }
        return false;
    }

    public static bool TryReadFloat(object target, out float result, params string[] names)
    {
        result = 0f;
        if (!TryReadObject(target, out object value, names)) return false;
        return TryConvertFloat(value, out result);
    }

    public static bool TryWriteFloat(object target, float value, params string[] names)
    {
        if (target == null) return false;
        foreach (var m in GetReadableMembers(target.GetType()))
        {
            if (!names.Any(n => string.Equals(n, m.Name, StringComparison.OrdinalIgnoreCase))) continue;
            if (TryWriteMemberFloat(target, m, value)) return true;
        }
        return false;
    }

    public static bool TryWriteMemberFloat(object target, MemberInfo member, float value)
    {
        try
        {
            if (member is FieldInfo f && !f.IsInitOnly)
            {
                f.SetValue(f.IsStatic ? null : target, ConvertNumber(value, f.FieldType));
                return true;
            }

            if (member is PropertyInfo p && p.CanWrite)
            {
                p.SetValue((p.SetMethod?.IsStatic ?? false) ? null : target, ConvertNumber(value, p.PropertyType));
                return true;
            }
        }
        catch { }
        return false;
    }

    private static object ConvertNumber(float value, System.Type type)
    {
        if (type == typeof(float)) return value;
        if (type == typeof(double)) return (double)value;
        if (type == typeof(int)) return (int)value;
        if (type == typeof(long)) return (long)value;
        return Convert.ChangeType(value, type);
    }

    public static bool TryConvertFloat(object value, out float result)
    {
        result = 0f;
        if (value == null) return false;
        try
        {
            result = Convert.ToSingle(value);
            return !float.IsNaN(result) && !float.IsInfinity(result);
        }
        catch { return false; }
    }

    public static IEnumerable<Transform> Descendants(Transform root)
    {
        if (root == null) yield break;
        var stack = new Stack<Transform>();
        stack.Push(root);

        int guard = 0;
        while (stack.Count > 0 && guard++ < 500)
        {
            var t = stack.Pop();
            yield return t;
            for (int i = 0; i < t.childCount; i++)
                stack.Push(t.GetChild(i));
        }
    }

    public static string TransformPath(Transform t)
    {
        if (t == null) return "";
        string path = t.name ?? "";
        var cur = t.parent;
        int guard = 0;

        while (cur != null && guard++ < 10)
        {
            path = (cur.name ?? "") + "/" + path;
            cur = cur.parent;
        }
        return path;
    }

    public static string ButtonText(Button button)
    {
        try
        {
            var t = button.GetComponentInChildren<Text>(true);
            return t?.text ?? "";
        }
        catch { return ""; }
    }
}
