# CleanCore — Modernizing Smart City Waste Architecture

AI-driven waste monitoring and worker-level route optimization.

**Team:** Ayesha Noman & Ayesha Nadeem
**Supervisor:** Ms Maha Rasheed
**University:** COMSATS University Islamabad — Department of Computer Science
**Industry Partner:** SmartEnds

---

## Repository layout

This is a monorepo containing all three components of the CleanCore system.

| Folder | Component | Stack |
|---|---|---|
| [`Backend/`](Backend/) | Inference + routing API | FastAPI, YOLOv8, Firebase Admin |
| [`Admin_Panel/`](Admin_Panel/) | Operations dashboard | React, TypeScript, Vite, shadcn/ui |
| [`CleanCore/`](CleanCore/) | Worker mobile app | Flutter / Dart |
| [`Docs/`](Docs/) | Report, addendum, brochure, demo video | — |

Firestore is the single source of truth shared by all three components.

---

## Architecture

```
IoT camera ──► POST /analyze/ ──► YOLOv8 (fill + waste) ──► Firestore
                                                              │
                        ┌─────────────────────────────────────┤
                        ▼                                     ▼
                 Admin Panel (React)                  Worker App (Flutter)
                 live onSnapshot dashboards           FCM push, assigned route
                        │                                     ▲
                        └──── POST /optimize-route ───────────┘
                              Greedy NN + 2-opt over Haversine
```

The backend orders stops by **Haversine** distance; the Flutter app draws the
path along **OSRM road polylines**. These serve different purposes — ordering
versus display — and are not in conflict.

---

## Scope

CleanCore is deliberately the **micro-level (worker-level)** optimization layer.
Macro-level fleet management — truck capacities, multi-vehicle dispatch — is
intentionally out of scope, as that layer is owned by commercial providers in
real European deployments. See §1 of the Final Addendum in [`Docs/`](Docs/).

---

## Running it

### Backend
```bash
cd Backend
python -m venv venv && venv\Scripts\activate     # Windows
pip install -r requirements.txt
uvicorn main:app --reload
```
Requires a `serviceAccountKey.json` (Firebase service account) in `Backend/`.
**This file is intentionally not committed** — obtain it from the Firebase
console. Trained weights ship in [`Backend/models/`](Backend/models/).

### Admin panel
```bash
cd Admin_Panel
npm install
npm run dev
```

### Worker app
```bash
cd CleanCore
flutter pub get
flutter run
```

---

## Notes on this repository

- Datasets, virtual environments, `node_modules/`, and build output are excluded
  via [`.gitignore`](.gitignore). Stock pretrained YOLO checkpoints
  (`yolov8s.pt`, `yolo26n.pt`) are also excluded — they are public upstream
  weights, not project source. The **trained** models are committed.
- Prior to consolidation, the three components lived in separate repositories.
  The mobile app's full commit history is preserved here; the backend and admin
  panel were imported at their current state. Their original histories remain at
  `Ayesha-Nadeem08/Backend` and `Ayesha-Nadeem08/Admin_Panel`, and the pre-merge
  state of this repository is tagged `archive/main-pre-monorepo`.
- Reference material and dataset attribution: [`REFERENCES.md`](REFERENCES.md).
