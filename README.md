<p align="center">
  <img src="https://raw.githubusercontent.com/20nPOINTs/iMic-macOS/main/Resources/AppIcon.png" width="128" height="128" alt="iMic Icon">
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
```

* **🎧 Preserve Original High-Quality Audio**: Automatically intercepts microphone input and routes it to your **iPad / iPhone / External Mic** in 0.1s, completely preventing your Bluetooth headset from dropping into degraded voice-call mode.
* **⚡ 100% Zero-Touch IDAM Automation**: No need to manually open Audio MIDI Setup—iMic automatically clicks the **"Enable"** button for your connected iPad in the background within 1 second.
* **🎯 Smart Priority Microphone Selection**: Automatically detects and connects the best microphone in optimal priority order: **`iPad` → `iPhone` → `External USB Mic` → `Mac Built-in Mic`**. (Manual device pinning supported)
* **🔄 Real-Time Hot-Plug Sync**: Instantly syncs device lists and audio states within 0.1s whenever USB mics, iPads, or iPhones are connected or disconnected.
* **🎧 Universal Bluetooth Headset Support**: Works seamlessly across all Bluetooth headphones and earbuds, including **AirPods (Standard / Pro / Max), Sony (WH/WF series), Samsung Galaxy Buds, Bose**, and more.

---

### 🏆 Comparison with SoundSource

| Feature | SoundSource | **iMic (Our Solution)** |
| :--- | :--- | :--- |
| **AirPods Spatial Audio & Head Tracking** | ❌ **Forcibly Disabled** (virtual driver limit) | 🟢 **100% Native & Fully Preserved** |
| **Wired iPad IDAM Auto-Activation** | ❌ **Not Supported** (manual setup required) | 🟢 **100% Automated upon USB plug-in** |
| **System Stability & Drivers** | ⚠️ **Requires Kernel/Virtual Drivers (ACE)** | 🟢 **Pure Native (0% driver installation)** |
| **Resource Usage** | Heavy (hundreds of MBs, persistent load) | **Ultra-Lightweight (<1MB, 0.0% CPU)** |
| **Price** | $39 USD (~55,000 KRW) | **100% Free & Open Source** |

---

### 🎨 Hardware-Adaptive Menu Bar Icons

The menu bar icon badge dynamically adapts to reflect your currently active microphone hardware:

* 📱 **iPad**: `mic.fill` + `ipad` badge
* 📱 **iPhone**: `mic.fill` + `iphone` badge
* 💻 **MacBook Built-in**: `mic.fill` + `laptopcomputer` badge
* 🖥️ **iMac / Mac mini**: `mic.fill` + `desktopcomputer` / `macmini` badge
* 🎙️ **External USB Mic**: `mic.fill` + `waveform` badge

---

### 🛠️ Technical Highlights (Architecture)

* **100% Pure Native Swift 6**: Built without third-party frameworks or heavy runtimes (Electron/Python), keeping the binary under 1MB.
* **Event-Driven Architecture (Zero Polling)**: Listens directly to macOS kernel events via **`CoreAudio HAL Property Listeners`** and **`IOKit USB Notifications`**—drawing **0.0% CPU and zero battery** at idle.
* **300ms CoreAudio Debouncing**: Merges rapid, consecutive audio hardware events from macOS into a single smooth execution to prevent system freezing.
* **Persistent Code Signing**: Signed with a persistent local certificate identity so that macOS **Accessibility permissions are never revoked** across builds or updates.

---

### 💻 Installation & Getting Started

1. Download the latest `iMic.dmg` from the [Releases](../../releases) section.
2. Drag `iMic.app` into your `Applications` folder.
3. On first launch, grant Accessibility permission once in [System Settings > Privacy & Security > Accessibility].
4. **Done!** Just plug in your iPad/iPhone and put on your AirPods—everything works in full high-fidelity audio automatically. 🚀

---

<br><br>

# 🇰🇷 한국어

### 🧐 왜 만들었나요? (The Problem)

에어팟이나 블루투스 헤드셋을 착용하고 **디스코드, 줌(Zoom), 온라인 게임, 화상회의**를 켜는 순간, 고음질 에어팟의 소리가 **20년 전 통화 모드(모노 전화기 음질)로 뚝 떨어지는 현상**을 겪어보셨을 겁니다.

* **원인**: 블루투스 대역폭 한계로 인해, 마이크가 켜지는 순간 음악 모드(A2DP)에서 통화 모드(HFP/SCO)로 강제 다운그레이드되기 때문입니다.
* **특히 데스크탑 맥(Mac mini, Mac Studio)**: 본체에 자체 내장 마이크가 아예 없어 비싼 외장 마이크를 추가로 사지 않는 이상 이 문제를 피하기 어렵습니다.

> **"맥 옆에 늘 꽂혀있는 아이패드나 아이폰의 스튜디오급 마이크를 맥용 유선 마이크로 쓸 수 없을까?"**
> 
> 이 고민에서 출발하여 무거운 서드파티 드라이버나 단축어 없이 100% 자체 동작하는 **초경량 순수 네이티브 macOS 메뉴바 앱 `iMic`**을 개발했습니다.

---

### ✨ 핵심 기능 (Key Features)

```mermaid
flowchart LR
    A["🎧 에어팟/BT 착용 감지"] --> B["⚡ iMic 자동 개입"]
    B --> C["📱 아이패드 IDAM 활성화 / 아이폰 감지"]
    C --> D["🎙️ 마이크만 유선으로 가로채기"]
    D --> E["✨ 헤드셋 고음질 스테레오 유지!"]
