using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using MelonLoader;

[assembly: MelonInfo(typeof(SolMDRGAutomation.SolAutomationMod), "Sol Automation", "0.3.0", "Sol")]
[assembly: MelonGame("IncontinentCell", "My Dystopian Robot Girlfriend")]

namespace SolMDRGAutomation;

public sealed class SolAutomationMod : MelonMod
{
    private MelonPreferences_Category _prefs;
    private MelonPreferences_Entry<bool> _streamSkip;
    private readonly FishingAutomation _fishing = new();
    private readonly StreamingAutomation _streaming = new();
    private bool _msmReady;
    private double _nextMsmTry;

    public override void OnInitializeMelon()
    {
        _prefs = MelonPreferences.CreateCategory("SolAutomation");
        _streamSkip = _prefs.CreateEntry("StreamingAutoSkip", false);
        MelonLogger.Msg("Sol Automation 0.3.0 iniciado.");
        TryRegisterSettings();
    }

    public override void OnUpdate()
    {
        double now = UnityBridge.UnscaledTime;

        if (!_msmReady && now >= _nextMsmTry)
        {
            _nextMsmTry = now + 2.0;
            TryRegisterSettings();
        }

        _fishing.Update();

        if (_fishing.IsMinigameActive && UnityBridge.KeyPressed("P"))
            _fishing.Toggle();

        _streaming.Enabled = _streamSkip?.Value ?? false;
        _streaming.Update();
    }

    public override void OnGUI()
    {
        if (!_fishing.IsMinigameActive)
            return;

        if (UnityBridge.DrawButton(
            "AUTO PESCA [P]: " + (_fishing.Enabled ? "ON" : "OFF"),
            250f,
            44f))
        {
            _fishing.Toggle();
        }
    }

    public override void OnDeinitializeMelon()
    {
        _streaming.Stop();
    }

    private void TryRegisterSettings()
    {
        if (_msmReady || _streamSkip == null)
            return;

        try
        {
            var msm = RuntimeReflect.FindType("ModSettingsMenu.MSM");
            var panel = RuntimeReflect.FindType("ModSettingsMenu.PanelSide");

            if (msm == null || panel == null)
                return;

            var register = msm.GetMethods(BindingFlags.Public | BindingFlags.Static)
                .FirstOrDefault(m => m.Name == "RegisterMod" && m.GetParameters().Length == 2);

            register?.Invoke(null, new object[] { "solAutomation", "Sol Automation" });

            object left = Enum.Parse(panel, "LeftPanel");
            Func<bool> getter = () => _streamSkip.Value;
            Action<bool> setter = value =>
            {
                _streamSkip.Value = value;
                _prefs.SaveToFile(true);
                if (!value)
                    _streaming.Stop();
            };

            var candidates = msm.GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Where(m => m.Name == "AddCheckbox")
                .OrderByDescending(m => m.GetParameters().Length)
                .ToArray();

            foreach (var method in candidates)
            {
                var p = method.GetParameters();

                try
                {
                    if (p.Length == 6)
                    {
                        method.Invoke(null, new object[]
                        {
                            "solAutomation",
                            left,
                            "Pular streaming automaticamente",
                            getter,
                            setter,
                            "Acelera cenas sexuais durante streaming e para no limite seguro de 10% de fome/energia."
                        });
                        _msmReady = true;
                        break;
                    }

                    if (p.Length == 5)
                    {
                        method.Invoke(null, new object[]
                        {
                            "solAutomation",
                            left,
                            "Pular streaming automaticamente",
                            getter,
                            setter
                        });
                        _msmReady = true;
                        break;
                    }
                }
                catch
                {
                }
            }

            if (_msmReady)
                MelonLogger.Msg("Opção de streaming registrada no Mod Settings Menu.");
        }
        catch (Exception ex)
        {
            MelonLogger.Warning("Falha ao registrar opções: " + ex.Message);
        }
    }
}

internal sealed class StreamingAutomation
{
    private const float MinResource = 0.10f;
    private const float GuardResource = 0.115f;
    private const float FastForward = 20f;

    public bool Enabled;

