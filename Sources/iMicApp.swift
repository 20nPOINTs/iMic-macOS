import SwiftUI

@main
struct iMicApp: App {
    @StateObject private var appState: AppState
    
    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        
        _ = IDAMAutomator.shared
        AudioEngine.shared.startMonitoring(appState: state)
        USBMonitor.shared.startMonitoring()
    }
    
    var body: some Scene {
        MenuBarExtra {
            ContentView(appState: appState)
        } label: {
            MenuBarIconView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @ObservedObject var appState: AppState
    
    private var inputDevices: [(name: String, uid: String, category: MicCategory)] {
        if !appState.availableInputDevices.isEmpty {
            return appState.availableInputDevices
        }
        return AudioEngine.shared.getCategorizedInputDevices(excludingBTOutputName: appState.currentOutput)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("🎧 iMic")
                    .font(.headline)
                
                Text("BETA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(4)
                
                Spacer()
                
                Text("v1.0.0-beta")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Status Section
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.isHighQuality ? "🟢 현재 상태: 고음질 유지 중" : "🟠 현재 상태: 통화 모드 (음질 저하)")
                    .font(.body.weight(.medium))
                Text("출력: \(appState.currentOutput)")
                    .font(.body)
                    .foregroundColor(.secondary)
                Text("입력: \(appState.currentInput)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Feat 2: Automation Toggles
            Text("⚙️ 자동화 설정")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("마이크 자동 전환")
                    .font(.body)
                Spacer()
                Toggle("", isOn: $appState.autoSwitchEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            HStack {
                Text("IDAM 자동 활성화")
                    .font(.body)
                Spacer()
                Toggle("", isOn: $appState.autoIDAMEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            Divider()
            
            // Preferred Mic Selection: Auto -> iPad -> iPhone -> Built-in -> External
            HStack {
                Text("🎙️ 마이크")
                    .font(.body)
                
                Spacer()
                
                Menu {
                    Button {
                        appState.preferredMicUID = nil
                        AudioEngine.shared.updateState()
                    } label: {
                        if appState.preferredMicUID == nil {
                            Text("✓ 자동 (스마트 감지)")
                        } else {
                            Text("자동 (스마트 감지)")
                        }
                    }
                    
                    if !inputDevices.isEmpty {
                        Divider()
                        
                        ForEach(inputDevices, id: \.uid) { device in
                            Button {
                                appState.preferredMicUID = device.uid
                                AudioEngine.shared.updateState()
                            } label: {
                                let isSelected = appState.preferredMicUID == device.uid
                                let check = isSelected ? "✓ " : ""
                                Text("\(check)\(device.category.icon)\(device.name)")
                            }
                        }
                    }
                } label: {
                    let selectedName: String = {
                        if let uid = appState.preferredMicUID,
                           let device = inputDevices.first(where: { $0.uid == uid }) {
                            return device.name
                        }
                        return "자동"
                    }()
                    Text(selectedName)
                }
            }
            
            Divider()
            
            HStack {
                Text("로그인 시 자동 실행")
                    .font(.body)
                Spacer()
                Toggle("", isOn: $appState.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            Divider()
            
            // Bottom Bar: Left and Right aligned
            HStack {
                Button("GitHub 방문") {
                    if let url = URL(string: "https://github.com/20nPOINTs/iMic-macOS") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Spacer()
                
                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(minWidth: 220)
    }
}

struct MenuBarIconView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        Image(nsImage: appState.menuBarIcon)
    }
}