```

* **🎧 헤드셋 본연의 고음질 상시 유지**: 마이크 입력을 헤드셋 마이크 대신 **아이패드 / 아이폰 / 외장 마이크**로 0.1초 만에 자동 가로채어, 블루투스 헤드셋 본연의 고음질 스테레오 사운드를 완벽하게 보존합니다.
* **⚡ 100% 무인 IDAM 자동화**: 오디오 MIDI 설정을 직접 켤 필요 없이, 아이패드 케이블을 꽂는 순간 백그라운드에서 **[활성화(Enable)] 버튼을 1초 만에 대신 클릭**해 줍니다.
* **🎯 스마트 우선순위 마이크 선택**: **`iPad` → `iPhone` → `외장 USB 마이크` → `Mac 내장 마이크`** 순으로 가장 안정적인 고음질 마이크를 자동 탐색하여 연결합니다. (특정 기기 고정 가능)
* **🔄 실시간 핫플러그(Hot-plug) 동기화**: USB 마이크나 아이폰/아이패드를 꽂거나 뽑는 즉시 0.1초 만에 메뉴와 오디오 상태가 실시간 갱신됩니다.
* **🎧 모든 블루투스 헤드셋 지원**: 에어팟(AirPods / Pro / Max)뿐만 아니라 **소니(Sony), 삼성 갤럭시 버즈, 보스(Bose)** 등 모든 블루투스 무선 이어폰/헤드폰에서 동일하게 동작합니다.

---

### 🏆 사운드소스(SoundSource)와의 차이점

| 비교 항목 | SoundSource | **iMic (우리 앱)** |
| :--- | :--- | :--- |
| **에어팟 공간 음향 & 머리 추적** | ❌ **강제 비활성화됨** (가상화 한계) | 🟢 **100% 완벽 지원 (순정 유지)** |
| **iPad IDAM 유선 마이크 자동화** | ❌ **지원 안 함** (수동 활성화 필요) | 🟢 **꽂으면 1초 만에 100% 자동 활성화** |
| **시스템 안전성 & 가상 드라이버** | ⚠️ **가상 드라이버(ACE) 필수 설치** (데드락 위험) | 🟢 **순수 Native (드라이버 설치 0%)** |
| **시스템 리소스 점유율** | 무거움 (수백 MB 상시 점유) | **초경량 (1MB 미만, CPU 0.0%)** |
| **가격** | $39 (약 55,000원) | **완전 무료 & 오픈소스** |

---

### 🎨 하드웨어 맞춤형 메뉴바 아이콘

현재 사용 중인 마이크 기종에 따라 메뉴바 아이콘 뱃지가 자동으로 바뀝니다:

* 📱 **iPad**: `mic.fill` + `ipad` 뱃지
* 📱 **iPhone**: `mic.fill` + `iphone` 뱃지
* 💻 **MacBook 내장**: `mic.fill` + `laptopcomputer` 뱃지
* 🖥️ **iMac / Mac mini**: `mic.fill` + `desktopcomputer` / `macmini` 뱃지
* 🎙️ **외장 USB 마이크**: `mic.fill` + `waveform` 뱃지

---

### 🛠️ 기술적 특징 (Architecture)

* **100% Pure Native Swift 6**: 서드파티 프레임워크나 외부 런타임 없이 순수 Swift로 빌드되어 가볍고 빠릅니다.
* **이벤트 기반 제어 (Zero Polling)**: `CoreAudio HAL Property Listener`와 `IOKit USB Notification` 이벤트 기반으로 동작하여 **평상시 CPU 0.0%, 배터리 소모 0%**입니다.
* **300ms CoreAudio 디바운싱**: 블루투스 연결 시 발생하는 OS의 연속 오디오 이벤트를 병합 처리하여 시스템 프리징을 방지합니다.
* **영구 권한 서명**: 로컬 코드 서명 인증서가 적용되어, 앱이 업데이트되어도 **손쉬운 사용(Accessibility) 권한이 절대 풀리지 않습니다.**

---

### 💻 설치 및 사용 방법

1. [Releases](../../releases)에서 최신 `iMic.dmg`를 다운로드합니다.
2. `iMic.app`을 `Applications` 폴더로 드래그합니다.
3. 최초 실행 시 안내에 따라 [시스템 설정 > 손쉬운 사용] 권한을 1회 허용합니다.
4. **끝!** 이제 아이패드나 아이폰을 꽂고 에어팟을 끼기만 하면 모든 것이 자동으로 고음질로 작동합니다. 🚀

---

### 📄 라이선스 (License)

이 프로젝트는 [MIT License](LICENSE)를 따릅니다.