    private object _gameVariables;
    private object _brain;
    private bool _isStreaming;
    private bool _fast;
    private float _oldScale = 1f;
    private double _nextScan;

    public void Update()
    {
        if (!Enabled)
        {
            Stop();
            return;
        }

        double now = UnityBridge.UnscaledTime;

        if (now >= _nextScan)
        {
            _nextScan = now + 0.35;
            _gameVariables = GameState.FindGameVariables();
            _brain = GameState.FindModelBrain();
            _isStreaming = GameState.DetectStreaming(_gameVariables);
        }

        if (_gameVariables == null ||
            _brain == null ||
            !_isStreaming ||
            !GameState.IsSexScene(_brain))
        {
            Stop();
            return;
        }

        bool hasStamina = RuntimeReflect.TryReadFloat(
            _gameVariables,
            out float stamina,
            "_stamina", "stamina", "Stamina");

        bool hasSatiation = RuntimeReflect.TryReadFloat(
            _gameVariables,
            out float satiation,
            "_satiation", "satiation", "Satiation");

        bool hasCum = RuntimeReflect.TryReadFloat(
            _gameVariables,
            out float currentCum,
            "CurrentCum", "currentCum");

        if (hasCum && currentCum < 5f)
        {
            Stop();
            return;
        }

        if ((hasStamina && stamina <= GuardResource) ||
            (hasSatiation && satiation <= GuardResource))
        {
            if (hasStamina && stamina < MinResource)
                RuntimeReflect.TryWriteFloat(
                    _gameVariables,
                    MinResource,
                    "_stamina", "stamina", "Stamina");

            if (hasSatiation && satiation < MinResource)
                RuntimeReflect.TryWriteFloat(
                    _gameVariables,
                    MinResource,
                    "_satiation", "satiation", "Satiation");

            Stop();
            return;
        }

        Start();
    }

    private void Start()
    {
        if (!_fast)
        {
            _oldScale = UnityBridge.TimeScale;
            _fast = true;
            MelonLogger.Msg("Streaming: avanço automático ON.");
        }

        UnityBridge.TimeScale = FastForward;
    }

    public void Stop()
    {
        if (!_fast)
            return;

        UnityBridge.TimeScale = Math.Max(0.01f, _oldScale);
        _fast = false;
        MelonLogger.Msg("Streaming: avanço automático encerrado.");
    }
}

internal sealed class FishingAutomation
{
    public bool Enabled { get; private set; }
    public bool IsMinigameActive => _roots.Count > 0;

    private readonly List<object> _roots = new();
    private double _nextScan;
    private double _nextContinue;
    private double _lastSeen;

    public void Toggle()
    {
        Enabled = !Enabled;
        MelonLogger.Msg("Auto pesca: " + (Enabled ? "ON" : "OFF"));
    }

    public void Update()
    {
        double now = UnityBridge.UnscaledTime;

        if (now >= _nextScan)
        {
            _nextScan = now + 0.20;
            Scan();
        }

        if (IsMinigameActive)
            _lastSeen = now;
        else if (now - _lastSeen > 2.5)
            Enabled = false;

        if (!Enabled || !IsMinigameActive)
            return;

        foreach (var root in _roots.ToArray())
        {
            if (root == null)
                continue;

            KeepBarOnFish(root);
            MaximizeProgress(root);
            TryPerfectMethods(root);
        }

        if (now >= _nextContinue)
        {
            _nextContinue = now + 0.30;
            ClickFishingContinuationButtons();
        }
    }

    private void Scan()
    {
        _roots.Clear();

        var mono = RuntimeReflect.FindType("UnityEngine.MonoBehaviour");
        if (mono == null)
            return;

        foreach (var obj in UnityBridge.FindAll(mono))
        {
            if (!UnityBridge.IsActiveComponent(obj))
                continue;

            string id = UnityBridge.Identity(obj).ToLowerInvariant();

            if (!id.Contains("fish"))
                continue;

            bool likely =
                id.Contains("minigame") ||
                id.Contains("reel") ||
                id.Contains("catch");

            if (!likely)
            {
                likely = RuntimeReflect.GetReadableMembers(obj.GetType()).Any(m =>
                {
                    string n = m.Name.ToLowerInvariant();
                    return n.Contains("catchprogress") ||
                           n.Contains("fishprogress") ||
                           n.Contains("reelprogress") ||
                           n.Contains("captureprogress") ||
                           n.Contains("successprogress");
                });
            }

            if (likely)
                _roots.Add(obj);
        }
    }

