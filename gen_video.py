#!/usr/bin/env python3
"""Generate realistic traffic video demo from real photos + animated objects"""
import cv2, numpy as np, os, math, random
from PIL import Image, ImageDraw, ImageFont

out_dir = "C:\\Users\\m9347\\Desktop\\apk\\SmartGlassesVision\\demo_output"
os.makedirs(out_dir, exist_ok=True)

assets = "C:\\Users\\m9347\\Desktop\\apk\\ultralytics_assets\\im"
bg_paths = [os.path.join(assets, f) for f in os.listdir(assets) if f.endswith((".jpg",".png")) and os.path.getsize(os.path.join(assets, f)) > 10000]
print(f"Found {len(bg_paths)} background images from ultralytics assets")

fps = 20
duration = 12
total = fps * duration
out_path = os.path.join(out_dir, "demo_traffic.mp4")
fourcc = cv2.VideoWriter_fourcc(*"mp4v")
vw = cv2.VideoWriter(out_path, fourcc, fps, (960, 720))

def put_cn(img, text, pos, fs=22, color=(255,255,255)):
    p = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    d = ImageDraw.Draw(p)
    try: f = ImageFont.truetype("msyh.ttc", fs)
    except: f = ImageFont.load_default()
    d.text(pos, text, font=f, fill=color)
    return cv2.cvtColor(np.array(p), cv2.COLOR_RGB2BGR)

for i in range(total):
    t = i / fps

    # 背景轮换 - 用真实照片
    bg = cv2.imread(bg_paths[i % len(bg_paths)])
    if bg is None: bg = np.ones((720, 960, 3), dtype=np.uint8) * 200
    bg = cv2.resize(bg, (960, 720))

    # 背景暗化处理让前景更明显
    bg = cv2.addWeighted(bg, 0.4, np.zeros_like(bg), 0, 0)

    # === 动态物体 ===
    # 1. 汽车 (从右向左)
    car_x = int(960 - (t * 80 % 1100))
    car_y = 420 + int(math.sin(t * 2) * 20)
    car_pan = ((car_x + 45) / 960 - 0.5) * 2

    # 2. 行人 (更慢)
    ped_x = int(980 - (t * 45 % 1100))
    ped_y = 500 + int(math.cos(t * 1.5) * 10)
    ped_pan = ((ped_x) / 960 - 0.5) * 2

    # 3. 自行车
    bike_x = int(1000 - (t * 60 % 1100))
    bike_y = 370 + int(math.sin(t * 2.5) * 15)
    bike_pan = ((bike_x + 20) / 960 - 0.5) * 2

    # 4. 第二辆车（从右向左，不同速度）
    car2_x = int(1050 - (t * 55 % 1150))
    car2_y = 340 + int(math.cos(t * 1.8) * 10)
    car2_pan = ((car2_x + 45) / 960 - 0.5) * 2

    # 画地面（透明道路指示）
    cv2.rectangle(bg, (0, 400), (960, 720), (50, 50, 40), -1)

    # 画物体
    # car
    cv2.rectangle(bg, (car_x, car_y), (car_x+90, car_y+45), (0, 165, 255), -1)
    cv2.rectangle(bg, (car_x, car_y), (car_x+90, car_y+45), (255, 255, 255), 2)
    # person
    cv2.circle(bg, (ped_x, ped_y-10), 12, (255, 220, 180), -1)
    cv2.rectangle(bg, (ped_x-8, ped_y), (ped_x+8, ped_y+30), (0, 0, 255), -1)
    cv2.rectangle(bg, (ped_x-8, ped_y), (ped_x+8, ped_y+30), (255, 255, 255), 1)
    # bicycle
    cv2.rectangle(bg, (bike_x, bike_y), (bike_x+40, bike_y+25), (255, 0, 0), -1)
    cv2.rectangle(bg, (bike_x, bike_y), (bike_x+40, bike_y+25), (255, 255, 255), 2)
    # car2
    cv2.rectangle(bg, (car2_x, car2_y), (car2_x+80, car2_y+40), (200, 100, 50), -1)
    cv2.rectangle(bg, (car2_x, car2_y), (car2_x+80, car2_y+40), (255, 255, 255), 2)

    # 行人方向
    ped_dir = "arrow_r" if ped_pan > 0.33 else "arrow_f" if ped_pan > -0.33 else "arrow_l"
    car_dir = "arrow_r" if car_pan > 0.33 else "arrow_f" if car_pan > -0.33 else "arrow_l"

    # === 渲染检测框 ===
    result = bg.copy()

    # 车
    car_col = (0,0,255) if car_pan>0.3 else (0,255,255)
    cv2.rectangle(result, (car_x, car_y), (car_x+90, car_y+45), car_col, 3)
    cv2.putText(result, "car 85%", (car_x, car_y-6), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255), 2)

    # person
    cv2.rectangle(result, (ped_x-8, ped_y), (ped_x+8, ped_y+30), (0,255,0), 2)
    cv2.putText(result, "person 72%", (ped_x-8, ped_y-6), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255,255,255), 2)

    # bicycle
    cv2.rectangle(result, (bike_x, bike_y), (bike_x+40, bike_y+25), (0,255,255), 2)
    cv2.putText(result, "bicycle 68%", (bike_x, bike_y-6), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255,255,255), 2)

    # car2
    cv2.rectangle(result, (car2_x, car2_y), (car2_x+80, car2_y+40), (100,100,255), 2)
    cv2.putText(result, "car 78%", (car2_x, car2_y-6), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255,255,255), 2)

    # HUD
    result = put_cn(result, "Frame {}/{} | 4 obstacles".format(i, total), (12, 12), 18, (0,255,255))
    result = put_cn(result, "Nearest: car | pan={:.2f} | FPS:{}".format(car_pan, fps), (12, 36), 18, (255,255,0))

    # 空间音频可视化
    cx, cy = 480, 640
    cv2.circle(result, (cx, cy), 50, (80,80,80), -1)
    cv2.circle(result, (cx, cy), 50, (200,200,200), 2)
    cv2.putText(result, "L", (410, cy+6), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 2)
    cv2.putText(result, "R", (540, cy+6), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 2)
    pan_px = int(car_pan * 35)
    pc = (0,0,255) if car_pan<-0.1 else (255,0,0) if car_pan>0.1 else (0,255,0)
    cv2.circle(result, (cx+pan_px, cy), 14, pc, -1)
    cv2.circle(result, (cx+pan_px, cy), 14, (255,255,255), 2)
    cv2.putText(result, "pan={:.2f}".format(car_pan), (cx+pan_px+20, cy+6), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255), 2)

    # TTS
    tts = "[TTS] car, direction {} pan={:.2f}".format(car_dir, car_pan)
    result = put_cn(result, tts, (12, 690), 14, (180,180,180))

    # 跌倒检测模拟 (最后3秒触发)
    secs_left = duration - i // fps
    if secs_left <= 3 and secs_left >= 0:
        result = put_cn(result, "FALL DETECTED! SVM=8.2G Angle=52deg", (12, 60), 16, (0,0,255))
        result = put_cn(result, "[Watchdog] Emergency call in {}s... Swipe to cancel".format(secs_left), (12, 80), 14, (255,0,0))
        if secs_left == 1:
            result = put_cn(result, "[ESCALATED] Sending GPS to rescue center...", (12, 100), 14, (255,0,0))

    vw.write(result)

vw.release()
size_mb = os.path.getsize(out_path) / (1024*1024)
print(f"\nDone! Video: {out_path}")
print(f"Size: {size_mb:.1f} MB | Frames: {total} | Duration: {duration}s | FPS: {fps}")
