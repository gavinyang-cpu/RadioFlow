import SwiftUI
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var radioManager = RadioManager()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Radio Stations
            sidebarView
        } detail: {
            // Main Content
            VStack(spacing: 0) {
                // Player View
                playerView
                
                // Content based on tab
                if selectedTab == 0 {
                    recordingsView
                } else if selectedTab == 1 {
                    transcriptionsView
                } else {
                    settingsView
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - Sidebar
    private var sidebarView: some View {
        List(selection: $radioManager.selectedStation) {
            Section("电台") {
                ForEach(radioManager.stations) { station in
                    StationRow(station: station, isPlaying: radioManager.currentStation?.id == station.id && radioManager.isPlaying)
                        .tag(station)
                }
            }
            
            Section("最近播放") {
                ForEach(radioManager.recentStations) { station in
                    StationRow(station: station, isPlaying: false)
                        .tag(station)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
    
    // MARK: - Player View
    private var playerView: some View {
        VStack(spacing: 20) {
            // Station Info
            if let station = radioManager.currentStation {
                VStack(spacing: 8) {
                    Text(station.name)
                        .font(.title2.bold())
                    Text(station.genre)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("选择一个电台")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Waveform Animation
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(radioManager.isPlaying ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 4, height: radioManager.isPlaying ? CGFloat.random(in: 10...40) : 10)
                }
            }
            .frame(height: 40)
            .animation(.easeInOut(duration: 0.2).repeatForever(), value: radioManager.isPlaying)
            
            // Controls
            HStack(spacing: 30) {
                // Record Button
                Button(action: { radioManager.toggleRecording() }) {
                    Image(systemName: radioManager.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 44))
                        .foregroundColor(radioManager.isRecording ? .red : .primary)
                }
                .buttonStyle(.plain)
                
                // Play/Pause
                Button(action: { radioManager.togglePlayback() }) {
                    Image(systemName: radioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(radioManager.currentStation == nil)
                
                // Volume
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                    Slider(value: $radioManager.volume, in: 0...1)
                        .frame(width: 100)
                }
            }
            
            // Recording indicator
            if radioManager.isRecording {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("正在录音: \(radioManager.recordingDuration)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(30)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Recordings View
    private var recordingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("录音")
                .font(.title2.bold())
                .padding(.horizontal)
            
            if radioManager.recordings.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无录音")
                        .foregroundColor(.secondary)
                    Text("选择一个电台开始播放和录音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(radioManager.recordings) { recording in
                    RecordingRow(recording: recording) {
                        radioManager.playRecording(recording)
                    } onTranscribe: {
                        radioManager.transcribeRecording(recording)
                    } onDelete: {
                        radioManager.deleteRecording(recording)
                    }
                }
            }
        }
    }
    
    // MARK: - Transcriptions View
    private var transcriptionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("转录文本")
                .font(.title2.bold())
                .padding(.horizontal)
            
            if radioManager.transcriptions.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无转录")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(radioManager.transcriptions) { transcription in
                    TranscriptionRow(transcription: transcription)
                }
            }
        }
    }
    
    // MARK: - Settings View
    private var settingsView: some View {
        Form {
            Section("录音设置") {
                Toggle("自动录音", isOn: $radioManager.autoRecord)
                Picker("音频格式", selection: $radioManager.audioFormat) {
                    Text("M4A").tag("m4a")
                    Text("MP3").tag("mp3")
                    Text("WAV").tag("wav")
                }
            }
            
            Section("转录设置") {
                TextField("API Endpoint", text: $radioManager.apiEndpoint)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $radioManager.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section("关于") {
                Text("RadioFlow v1.0.0")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Station Row
struct StationRow: View {
    let station: RadioStation
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(station.name)
                    .font(.headline)
                Text(station.genre)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recording Row
struct RecordingRow: View {
    let recording: Recording
    let onPlay: () -> Void
    let onTranscribe: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(recording.name)
                    .font(.headline)
                Text(recording.date.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(recording.duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Button(action: onPlay) {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.plain)
                
                Button(action: onTranscribe) {
                    Image(systemName: "text.bubble")
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Transcription Row
struct TranscriptionRow: View {
    let transcription: Transcription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transcription.title)
                .font(.headline)
            Text(transcription.content)
                .font(.body)
                .lineLimit(3)
            Text(transcription.date.formatted())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