    private static void KeepBarOnFish(object root)
    {
        object transform = UnityBridge.GetTransform(root);
        if (transform == null)
            return;

        object fish = null;
        object bar = null;

        foreach (var t in UnityBridge.Descendants(transform))
        {
            string n = UnityBridge.ObjectName(t).ToLowerInvariant();

            if (fish == null &&
                n.Contains("fish") &&
                !n.Contains("bar") &&
                !n.Contains("button"))
            {
                fish = t;
            }

            if (bar == null &&
                (n.Contains("white") ||
                 n.Contains("catchbar") ||
                 n.Contains("catch_bar") ||
                 n.Contains("reelzone") ||
                 n.Contains("reel_zone") ||
                 n == "bar"))
            {
                bar = t;
            }
        }

        if (fish == null || bar == null)
            return;

        if (TryMatchY(bar, fish, "anchoredPosition"))
            return;

        TryMatchY(bar, fish, "localPosition");
    }

    private static bool TryMatchY(object bar, object fish, string positionName)
    {
        if (!RuntimeReflect.TryReadObject(bar, out object barPos, positionName) ||
            !RuntimeReflect.TryReadObject(fish, out object fishPos, positionName) ||
            barPos == null ||
            fishPos == null)
        {
            return false;
        }

        if (!RuntimeReflect.TryReadFloat(fishPos, out float fishY, "y"))
            return false;

        if (!RuntimeReflect.TryWriteFloat(barPos, fishY, "y"))
            return false;

        return RuntimeReflect.TryWriteObject(bar, barPos, positionName);
    }

    private static void MaximizeProgress(object root)
    {
        foreach (var member in RuntimeReflect.GetReadableMembers(root.GetType()))
        {
            string n = member.Name.ToLowerInvariant();

            bool target =
                n == "progress" ||
                n.Contains("catchprogress") ||
                n.Contains("fishprogress") ||
                n.Contains("reelprogress") ||
                n.Contains("captureprogress") ||
                n.Contains("successprogress");

            if (!target)
                continue;

            object value;
            try
            {
                value = RuntimeReflect.ReadMember(root, member);
            }
            catch
            {
                continue;
            }

            if (value == null)
                continue;

            string typeName = value.GetType().FullName ?? "";

            if (typeName.EndsWith(".Slider", StringComparison.Ordinal))
            {
                if (RuntimeReflect.TryReadFloat(value, out float max, "maxValue"))
                    RuntimeReflect.TryWriteFloat(value, max, "value");
                continue;
            }

            if (typeName.EndsWith(".Image", StringComparison.Ordinal))
            {
                RuntimeReflect.TryWriteFloat(value, 1f, "fillAmount");
                continue;
            }

            if (!RuntimeReflect.TryConvertFloat(value, out float current))
                continue;

            float targetValue =
                current <= 1.5f ? 1f :
                current <= 100f ? 100f :
                current;

            RuntimeReflect.TryWriteMemberFloat(root, member, targetValue);
        }
    }

    private static void TryPerfectMethods(object root)
    {
        MethodInfo[] methods;

        try
        {
            methods = root.GetType().GetMethods(
                BindingFlags.Instance |
                BindingFlags.Public |
                BindingFlags.NonPublic);
        }
        catch
        {
            return;
        }

        foreach (var method in methods)
        {
            if (method.GetParameters().Length != 0)
                continue;

            string n = method.Name.ToLowerInvariant();

            if (!(n.Contains("perfect") &&
                  (n.Contains("click") ||
                   n.Contains("hit") ||
                   n.Contains("catch"))))
            {
                continue;
            }

            try
            {
                method.Invoke(root, null);
            }
            catch
            {
            }
        }
    }

