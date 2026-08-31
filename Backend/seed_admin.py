"""
seed_admin.py — Create or fix the CleanCore admin account.

Usage:
    python seed_admin.py

Creates Firebase Auth account + Firestore profile for:
  Email:    cleancore.admin@gmail.com
  Password: CleanCore@123
  Role:     admin
"""

import sys
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import auth, credentials, firestore

SERVICE_ACCOUNT = "serviceAccountKey.json"
try:
    cred = credentials.Certificate(SERVICE_ACCOUNT)
    firebase_admin.initialize_app(cred)
except ValueError:
    pass  # already initialised
except Exception as e:
    print(f"[ERROR] Firebase init failed: {e}")
    sys.exit(1)

db  = firestore.client()
now = datetime.now(timezone.utc)

ADMIN_EMAIL    = "cleancore.admin@gmail.com"
ADMIN_PASSWORD = "CleanCore@123"

def main():
    print("=" * 55)
    print("  CleanCore — Admin Account Seeder")
    print("=" * 55)

    uid = None

    # ── Step 1: Firebase Auth ────────────────────────────────
    try:
        existing = auth.get_user_by_email(ADMIN_EMAIL)
        uid = existing.uid
        print(f"[EXISTS] Auth account already exists: {ADMIN_EMAIL}")
        print(f"         uid = {uid}")
        # Update password in case it was different
        auth.update_user(uid, password=ADMIN_PASSWORD, email_verified=True)
        print(f"[UPDATE] Password reset to '{ADMIN_PASSWORD}'")
    except auth.UserNotFoundError:
        record = auth.create_user(
            email=ADMIN_EMAIL,
            password=ADMIN_PASSWORD,
            display_name="CleanCore Admin",
            email_verified=True,
        )
        uid = record.uid
        print(f"[CREATED] Auth account created: {ADMIN_EMAIL}")
        print(f"          uid = {uid}")

    # ── Step 2: Firestore profile ────────────────────────────
    db.collection("users").document(uid).set(
        {
            "uid":               uid,
            "email":             ADMIN_EMAIL,
            "firstName":         "CleanCore",
            "lastName":          "Admin",
            "role":              "admin",
            "status":            "active",
            "assignedArea":      "Islamabad",
            "assignedWasteType": "All",
            "lat":               33.7077,
            "lng":               73.0499,
            "collections":       0,
            "routes":            0,
            "profilePicture":    "",
            "createdAt":         now,
        },
        merge=True,
    )
    print(f"[FIRESTORE] Admin profile written with role='admin'")

    print("\n" + "=" * 55)
    print("  ADMIN LOGIN CREDENTIALS")
    print("=" * 55)
    print(f"  Email   : {ADMIN_EMAIL}")
    print(f"  Password: {ADMIN_PASSWORD}")
    print(f"  Role    : admin")
    print(f"  UID     : {uid}")
    print("\n  You can now sign in to the admin dashboard.\n")


if __name__ == "__main__":
    main()
