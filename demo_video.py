#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI 导盲眼镜 — 实时摄像头 Demo（无头模式）
捕获摄像头画面，实时模拟 YOLOv8 检测 + 空间音频 + 跌倒检测
输出到视频文件 demo_live.mp4
"""
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import math, time, os, random
from dataclasses import dataclass

CONFIDENCE_THRESHOLD = 0.45
IMPACT_THRESHOLD = 3.5
ANGLE_THRESHOLD_DEG = 45.0

@dataclass
class DetectedObstacle:
    label: str
    confidence: float
    bounding_box: tuple
    @property
    def center_x(self): return self.bounding_box[0] + self.bounding_box[2] / 2
    @property
    def pan(self): return (self.center_x - 0.5) * 2
    @property
    def estimated_distance(self):
        h = self.bounding_box[3]
        return 1.0 - min(max(h / 0.6, 0.0), 1.0)
    def direction_text(self):
        if self.pan < -0.33: return "\u2190 \u5de6\u4fa7"
        elif self.pan > 0.33: return "\u2192 \u53f3\u4fa7"
        else: return "\u2191 \u524d\u65b9"

def detect_by_opencv(frame):
    h, w = frame.shape[:2]
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blur, 50, 150)
    kernel = np.ones((3, 3), np.uint8)
    dilated = cv2.dilate(edges, kernel, iterations=1)
    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    detections = []
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < 2000 or area > h * w * 0.6: continue
        x, y, bw, bh = cv2.boundingRect(cnt)
        aspect = bw / max(bh, 1)
        label = "person" if aspect < 0.6 and bh > bw else "car" if aspect > 1.2 and bw > 60 else np.random.choice(["chair","bicycle","backpack"])
        conf = round(random.uniform(0.55, 0.92), 3)
        if conf >= CONFIDENCE_THRESHOLD:
            detections.append(DetectedObstacle(label=label, confidence=conf, bounding_box=(x/w, y/h, bw/w, bh/h)))
    detections.sort(key=lambda d: d.confidence, reverse=True)
    return detections[:5]

def put_cn(img, text, pos, font_size=22, color=(255,255,255)):
    img_pil = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(img_pil)
    try: font = ImageFont.truetype("msyh.ttc", font_size)
    except: font = ImageFont.load_default()
    draw.text(pos, text, font=font, fill=color)
    return cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)

def render_overlay(frame, detections, fps, fall_info=""):
    h, w = frame.shape[:2]
    result = frame.copy()
    for d in detections:
        x = int(d.bounding_box[0]*w); y = int(d.bounding_box[1]*h)
        bw = int(d.bounding_box[2]*w); bh = int(d.bounding_box[3]*h)
        dist = d.estimated_distance
        color = (0,0,255) if dist>0.6 else (0,255,255) if dist>0.3 else (0,255,0)
        thickness = 3 if dist>0.6 else 2
        cv2.rectangle(result, (x,y), (x+bw,y+bh), color, thickness)
        cv2.putText(result, f"{d.label} {int(d.confidence*100)}%", (x,y-6), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255,255,255), 2)
        cv2.putText(result, d.direction_text(), (x,y+bh+20), cv2.FONT_HERSHEY_SIMPLEX, 0.45, color, 2)
    result = put_cn(result, f"Camera FPS: {fps:.0f} | Obstacles: {len(detections)}", (12,12), 18, (0,255,255))
    if detections:
        n = detections[0]
        result = put_cn(result, f"Nearest: {n.label} | pan={n.pan:+.2f} | {n.direction_text()}", (12,36), 18, (255,255,0))
        cx, cy = w//2, h-80
        cv2.circle(result, (cx,cy), 50, (80,80,80), -1)
        cv2.circle(result, (cx,cy), 50, (200,200,200), 2)
        cv2.putText(result, "L", (cx-70,cy+6), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 2)
        cv2.putText(result, "R", (cx+60,cy+6), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 2)
        pan_px = int(n.pan*35)
        pan_color = (0,0,255) if n.pan<-0.1 else (255,0,0) if n.pan>0.1 else (0,255,0)
        cv2.circle(result, (cx+pan_px,cy), 14, pan_color, -1)
        cv2.circle(result, (cx+pan_px,cy), 14, (255,255,255), 2)
        cv2.putText(result, f"pan={n.pan:+.2f}", (cx+pan_px+20,cy+6), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255), 2)
        tts = f"[TTS] {n.label}, {n.direction_text()}, pan={n.pan:+.2f}"
        result = put_cn(result, tts, (12,h-18), 15, (180,180,180))
    if fall_info:
        result = put_cn(result, fall_info, (12,60), 16, (0,0,255))
    return result

def simulate_imu_fall(t):
    ax = random.uniform(-0.5,0.5) + math.sin(t*1.5)*0.3
    ay = random.uniform(-0.3,0.3) + 1.0
    az = random.uniform(-0.4,0.4) + math.cos(t)*0.2
    svm = math.sqrt(ax**2 + ay**2 + az**2)
    angle = abs(math.atan2(math.sqrt(ax**2+az**2), abs(ay)+1e-8)) * (180.0/math.pi)
    if int(t) % 15 == 0 and int(t) % 2 == 0:
        svm += 5.0; angle += 35.0
        return svm, angle, True
    return svm, angle, False

def main():
    out_dir = r"C:\Users\m9347\Desktop\apk\SmartGlassesVision\demo_output"
    os.makedirs(out_dir, exist_ok=True)
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] No webcam available"); return
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 960)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
    cap.set(cv2.CAP_PROP_FPS, 15)

    fps = 15
    duration = 12  # seconds
    total_frames = fps * duration
    out_path = os.path.join(out_dir, "demo_live.mp4")
    out_video = cv2.VideoWriter(out_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (960, 720))

    print("=" * 60)
    print("  AI Smart Glasses - Live Camera Demo (Headless)")
    print(f"  Capturing {duration}s @ {fps}fps = {total_frames} frames")
    print(f"  Output: {out_path}")
    print("=" * 60)

    frame_count = 0
    fps_start = time.time()
    fps_counter = 0
    last_fall = 0

    while frame_count < total_frames:
        ret, frame = cap.read()
        if not ret: break
        frame = cv2.resize(frame, (960, 720))

        fps_counter += 1
        if time.time() - fps_start >= 1.0:
            fps = fps_counter
            fps_counter = 0
            fps_start = time.time()

        detections = detect_by_opencv(frame)
        svm, angle, is_fall = simulate_imu_fall(time.time())
        fall_info = ""
        if is_fall and svm > IMPACT_THRESHOLD and angle > ANGLE_THRESHOLD_DEG:
            fall_info = f"FALL DETECTED! SVM={svm:.1f}G Angle={angle:.0f}deg"
            last_fall = int(time.time())
        elif int(time.time()) - last_fall < 3:
            fall_info = "FALL DETECTED! Initiating emergency..."

        result = render_overlay(frame, detections, fps, fall_info)
        out_video.write(result)
        frame_count += 1

        if frame_count % fps == 0:
            sec = frame_count // fps
            status = f"  [{sec}s/{duration}s] FPS:{fps:.0f} Det:{len(detections)}"
            if detections: status += f" Nearest:{detections[0].label} pan={detections[0].pan:+.2f}"
            if fall_info: status += f" **{fall_info[:40]}**"
            print(status)

    cap.release()
    out_video.release()
    print(f"\n  Done! Video saved: {out_path}")
    print(f"  File size: {os.path.getsize(out_path)/1024:.0f} KB")

if __name__ == "__main__":
    main()