    private static void ClickFishingContinuationButtons()
    {
        var buttonType = RuntimeReflect.FindType("UnityEngine.UI.Button");
        if (buttonType == null)
            return;

        foreach (var button in UnityBridge.FindAll(buttonType))
        {
            if (!UnityBridge.IsActiveComponent(button))
                continue;

            if (RuntimeReflect.TryReadObject(
                    button,
                    out object interactable,
                    "interactable") &&
                interactable is bool canClick &&
                !canClick)
            {
                continue;
            }

            string label = UnityBridge.ButtonText(button);
            string id = (UnityBridge.Identity(button) + " " + label).ToLowerInvariant();

            if (!id.Contains("fish"))
                continue;

            if (id.Contains("exit") ||
                id.Contains("leave") ||
                id.Contains("quit") ||
                id.Contains("cancel"))
            {
                continue;
            }

            if (id.Contains("cast") ||
                id.Contains("again") ||
                id.Contains("continue") ||
                id.Contains("retry"))
            {
                UnityBridge.ClickButton(button);
            }
        }
    }
}

internal static class GameState
{
    public static object FindGameVariables()
    {
        var gs = RuntimeReflect.FindType("Il2Cpp.GameScript")
              ?? RuntimeReflect.FindTypeBySimpleName("GameScript");

        if (gs == null)
            return null;

        object instance = RuntimeReflect.ReadStaticMember(gs, "Instance", "instance");

        if (instance == null)
            instance = UnityBridge.FindAll(gs).FirstOrDefault();

        if (instance == null)
            return null;

        RuntimeReflect.TryReadObject(
            instance,
            out object vars,
            "GameVariables", "gameVariables");

        return vars;
    }

    public static object FindModelBrain()
    {
        var brainType = RuntimeReflect.FindType("Il2Cpp.ModelBrain")
                     ?? RuntimeReflect.FindTypeBySimpleName("ModelBrain");

        if (brainType == null)
            return null;

        var all = UnityBridge.FindAll(brainType).ToArray();

        return all.FirstOrDefault(x =>
                   UnityBridge.ObjectName(x)
                       .Contains("bot", StringComparison.OrdinalIgnoreCase))
               ?? all.FirstOrDefault();
    }

    public static bool IsSexScene(object brain)
    {
        if (brain == null)
            return false;

        if (!RuntimeReflect.TryReadObject(
                brain,
                out object state,
                "CurrentState", "currentState") ||
            state == null)
        {
            return false;
        }

        string n = state.GetType().FullName?.ToLowerInvariant() ?? "";

        return n.Contains("fuck") ||
               n.Contains("cowgirl") ||
               n.Contains("shower") ||
               n.Contains("missionary") ||
               n.Contains("doggy") ||
               n.Contains("blowjob") ||
               n.Contains("sex");
    }

    public static bool DetectStreaming(object vars)
    {
        if (vars != null)
        {
            foreach (var m in RuntimeReflect.GetReadableMembers(vars.GetType()))
            {
                string n = m.Name.ToLowerInvariant();

                if (!(n.Contains("stream") ||
                      n.Contains("cocktwitch")))
                {
                    continue;
                }

                object v;

                try
                {
                    v = RuntimeReflect.ReadMember(vars, m);
                }
                catch
                {
                    continue;
                }

                if (v is bool b && b)
                    return true;
            }
        }

        var mono = RuntimeReflect.FindType("UnityEngine.MonoBehaviour");

        if (mono == null)
            return false;

        foreach (var obj in UnityBridge.FindAll(mono))
        {
            if (!UnityBridge.IsActiveComponent(obj))
                continue;

            string id = UnityBridge.Identity(obj).ToLowerInvariant();

            if (id.Contains("cocktwitch") ||
                id.Contains("streaming") ||
                id.Contains("streamcontroller"))
            {
                return true;
            }
        }

        return false;
    }
}

internal static class UnityBridge
{
    public static double UnscaledTime
    {
        get
        {
            if (RuntimeReflect.TryReadStaticFloat(
                    "UnityEngine.Time",
                    out float value,
                    "unscaledTime"))
            {
                return value;
            }

            return Environment.TickCount64 / 1000.0;
        }
    }

