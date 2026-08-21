# 🎧 iMic (Bluetooth Sound Guard)

<p align="center">
  <img src="https://github.com/user-attachments/assets/3ecbf51a-cee7-4452-8729-eb985116e00b" width="128" height="128" alt="iMic Icon">
  <br>
  <h2 align="center">"당신의 에어팟에 음질의 자유를."</h2>
  <p align="center"><i>"Freedom of Sound Quality for Your AirPods."</i></p>
  <p align="center">
    <b><a href="#-english">English</a></b> | <b><a href="#-한국어">한국어</a></b>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-black?style=for-the-badge&logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6.0+-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/Architecture-100%25%20Native-blue?style=for-the-badge" alt="Native">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
</p>

---

# 🌐 English

### 🧐 The Problem

Have you ever joined a **Discord voice channel, Zoom meeting, Google Meet, or gaming voice chat** with your AirPods (or any Bluetooth headset) on macOS, only to find that your crystal-clear audio suddenly collapses into **muffled, 20-year-old telephone-quality mono audio**?

* **The Cause**: Due to Bluetooth bandwidth limitations, the moment a microphone stream is requested, macOS forcibly downgrades the Bluetooth profile from high-fidelity music playback (**A2DP**) to low-bandwidth bidirectional voice-call mode (**HFP/SCO**).
* **Especially on Desktop Macs (Mac mini, Mac Studio)**: These machines have no built-in microphones at all, leaving users stuck with degraded Bluetooth audio unless they buy expensive external USB mics.

> **"Why can't we use the studio-grade microphones on our plugged-in iPad or iPhone as a wired Mac microphone automatically?"**
> 
> To solve this once and for all without heavy virtual drivers or manual Shortcut clicks, we built **`iMic`**—an ultra-lightweight, 100% pure native macOS menu bar utility.

---

### ✨ Key Features

```mermaid
flowchart LR
    A["🎧 Headset Connection Detected"] --> B["⚡ iMic Auto-Intervention"]
    B --> C["📱 Enable iPad IDAM / Detect iPhone"]
    C --> D["🎙️ Route Mic Input to Wired Source"]
    D --> E["✨ Preserve Full Hi-Fi Stereo Audio!"]
