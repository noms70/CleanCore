import { useEffect, useRef } from "react";
import { Outlet } from "react-router-dom";
import { AdminSidebar } from "./AdminSidebar";
import { useInactivityTimeout } from "@/hooks/useInactivityTimeout";
import { db } from "@/firebase";
import { collection, query, where, onSnapshot } from "firebase/firestore";
import { toast } from "sonner";

export function AdminLayout() {
  // SFR-005: Sign out after 30 min of inactivity (controlled by Settings → sessionTimeout)
  useInactivityTimeout(30);

  const initialLoad = useRef(true);

  // Global listener for new anomalies (SFR-017 Admin Alert)
  useEffect(() => {
    const q = query(
      collection(db, "anomalies"),
      where("status", "==", "pending")
    );
    const unsub = onSnapshot(q, (snapshot) => {
      if (initialLoad.current) {
        initialLoad.current = false;
        return;
      }
      snapshot.docChanges().forEach((change) => {
        if (change.type === "added") {
          const data = change.doc.data();
          toast.error(`🚨 URGENT: New Anomaly Reported!`, {
            description: `${data.anomalyType} at Bin ${data.binId}. Sector: ${data.sector}`,
            duration: 10000,
          });
        }
      });
    });
    return () => unsub();
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-primary/5 to-background">
      <AdminSidebar />
      <main className="pl-20 lg:pl-64 transition-all duration-300">
        <Outlet />
      </main>
    </div>
  );
}