    public static float TimeScale
    {
        get
        {
            if (RuntimeReflect.TryReadStaticFloat(
                    "UnityEngine.Time",
                    out float value,
                    "timeScale"))
            {
                return value;
            }

            return 1f;
        }
        set
        {
            RuntimeReflect.TryWriteStaticFloat(
                "UnityEngine.Time",
                value,
                "timeScale");
        }
    }

    public static bool KeyPressed(string keyName)
    {
        try
        {
            var input = RuntimeReflect.FindType("UnityEngine.Input");
            var keyCode = RuntimeReflect.FindType("UnityEngine.KeyCode");

            if (input == null || keyCode == null)
                return false;

            object key = Enum.Parse(keyCode, keyName, true);

            var method = input.GetMethods(
                    BindingFlags.Public |
                    BindingFlags.Static)
                .FirstOrDefault(m =>
                    m.Name == "GetKeyDown" &&
                    m.GetParameters().Length == 1 &&
                    m.GetParameters()[0].ParameterType == keyCode);

            if (method == null)
                return false;

            object result = method.Invoke(null, new[] { key });
            return result is bool b && b;
        }
        catch
        {
            return false;
        }
    }

    public static bool DrawButton(string text, float width, float height)
    {
        try
        {
            var gui = RuntimeReflect.FindType("UnityEngine.GUI");
            var rectType = RuntimeReflect.FindType("UnityEngine.Rect");
            var screen = RuntimeReflect.FindType("UnityEngine.Screen");

            if (gui == null || rectType == null || screen == null)
                return false;

            float screenWidth = 1280f;

            if (RuntimeReflect.TryReadStaticFloat(
                    "UnityEngine.Screen",
                    out float w,
                    "width"))
            {
                screenWidth = w;
            }

            float x = screenWidth - width - 20f;
            float y = 20f;

            object rect;

            try
            {
                rect = Activator.CreateInstance(
                    rectType,
                    new object[] { x, y, width, height });
            }
            catch
            {
                rect = Activator.CreateInstance(rectType);

                RuntimeReflect.TryWriteFloat(rect, x, "x");
                RuntimeReflect.TryWriteFloat(rect, y, "y");
                RuntimeReflect.TryWriteFloat(rect, width, "width");
                RuntimeReflect.TryWriteFloat(rect, height, "height");
            }

            foreach (var method in gui.GetMethods(
                         BindingFlags.Public |
                         BindingFlags.Static)
                     .Where(m => m.Name == "Button"))
            {
                var p = method.GetParameters();

                if (p.Length != 2 ||
                    p[0].ParameterType != rectType ||
                    p[1].ParameterType != typeof(string))
                {
                    continue;
                }

                object result = method.Invoke(
                    null,
                    new object[] { rect, text });

                return result is bool b && b;
            }
        }
        catch
        {
        }

        return false;
    }

    public static IEnumerable<object> FindAll(Type targetType)
    {
        if (targetType == null)
            yield break;

        object result = null;

        try
        {
            var resources = RuntimeReflect.FindType("UnityEngine.Resources");

            if (resources != null)
            {
                foreach (var method in resources.GetMethods(
                             BindingFlags.Public |
                             BindingFlags.Static)
                         .Where(m => m.Name == "FindObjectsOfTypeAll"))
                {
                    try
                    {
                        if (method.IsGenericMethodDefinition &&
                            method.GetGenericArguments().Length == 1 &&
                            method.GetParameters().Length == 0)
                        {
                            result = method
                                .MakeGenericMethod(targetType)
                                .Invoke(null, null);

                            if (result != null)
                                break;
                        }

                        var p = method.GetParameters();

                        if (p.Length == 1 &&
                            p[0].ParameterType == typeof(Type))
                        {
                            result = method.Invoke(
                                null,
                                new object[] { targetType });

                            if (result != null)
                                break;
                        }
                    }
                    catch
                    {
                    }
                }
            }
        }
        catch
        {
        }

        if (result is IEnumerable enumerable)
        {
            foreach (var item in enumerable)
            {
                if (item != null)
                    yield return item;
            }
        }
    }

