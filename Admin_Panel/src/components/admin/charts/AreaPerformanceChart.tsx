import { useEffect, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { collection, onSnapshot } from "firebase/firestore";
import { db } from "@/firebase";

interface AreaData {
  area: string;
  collections: number;
}

const COLORS = [
  "hsl(190, 95%, 55%)",
  "hsl(262, 83%, 65%)",
  "hsl(142, 76%, 50%)",
  "hsl(38, 92%, 55%)",
  "hsl(0, 72%, 55%)",
  "hsl(210, 80%, 60%)",
];

export function AreaPerformanceChart() {
  const [data, setData] = useState<AreaData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "pickupLogs"),
      (snap) => {
        const byArea = new Map<string, number>();
        snap.docs.forEach((d) => {
          const area = d.data().area;
          if (!area || area === "—") return;
          byArea.set(area, (byArea.get(area) ?? 0) + 1);
        });
        const sorted = Array.from(byArea.entries())
          .map(([area, collections]) => ({ area, collections }))
          .sort((a, b) => b.collections - a.collections)
          .slice(0, 8);
        setData(sorted);
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const total = data.reduce((s, d) => s + d.collections, 0);

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "450ms" }}
    >
      <div className="mb-4 flex items-start justify-between gap-2">
        <div>
          <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
            Collections by District
          </h3>
          <p className="text-sm text-muted-foreground">Top districts — last 30 days</p>
        </div>
        {!loading && total > 0 && (
          <div className="text-right shrink-0">
            <p className="text-xl font-bold text-accent">{total}</p>
            <p className="text-xs text-muted-foreground">total pickups</p>
          </div>
        )}
      </div>

      {loading ? (
        <div className="h-[260px] flex items-center justify-center text-muted-foreground text-sm">
          Loading…
        </div>
      ) : data.length === 0 ? (
        <div className="h-[260px] flex items-center justify-center text-muted-foreground text-sm">
          No district data yet — complete pickups with area assigned to see this chart
        </div>
      ) : (
        <div className="h-[260px]">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={data}
              layout="vertical"
              margin={{ top: 0, right: 8, left: 8, bottom: 0 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(222 30% 25%)" horizontal={false} />
              <XAxis
                type="number"
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 11 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
                allowDecimals={false}
              />
              <YAxis
                type="category"
                dataKey="area"
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 11 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
                width={80}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(222 47% 14%)",
                  border: "1px solid hsl(222 30% 25%)",
                  borderRadius: "8px",
                  color: "hsl(180 100% 95%)",
                }}
                formatter={(v: number) => [v, "Pickups"]}
              />
              <Bar dataKey="collections" radius={[0, 4, 4, 0]}>
                {data.map((_, i) => (
                  <Cell key={i} fill={COLORS[i % COLORS.length]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}
