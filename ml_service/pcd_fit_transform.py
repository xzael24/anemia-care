"""Automatically find the transform from GT coords to actual nail positions.

Strategy: For each image, detect the hand/skin region using color segmentation
(in the rotated portrait image), then find the translation that best aligns
GT nail boxes with the detected skin blobs.

Test hypotheses:
  H1: (x,y) = (u,v)              -- direct on portrait
  H2: (x,y) = (800-u, v)         -- 90° CW on landscape
  H3: (x,y) = (v, u)             -- swapped on portrait
  H4: (x,y) = (v, 800-u)         -- swapped on landscape
  H5: (x,y) = (800-v, u)         -- 90° CCW on portrait
  H6: (x,y) = (600-u, v)         -- 90° CW on portrait
  H7: (x,y) = (v, 600-u)         -- 90° CCW on landscape
"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\scale_probe")

df = pd.read_csv(META)

# --- Hypothesis transforms: (u,v) -> (x,y) on PORTRAIT image ---
def h1(u, v): return (u, v)                        # direct
def h2(u, v): return (800 - u, v)                  # 90 CW from landscape
def h3(u, v): return (v, u)                        # swap
def h4(u, v): return (v, 800 - u)                  # swap + CW
def h5(u, v): return (800 - v, u)                  # 90 CCW from landscape
def h6(u, v): return (600 - u, v)                  # CW on portrait
def h7(u, v): return (v, 600 - u)                  # CCW on landscape

HYPOTHESIS = {
    "H1_direct": h1,
    "H2_90cw_lsc": h2,
    "H3_swap": h3,
    "H4_swap_cw": h4,
    "H5_90ccw_lsc": h5,
    "H6_90cw_pt": h6,
    "H7_90ccw_lsc": h7,
}


def detect_skin_mask(img_bgr):
    """Detect skin-colored region. Skin is warm-toned (even if desaturated)."""
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    # Skin hue range (loosely): H 0-25, S 20-180, V 60-255
    lower = np.array([0, 20, 60])
    upper = np.array([25, 180, 255])
    mask = cv2.inRange(hsv, lower, upper)
    # Also try with broader range for near-desaturated
    lower2 = np.array([0, 8, 80])
    upper2 = np.array([30, 120, 255])
    mask2 = cv2.inRange(hsv, lower2, upper2)
    mask = cv2.bitwise_or(mask, mask2)
    # Dilate to fill gaps
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    mask = cv2.dilate(mask, kernel, iterations=3)
    return mask


def find_skin_blobs(mask, min_area=2000):
    """Find large connected components (likely hand/fingers)."""
    n_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(mask, 8)
    blobs = []
    for i in range(1, n_labels):  # skip background
        area = stats[i, cv2.CC_STAT_AREA]
        if area < min_area:
            continue
        x = stats[i, cv2.CC_STAT_LEFT]
        y = stats[i, cv2.CC_STAT_TOP]
        w = stats[i, cv2.CC_STAT_WIDTH]
        h = stats[i, cv2.CC_STAT_HEIGHT]
        cx, cy = centroids[i]
        blobs.append({"area": area, "bbox": (x, y, x+w, y+h), "center": (cx, cy)})
    blobs.sort(key=lambda b: b["area"], reverse=True)
    return blobs


def box_center(box):
    x1, y1, x2, y2 = box
    return ((x1+x2)/2, (y1+y2)/2)


def compute_iou(b1, b2):
    """IoU between two boxes (x1,y1,x2,y2)."""
    x1 = max(b1[0], b2[0])
    y1 = max(b1[1], b2[1])
    x2 = min(b1[2], b2[2])
    y2 = min(b1[3], b2[3])
    inter = max(0, x2-x1) * max(0, y2-y1)
    a1 = (b1[2]-b1[0]) * (b1[3]-b1[1])
    a2 = (b2[2]-b2[0]) * (b2[3]-b2[1])
    return inter / (a1 + a2 - inter + 1e-6)


# --- TEST ALL HYPOTHESES ON MULTIPLE IMAGES ---
PIDS = [288, 54, 47, 200, 100, 150, 50, 30, 250, 10, 5, 245]

print("="*80)
print("HYPOTHESIS TEST: skin mask overlap with transformed GT boxes")
print("="*80)

results = {name: [] for name in HYPOTHESIS}

for pid in PIDS:
    rows = df[df.PATIENT_ID == pid]
    if rows.empty:
        continue
    r = rows.iloc[0]
    img_path = PHOTO / f"{pid}.jpg"
    if not img_path.exists():
        continue
    
    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)  # portrait 800H x 600W
    H, W = img_rot.shape[:2]  # 800, 600
    
    nails = json.loads(r.NAIL_BOUNDING_BOXES)
    skins = json.loads(r.SKIN_BOUNDING_BOXES)
    all_boxes = nails + skins
    
    # Detect skin
    skin_mask = detect_skin_mask(img_rot)
    blobs = find_skin_blobs(skin_mask, min_area=1000)
    
    # Find the largest blob (likely the hand)
    if not blobs:
        print(f"  pid {pid}: NO SKIN DETECTED, skip")
        continue
    
    hand_blob = blobs[0]
    hand_bbox = hand_blob["bbox"]  # (x,y,x+w,y+h)
    
    # For each hypothesis, compute average IoU of GT boxes with skin mask
    # AND check if box centers fall within skin regions
    for hname, hfunc in HYPOTHESIS.items():
        overlap_scores = []
        center_in_skin = 0
        total_boxes = len(all_boxes)
        
        for (u1, v1, u2, v2) in all_boxes:
            # Transform all 4 corners and get bounding rect
            corners = [(u1,v1),(u2,v1),(u1,v2),(u2,v2)]
            try:
                new_corners = [hfunc(c[0], c[1]) for c in corners]
            except:
                continue
            xs = [c[0] for c in new_corners]
            ys = [c[1] for c in new_corners]
            tx1, ty1, tx2, ty2 = min(xs), min(ys), max(xs), max(ys)
            
            # Check if within image bounds
            if tx1 < 0 or ty1 < 0 or tx2 >= W or ty2 >= H:
                overlap_scores.append(-1)
                continue
            
            # IoU with skin mask (approximate: use hand bbox as proxy)
            iou = compute_iou((tx1,ty1,tx2,ty2), hand_bbox)
            overlap_scores.append(iou)
            
            # Check center in skin mask
            cx, cy = (tx1+tx2)/2, (ty1+ty2)/2
            if 0 <= int(cx) < W and 0 <= int(cy) < H:
                if skin_mask[int(cy), int(cx)] > 0:
                    center_in_skin += 1
        
        valid = [s for s in overlap_scores if s >= 0]
        mean_iou = np.mean(valid) if valid else 0
        pct_centers = center_in_skin / total_boxes if total_boxes > 0 else 0
        results[hname].append({"pid": pid, "mean_iou": mean_iou, 
                                "pct_centers_in_skin": pct_centers,
                                "n_valid": len(valid), "n_total": total_boxes})
    
    # Print per-image results
    print(f"\n  pid {pid}: {len(nails)} nails, {len(skins)} skins, {len(blobs)} skin blobs")
    print(f"    hand bbox: {hand_bbox}, area: {hand_blob['area']}")
    for hname in HYPOTHESIS:
        r_dict = [x for x in results[hname] if x["pid"] == pid][-1]
        print(f"    {hname:15s}: mean_iou={r_dict['mean_iou']:.3f}, "
              f"centers_in_skin={r_dict['pct_centers_in_skin']:.1%} "
              f"({r_dict['n_valid']}/{r_dict['n_total']} in-bounds)")


# --- SUMMARY ---
print("\n" + "="*80)
print("SUMMARY: Average scores across all images")
print("="*80)
for hname in HYPOTHESIS:
    data = results[hname]
    avg_iou = np.mean([d["mean_iou"] for d in data])
    avg_centers = np.mean([d["pct_centers_in_skin"] for d in data])
    n_images = len(data)
    print(f"  {hname:15s}: avg_iou={avg_iou:.3f}, avg_centers_in_skin={avg_centers:.1%} (n={n_images})")


# --- VISUAL OVERLAY: Generate comparison images for 4 pids ---
print("\n\nGenerating visual overlays...")
OVERLAY_PIDS = [288, 54, 47, 200]
SELECTED_HYP = ["H1_direct", "H3_swap", "H5_90ccw_lsc"]

for pid in OVERLAY_PIDS:
    rows = df[df.PATIENT_ID == pid]
    if rows.empty:
        continue
    r = rows.iloc[0]
    img_path = PHOTO / f"{pid}.jpg"
    if not img_path.exists():
        continue
    
    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    H, W = img_rot.shape[:2]
    
    nails = json.loads(r.NAIL_BOUNDING_BOXES)
    skins = json.loads(r.SKIN_BOUNDING_BOXES)
    all_boxes = nails + skins
    
    # Detect skin for background reference
    skin_mask = detect_skin_mask(img_rot)
    
    # Create 4-panel: original rotated + 3 hypothesis overlays
    panels = []
    
    # Panel 0: original with skin mask highlight
    panel0 = img_rot.copy()
    skin_color = np.zeros_like(panel0)
    skin_color[:] = (0, 200, 0)  # green
    skin_overlay = cv2.bitwise_and(skin_color, skin_color, mask=skin_mask)
    panel0 = cv2.addWeighted(panel0, 0.7, skin_overlay, 0.3, 0)
    cv2.putText(panel0, "SKIN MASK", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255,255,255), 2)
    panels.append(panel0)
    
    colors_hyp = [(0,255,0), (255,0,0), (0,0,255)]
    for idx, hname in enumerate(SELECTED_HYP):
        panel = img_rot.copy()
        hfunc = HYPOTHESIS[hname]
        for (u1,v1,u2,v2) in all_boxes:
            corners = [(u1,v1),(u2,v1),(u1,v2),(u2,v2)]
            try:
                new_corners = [hfunc(c[0], c[1]) for c in corners]
            except:
                continue
            xs = [c[0] for c in new_corners]
            ys = [c[1] for c in new_corners]
            tx1, ty1, tx2, ty2 = int(min(xs)), int(min(ys)), int(max(xs)), int(max(ys))
            color = colors_hyp[idx]
            cv2.rectangle(panel, (tx1,ty1), (tx2,ty2), color, 2)
        cv2.putText(panel, hname, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255,255,255), 2)
        panels.append(panel)
    
    # Stack 2x2
    top = np.hstack(panels[:2])
    bottom = np.hstack(panels[2:])
    combo = np.vstack([top, bottom])
    
    out_path = OUT / f"{pid}_transform_test.png"
    cv2.imwrite(str(out_path), combo)
    print(f"  Saved {out_path}")

print("\nDone! Check visual overlays in:", OUT)
