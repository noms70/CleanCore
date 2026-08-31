"""
reset_locks.py — Unlock all bins locked by a stuck/old route and optionally
mark the route as 'cancelled' so workers can generate fresh routes.

Usage:
    python reset_locks.py

Safe to run: only unlocks bins with isLocked=True and marks stuck active
routes older than 2 hours as 'cancelled'.
"""

import sys
from datetime import datetime, timezone, timedelta

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter

SERVICE_ACCOUNT = "serviceAccountKey.json"
try:
    cred = credentials.Certificate(SERVICE_ACCOUNT)
    firebase_admin.initialize_app(cred)
except ValueError:
    pass
except Exception as e:
    print(f"[ERROR] Firebase init failed: {e}")
    sys.exit(1)

db = firestore.client()

def main():
    print("=" * 55)
    print("  CleanCore — Reset Bin Locks & Stale Routes")
    print("=" * 55)

    # ── 1. Cancel stuck active routes ────────────────────────────────────────
    print("\n[STEP 1] Scanning for stuck active routes...")
    cutoff = datetime.now(timezone.utc) - timedelta(hours=2)
    active_routes = list(
        db.collection("routes")
        .where(filter=FieldFilter("status", "==", "active"))
        .stream()
    )
    cancelled = 0
    for rdoc in active_routes:
        data = rdoc.to_dict()
        created = data.get("createdAt")
        route_id = data.get("routeId", rdoc.id)
        # Cancel if older than 2 hours (stale) or if created_at is missing
        if created is None or (hasattr(created, 'tzinfo') and created < cutoff):
            rdoc.reference.update({
                "status": "cancelled",
                "cancelledAt": datetime.now(timezone.utc),
            })
            print(f"  [CANCELLED] route {route_id}  (driverId={data.get('driverId','?')})")
            cancelled += 1
        else:
            print(f"  [SKIP] route {route_id} is recent — leaving active")

    print(f"  → {cancelled} stale routes cancelled")

    # ── 2. Unlock all locked bins ────────────────────────────────────────────
    print("\n[STEP 2] Unlocking all locked bins...")
    locked_bins = list(
        db.collection("bins")
        .where(filter=FieldFilter("isLocked", "==", True))
        .stream()
    )
    if not locked_bins:
        print("  No locked bins found.")
    else:
        batch = db.batch()
        for bdoc in locked_bins:
            batch.update(bdoc.reference, {
                "isLocked": False,
                "routeId":  firestore.DELETE_FIELD,
            })
        batch.commit()
        print(f"  [UNLOCKED] {len(locked_bins)} bins are now available for routing")

    # ── 3. Summary ───────────────────────────────────────────────────────────
    remaining_active = list(
        db.collection("routes").where(filter=FieldFilter("status", "==", "active")).stream()
    )
    available_bins = list(
        db.collection("bins")
        .where(filter=FieldFilter("fillLevel", ">", 70))
        .where(filter=FieldFilter("isLocked", "==", False))
        .stream()
    )
    print("\n" + "=" * 55)
    print("  RESULT")
    print("=" * 55)
    print(f"  -> {len(remaining_active)} active routes remaining")
    print(f"  -> {len(available_bins)} bins available (>70% full, unlocked)")
    print("\n  Workers can now tap 'Generate My Route' successfully.\n")


if __name__ == "__main__":
    main()
