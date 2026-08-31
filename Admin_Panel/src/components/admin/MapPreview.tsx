import { useEffect, useState } from "react";
import { MapContainer, TileLayer, CircleMarker, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import { MapPin } from "lucide-react";
import { collection, onSnapshot, query, where } from "firebase/firestore";
import { db } from "@/firebase";
import "leaflet/dist/leaflet.css";

interface RawBin {
  id: string;
  lat: number;
  lng: number;
  fill: number;
  wasteType: string;
  area: string;
  isLocked: boolean;
  status: "normal" | "warning" | "critical";
}

interface RawWorker {
  id: string;
  lat: number;
  lng: number;
  name: string;
  area: string;
}

function extractLatLng(raw: Record<string, unknown>): { lat: number; lng: number } | null {
  if (raw.location && typeof raw.location === "object") {
    const loc = raw.location as Record<string, unknown>;
    const lat = (loc._lat ?? loc.latitude) as number | undefined;
    const lng = (loc._long ?? loc.longitude) as number | undefined;
    if (lat !== undefined && lng !== undefined) return { lat, lng };
  }
  if (raw.lat !== undefined && raw.lng !== undefined)
    return { lat: raw.lat as number, lng: raw.lng as number };
  if (raw.latitude !== undefined && raw.longitude !== undefined)
    return { lat: raw.latitude as number, lng: raw.longitude as number };
  return null;
}

// Status is always derived from fill level — locked state is shown via border only
function deriveStatus(raw: Record<string, unknown>, fill: number): "normal" | "warning" | "critical" {
  const s = (raw.status ?? "") as string;
  if (s === "full" || s === "critical" || fill >= 90) return "critical";
  if (s === "partial" || s === "warning" || fill >= 70) return "warning";
  return "normal";
}

const STATUS_COLORS: Record<string, string> = {
  normal:   "#22c55e",
  warning:  "#f59e0b",
  critical: "#ef4444",
};

// Custom worker marker — distinct from bin CircleMarkers
const workerIcon = L.divIcon({
  html: `<div style="
    width:32px;height:32px;
    background:linear-gradient(135deg,#14b8a6,#0d9488);
    border:2px solid white;
    border-radius:50%;
    display:flex;align-items:center;justify-content:center;
    box-shadow:0 2px 8px rgba(0,0,0,0.45);
    font-size:16px;
    line-height:1;
  ">👷</div>`,
  className: "",
  iconSize: [32, 32],
  iconAnchor: [16, 16],
  popupAnchor: [0, -16],
});

export function MapPreview() {
  const [rawBins, setRawBins]       = useState<RawBin[]>([]);
  const [rawWorkers, setRawWorkers] = useState<RawWorker[]>([]);
  const [hasCoordsData, setHasCoordsData] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "bins"),
      (snap) => {
        const bins: RawBin[] = [];
        snap.docs.forEach((d) => {
          const raw = d.data() as Record<string, unknown>;
          const coords = extractLatLng(raw);
          if (!coords) return;
          const fill = (raw.fillLevel ?? raw.fill_level ?? raw.currentLevel ?? 0) as number;
          bins.push({
            id:        d.id,
            lat:       coords.lat,
            lng:       coords.lng,
            fill,
            wasteType: (raw.wasteType ?? raw.waste_type ?? raw.type ?? "—") as string,
            area:      (raw.area ?? raw.sector ?? "") as string,
            isLocked:  (raw.isLocked ?? false) as boolean,
            status:    deriveStatus(raw, fill),
          });
        });
        setHasCoordsData(bins.length > 0);
        setRawBins(bins);
      },
      () => { setHasCoordsData(false); setRawBins([]); }
    );
    return () => unsub();
  }, []);

  useEffect(() => {
    const q = query(collection(db, "users"), where("role", "==", "worker"));
    const unsub = onSnapshot(q, (snap) => {
      const workers: RawWorker[] = [];
      snap.docs.forEach((d) => {
        const r = d.data() as Record<string, unknown>;
        const lat = r.lat as number | undefined;
        const lng = r.lng as number | undefined;
        if (!lat || !lng || lat === 0 || lng === 0) return;
        workers.push({
          id:   d.id,
          lat,
          lng,
          name: `${r.firstName ?? ""} ${r.lastName ?? ""}`.trim() || d.id,
          area: (r.assignedArea ?? "") as string,
        });
      });
      setRawWorkers(workers);
    });
    return () => unsub();
  }, []);

  const allPoints = [...rawBins, ...rawWorkers];
  const center: [number, number] = allPoints.length > 0
    ? [
        allPoints.reduce((s, p) => s + p.lat, 0) / allPoints.length,
        allPoints.reduce((s, p) => s + p.lng, 0) / allPoints.length,
      ]
    : [33.6844, 73.0479];

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "500ms" }}
    >
      <div className="mb-6 flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
              Live City Map
            </h3>
            <span className="flex items-center gap-1 rounded-full bg-success/10 border border-success/30 px-2 py-0.5">
              <span className="relative flex h-1.5 w-1.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75" />
                <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-success" />
              </span>
              <span className="text-[10px] font-medium text-success">LIVE</span>
            </span>
          </div>
          <p className="text-sm text-muted-foreground">Bins + worker positions via Firestore</p>
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-1.5">
            <div className="h-3 w-3 rounded-full bg-success" />
            <span className="text-xs text-muted-foreground">Normal</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="h-3 w-3 rounded-full bg-warning" />
            <span className="text-xs text-muted-foreground">Warning</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="h-3 w-3 rounded-full bg-destructive" />
            <span className="text-xs text-muted-foreground">Critical</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="h-3 w-3 rounded-full border-2 border-blue-400 bg-transparent" style={{ boxSizing: "border-box" }} />
            <span className="text-xs text-muted-foreground">Locked (border)</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="h-5 w-5 rounded-full bg-teal-500 border-2 border-white flex items-center justify-center text-[9px]">👷</div>
            <span className="text-xs text-muted-foreground">Worker</span>
          </div>
        </div>
      </div>

      <div className="relative h-[420px] rounded-lg overflow-hidden border border-border/50">
        {!hasCoordsData && rawBins.length === 0 ? (
          <div className="absolute inset-0 bg-muted/20 flex flex-col items-center justify-center gap-2">
            <MapPin className="h-12 w-12 text-primary opacity-40" />
            <p className="text-sm text-muted-foreground">No GPS coordinates found in bin data</p>
          </div>
        ) : (
          <MapContainer
            center={center}
            zoom={13}
            style={{ height: "100%", width: "100%" }}
            zoomControl={true}
            scrollWheelZoom={false}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            {rawBins.map((bin) => (
              <CircleMarker
                key={bin.id}
                center={[bin.lat, bin.lng]}
                radius={8}
                pathOptions={{
                  // Fill color always reflects fill level status
                  fillColor: STATUS_COLORS[bin.status],
                  fillOpacity: 0.88,
                  // Locked bins get a blue dashed stroke; others match fill
                  color: bin.isLocked ? "#60a5fa" : STATUS_COLORS[bin.status],
                  weight: bin.isLocked ? 3 : 2,
                  dashArray: bin.isLocked ? "5 3" : undefined,
                }}
              >
                <Popup>
                  <div className="text-sm space-y-1">
                    <p className="font-semibold">Bin {bin.id.slice(0, 10)}…</p>
                    <p>{bin.fill}% full · {bin.wasteType}</p>
                    {bin.area && <p>{bin.area}</p>}
                    <p className="capitalize text-xs" style={{ color: STATUS_COLORS[bin.status] }}>
                      {bin.status}{bin.isLocked ? " 🔒 Locked" : ""}
                    </p>
                  </div>
                </Popup>
              </CircleMarker>
            ))}

            {rawWorkers.map((worker) => (
              <Marker
                key={worker.id}
                position={[worker.lat, worker.lng]}
                icon={workerIcon}
              >
                <Popup>
                  <div className="text-sm space-y-1">
                    <p className="font-semibold">👷 {worker.name}</p>
                    {worker.area && <p>{worker.area}</p>}
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        )}
      </div>
    </div>
  );
}
