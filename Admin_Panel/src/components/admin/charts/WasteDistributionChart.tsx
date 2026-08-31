import { useEffect, useState } from "react";
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { collection, onSnapshot } from "firebase/firestore";
import { db } from "@/firebase";

const WASTE_COLORS: Record<string, string> = {
  General: "hsl(190, 95%, 55%)",
  Recyclable: "hsl(262, 83%, 65%)",
  Recyclables: "hsl(262, 83%, 65%)",
  Organic: "hsl(142, 76%, 50%)",
  Hazardous: "hsl(38, 92%, 55%)",
  "E-Waste": "hsl(0, 72%, 55%)",
};
const FALLBACK_COLORS = [
  "hsl(190, 95%, 55%)",
  "hsl(262, 83%, 65%)",
  "hsl(142, 76%, 50%)",
  "hsl(38, 92%, 55%)",
  "hsl(0, 72%, 55%)",
];

interface ChartItem {
  name: string;
  value: number;
  color: string;
}

export function WasteDistributionChart() {
  const [data, setData] = useState<ChartItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "bins"),
      (snap) => {
        const counts: Record<string, number> = {};
        snap.docs.forEach((d) => {
          const raw = d.data();
          const type = raw.wasteType ?? raw.waste_type ?? raw.type ?? "General";
          counts[type] = (counts[type] || 0) + 1;
        });
        const total = Object.values(counts).reduce((s, v) => s + v, 0);
        if (total === 0) {
          setData([]);
          setLoading(false);
          return;
        }
        const chartData: ChartItem[] = Object.entries(counts).map(
          ([name, count], i) => ({
            name,
            value: Math.round((count / total) * 100),
            color: WASTE_COLORS[name] ?? FALLBACK_COLORS[i % FALLBACK_COLORS.length],
          })
        );
        setData(chartData);
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "300ms" }}
    >
      <div className="mb-6">
        <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
          Waste Distribution
        </h3>
        <p className="text-sm text-muted-foreground">By waste type (live)</p>
      </div>

      {loading ? (
        <div className="h-[250px] flex items-center justify-center text-muted-foreground text-sm">
          Loading...
        </div>
      ) : data.length === 0 ? (
        <div className="h-[250px] flex items-center justify-center text-muted-foreground text-sm">
          No bin data available
        </div>
      ) : (
        <>
          <div className="h-[250px]">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={data}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={100}
                  paddingAngle={3}
                  dataKey="value"
                >
                  {data.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: "hsl(222 47% 14%)",
                    border: "1px solid hsl(222 30% 25%)",
                    borderRadius: "8px",
                    color: "hsl(180 100% 95%)",
                  }}
                  formatter={(value: number) => [`${value}%`, ""]}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="mt-4 grid grid-cols-2 gap-2">
            {data.map((item) => (
              <div key={item.name} className="flex items-center gap-2">
                <div
                  className="h-2 w-2 rounded-full shrink-0"
                  style={{ backgroundColor: item.color }}
                />
                <span className="text-xs text-muted-foreground truncate">{item.name}</span>
                <span className="text-xs font-medium text-foreground ml-auto">
                  {item.value}%
                </span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
