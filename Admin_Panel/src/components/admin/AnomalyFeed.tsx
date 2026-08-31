import { useEffect, useState } from "react";
import { collection, onSnapshot, orderBy, limit, query } from "firebase/firestore";
import { db } from "@/firebase";
import { Badge } from "@/components/ui/badge";
import { AlertTriangle, CheckCircle, Clock, Trash2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface AnomalyItem {
  id: string;
  binId: string;
  anomalyType: string;
  reportedBy: string;
  sector: string;
  priority: "high" | "medium" | "low";
  status: "pending" | "resolved" | "investigating";
  timeAgo: string;
}

function relativeTime(ts: Date | null | undefined): string {
  if (!ts) return "Recently";
  const diff = Math.round((Date.now() - ts.getTime()) / 60000);
  if (diff < 1) return "Just now";
  if (diff < 60) return `${diff}m ago`;
  const h = Math.round(diff / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.round(h / 24)}d ago`;
}

const PRIORITY_CLASS: Record<string, string> = {
  high: "bg-destructive/10 text-destructive border-destructive/30",
  medium: "bg-warning/10 text-warning border-warning/30",
  low: "bg-muted/30 text-muted-foreground border-border",
};

const STATUS_CLASS: Record<string, string> = {
  resolved: "border-success/30 text-success",
  pending: "border-warning/30 text-warning",
  investigating: "border-info/30 text-info",
};

export function AnomalyFeed() {
  const [anomalies, setAnomalies] = useState<AnomalyItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(
      collection(db, "anomalies"),
      orderBy("createdAt", "desc"),
      limit(8)
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        setAnomalies(
          snap.docs.map((d) => {
            const raw = d.data();
            return {
              id: d.id,
              // backend writes binId; older docs may use bin
              binId: raw.binId ?? raw.bin ?? "—",
              // backend writes anomalyType; older docs may use type
              anomalyType: raw.anomalyType ?? raw.type ?? "Issue",
              // backend writes reportedBy; older docs may use workerName / worker
              reportedBy: raw.reportedBy ?? raw.workerName ?? raw.worker ?? "Unknown",
              sector: raw.sector ?? raw.sectorId ?? "",
              priority: (raw.priority as AnomalyItem["priority"]) ?? "medium",
              status: (raw.status as AnomalyItem["status"]) ?? "pending",
              timeAgo: relativeTime(raw.createdAt?.toDate?.()),
            };
          })
        );
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  return (
    <div
      className="rounded-xl border border-border bg-card p-6 animate-fade-in"
      style={{ animationDelay: "750ms" }}
    >
      {/* Header */}
      <div className="mb-5 flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold text-foreground">Anomaly Feed</h3>
          <p className="text-sm text-muted-foreground">
            Live · anomalies collection
          </p>
        </div>
        <div className="flex items-center gap-2">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-destructive opacity-75" />
            <span className="relative inline-flex rounded-full h-2 w-2 bg-destructive" />
          </span>
          <span className="text-xs text-muted-foreground">Live</span>
        </div>
      </div>

      {/* Feed */}
      <div className="space-y-2.5">
        {loading ? (
          <p className="text-sm text-muted-foreground text-center py-4">Loading…</p>
        ) : anomalies.length === 0 ? (
          <div className="flex flex-col items-center gap-2 py-8 text-muted-foreground">
            <CheckCircle className="h-8 w-8 text-success/50" />
            <p className="text-sm">No anomalies reported yet</p>
          </div>
        ) : (
          anomalies.map((a) => (
            <div
              key={a.id}
              className="flex items-start gap-3 rounded-lg p-3 bg-muted/20 hover:bg-muted/40 transition-colors"
            >
              {/* Status icon */}
              <div className="mt-0.5 shrink-0">
                {a.status === "resolved" ? (
                  <CheckCircle className="h-4 w-4 text-success" />
                ) : a.status === "investigating" ? (
                  <Clock className="h-4 w-4 text-info" />
                ) : (
                  <AlertTriangle className="h-4 w-4 text-warning" />
                )}
              </div>

              {/* Content */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5 flex-wrap">
                  <span className="text-sm font-medium text-foreground capitalize">
                    {a.anomalyType.replace(/_/g, " ")}
                  </span>
                  <Badge
                    className={cn(
                      "text-[10px] h-4 px-1.5 py-0 capitalize",
                      PRIORITY_CLASS[a.priority] ?? PRIORITY_CLASS.medium
                    )}
                  >
                    {a.priority}
                  </Badge>
                  <Badge
                    variant="outline"
                    className={cn(
                      "text-[10px] h-4 px-1.5 py-0 capitalize",
                      STATUS_CLASS[a.status] ?? STATUS_CLASS.pending
                    )}
                  >
                    {a.status}
                  </Badge>
                </div>
                <div className="mt-0.5 flex items-center gap-1.5 text-xs text-muted-foreground flex-wrap">
                  <Trash2 className="h-3 w-3" />
                  <span>
                    Bin&nbsp;
                    {a.binId.length > 10 ? a.binId.slice(0, 10) + "…" : a.binId}
                  </span>
                  {a.sector && <span>· Sector {a.sector}</span>}
                  <span>· {a.reportedBy}</span>
                </div>
              </div>

              <span className="text-xs text-muted-foreground shrink-0 mt-0.5">
                {a.timeAgo}
              </span>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
