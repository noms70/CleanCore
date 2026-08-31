import { useEffect, useState } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Slider } from "@/components/ui/slider";
import {
  Settings as SettingsIcon,
  Brain,
  Save,
  Sun,
  Moon,
  Palette,
  Upload,
  RefreshCw,
} from "lucide-react";
import { db } from "@/firebase";
import { doc, onSnapshot, setDoc, serverTimestamp } from "firebase/firestore";
import { toast } from "sonner";

interface SettingsState {
  orgName: string;
  timezone: string;
  dateFormat: string;
  language: string;
  warningThreshold: number;
  criticalThreshold: number;
  modelVersion: string;
  predictionInterval: string;
  confidenceThreshold: number;
}

const defaultSettings: SettingsState = {
  orgName: "Clean Core Municipal",
  timezone: "utc+5",
  dateFormat: "mdy",
  language: "en",
  warningThreshold: 70,
  criticalThreshold: 90,
  modelVersion: "v2.3",
  predictionInterval: "5",
  confidenceThreshold: 75,
};

function applyTheme(mode: "dark" | "light") {
  const html = document.documentElement;
  if (mode === "light") {
    html.classList.remove("dark");
    html.classList.add("light");
  } else {
    html.classList.remove("light");
    html.classList.add("dark");
  }
  localStorage.setItem("theme", mode);
}

const BACKEND = import.meta.env.VITE_BACKEND_URL ?? "";

