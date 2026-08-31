import { useEffect, useState } from "react";
import { Brain, AlertTriangle, TrendingUp, Clock, CheckCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import { collection, onSnapshot } from "firebase/firestore";
import { db } from "@/firebase";

interface Insight {
  icon: React.ElementType;
  title: string;
  description: string;
  type: "warning" | "info" | "success";
  confidence: number;
}

export function AIInsightsPanel() {
  const [insights, setInsights] = useState<Insight[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "bins"),
      (snap) => {
        const bins = snap.docs.map((d) => {
          const raw = d.data();
          return {
            id: d.id,
            fill: raw.fillLevel ?? raw.fill_level ?? raw.currentLevel ?? 0,
            status: raw.status ?? "normal",
            wasteType: raw.wasteType ?? raw.waste_type ?? raw.type ?? "General",
            sector: raw.sector ?? null,
          };
        });

        const total = bins.length;
        if (total === 0) {
          setInsights([]);
          setLoading(false);
          return;
        }

        const generated: Insight[] = [];

        // Insight 1: Overflow risk — bins with fill > 80
        const highFill = bins.filter((b) => b.fill >= 80);
        if (highFill.length > 0) {
          const sectorGroup: Record<string, number> = {};
          highFill.forEach((b) => {
            const s = b.sector || "Unknown";
            sectorGroup[s] = (sectorGroup[s] || 0) + 1;
          });
          const topSector = Object.entries(sectorGroup).sort(
            (a, b) => b[1] - a[1]
          )[0];
          generated.push({
            icon: AlertTriangle,
            title: "Overflow Prediction",
            description:
              topSector && topSector[0] !== "Unknown"
                ? `${highFill.length} bin${highFill.length > 1 ? "s" : ""} near full — ${topSector[1]} in Sector ${topSector[0]} need urgent collection`
                : `${highFill.length} bin${highFill.length > 1 ? "s" : ""} at or above 80% capacity and require collection`,
            type: "warning",
            confidence: 89,
          });
        }

        // Insight 2: Average fill rate across all bins
        const avgFill =
          bins.reduce((sum, b) => sum + b.fill, 0) / total;
        generated.push({
          icon: TrendingUp,
          title: "City Fill Rate",
          description: `Average fill level across all ${total} bins is ${Math.round(avgFill)}%. ${
            avgFill > 65
              ? "Collection frequency should be increased."
              : "Collection schedule is within normal range."
          }`,
          type: avgFill > 65 ? "warning" : "info",
          confidence: 94,
        });

        // Insight 3: Low-fill bins that can be skipped
        const lowFill = bins.filter((b) => b.fill < 30);
        if (lowFill.length > 0) {
          generated.push({
            icon: Clock,
            title: "Route Optimization",
            description: `${lowFill.length} bin${lowFill.length > 1 ? "s" : ""} below 30% capacity. Skip these on the next route to improve collection efficiency.`,
            type: "success",
            confidence: 91,
          });
        } else {
          generated.push({
            icon: CheckCircle,
            title: "Collection Efficiency",
            description: `All ${total} bins are above 30% capacity — consider increasing route frequency to prevent overflow.`,
            type: "info",
            confidence: 88,
          });
        }

        setInsights(generated);
        setLoading(false);
      },
      () => setLoading(false)
    );

    return () => unsub();
  }, []);

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "600ms" }}
    >
      <div className="mb-6 flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-accent to-primary shadow-lg shadow-accent/40">
          <Brain className="h-5 w-5 text-card" />
        </div>
        <div>
          <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
            AI Insights
          </h3>
          <p className="text-sm text-muted-foreground">
            Smart predictions & recommendations
          </p>
        </div>
      </div>

      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="h-20 rounded-lg bg-muted/30 animate-pulse border border-border"
            />
          ))}
        </div>
      ) : insights.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-8">
          No bin data to generate insights
        </p>
      ) : (
        <div className="space-y-4">
          {insights.map((insight, index) => (
            <div
              key={index}
              className={cn(
                "group relative overflow-hidden rounded-lg border p-4 transition-all duration-300 hover:shadow-xl backdrop-blur-sm bg-gradient-to-br from-card/50 to-transparent",
                insight.type === "warning" &&
                  "border-warning/40 hover:border-warning/60 hover:shadow-warning/20",
                insight.type === "info" &&
                  "border-info/40 hover:border-info/60 hover:shadow-info/20",
                insight.type === "success" &&
                  "border-success/40 hover:border-success/60 hover:shadow-success/20"
              )}
            >
              <div className="flex items-start gap-3">
                <div
                  className={cn(
                    "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
                    insight.type === "warning" && "bg-warning/10 text-warning",
                    insight.type === "info" && "bg-info/10 text-info",
                    insight.type === "success" && "bg-success/10 text-success"
                  )}
                >
                  <insight.icon className="h-4 w-4" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <h4 className="font-medium text-foreground truncate">
                      {insight.title}
                    </h4>
                    <span
                      className={cn(
                        "text-xs font-medium px-2 py-0.5 rounded-full shrink-0",
                        insight.type === "warning" && "bg-warning/10 text-warning",
                        insight.type === "info" && "bg-info/10 text-info",
                        insight.type === "success" && "bg-success/10 text-success"
                      )}
                    >
                      {insight.confidence}% confidence
                    </span>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    {insight.description}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
