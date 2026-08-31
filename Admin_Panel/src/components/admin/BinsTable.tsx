import { useState, useEffect } from "react";
import { db } from "../../firebase";
import { collection, onSnapshot, doc, updateDoc } from "firebase/firestore";
import { Lock } from "lucide-react";

interface Bin {
  id: string;
  location: string;
  area: string;
  fillLevel: number;
  wasteType: string;
  status: string;
  isLocked: boolean;
}

export default function BinsTable() {
  const [bins, setBins] = useState<Bin[]>([]);

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, "bins"), (snapshot) => {
      const data: Bin[] = snapshot.docs.map(d => {
        const raw = d.data();

        let locationStr = "Unknown";
        if (typeof raw.location === "string") {
          locationStr = raw.location;
        } else if (raw.location && typeof raw.location === "object") {
          const lat = raw.location._lat ?? raw.location.latitude;
          const lng = raw.location._long ?? raw.location.longitude;
          if (lat !== undefined && lng !== undefined) {
            locationStr = `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
          }
        }
        if (raw.lat !== undefined && raw.lng !== undefined) {
          locationStr = `${Number(raw.lat).toFixed(4)}, ${Number(raw.lng).toFixed(4)}`;
        }
        if (raw.address) locationStr = raw.address;

        return {
          id:        d.id,
          location:  locationStr,
          area:      raw.area ?? raw.sector ?? "—",
          fillLevel: raw.fillLevel ?? raw.fill_level ?? raw.currentLevel ?? 0,
          wasteType: raw.wasteType ?? raw.waste_type ?? raw.type ?? "General",
          status:    raw.status ?? (raw.fillLevel >= 90 ? "full" : raw.fillLevel >= 70 ? "partial" : "empty"),
          isLocked:  raw.isLocked ?? false,
        };
      });
      setBins(data);
    }, (error) => {
      console.error("Bins Firestore error:", error.message);
    });

    return () => unsubscribe();
  }, []);

  const handleStatusChange = async (id: string, newStatus: string) => {
    await updateDoc(doc(db, "bins", id), { status: newStatus });
  };

  return (
    <div className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm shadow-xl shadow-accent/10 overflow-hidden">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-border/50">
          <thead className="bg-gradient-to-r from-accent/15 via-primary/10 to-accent/15">
            <tr>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">ID</th>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">District</th>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">GPS</th>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Fill Level</th>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Waste Type</th>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Status</th>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Locked</th>
              <th className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border/50">
            {bins.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-6 py-10 text-center text-sm text-muted-foreground">
                  No bins found in Firestore. Run the seed script or scan bins with the mobile app.
                </td>
              </tr>
            ) : bins.map((bin, index) => (
              <tr
                key={bin.id}
                className="hover:bg-gradient-to-r hover:from-primary/5 hover:to-accent/5 transition-all duration-200"
                style={{ animationDelay: `${index * 50}ms` }}
              >
                <td className="px-4 py-4 text-xs font-mono text-foreground max-w-[120px] truncate" title={bin.id}>
                  {bin.id.slice(0, 12)}…
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
                <td className="px-4 py-4 text-xs text-muted-foreground font-mono">{bin.location}</td>
                <td className="px-4 py-4 text-sm">
                  <div className="flex items-center gap-2">
                    <div className="w-20 h-2 bg-muted rounded-full overflow-hidden">
                      <div
                        className={`h-full rounded-full transition-all duration-500 ${
                          bin.fillLevel >= 90 ? "bg-destructive" :
                          bin.fillLevel >= 70 ? "bg-warning" : "bg-success"
                        }`}
                        style={{ width: `${bin.fillLevel}%` }}
                      />
                    </div>
                    <span className="text-foreground font-medium text-xs">{bin.fillLevel}%</span>
                  </div>
                </td>
                <td className="px-4 py-4 text-sm">
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-accent/20 text-accent border border-accent/40">
                    {bin.wasteType}
                  </span>
                </td>
                <td className="px-4 py-4 text-sm">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                    bin.status === "full"    ? "bg-destructive/20 text-destructive border border-destructive/30" :
                    bin.status === "partial" ? "bg-warning/20 text-warning border border-warning/30" :
                                              "bg-success/20 text-success border border-success/30"
                  }`}>
                    {bin.status}
                  </span>
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
                <td className="px-4 py-4 text-sm">
                  <select
                    value={bin.status}
                    onChange={e => handleStatusChange(bin.id, e.target.value)}
                    className="border border-border/50 bg-card px-2 py-1 rounded text-foreground text-xs focus:border-accent transition-all cursor-pointer"
                  >
                    <option value="empty">Empty</option>
                    <option value="partial">Partial</option>
                    <option value="full">Full</option>
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