    public static bool IsActiveComponent(object component)
    {
        if (component == null)
            return false;

        if (!RuntimeReflect.TryReadObject(
                component,
                out object gameObject,
                "gameObject") ||
            gameObject == null)
        {
            return true;
        }

        if (RuntimeReflect.TryReadObject(
                gameObject,
                out object active,
                "activeInHierarchy") &&
            active is bool b)
        {
            return b;
        }

        return true;
    }

    public static string Identity(object component)
    {
        if (component == null)
            return "";

        string typeName = component.GetType().FullName ?? "";
        string own = ObjectName(component);
        string go = "";

        if (RuntimeReflect.TryReadObject(
                component,
                out object gameObject,
                "gameObject") &&
            gameObject != null)
        {
            go = ObjectName(gameObject);
        }

        object transform = GetTransform(component);

        return typeName + " " +
               own + " " +
               go + " " +
               TransformPath(transform);
    }

    public static object GetTransform(object component)
    {
        if (component == null)
            return null;

        RuntimeReflect.TryReadObject(
            component,
            out object transform,
            "transform");

        return transform;
    }

    public static string ObjectName(object obj)
    {
        if (obj == null)
            return "";

        if (RuntimeReflect.TryReadObject(
                obj,
                out object name,
                "name") &&
            name != null)
        {
            return name.ToString() ?? "";
        }

        return "";
    }

    public static IEnumerable<object> Descendants(object root)
    {
        if (root == null)
            yield break;

        var stack = new Stack<object>();
        stack.Push(root);

        int guard = 0;

        while (stack.Count > 0 && guard++ < 500)
        {
            object current = stack.Pop();
            yield return current;

            if (!RuntimeReflect.TryReadFloat(
                    current,
                    out float countValue,
                    "childCount"))
            {
                continue;
            }

            int count = Math.Max(0, (int)countValue);

            var getChild = current.GetType()
                .GetMethods(
                    BindingFlags.Instance |
                    BindingFlags.Public |
                    BindingFlags.NonPublic)
                .FirstOrDefault(m =>
                    m.Name == "GetChild" &&
                    m.GetParameters().Length == 1);

            if (getChild == null)
                continue;

            for (int i = 0; i < count; i++)
            {
                try
                {
                    object child = getChild.Invoke(
                        current,
                        new object[] { i });

                    if (child != null)
                        stack.Push(child);
                }
                catch
                {
                }
            }
        }
    }

    public static string TransformPath(object transform)
    {
        if (transform == null)
            return "";

        string path = ObjectName(transform);
        object current = transform;

        for (int i = 0; i < 10; i++)
        {
            if (!RuntimeReflect.TryReadObject(
                    current,
                    out object parent,
                    "parent") ||
                parent == null)
            {
                break;
            }

            path = ObjectName(parent) + "/" + path;
            current = parent;
        }

        return path;
    }

    public static string ButtonText(object button)
    {
        try
        {
            var textType = RuntimeReflect.FindType("UnityEngine.UI.Text");

            if (textType == null)
                return "";

            var methods = button.GetType().GetMethods(
                    BindingFlags.Instance |
                    BindingFlags.Public |
                    BindingFlags.NonPublic)
                .Where(m =>
                    m.Name == "GetComponentInChildren" &&
                    m.IsGenericMethodDefinition &&
                    m.GetGenericArguments().Length == 1)
                .ToArray();

            foreach (var method in methods)
            {
                try
                {
                    var gm = method.MakeGenericMethod(textType);
                    var p = gm.GetParameters();

                    object textObj = p.Length switch
                    {
                        0 => gm.Invoke(button, null),
                        1 when p[0].ParameterType == typeof(bool)
                            => gm.Invoke(button, new object[] { true }),
                        _ => null
                    };

                    if (textObj == null)
                        continue;

                    if (RuntimeReflect.TryReadObject(
                            textObj,
                            out object text,
                            "text") &&
                        text != null)
                    {
                        return text.ToString() ?? "";
                    }
                }
                catch
                {
                }
            }
        }
        catch
        {
        }

        return "";
    }

