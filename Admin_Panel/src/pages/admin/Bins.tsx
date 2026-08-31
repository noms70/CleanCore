import { useState, useEffect } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { MapContainer, TileLayer, Marker, useMapEvents, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// Fix leaflet default marker icons broken by bundlers
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import {
  Search,
  Plus,
  MapPin,
  List,
  Download,
  Navigation,
  Route,
  ChevronLeft,
  ChevronRight,
  Lock,
  Brain,
  Pencil,
  Trash2,
  Camera,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Progress } from "@/components/ui/progress";
import { useBinLocationNames } from "@/hooks/useBinLocationNames";
import { db } from "@/firebase";
import {
  collection,
  onSnapshot,
  updateDoc,
  doc,
} from "firebase/firestore";
import { toast } from "sonner";

// Ngrok tunnel URL for the FastAPI backend.
const BACKEND = import.meta.env.VITE_BACKEND_URL ?? "";

interface Bin {
  id: string;
  address: string;
  lat: number | null;
  lng: number | null;
  area: string;
  sector: string;
  fill: number;
  wasteType: string;
  status: "normal" | "warning" | "critical";
  lastCollected: string;
  aiConfidence: number | null;
  isLocked: boolean;
}

interface AddBinForm {
  lat: string;
  lng: string;
  area: string;
}

interface EditBinForm {
  sector: string;
  fillLevel: string;
  wasteType: string;
  status: string;
}

// ── Route Optimization Types ─────────────────────────────────────────────────
interface RouteStop {
  binId: string;
  lat: number;
  lng: number;
  fillLevel: number;
  wasteType: string;
  sector: string;
}

interface RouteResult {
  routeId: string;
  driverId: string;
  status: string;
  totalStops: number;
  completedStops: number;
  stops: RouteStop[];
  totalDistanceKm: number;
  estimatedFuel: number;
}

const emptyAddForm: AddBinForm = { lat: "", lng: "", area: "" };
const emptyEditForm: EditBinForm = { sector: "", fillLevel: "0", wasteType: "General", status: "empty" };

// Leaflet click handler — calls onPick with the clicked lat/lng
function PinPicker({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({
    click(e) {
      onPick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

// Forces Leaflet to recalculate tile layout after the dialog finishes animating.
// Without this the map renders as a grey/black box inside a Dialog.
function MapResizer() {
  const map = useMap();
  useEffect(() => {
    const id = setTimeout(() => map.invalidateSize(), 150);
    return () => clearTimeout(id);
  }, [map]);
  return null;
}



function parseStatus(
  raw: Record<string, any>,
  fill: number
): "normal" | "warning" | "critical" {
  const s = String(raw.status ?? "").toLowerCase();
  if (s === "full" || s === "critical" || fill >= 90) return "critical";
  if (s === "partial" || s === "warning" || fill >= 70) return "warning";
  return "normal";
}

function toCsv(rows: Bin[]): string {
  const headers = [
    "Bin ID",
    "Location",
    "Sector",
    "Fill Level (%)",
    "Waste Type",
    "Status",
    "AI Confidence",
    "Last Collected",
  ];
  const escape = (v: string | number | null) => {
    const s = v === null || v === undefined ? "" : String(v);
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const lines = rows.map((b) =>
    [
      b.id,
      b.address,
      b.sector,
      b.fill,
      b.wasteType,
      b.status,
      b.aiConfidence ?? "",
      b.lastCollected,
    ]
      .map(escape)
      .join(",")
  );
  return [headers.join(","), ...lines].join("\n");
}

function downloadFile(filename: string, content: string, mime: string) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export default function Bins() {
  const [view, setView] = useState<"table" | "map">("table");
  const [bins, setBins] = useState<Bin[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [sectorFilter, setSectorFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");

  const [currentPage, setCurrentPage] = useState(1);
  const ITEMS_PER_PAGE = 10;

  // ── Add Bin (POST /analyze/) ──────────────────────────────────────────────
  const [addOpen, setAddOpen] = useState(false);
  const [addForm, setAddForm] = useState<AddBinForm>(emptyAddForm);
  const [addImage, setAddImage] = useState<File | null>(null);
  const [addSaving, setAddSaving] = useState(false);

  // ── Edit Bin (Firestore updateDoc) ────────────────────────────────────────
  const [editOpen, setEditOpen] = useState(false);
  const [editingBin, setEditingBin] = useState<Bin | null>(null);
  const [editForm, setEditForm] = useState<EditBinForm>(emptyEditForm);
  const [editSaving, setEditSaving] = useState(false);

  // ── Rescan Image (POST /rescan-bin/{id}) ──────────────────────────────────
  const [rescanOpen, setRescanOpen] = useState(false);
  const [rescanBin, setRescanBin] = useState<Bin | null>(null);
  const [rescanImage, setRescanImage] = useState<File | null>(null);
  const [rescanSaving, setRescanSaving] = useState(false);

  // ── Delete ────────────────────────────────────────────────────────────────
  const [deleteTarget, setDeleteTarget] = useState<Bin | null>(null);

  // ── Route Optimization State ───────────────────────────────────────────────
  const [routeDialogOpen, setRouteDialogOpen] = useState(false);
  const [routeDriverId, setRouteDriverId] = useState("");
  const [routeDepotLat, setRouteDepotLat] = useState("0");
  const [routeDepotLng, setRouteDepotLng] = useState("0");
  const [optimizing, setOptimizing] = useState(false);
  const [routeResult, setRouteResult] = useState<RouteResult | null>(null);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "bins"),
      (snap) => {
        const data: Bin[] = snap.docs.map((d) => {
          const raw = d.data();
          const fill = raw.fillLevel ?? raw.fill_level ?? raw.currentLevel ?? 0;

          // Extract GPS coordinates from all possible Firestore shapes
          let lat: number | null = null;
          let lng: number | null = null;
          if (raw.location && typeof raw.location === "object") {
            lat = raw.location._lat ?? raw.location.latitude ?? null;
            lng = raw.location._long ?? raw.location.longitude ?? null;
          }
          if (raw.lat !== undefined && raw.lng !== undefined) {
            lat = Number(raw.lat);
            lng = Number(raw.lng);
          }
          if (raw.latitude !== undefined && raw.longitude !== undefined) {
            lat = Number(raw.latitude);
            lng = Number(raw.longitude);
          }

          return {
            id: d.id,
            address: raw.address ?? (typeof raw.location === "string" ? raw.location : null) ?? "",
            lat,
            lng,
            area: raw.area ?? raw.sector ?? "—",
            sector: raw.sector ?? raw.area ?? "N/A",
            fill,
            wasteType: raw.wasteType ?? raw.waste_type ?? raw.type ?? "General",
            status: parseStatus(raw, fill),
            lastCollected:
              raw.lastCollected?.toDate?.()?.toLocaleString() ??
              raw.lastCollected ??
              "N/A",
            aiConfidence: raw.aiConfidence ?? raw.ai_confidence ?? null,
            isLocked: raw.isLocked ?? false,
          };
        });
        setBins(data);
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const locationNames = useBinLocationNames(bins);

  const sectors = Array.from(
    new Set(bins.map((b) => b.sector).filter((s) => s !== "N/A" && s.trim() !== ""))
  );

  const filtered = bins.filter((bin) => {
    const q = search.toLowerCase();
    const matchSearch =
      q === "" ||
      bin.id.toLowerCase().includes(q) ||
      bin.address.toLowerCase().includes(q);
    const matchSector =
      sectorFilter === "all" || bin.sector === sectorFilter;
    const matchStatus =
      statusFilter === "all" || bin.status === statusFilter;
    return matchSearch && matchSector && matchStatus;
  });

  // Reset to page 1 whenever filters change
  useEffect(() => { setCurrentPage(1); }, [search, sectorFilter, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / ITEMS_PER_PAGE));
  const safePage = Math.min(currentPage, totalPages);
  const paginated = filtered.slice((safePage - 1) * ITEMS_PER_PAGE, safePage * ITEMS_PER_PAGE);


  const openAdd = () => {
    setAddForm(emptyAddForm);
    setAddImage(null);
    setAddOpen(true);
  };

  const openEdit = (bin: Bin) => {
    setEditingBin(bin);
    // Prefer `area` (canonical) over `sector` (legacy mirror). The "—" /
    // "N/A" placeholders mean "unset" — show an empty field instead.
    const initialArea =
      bin.area && bin.area !== "—" ? bin.area
      : bin.sector && bin.sector !== "N/A" ? bin.sector
      : "";
    setEditForm({ sector: initialArea, fillLevel: String(bin.fill), wasteType: bin.wasteType, status: bin.status });
    setEditOpen(true);
  };

  const openRescan = (bin: Bin) => {
    setRescanBin(bin);
    setRescanImage(null);
    setRescanOpen(true);
  };

  const handleAddBin = async () => {
    const lat = parseFloat(addForm.lat);
    const lng = parseFloat(addForm.lng);
    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      toast.error("Valid latitude and longitude are required");
      return;
    }
    if (!addForm.area.trim()) {
      toast.error("Area is required");
      return;
    }
    if (!addImage) {
      toast.error("An image is required");
      return;
    }
    setAddSaving(true);
    try {
      // Backend declares lat/lng/area as Query params, so they must go in the
      // URL, not the multipart body. Only image_file belongs in FormData.
      const fd = new FormData();
      fd.append("image_file", addImage);
      const qs = new URLSearchParams({
        lat: String(lat),
        lng: String(lng),
        area: addForm.area.trim(),
      });
      const res = await fetch(`${BACKEND}/analyze/?${qs.toString()}`, {
        method: "POST",
        headers: { "ngrok-skip-browser-warning": "true" },
        body: fd,
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? `Server error ${res.status}`);
      }
      toast.success("Bin added and analyzed by AI");
      setAddOpen(false);
      setAddForm(emptyAddForm);
      setAddImage(null);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to add bin");
    } finally {
      setAddSaving(false);
    }
  };

  const handleEditBin = async () => {
    if (!editingBin) return;
    const fillNum = Number(editForm.fillLevel);
    if (Number.isNaN(fillNum) || fillNum < 0 || fillNum > 100) {
      toast.error("Fill level must be between 0 and 100");
      return;
    }
    setEditSaving(true);
    try {
      // Keep `area` and `sector` in lockstep. The Flutter worker app reads
      // `area` first and falls back to `sector` only when `area` is null —
      // an empty-string `area` would otherwise shadow the new `sector` and
      // hide this bin from the assigned worker.
      const areaValue = editForm.sector.trim() || "Unassigned";
      await updateDoc(doc(db, "bins", editingBin.id), {
        area: areaValue,
        sector: areaValue,
        fillLevel: fillNum,
        wasteType: editForm.wasteType,
        status: editForm.status,
      });
      toast.success("Bin updated");
      setEditOpen(false);
      setEditingBin(null);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to update bin");
    } finally {
      setEditSaving(false);
    }
  };

  const handleRescanBin = async () => {
    if (!rescanBin || !rescanImage) {
      toast.error("Please select an image");
      return;
    }
    setRescanSaving(true);
    try {
      const fd = new FormData();
      fd.append("image_file", rescanImage);
      const res = await fetch(`${BACKEND}/rescan-bin/${rescanBin.id}`, {
        method: "POST",
        headers: { "ngrok-skip-browser-warning": "true" },
        body: fd,
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? `Server error ${res.status}`);
      }
      toast.success("Bin image rescanned and updated");
      setRescanOpen(false);
      setRescanBin(null);
      setRescanImage(null);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to rescan bin");
    } finally {
      setRescanSaving(false);
    }
  };

  const handleDeleteBin = async () => {
    if (!deleteTarget) return;
    try {
      const res = await fetch(`${BACKEND}/admin/delete-bin/${deleteTarget.id}`, {
        method: "DELETE",
        headers: { "ngrok-skip-browser-warning": "true" },
      });
      if (!res.ok) throw new Error(`Server error ${res.status}`);
      toast.success("Bin deleted and removed from active routes");
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Failed to delete bin";
      toast.error(message);
    } finally {
      setDeleteTarget(null);
    }
  };

  // ── Route Optimization Handler ────────────────────────────────────────────
  // POSTs to backend which queries bins where fillLevel > 70, runs Greedy
  // Nearest-Neighbor, writes result to Firestore 'routes' collection, and
  // returns the optimised plan so we can display it immediately.
  const handleOptimizeRoute = async () => {
    if (!routeDriverId.trim()) {
      toast.error("Please enter a Driver ID");
      return;
    }
    setOptimizing(true);
    try {
      const res = await fetch(`${BACKEND}/optimize-route`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "ngrok-skip-browser-warning": "true" },
        body: JSON.stringify({
          driver_id: routeDriverId.trim(),
          depot_lat: parseFloat(routeDepotLat) || 0,
          depot_lng: parseFloat(routeDepotLng) || 0,
        }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? `Server error ${res.status}`);
      }
      const data = await res.json();
      setRouteResult(data.route as RouteResult);
      toast.success(
        `Route saved! ${data.route.totalStops} stops · ${data.route.totalDistanceKm} km · ${data.route.estimatedFuel} L`
      );
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to optimize route");
    } finally {
      setOptimizing(false);
    }
  };

  const handleExportCsv = () => {
    if (filtered.length === 0) {
      toast.error("No bins to export");
      return;
    }
    const csv = toCsv(filtered);
    const stamp = new Date().toISOString().slice(0, 10);
    downloadFile(`bins-${stamp}.csv`, csv, "text/csv;charset=utf-8;");
    toast.success(`Exported ${filtered.length} bins`);
  };

  const sectorSummary = Array.from(
    filtered.reduce<Map<string, { count: number; fillSum: number; critical: number }>>(
      (acc, b) => {
        const key = b.sector;
        const entry =
          acc.get(key) ?? { count: 0, fillSum: 0, critical: 0 };
        entry.count += 1;
        entry.fillSum += b.fill;
        if (b.status === "critical") entry.critical += 1;
        acc.set(key, entry);
        return acc;
      },
      new Map()
    )
  )
    .map(([sector, v]) => ({
      sector,
      count: v.count,
      avgFill: Math.round(v.fillSum / v.count),
      critical: v.critical,
    }))
    .sort((a, b) => a.sector.localeCompare(b.sector));

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-card/10 to-background">
      <AdminHeader
        title="Manage Bins"
        subtitle="Monitor and manage all waste bins across the city"
      />

      <div className="p-6 space-y-6">
        {/* Toolbar */}
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-1 items-center gap-4">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search bins by ID or location..."
                className="pl-10 bg-card/50 border-border/50 focus:border-primary focus:ring-primary/20 focus:shadow-lg focus:shadow-primary/10 backdrop-blur-sm"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <Select value={sectorFilter} onValueChange={setSectorFilter}>
              <SelectTrigger className="w-40 bg-muted/50 border-border">
                <SelectValue placeholder="Sector" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Sectors</SelectItem>
                {sectors.map((s) => (
                  <SelectItem key={s} value={s}>
                    Sector {s}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-40 bg-muted/50 border-border">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="normal">Normal</SelectItem>
                <SelectItem value="warning">Warning</SelectItem>
                <SelectItem value="critical">Critical</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="flex items-center gap-2">
            <div className="flex rounded-lg border border-border p-1 bg-muted/30">
              <Button
                variant={view === "table" ? "default" : "ghost"}
                size="sm"
                onClick={() => setView("table")}
                className={cn(view === "table" && "gradient-primary")}
              >
                <List className="h-4 w-4" />
              </Button>
              <Button
                variant={view === "map" ? "default" : "ghost"}
                size="sm"
                onClick={() => setView("map")}
                className={cn(view === "map" && "gradient-primary")}
              >
                <MapPin className="h-4 w-4" />
              </Button>
            </div>
            <Button
              variant="outline"
              size="sm"
              className="border-border"
              onClick={handleExportCsv}
            >
              <Download className="h-4 w-4 mr-2" />
              Export
            </Button>
            <Button
              size="sm"
              className="gradient-primary text-primary-foreground"
              onClick={openAdd}
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Bin
            </Button>
          </div>
        </div>

        {/* Table View */}
        {view === "table" && (
          <div className="rounded-xl border border-border/50 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm overflow-hidden animate-fade-in shadow-xl shadow-primary/5">
            {loading ? (
              <div className="p-12 text-center text-muted-foreground">
                Loading bins from Firestore...
              </div>
            ) : filtered.length === 0 ? (
              <div className="p-12 text-center text-muted-foreground">
                {bins.length === 0
                  ? "No bins found in Firestore. Click \"Add Bin\" to create one."
                  : "No bins match the current filters"}
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-border/50">
                  <thead className="bg-gradient-to-r from-accent/15 via-primary/10 to-accent/15">
                    <tr>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">ID</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Area / District</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">GPS Coordinates</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Fill Level</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Waste Type</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Status</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">AI Confidence</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Locked</th>
                      <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border/50">
                    {paginated.map((bin, index) => (
                      <tr
                        key={bin.id}
                        className="hover:bg-gradient-to-r hover:from-primary/5 hover:to-accent/5 transition-all duration-200 animate-fade-in"
                        style={{ animationDelay: `${index * 50}ms` }}
                      >
                        <td className="px-4 py-4 max-w-[150px]" title={bin.id}>
                          <p className="text-xs font-mono text-foreground truncate">{bin.id.slice(0, 12)}…</p>
                          {locationNames[bin.id] && (
                            <p className="text-xs text-muted-foreground truncate mt-0.5">{locationNames[bin.id]}</p>
                          )}
                        </td>
                        <td className="px-4 py-4 text-sm text-foreground">
                          {bin.area !== "—" ? (
                            <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-info/10 text-info border border-info/30">
                              {bin.area}
                            </span>
                          ) : (
                            <span className="text-muted-foreground">—</span>
                          )}
                        </td>
                        <td className="px-4 py-4 text-xs font-mono text-muted-foreground whitespace-nowrap">
                          {bin.lat !== null && bin.lng !== null
                            ? `${bin.lat.toFixed(5)}, ${bin.lng.toFixed(5)}`
                            : <span className="text-muted-foreground/50">No GPS</span>}
                        </td>
                        <td className="px-4 py-4 text-sm">
                          <div className="flex items-center gap-2">
                            <div className="w-20 h-2 bg-muted rounded-full overflow-hidden">
                              <div
                                className={cn(
                                  "h-full rounded-full transition-all duration-500",
                                  bin.fill >= 90 ? "bg-destructive" :
                                  bin.fill >= 70 ? "bg-warning" : "bg-success"
                                )}
                                style={{ width: `${bin.fill}%` }}
                              />
                            </div>
                            <span className="text-foreground font-medium text-xs">{bin.fill}%</span>
                          </div>
                        </td>
                        <td className="px-4 py-4 text-sm">
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-accent/20 text-accent border border-accent/40">
                            {bin.wasteType}
                          </span>
                        </td>
                        <td className="px-4 py-4 text-sm">
                          <span className={cn(
                            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                            bin.status === "critical" && "bg-destructive/20 text-destructive border border-destructive/30",
                            bin.status === "warning"  && "bg-warning/20 text-warning border border-warning/30",
                            bin.status === "normal"   && "bg-success/20 text-success border border-success/30"
                          )}>
                            {bin.status}
                          </span>
                        </td>
                        <td className="px-4 py-4 text-sm">
                          {bin.aiConfidence !== null ? (() => {
                            const pct = Math.round(bin.aiConfidence! * 100);
                            const colorClass =
                              pct >= 90 ? "text-success" :
                              pct >= 70 ? "text-warning" : "text-destructive";
                            return (
                              <div className={cn("inline-flex items-center gap-1.5", colorClass)}>
                                <Brain className="h-4 w-4 shrink-0" />
                                <span className="text-xs font-semibold tabular-nums">{pct}%</span>
                              </div>
                            );
                          })() : (
                            <span className="text-muted-foreground text-xs">—</span>
                          )}
                        </td>
                        <td className="px-4 py-4 text-sm">
                          {bin.isLocked ? (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-blue-500/10 text-blue-400 border border-blue-500/30">
                              <Lock className="h-3 w-3" /> Locked
                            </span>
                          ) : (
                            <span className="text-muted-foreground text-xs">Free</span>
                          )}
                        </td>
                        <td className="px-4 py-4">
                          <div className="flex items-center gap-1">
                            <button
                              onClick={() => openRescan(bin)}
                              className="p-1.5 rounded-md hover:bg-accent/10 text-muted-foreground hover:text-accent transition-colors"
                              title="Rescan bin image"
                            >
                              <Camera className="h-3.5 w-3.5" />
                            </button>
                            <button
                              onClick={() => setDeleteTarget(bin)}
                              className="p-1.5 rounded-md hover:bg-destructive/10 text-muted-foreground hover:text-destructive transition-colors"
                              title="Delete bin"
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {/* Pagination */}
            {filtered.length > ITEMS_PER_PAGE && (
              <div className="flex items-center justify-between px-4 py-3 border-t border-border">
                <p className="text-sm text-muted-foreground">
                  Showing {(safePage - 1) * ITEMS_PER_PAGE + 1}–{Math.min(safePage * ITEMS_PER_PAGE, filtered.length)} of {filtered.length} bins
                </p>
                <div className="flex items-center gap-1">
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-8 w-8"
                    disabled={safePage === 1}
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </Button>
                  {Array.from({ length: totalPages }, (_, i) => i + 1)
                    .filter((p) => p === 1 || p === totalPages || Math.abs(p - safePage) <= 1)
                    .reduce<(number | "…")[]>((acc, p, i, arr) => {
                      if (i > 0 && p - (arr[i - 1] as number) > 1) acc.push("…");
                      acc.push(p);
                      return acc;
                    }, [])
                    .map((p, i) =>
                      p === "…" ? (
                        <span key={"ellipsis-" + i} className="px-2 text-muted-foreground text-sm">…</span>
                      ) : (
                        <Button
                          key={p}
                          variant={safePage === p ? "default" : "ghost"}
                          size="icon"
                          className="h-8 w-8 text-sm"
                          onClick={() => setCurrentPage(p as number)}
                        >
                          {p}
                        </Button>
                      )
                    )}
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-8 w-8"
                    disabled={safePage === totalPages}
                    onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                  >
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Map View — sector overview grid */}
        {view === "map" && (
          <div className="rounded-xl border border-border bg-card p-6 animate-fade-in">
            <div className="mb-6 flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold text-foreground">
                  Sector Overview
                </h3>
                <p className="text-sm text-muted-foreground">
                  {filtered.length} bins across {sectorSummary.length} sectors
                </p>
              </div>
              <MapPin className="h-6 w-6 text-primary" />
            </div>
            {sectorSummary.length === 0 ? (
              <div className="h-40 rounded-lg bg-muted/30 border border-border flex items-center justify-center text-muted-foreground text-sm">
                No bins match the current filters
              </div>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {sectorSummary.map((s) => (
                  <div
                    key={s.sector}
                    className={cn(
                      "rounded-lg border p-4 bg-muted/20 hover:bg-muted/40 transition-colors",
                      s.critical > 0
                        ? "border-destructive/40"
                        : s.avgFill >= 70
                        ? "border-warning/40"
                        : "border-success/30"
                    )}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-medium text-foreground">
                        {s.sector === "N/A" ? "Unassigned" : "Sector " + s.sector}
                      </span>
                      <Badge
                        className={cn(
                          s.critical > 0 &&
                            "bg-destructive/10 text-destructive border-destructive/30",
                          s.critical === 0 &&
                            s.avgFill >= 70 &&
                            "bg-warning/10 text-warning border-warning/30",
                          s.critical === 0 &&
                            s.avgFill < 70 &&
                            "bg-success/10 text-success border-success/30"
                        )}
                      >
                        {s.count} bins
                      </Badge>
                    </div>
                    <div className="space-y-2 text-sm">
                      <div className="flex items-center justify-between text-muted-foreground">
                        <span>Avg fill</span>
                        <span className="text-foreground font-medium">
                          {s.avgFill}%
                        </span>
                      </div>
                      <Progress
                        value={s.avgFill}
                        className={cn(
                          "h-2",
                          s.avgFill >= 90 && "[&>div]:bg-destructive",
                          s.avgFill >= 70 &&
                            s.avgFill < 90 &&
                            "[&>div]:bg-warning",
                          s.avgFill < 70 && "[&>div]:bg-success"
                        )}
                      />
                      {s.critical > 0 && (
                        <div className="flex items-center justify-between text-destructive pt-1">
                          <span>Critical bins</span>
                          <span className="font-medium">{s.critical}</span>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Add Bin Dialog (POST /analyze/) ─────────────────────────────── */}
      <Dialog open={addOpen} onOpenChange={(open) => { setAddOpen(open); if (!open) { setAddForm(emptyAddForm); setAddImage(null); } }}>
        <DialogContent className="bg-card border-border max-w-lg">
          <DialogHeader>
            <DialogTitle className="text-foreground flex items-center gap-2">
              <Plus className="h-5 w-5 text-primary" />
              Add New Bin
            </DialogTitle>
            <DialogDescription className="text-muted-foreground">
              Click on the map to drop a pin and set GPS coordinates. Fill in the area and upload a bin image.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            {/* Interactive map for pin drop */}
            <div className="grid gap-2">
              <Label className="text-foreground">Location (click map to drop pin)</Label>
              <div className="rounded-lg overflow-hidden border border-border" style={{ height: 280 }}>
                <MapContainer
                  center={[33.6844, 73.0479]}
                  zoom={12}
                  style={{ height: "100%", width: "100%" }}
                  key="add-bin-map"
                >
                  <TileLayer
                    attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                  />
                  <MapResizer />
                  <PinPicker
                    onPick={(lat, lng) =>
                      setAddForm((f) => ({
                        ...f,
                        lat: lat.toFixed(6),
                        lng: lng.toFixed(6),
                      }))
                    }
                  />
                  {addForm.lat && addForm.lng && (
                    <Marker
                      position={[parseFloat(addForm.lat), parseFloat(addForm.lng)]}
                    />
                  )}
                </MapContainer>
              </div>
              {addForm.lat && addForm.lng ? (
                <p className="text-xs text-muted-foreground font-mono">
                  Pin: {addForm.lat}, {addForm.lng}
                </p>
              ) : (
                <p className="text-xs text-muted-foreground">No pin placed yet</p>
              )}
            </div>
            <div className="grid gap-2">
              <Label className="text-foreground">Area / District</Label>
              <Input
                value={addForm.area}
                onChange={(e) => setAddForm({ ...addForm, area: e.target.value })}
                placeholder="e.g. Islamabad F-7"
                className="bg-muted/50 border-border"
              />
            </div>
            <div className="grid gap-2">
              <Label className="text-foreground">Bin Image</Label>
              <input
                type="file"
                accept="image/*"
                onChange={(e) => setAddImage(e.target.files?.[0] ?? null)}
                className="block w-full text-sm text-muted-foreground file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-primary/10 file:text-primary hover:file:bg-primary/20 cursor-pointer"
              />
              {addImage && <p className="text-xs text-muted-foreground truncate">{addImage.name}</p>}
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddOpen(false)} disabled={addSaving}>Cancel</Button>
            <Button className="gradient-primary text-primary-foreground" onClick={handleAddBin} disabled={addSaving}>
              {addSaving ? "Analyzing…" : "Add Bin"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Edit Bin Dialog (Firestore updateDoc) ─────────────────────── */}
      <Dialog open={editOpen} onOpenChange={(open) => { setEditOpen(open); if (!open) setEditingBin(null); }}>
        <DialogContent className="bg-card border-border">
          <DialogHeader>
            <DialogTitle className="text-foreground flex items-center gap-2">
              <Pencil className="h-5 w-5 text-primary" />
              Edit Bin
            </DialogTitle>
            <DialogDescription className="text-muted-foreground">
              Update bin metadata. To update the image use Rescan.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label className="text-foreground">Area / District</Label>
              <Input
                value={editForm.sector}
                onChange={(e) => setEditForm({ ...editForm, sector: e.target.value })}
                placeholder="e.g. G-9 or Blue Area"
                className="bg-muted/50 border-border"
              />
              <p className="text-xs text-muted-foreground">
                Workers only see bins whose area matches their assigned area. Use the
                same value you set on the worker's profile (e.g. "G-9").
              </p>
            </div>
            <div className="grid gap-2">
              <Label className="text-foreground">Fill Level (%)</Label>
              <Input
                type="number"
                min={0}
                max={100}
                value={editForm.fillLevel}
                onChange={(e) => setEditForm({ ...editForm, fillLevel: e.target.value })}
                className="bg-muted/50 border-border"
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-2">
                <Label className="text-foreground">Waste Type</Label>
                <Select value={editForm.wasteType} onValueChange={(v) => setEditForm({ ...editForm, wasteType: v })}>
                  <SelectTrigger className="bg-muted/50 border-border"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="General">General</SelectItem>
                    <SelectItem value="Recyclable">Recyclable</SelectItem>
                    <SelectItem value="Organic">Organic</SelectItem>
                    <SelectItem value="Hazardous">Hazardous</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="grid gap-2">
                <Label className="text-foreground">Status</Label>
                <Select value={editForm.status} onValueChange={(v) => setEditForm({ ...editForm, status: v })}>
                  <SelectTrigger className="bg-muted/50 border-border"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="empty">Empty</SelectItem>
                    <SelectItem value="half_full">Half Full</SelectItem>
                    <SelectItem value="full">Full</SelectItem>
                    <SelectItem value="overflowing">Overflowing</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditOpen(false)} disabled={editSaving}>Cancel</Button>
            <Button className="gradient-primary text-primary-foreground" onClick={handleEditBin} disabled={editSaving}>
              {editSaving ? "Saving…" : "Update Bin"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Rescan Image Dialog (POST /rescan-bin/{id}) ───────────────── */}
      <Dialog open={rescanOpen} onOpenChange={(open) => { setRescanOpen(open); if (!open) { setRescanBin(null); setRescanImage(null); } }}>
        <DialogContent className="bg-card border-border">
          <DialogHeader>
            <DialogTitle className="text-foreground flex items-center gap-2">
              <Camera className="h-5 w-5 text-accent" />
              Rescan Bin Image
            </DialogTitle>
            <DialogDescription className="text-muted-foreground">
              Upload a new image for bin{" "}
              <span className="font-mono text-xs">{rescanBin?.id.slice(0, 12)}…</span>
              {rescanBin && locationNames[rescanBin.id] && (
                <span className="text-foreground"> ({locationNames[rescanBin.id]})</span>
              )}
              . The AI backend will re-analyze fill level and waste type.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label className="text-foreground">New Bin Image</Label>
              <input
                type="file"
                accept="image/*"
                onChange={(e) => setRescanImage(e.target.files?.[0] ?? null)}
                className="block w-full text-sm text-muted-foreground file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-accent/10 file:text-accent hover:file:bg-accent/20 cursor-pointer"
              />
              {rescanImage && <p className="text-xs text-muted-foreground truncate">{rescanImage.name}</p>}
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRescanOpen(false)} disabled={rescanSaving}>Cancel</Button>
            <Button className="gradient-primary text-primary-foreground" onClick={handleRescanBin} disabled={rescanSaving}>
              {rescanSaving ? "Rescanning…" : "Rescan Image"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Route Optimization Dialog ─────────────────────────────────────── */}
      <Dialog
        open={routeDialogOpen}
        onOpenChange={(open) => {
          setRouteDialogOpen(open);
          if (!open) setRouteResult(null);
        }}
      >
        <DialogContent className="bg-card border-border max-w-lg">
          {!routeResult ? (
            /* ── Input form ─────────────────────────────────────────────── */
            <>
              <DialogHeader>
                <DialogTitle className="text-foreground flex items-center gap-2">
                  <Route className="h-5 w-5 text-accent" />
                  Generate Optimised Route
                </DialogTitle>
                <DialogDescription className="text-muted-foreground">
                  Fetches all bins with fill level &gt; 70%, runs Greedy
                  Nearest-Neighbor, and saves the plan to Firestore.
                </DialogDescription>
              </DialogHeader>

              <div className="grid gap-4 py-4">
                <div className="grid gap-2">
                  <Label className="text-foreground">Driver ID</Label>
                  <Input
                    value={routeDriverId}
                    onChange={(e) => setRouteDriverId(e.target.value)}
                    placeholder="Firestore user ID of the assigned driver"
                    className="bg-muted/50 border-border"
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="grid gap-2">
                    <Label className="text-foreground">Depot Latitude</Label>
                    <Input
                      type="number"
                      value={routeDepotLat}
                      onChange={(e) => setRouteDepotLat(e.target.value)}
                      placeholder="e.g. 33.6844"
                      className="bg-muted/50 border-border"
                    />
                  </div>
                  <div className="grid gap-2">
                    <Label className="text-foreground">Depot Longitude</Label>
                    <Input
                      type="number"
                      value={routeDepotLng}
                      onChange={(e) => setRouteDepotLng(e.target.value)}
                      placeholder="e.g. 73.0479"
                      className="bg-muted/50 border-border"
                    />
                  </div>
                </div>
                <p className="text-xs text-muted-foreground">
                  Leave depot at 0,0 if you don't have a fixed yard location.
                </p>
              </div>

              <DialogFooter>
                <Button
                  variant="outline"
                  onClick={() => setRouteDialogOpen(false)}
                  disabled={optimizing}
                >
                  Cancel
                </Button>
                <Button
                  className="gradient-primary text-primary-foreground"
                  onClick={handleOptimizeRoute}
                  disabled={optimizing}
                >
                  {optimizing ? "Optimising…" : "Generate Route"}
                </Button>
              </DialogFooter>
            </>
          ) : (
            /* ── Result view ─────────────────────────────────────────────── */
            <>
              <DialogHeader>
                <DialogTitle className="text-foreground flex items-center gap-2">
                  <Navigation className="h-5 w-5 text-success" />
                  Route Saved to Firestore
                </DialogTitle>
                <DialogDescription className="text-muted-foreground font-mono text-xs">
                  routes/{routeResult.routeId}
                </DialogDescription>
              </DialogHeader>

              <div className="py-4 space-y-4">
                {/* KPI summary */}
                <div className="grid grid-cols-3 gap-3">
                  <div className="rounded-lg bg-muted/30 border border-border p-3 text-center">
                    <p className="text-2xl font-bold text-foreground">
                      {routeResult.totalStops}
                    </p>
                    <p className="text-xs text-muted-foreground mt-0.5">Stops</p>
                  </div>
                  <div className="rounded-lg bg-muted/30 border border-border p-3 text-center">
                    <p className="text-2xl font-bold text-foreground">
                      {routeResult.totalDistanceKm}
                    </p>
                    <p className="text-xs text-muted-foreground mt-0.5">km total</p>
                  </div>
                  <div className="rounded-lg bg-warning/10 border border-warning/30 p-3 text-center">
                    <p className="text-2xl font-bold text-warning">
                      {routeResult.estimatedFuel}
                    </p>
                    <p className="text-xs text-muted-foreground mt-0.5">Litres fuel</p>
                  </div>
                </div>

                {/* Stop list */}
                <div>
                  <p className="text-xs font-medium text-muted-foreground mb-2 uppercase tracking-wide">
                    Collection order
                  </p>
                  <div className="max-h-56 overflow-y-auto space-y-1.5 pr-1">
                    {routeResult.stops.map((stop, i) => (
                      <div
                        key={stop.binId}
                        className="flex items-center gap-3 p-2 rounded-lg bg-muted/20 text-sm"
                      >
                        <span className="h-5 w-5 rounded-full bg-primary/20 text-primary flex items-center justify-center text-xs font-bold shrink-0">
                          {i + 1}
                        </span>
                        <div className="flex-1 min-w-0">
                          <p className="font-mono text-xs text-foreground truncate">
                            {stop.binId.length > 14 ? stop.binId.slice(0, 14) + "…" : stop.binId}
                          </p>
                          {locationNames[stop.binId] && (
                            <p className="text-xs text-muted-foreground truncate">{locationNames[stop.binId]}</p>
                          )}
                        </div>
                        <Badge
                          variant="secondary"
                          className={cn(
                            "text-xs shrink-0",
                            stop.fillLevel >= 90 &&
                              "bg-destructive/10 text-destructive",
                            stop.fillLevel >= 70 &&
                              stop.fillLevel < 90 &&
                              "bg-warning/10 text-warning",
                            stop.fillLevel < 70 && "bg-success/10 text-success"
                          )}
                        >
                          {stop.fillLevel}% · {stop.wasteType}
                        </Badge>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              <DialogFooter>
                <Button
                  variant="outline"
                  onClick={() => setRouteResult(null)}
                >
                  New Route
                </Button>
                <Button
                  className="gradient-primary text-primary-foreground"
                  onClick={() => {
                    setRouteDialogOpen(false);
                    setRouteResult(null);
                  }}
                >
                  Close
                </Button>
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>

      {/* Delete confirmation */}
      <AlertDialog
        open={deleteTarget !== null}
        onOpenChange={(open) => !open && setDeleteTarget(null)}
      >
        <AlertDialogContent className="bg-card border-border">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-foreground">
              Delete this bin?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-muted-foreground">
              This will permanently remove the bin record and cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteBin}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
