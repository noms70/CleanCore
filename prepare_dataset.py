"""
prepare_dataset.py

Converts the proprietary industrial bin dataset into YOLOv8 detection format.

Sources:
  - Training_Data/Paprec/Training_Data_0DD74B.../ : 593 images  → train
  - Training_Data/Slinger/Training_Dataset_0360D6.../: 257 images → 80% train / 20% val (by sorted index)
  - Training_Data/UKConnect/Training_Data_037E1B.../: 40 images  → test (held-out, unseen camera)
  - Fill-Level/device-empty-images/               :   5 images  → train (class 0, by folder)

Fill % → YOLO class:
  0–15%  → 0 (empty)
  16–55% → 1 (half_full)
  56–89% → 2 (full)
  90%+   → 3 (overflowing)

Bounding box: full-frame template (0.5 0.5 1.0 1.0) — IoT cameras always show the full bin.

Output:
  industrial_dataset/
    images/{train,val,test}/
    labels/{train,val,test}/
  industrial_bins.yaml
"""

import os
import shutil
from pathlib import Path
from collections import Counter

# ── Paths ─────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent
MLDATA = ROOT / "Datasets_v2" / "mldata" / "mldata"

SOURCES = {
    "paprec": MLDATA / "Training_Data" / "Paprec" / "Training_Data_0DD74B464041749B_A9C9D71961FC578E_A763537F2E57E23A",
    "slinger": MLDATA / "Training_Data" / "Slinger" / "Training_Dataset_0360D61418A6C10E_21March2025",
    "ukconnect": MLDATA / "Training_Data" / "UKConnect" / "Training_Data_037E1B68BD3CFA5A_Demo",
    "empty": MLDATA / "Fill-Level" / "device-empty-images",
}

OUT = ROOT / "industrial_dataset"
YAML_PATH = ROOT / "industrial_bins.yaml"

CLASS_NAMES = ["empty", "half_full", "full", "overflowing"]


def fill_to_class(pct: int) -> int:
    if pct <= 15:
        return 0
    elif pct <= 55:
        return 1
    elif pct <= 89:
        return 2
    else:
        return 3


def yolo_label(cls: int) -> str:
    # Full-frame bounding box: class cx cy w h
    return f"{cls} 0.5 0.5 1.0 1.0\n"


def collect_images(folder: Path, forced_class: int | None = None) -> list[tuple[Path, int]]:
    """Return list of (image_path, class_id) from folder."""
    result = []
    for f in sorted(folder.glob("*.jpg")):
        parts = f.stem.split("_")
        if forced_class is not None:
            cls = forced_class
        elif len(parts) >= 3:
            try:
                pct = int(parts[-1])
                cls = fill_to_class(pct)
            except ValueError:
                print(f"  [SKIP] Cannot parse fill%: {f.name}")
                continue
        else:
            print(f"  [SKIP] No fill% in filename: {f.name}")
            continue
        result.append((f, cls))
    return result


def write_split(items: list[tuple[Path, int]], split: str, counters: Counter) -> None:
    img_dir = OUT / "images" / split
    lbl_dir = OUT / "labels" / split
    img_dir.mkdir(parents=True, exist_ok=True)
    lbl_dir.mkdir(parents=True, exist_ok=True)

    for src, cls in items:
        dst_img = img_dir / src.name
        dst_lbl = lbl_dir / (src.stem + ".txt")
        shutil.copy2(src, dst_img)
        dst_lbl.write_text(yolo_label(cls))
        counters[cls] += 1


def write_yaml() -> None:
    yaml_content = f"""path: {OUT.as_posix()}
train: images/train
val: images/val
test: images/test
nc: {len(CLASS_NAMES)}
names: {CLASS_NAMES}
"""
    YAML_PATH.write_text(yaml_content)
    print(f"\nWrote {YAML_PATH}")


def main() -> None:
    # Clear previous output
    if OUT.exists():
        shutil.rmtree(OUT)
        print(f"Cleared existing {OUT.name}/")

    print("Collecting images...")

    paprec_imgs = collect_images(SOURCES["paprec"])
    slinger_imgs = collect_images(SOURCES["slinger"])
    ukconnect_imgs = collect_images(SOURCES["ukconnect"])
    empty_imgs = collect_images(SOURCES["empty"], forced_class=0)

    # Split strategy:
    # Paprec: 80% train / 20% val — sampled per-class to ensure all 4 classes in val
    # Slinger: 100% train — only overflowing class, adds volume
    # UKConnect: 100% test — held-out unseen camera angle
    # empty images: train
    paprec_by_class: dict[int, list] = {0: [], 1: [], 2: [], 3: []}
    for item in paprec_imgs:
        paprec_by_class[item[1]].append(item)

    paprec_train, paprec_val = [], []
    for cls_items in paprec_by_class.values():
        cut = max(1, int(len(cls_items) * 0.80))
        paprec_train.extend(cls_items[:cut])
        paprec_val.extend(cls_items[cut:])

    train_items = paprec_train + slinger_imgs + empty_imgs
    val_items = paprec_val
    test_items = ukconnect_imgs

    train_counts: Counter = Counter()
    val_counts: Counter = Counter()
    test_counts: Counter = Counter()

    print(f"\nWriting train  ({len(train_items)} images)...")
    write_split(train_items, "train", train_counts)

    print(f"Writing val    ({len(val_items)} images)...")
    write_split(val_items, "val", val_counts)

    print(f"Writing test   ({len(test_items)} images)...")
    write_split(test_items, "test", test_counts)

    write_yaml()

    # Summary
    print("\n" + "=" * 56)
    print("DATASET SUMMARY")
    print("=" * 56)
    all_counts = train_counts + val_counts + test_counts
    header = f"{'Class':<14} {'Train':>6} {'Val':>6} {'Test':>6} {'Total':>7}"
    print(header)
    print("-" * 56)
    for i, name in enumerate(CLASS_NAMES):
        print(f"{name:<14} {train_counts[i]:>6} {val_counts[i]:>6} {test_counts[i]:>6} {all_counts[i]:>7}")
    print("-" * 56)
    total_t = sum(train_counts.values())
    total_v = sum(val_counts.values())
    total_x = sum(test_counts.values())
    print(f"{'TOTAL':<14} {total_t:>6} {total_v:>6} {total_x:>6} {total_t+total_v+total_x:>7}")
    print("=" * 56)

    # Go/No-Go check
    empty_total = all_counts[0]
    if empty_total < 40:
        print(f"\n[WARNING] Only {empty_total} empty-class images — heavy augmentation required (5× in Roboflow)")
    else:
        print(f"\n[OK] Empty class has {empty_total} images")

    print("\nNext steps:")
    print("  1. Upload industrial_dataset/ to Roboflow")
    print("  2. Apply augmentation: 5× on 'empty', 2× on 'half_full'")
    print("  3. Export YOLOv8 format — replaces industrial_dataset/")
    print("  4. Run: yolo detect train model=yolov8s.pt data=industrial_bins.yaml")
    print("          epochs=120 imgsz=640 batch=16 cls_pw=3.0 patience=20")
    print("          project=runs/industrial name=fill_model_v2")


if __name__ == "__main__":
    main()