    public static void ClickButton(object button)
    {
        if (button == null)
            return;

        if (!RuntimeReflect.TryReadObject(
                button,
                out object onClick,
                "onClick") ||
            onClick == null)
        {
            return;
        }

        var invoke = onClick.GetType().GetMethods(
                BindingFlags.Instance |
                BindingFlags.Public |
                BindingFlags.NonPublic)
            .FirstOrDefault(m =>
                m.Name == "Invoke" &&
                m.GetParameters().Length == 0);

        if (invoke == null)
            return;

        try
        {
            invoke.Invoke(onClick, null);
        }
        catch
        {
        }
    }
}

internal static class RuntimeReflect
{
    private const BindingFlags All =
        BindingFlags.Instance |
        BindingFlags.Static |
        BindingFlags.Public |
        BindingFlags.NonPublic;

    private static readonly Dictionary<string, Type> TypeCache =
        new(StringComparer.Ordinal);

    public static Type FindType(string fullName)
    {
        if (string.IsNullOrWhiteSpace(fullName))
            return null;

        if (TypeCache.TryGetValue(fullName, out var cached))
            return cached;

        foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
        {
            Type type = null;

            try
            {
                type = assembly.GetType(
                    fullName,
                    throwOnError: false,
                    ignoreCase: false);
            }
            catch
            {
            }

            if (type == null)
                continue;

            TypeCache[fullName] = type;
            return type;
        }

        return null;
    }

    public static Type FindTypeBySimpleName(string simpleName)
    {
        if (string.IsNullOrWhiteSpace(simpleName))
            return null;

        string key = "#simple:" + simpleName;

        if (TypeCache.TryGetValue(key, out var cached))
            return cached;

        foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
        {
            Type[] types;

            try
            {
                types = assembly.GetTypes();
            }
            catch (ReflectionTypeLoadException ex)
            {
                types = ex.Types
                    .Where(t => t != null)
                    .Cast<Type>()
                    .ToArray();
            }
            catch
            {
                continue;
            }

            var match = types.FirstOrDefault(t =>
                string.Equals(
                    t.Name,
                    simpleName,
                    StringComparison.Ordinal));

            if (match == null)
                continue;

            TypeCache[key] = match;
            return match;
        }

        return null;
    }

    public static IEnumerable<MemberInfo> GetReadableMembers(Type type)
    {
        if (type == null)
            yield break;

        FieldInfo[] fields = Array.Empty<FieldInfo>();
        PropertyInfo[] properties = Array.Empty<PropertyInfo>();

        try
        {
            fields = type.GetFields(All);
        }
        catch
        {
        }

        try
        {
            properties = type.GetProperties(All);
        }
        catch
        {
        }

        foreach (var field in fields)
            yield return field;

        foreach (var property in properties)
        {
            if (property.CanRead &&
                property.GetIndexParameters().Length == 0)
            {
                yield return property;
            }
        }
    }

    public static object ReadMember(object target, MemberInfo member)
    {
        if (member is FieldInfo field)
            return field.GetValue(field.IsStatic ? null : target);

        if (member is PropertyInfo property)
        {
            MethodInfo getter = property.GetGetMethod(true);
            return property.GetValue(
                getter?.IsStatic == true ? null : target);
        }

        return null;
    }

    public static object ReadStaticMember(
        Type type,
        params string[] names)
    {
        if (type == null)
            return null;

        foreach (var member in GetReadableMembers(type))
        {
            if (!names.Any(n =>
                    string.Equals(
                        n,
                        member.Name,
                        StringComparison.OrdinalIgnoreCase)))
            {
                continue;
            }

            try
            {
                return ReadMember(null, member);
            }
            catch
            {
            }
        }

        return null;
    }