export default function Settings() {
  const [settings, setSettings] = useState<SettingsState>(defaultSettings);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [isDark, setIsDark] = useState(
    () => (localStorage.getItem("theme") ?? "dark") !== "light"
  );

  // Model management state
  const [fillModelVersion, setFillModelVersion]   = useState<string>("—");
  const [wasteModelVersion, setWasteModelVersion] = useState<string>("—");
  const [lastModelUpdate, setLastModelUpdate]     = useState<string>("—");
  const [fillFile, setFillFile]   = useState<File | null>(null);
  const [wasteFile, setWasteFile] = useState<File | null>(null);
  const [fillTag, setFillTag]     = useState("");
  const [wasteTag, setWasteTag]   = useState("");
  const [uploading, setUploading] = useState<"fill" | "waste" | "reload" | null>(null);
  const [confirmReload, setConfirmReload] = useState(false);

  const handleThemeToggle = (checked: boolean) => {
    const mode = checked ? "dark" : "light";
    setIsDark(checked);
    applyTheme(mode);
  };

  useEffect(() => {
    const settingsRef = doc(db, "settings", "main");
    const unsub = onSnapshot(
      settingsRef,
      (snap) => {
        if (snap.exists()) {
          const data = snap.data() as Partial<SettingsState> & Record<string, unknown>;
          setSettings({ ...defaultSettings, ...data });
          setFillModelVersion((data.fillModelVersion  as string) ?? "—");
          setWasteModelVersion((data.wasteModelVersion as string) ?? "—");
          const lu = data.lastModelUpdate as { seconds?: number } | null | undefined;
          if (lu?.seconds) {
            setLastModelUpdate(new Date(lu.seconds * 1000).toLocaleString("en-GB"));
          }
        }
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const update = <K extends keyof SettingsState>(key: K, value: SettingsState[K]) =>
    setSettings((s) => ({ ...s, [key]: value }));

  const handleSave = async () => {
    if (settings.warningThreshold >= settings.criticalThreshold) {
      toast.error("Warning threshold must be lower than critical threshold");
      return;
    }

    setSaving(true);
    try {
      // 1. Save non-threshold settings directly to Firestore.
      const { warningThreshold, criticalThreshold, ...nonThresholdSettings } = settings;
      await setDoc(
        doc(db, "settings", "main"),
        { ...nonThresholdSettings, updatedAt: serverTimestamp() },
        { merge: true }
      );

      // 2. Save thresholds via backend so it can recompute every bin's status
      //    AND auto-attach newly-critical bins to matching active routes in
      //    the same call.
      if (!BACKEND) {
        toast.error("VITE_BACKEND_URL not configured — thresholds not saved");
        return;
      }
      const res = await fetch(`${BACKEND}/admin/save-thresholds`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: JSON.stringify({
          warning_threshold:  warningThreshold,
          critical_threshold: criticalThreshold,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        toast.error(json.detail ?? "Failed to save thresholds");
        return;
      }
      const updated  = json.updated_bins ?? 0;
      const attached = json.auto_attached ?? 0;
      const notified = json.orphan_notified ?? 0;
      const parts = [`recomputed ${updated} bin${updated === 1 ? "" : "s"}`];
      if (attached > 0) {
        parts.push(`${attached} added to active route${attached === 1 ? "" : "s"}`);
      }
      if (notified > 0) {
        parts.push(`${notified} worker${notified === 1 ? "" : "s"} notified`);
      }
      toast.success(`Settings saved — ${parts.join(", ")}`);
    } catch (err) {
      const msg =
        err instanceof Error ? err.message : "Failed to save settings";
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  async function handleUploadModel(modelType: "fill" | "waste") {
    const file    = modelType === "fill" ? fillFile : wasteFile;
    const tag     = modelType === "fill" ? fillTag  : wasteTag;
    if (!file || !tag.trim()) {
      toast.error("Select a .pt file and enter a version tag");
      return;
    }
    setUploading(modelType);
    try {
      const fd = new FormData();
      fd.append("model_file",  file);
      fd.append("model_type",  modelType);
      fd.append("version_tag", tag.trim());
      const res = await fetch(`${BACKEND}/admin/upload-model`, {
        method: "POST",
        headers: { "ngrok-skip-browser-warning": "true" },
        body: fd,
      });
      const json = await res.json();
      if (res.ok && json.success) {
        toast.success(`${modelType} model uploaded — confidence: ${json.test_confidence}`);
        if (modelType === "fill") { setFillFile(null); setFillTag(""); }
        else                      { setWasteFile(null); setWasteTag(""); }
      } else {
        toast.error(json.detail ?? "Upload failed");
      }
    } catch {
      toast.error("Network error during upload");
    } finally {
      setUploading(null);
    }
  }

  async function handleReloadModels() {
    setUploading("reload");
    setConfirmReload(false);
    try {
      const res  = await fetch(`${BACKEND}/admin/reload-models`, {
        method: "POST",
        headers: { "ngrok-skip-browser-warning": "true" },
      });
      const json = await res.json();
      if (res.ok && json.success) toast.success("Models reloaded from disk");
      else toast.error("Reload failed");
    } catch {
      toast.error("Network error");
    } finally {
      setUploading(null);
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-card/10 to-background">
      <AdminHeader
        title="Settings"
        subtitle="Configure system preferences and notifications"
      />

      <div className="p-6">
        {loading ? (
          <div className="p-12 text-center text-muted-foreground">
            Loading settings...
          </div>
        ) : (
          <Tabs defaultValue="general" className="space-y-6">
            <TabsList className="bg-muted/50 border border-border">
              <TabsTrigger
                value="general"
                className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
              >
                <SettingsIcon className="h-4 w-4 mr-2" />
                General
              </TabsTrigger>
              <TabsTrigger
                value="ai"
                className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
              >
                <Brain className="h-4 w-4 mr-2" />
                AI Model
              </TabsTrigger>
              <TabsTrigger
                value="appearance"
                className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
              >
                <Palette className="h-4 w-4 mr-2" />
                Appearance
              </TabsTrigger>
            </TabsList>

            {/* General */}
            <TabsContent value="general" className="space-y-6">
              <Card className="bg-card border-border">
                <CardHeader>
                  <CardTitle className="text-foreground">
                    Collection Settings
                  </CardTitle>
                  <CardDescription className="text-muted-foreground">
                    Configure collection thresholds and schedules
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Label className="text-foreground">
                          Warning Fill Level Threshold
                        </Label>
                        <span className="text-primary font-medium">
                          {settings.warningThreshold}%
                        </span>
                      </div>
                      <Slider
                        value={[settings.warningThreshold]}
                        onValueChange={([v]) =>
                          update("warningThreshold", v)
                        }
                        max={100}
                        step={5}
                        className="[&>span]:bg-warning"
                      />
                    </div>
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Label className="text-foreground">
                          Critical Fill Level Threshold
                        </Label>
                        <span className="text-destructive font-medium">
                          {settings.criticalThreshold}%
                        </span>
                      </div>
                      <Slider
                        value={[settings.criticalThreshold]}
                        onValueChange={([v]) =>
                          update("criticalThreshold", v)
                        }
                        max={100}
                        step={5}
                        className="[&>span]:bg-destructive"
                      />
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            {/* AI Model */}
            <TabsContent value="ai" className="space-y-6">
              <Card className="bg-card border-border">
                <CardHeader>
                  <CardTitle className="text-foreground flex items-center gap-2">
                    <Brain className="h-5 w-5 text-primary" />
                    AI Model Configuration
                  </CardTitle>
                  <CardDescription className="text-muted-foreground">
                    Configure AI prediction model settings and thresholds
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="grid gap-4 md:grid-cols-2">
                    <div className="space-y-2">
                      <Label className="text-foreground">Model Version</Label>
                      <Select
                        value={settings.modelVersion}
                        onValueChange={(v) => update("modelVersion", v)}
                      >
                        <SelectTrigger className="bg-muted/50 border-border">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="v2.3">v2.3.1 (Current)</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label className="text-foreground">
                        Prediction Interval
                      </Label>
                      <Select
                        value={settings.predictionInterval}
                        onValueChange={(v) =>
                          update("predictionInterval", v)
                        }
                      >
                        <SelectTrigger className="bg-muted/50 border-border">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="5">Every 5 minutes</SelectItem>
                          <SelectItem value="10">Every 10 minutes</SelectItem>
                          <SelectItem value="15">Every 15 minutes</SelectItem>
                          <SelectItem value="30">Every 30 minutes</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Label className="text-foreground">
                          Minimum Confidence Threshold
                        </Label>
                        <span className="text-primary font-medium">
                          {settings.confidenceThreshold}%
                        </span>
                      </div>
                      <Slider
                        value={[settings.confidenceThreshold]}
                        onValueChange={([v]) =>
                          update("confidenceThreshold", v)
                        }
                        max={100}
                        step={5}
                      />
                      <p className="text-xs text-muted-foreground">
                        Predictions below this threshold will be flagged for
                        manual review
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Model Management — upload + reload */}
              <Card className="bg-card border-border">
                <CardHeader>
                  <CardTitle className="text-foreground flex items-center gap-2">
                    <Upload className="h-5 w-5 text-primary" />
                    Model Management
                  </CardTitle>
                  <CardDescription className="text-muted-foreground">
                    Upload new .pt weights or reload from disk. The backend runs a test inference before promoting.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  {/* Current version info */}
                  <div className="grid gap-3 md:grid-cols-3 text-sm p-4 rounded-lg bg-muted/40 border border-border">
                    <div><span className="text-muted-foreground">Fill Model:</span> <span className="font-medium text-foreground">{fillModelVersion}</span></div>
                    <div><span className="text-muted-foreground">Waste Model:</span> <span className="font-medium text-foreground">{wasteModelVersion}</span></div>
                    <div><span className="text-muted-foreground">Last Updated:</span> <span className="font-medium text-foreground">{lastModelUpdate}</span></div>
                  </div>

                  {/* Upload Fill Model */}
                  <div className="space-y-3 border border-border/50 rounded-lg p-4">
                    <Label className="text-foreground font-medium">Upload Fill Model</Label>
                    <div className="flex flex-wrap gap-2">
                      <div className="flex-1 min-w-[180px]">
                        <input
                          type="file" accept=".pt"
                          onChange={(e) => setFillFile(e.target.files?.[0] ?? null)}
                          className="block w-full text-sm text-muted-foreground file:mr-3 file:rounded file:border-0 file:bg-primary/10 file:px-3 file:py-1.5 file:text-xs file:font-medium file:text-primary hover:file:bg-primary/20"
                        />
                      </div>
                      <Input placeholder="Version tag e.g. v2-industrial" value={fillTag}
                        onChange={(e) => setFillTag(e.target.value)} className="w-52" />
                      <Button disabled={!fillFile || !fillTag.trim() || uploading !== null}
                        onClick={() => handleUploadModel("fill")} className="shrink-0">
                        {uploading === "fill" ? <RefreshCw className="w-4 h-4 animate-spin mr-2" /> : <Upload className="w-4 h-4 mr-2" />}
                        {uploading === "fill" ? "Uploading…" : "Upload & Swap"}
                      </Button>
                    </div>
                    {fillFile && <p className="text-xs text-muted-foreground">Selected: {fillFile.name} ({(fillFile.size / 1048576).toFixed(1)} MB)</p>}
                  </div>

                  {/* Upload Waste Model */}
                  <div className="space-y-3 border border-border/50 rounded-lg p-4">
                    <Label className="text-foreground font-medium">Upload Waste Model</Label>
                    <div className="flex flex-wrap gap-2">
                      <div className="flex-1 min-w-[180px]">
                        <input
                          type="file" accept=".pt"
                          onChange={(e) => setWasteFile(e.target.files?.[0] ?? null)}
                          className="block w-full text-sm text-muted-foreground file:mr-3 file:rounded file:border-0 file:bg-primary/10 file:px-3 file:py-1.5 file:text-xs file:font-medium file:text-primary hover:file:bg-primary/20"
                        />
                      </div>
                      <Input placeholder="Version tag e.g. v1.2" value={wasteTag}
                        onChange={(e) => setWasteTag(e.target.value)} className="w-52" />
                      <Button disabled={!wasteFile || !wasteTag.trim() || uploading !== null}
                        onClick={() => handleUploadModel("waste")} className="shrink-0">
                        {uploading === "waste" ? <RefreshCw className="w-4 h-4 animate-spin mr-2" /> : <Upload className="w-4 h-4 mr-2" />}
                        {uploading === "waste" ? "Uploading…" : "Upload & Swap"}
                      </Button>
                    </div>
                    {wasteFile && <p className="text-xs text-muted-foreground">Selected: {wasteFile.name} ({(wasteFile.size / 1048576).toFixed(1)} MB)</p>}
                  </div>

                  {/* Reload from disk */}
                  <div className="flex items-center justify-between p-4 border border-border/50 rounded-lg">
                    <div>
                      <p className="text-sm font-medium text-foreground">Reload Models from Disk</p>
                      <p className="text-xs text-muted-foreground">Hot-reloads current .pt files without uploading a new file</p>
                    </div>
                    {confirmReload ? (
                      <div className="flex gap-2">
                        <Button size="sm" variant="outline" onClick={() => setConfirmReload(false)}>Cancel</Button>
                        <Button size="sm" disabled={uploading !== null} onClick={handleReloadModels}>
                          {uploading === "reload" ? <RefreshCw className="w-3 h-3 animate-spin mr-1" /> : null}
                          Confirm
                        </Button>
                      </div>
                    ) : (
                      <Button size="sm" variant="outline" disabled={uploading !== null} onClick={() => setConfirmReload(true)}>
                        <RefreshCw className="w-4 h-4 mr-2" /> Reload
                      </Button>
                    )}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            {/* Appearance */}
            <TabsContent value="appearance" className="space-y-6">
              <Card className="bg-card border-border">
                <CardHeader>
                  <CardTitle className="text-foreground flex items-center gap-2">
                    <Palette className="h-5 w-5 text-primary" />
                    Appearance
                  </CardTitle>
                  <CardDescription className="text-muted-foreground">
                    Customize the look and feel of the dashboard
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="flex items-center justify-between p-4 rounded-lg bg-muted/30 border border-border">
                    <div className="flex items-center gap-3">
                      {isDark ? (
                        <Moon className="h-5 w-5 text-primary" />
                      ) : (
                        <Sun className="h-5 w-5 text-warning" />
                      )}
                      <div>
                        <p className="font-medium text-foreground">
                          {isDark ? "Dark Mode" : "Light Mode"}
                        </p>
                        <p className="text-sm text-muted-foreground">
                          {isDark
                            ? "Currently using the dark navy theme"
                            : "Currently using the light theme"}
                        </p>
                      </div>
                    </div>
                    <Switch
                      checked={isDark}
                      onCheckedChange={handleThemeToggle}
                    />
                  </div>
                  <p className="text-xs text-muted-foreground">
                    Theme preference is saved locally and applied on every visit.
                  </p>
                </CardContent>
              </Card>
            </TabsContent>

          </Tabs>
        )}

        <div className="mt-6 flex justify-end">
          <Button
            className="gradient-primary text-primary-foreground"
            onClick={handleSave}
            disabled={saving || loading}
          >
            <Save className="h-4 w-4 mr-2" />
            {saving ? "Saving..." : "Save Changes"}
          </Button>
        </div>
      </div>
    </div>
  );
}
