import Foundation
import AVFoundation
import Combine

// MARK: - Radio Station Model
struct RadioStation: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var streamURL: String
    var genre: String
    var country: String
    
    init(id: UUID = UUID(), name: String, streamURL: String, genre: String = "General", country: String = "") {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.genre = genre
        self.country = country
    }
}

// MARK: - Recording Model
struct Recording: Identifiable, Codable {
    var id: UUID
    var name: String
    var fileURL: String
    var duration: String
    var date: Date
    var transcriptionId: UUID?
    
    init(id: UUID = UUID(), name: String, fileURL: String, duration: String, date: Date = Date()) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.duration = duration
        self.date = date
    }
}

// MARK: - Transcription Model
struct Transcription: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var date: Date
    var recordingId: UUID
    
    init(id: UUID = UUID(), title: String, content: String, date: Date = Date(), recordingId: UUID) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.recordingId = recordingId
    }
}

// MARK: - Radio Manager
class RadioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var stations: [RadioStation] = []
    @Published var recentStations: [RadioStation] = []
    @Published var selectedStation: RadioStation?
    @Published var currentStation: RadioStation?
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var recordingDuration = "00:00"
    @Published var volume: Double = 0.8
    @Published var recordings: [Recording] = []
    @Published var transcriptions: [Transcription] = []
    
    // Settings
    @Published var autoRecord = false
    @Published var audioFormat = "m4a"
    @Published var apiEndpoint = "https://aigw-gzgy2.cucloud.cn:8443/v1/audio/transcriptions"
    @Published var apiKey = ""
    
    // Private
    private var player: AVPlayer?
    private var recorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSampleStations()
        loadRecordings()
    }
    
    // MARK: - Sample Stations
    private func loadSampleStations() {
        stations = [
            RadioStation(name: "NPR News", streamURL: "https://npr-ice.streamguys1.com/live.mp3", genre: "News", country: "USA"),
            RadioStation(name: "BBC World Service", streamURL: "https://stream.live.vc.bbcmedia.co.uk/bbc_world_service", genre: "News", country: "UK"),
            RadioStation(name: "Jazz FM", streamURL: "https://jazz-wr01.ice.infomaniak.ch/jazz-wr01-128.mp3", genre: "Jazz", country: "UK"),
            RadioStation(name: "Classical KING FM", streamURL: "https://classicalking.streamguys1.com/king-fm-aac", genre: "Classical", country: "USA"),
            RadioStation(name: "BBC Radio 1", streamURL: "https://stream.live.vc.bbcmedia.co.uk/bbc_radio_one", genre: "Pop", country: "UK"),
        ]
    }
    
    // MARK: - Playback Controls
    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    func startPlayback() {
        guard let station = selectedStation ?? stations.first else { return }
        
        guard let url = URL(string: station.streamURL) else { return }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = Float(volume)
        player?.play()
        
        currentStation = station
        isPlaying = true
        
        // Add to recent
        if !recentStations.contains(where: { $0.id == station.id }) {
            recentStations.insert(station, at: 0)
            if recentStations.count > 10 {
                recentStations.removeLast()
            }
        }
    }
    
    func stopPlayback() {
        player?.pause()
        player = nil
        isPlaying = false
    }
    
    // MARK: - Recording Controls
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).\(audioFormat)"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            
            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateRecordingDuration()
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = "00:00"
        
        // Save recording
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            let durationString = String(format: "%02d:%02d", minutes, seconds)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Int(startTime.timeIntervalSince1970)).\(audioFormat)"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            let recording = Recording(
                name: "Recording \(recordings.count + 1)",
                fileURL: fileURL.path,
                duration: durationString,
                date: startTime
            )
            
            recordings.insert(recording, at: 0)
            saveRecordings()
        }
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        recordingDuration = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Recording Management
    func deleteRecording(_ recording: Recording) {
        recordings.removeAll { $0.id == recording.id }
        
        // Delete file
        try? FileManager.default.removeItem(atPath: recording.fileURL)
        
        saveRecordings()
    }
    
    func playRecording(_ recording: Recording) {
        let url = URL(fileURLWithPath: recording.fileURL)
        player = AVPlayer(url: url)
        player?.play()
    }
    
    // MARK: - Transcription
    func transcribeRecording(_ recording: Recording) {
        // This would use the Cloudflare AI Gateway
        // For now, create a placeholder
        let transcription = Transcription(
            title: "Transcription - \(recording.name)",
            content: "Transcription would appear here after processing with AI...",
            recordingId: recording.id
        )
        
        transcriptions.insert(transcription, at: 0)
        
        // Update recording
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index].transcriptionId = transcription.id
            saveRecordings()
        }
    }
    
    // MARK: - Persistence
    private func saveRecordings() {
        if let data = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(data, forKey: "recordings")
        }
    }
    
    private func loadRecordings() {
        if let data = UserDefaults.standard.data(forKey: "recordings"),
           let saved = try? JSONDecoder().decode([Recording].self, from: data) {
            recordings = saved
        }
    }
}