    public static bool TryReadObject(
        object target,
        out object value,
        params string[] names)
    {
        value = null;

        if (target == null)
            return false;

        foreach (var member in GetReadableMembers(target.GetType()))
        {
            if (!names.Any(n =>
                    string.Equals(
                        n,
                        member.Name,
                        StringComparison.OrdinalIgnoreCase)))
            {
                continue;
            }

            try
            {
                value = ReadMember(target, member);
                return true;
            }
            catch
            {
            }
        }

        return false;
    }

    public static bool TryWriteObject(
        object target,
        object value,
        params string[] names)
    {
        if (target == null)
            return false;

        foreach (var member in GetReadableMembers(target.GetType()))
        {
            if (!names.Any(n =>
                    string.Equals(
                        n,
                        member.Name,
                        StringComparison.OrdinalIgnoreCase)))
            {
                continue;
            }

            try
            {
                if (member is FieldInfo field &&
                    !field.IsInitOnly)
                {
                    field.SetValue(
                        field.IsStatic ? null : target,
                        value);
                    return true;
                }

                if (member is PropertyInfo property &&
                    property.CanWrite)
                {
                    MethodInfo setter = property.GetSetMethod(true);

                    property.SetValue(
                        setter?.IsStatic == true ? null : target,
                        value);
                    return true;
                }
            }
            catch
            {
            }
        }

        return false;
    }

    public static bool TryReadFloat(
        object target,
        out float result,
        params string[] names)
    {
        result = 0f;

        if (!TryReadObject(
                target,
                out object value,
                names))
        {
            return false;
        }

        return TryConvertFloat(value, out result);
    }

    public static bool TryReadStaticFloat(
        string typeName,
        out float result,
        params string[] names)
    {
        result = 0f;

        Type type = FindType(typeName);

        if (type == null)
            return false;

        object value = ReadStaticMember(type, names);

        return TryConvertFloat(value, out result);
    }

    public static bool TryWriteStaticFloat(
        string typeName,
        float value,
        params string[] names)
    {
        Type type = FindType(typeName);

        if (type == null)
            return false;

        foreach (var member in GetReadableMembers(type))
        {
            if (!names.Any(n =>
                    string.Equals(
                        n,
                        member.Name,
                        StringComparison.OrdinalIgnoreCase)))
            {
                continue;
            }

            if (TryWriteMemberFloat(null, member, value))
                return true;
        }

        return false;
    }

    public static bool TryWriteFloat(
        object target,
        float value,
        params string[] names)
    {
        if (target == null)
            return false;

        foreach (var member in GetReadableMembers(target.GetType()))
        {
            if (!names.Any(n =>
                    string.Equals(
                        n,
                        member.Name,
                        StringComparison.OrdinalIgnoreCase)))
            {
                continue;
            }

            if (TryWriteMemberFloat(target, member, value))
                return true;
        }

        return false;
    }

    public static bool TryWriteMemberFloat(
        object target,
        MemberInfo member,
        float value)
    {
        try
        {
            if (member is FieldInfo field &&
                !field.IsInitOnly)
            {
                field.SetValue(
                    field.IsStatic ? null : target,
                    ConvertNumber(value, field.FieldType));

                return true;
            }

            if (member is PropertyInfo property &&
                property.CanWrite)
            {
                MethodInfo setter = property.GetSetMethod(true);

                property.SetValue(
                    setter?.IsStatic == true ? null : target,
                    ConvertNumber(
                        value,
                        property.PropertyType));

                return true;
            }
        }
        catch
        {
        }

        return false;
    }

    public static bool TryConvertFloat(
        object value,
        out float result)
    {
        result = 0f;

        if (value == null)
            return false;

        try
        {
            result = Convert.ToSingle(value);
            return !float.IsNaN(result) &&
                   !float.IsInfinity(result);
        }
        catch
        {
            return false;
        }
    }

    private static object ConvertNumber(
        float value,
        Type type)
    {
        if (type == typeof(float))
            return value;

        if (type == typeof(double))
            return (double)value;

        if (type == typeof(int))
            return (int)value;

        if (type == typeof(long))
            return (long)value;

        if (type == typeof(short))
            return (short)value;

        if (type == typeof(byte))
            return (byte)value;

        return Convert.ChangeType(value, type);
    }
}
