import { useState, useEffect, useRef } from "react";

interface BinCoord {
  id: string;
  lat: number | null;
  lng: number | null;
}

/**
 * Reverse-geocodes each bin's lat/lng via Nominatim (same logic as the mobile
 * app's _fetchBinNamesForNewBins). Returns a map of binId → readable name.
 * Requests are staggered 250 ms apart to honour Nominatim's 1 req/sec limit.
 */
export function useBinLocationNames(bins: BinCoord[]): Record<string, string> {
  const [names, setNames] = useState<Record<string, string>>({});
  const fetched = useRef<Set<string>>(new Set());

  // Re-run only when the set of bin IDs changes (new bins added/removed)
  const idKey = bins.map((b) => b.id).join(",");

  useEffect(() => {
    const toFetch = bins.filter(
      (b) => b.lat !== null && b.lng !== null && !fetched.current.has(b.id)
    );
    if (toFetch.length === 0) return;

    let cancelled = false;

    (async () => {
      for (const bin of toFetch) {
        if (cancelled) return;
        fetched.current.add(bin.id); // mark before fetch so re-renders don't retry
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?format=json&lat=${bin.lat}&lon=${bin.lng}`,
            { headers: { "User-Agent": "CleanCore/1.0" } }
          );
          if (!res.ok || cancelled) continue;
          const data = await res.json();
          const addr = (data.address ?? {}) as Record<string, string>;
          const name: string | undefined =
            (data.name as string | undefined)?.trim() ||
            addr.amenity?.trim() ||
            addr.shop?.trim() ||
            addr.building?.trim() ||
            addr.road?.trim() ||
            addr.suburb?.trim();
          if (name && !cancelled) {
            setNames((prev) => ({ ...prev, [bin.id]: name }));
          }
        } catch {
          // geocoding failure is non-fatal — bin ID remains as fallback
        }
        await new Promise<void>((r) => setTimeout(r, 250));
      }
    })();

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [idKey]);

  return names;
}
