//
//  ViewController.swift
//  Voice Assistant
//
//  Created by Vineet Rai on 10/06/22.
//

import UIKit
import Speech
import Lottie
import ContactsUI

class ViewController: UIViewController, UIGestureRecognizerDelegate, AVAudioRecorderDelegate, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var progressAnimation: AnimationView!
    @IBOutlet weak var textView: UILabel!
    @IBOutlet weak var animation: AnimationView!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var timepass = 0
    var contactTask = ContactTask()
    var openTask:String?
    
    // Contact
    let store = CNContactStore()
    let contact = CNMutableContact()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.animation.isUserInteractionEnabled = false
        self.uiSetup()
    }
    
    func uiSetup(){
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tap.delegate = self
        animation.loopMode = .loop
        animation.addGestureRecognizer(tap)
        progressAnimation.loopMode = .loop
        animation.stop()
        progressAnimation.isHidden = true
        textView.isHidden = true
        self.speakOut(str: "Hi, I am louie voice control.")
        _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil){
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            animation.stop()
            self.textView.isHidden = true
        } else {
            do {
                animation.play()
                self.textView.isHidden = true
                try startRecording()
            } catch {
                print(error)
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.animation.isUserInteractionEnabled = true
                    
                case .denied:
                    self.animation.isUserInteractionEnabled = false
                    
                case .restricted:
                    self.animation.isUserInteractionEnabled = false
                    
                case .notDetermined:
                    self.animation.isUserInteractionEnabled = false
                    
                default:
                    self.animation.isUserInteractionEnabled = false
                }
            }
        }
    }
    
    private func startRecording() throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            if let result = result {
                self.textView.isHidden = false
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                print("Text \(result.bestTranscription.formattedString)")
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.animation.isUserInteractionEnabled = true
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        textView.text = "(Go ahead, I'm listening)"
    }
    
 
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            self.animation.isUserInteractionEnabled = true
        } else {
            self.animation.isUserInteractionEnabled = false
        }
    }
    
    func speakOut(str:String){
        let seconds = 4.0
        self.progressAnimation.isHidden = false
        self.progressAnimation.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.progressAnimation.stop()
            self.progressAnimation.isHidden = true
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [])
        let utterance = AVSpeechUtterance(string: str)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
    
    func performNewTask(str:String){
        switch str.lowercased(){
        case "add contact":
            openTask = "contact"
            self.performContactTask()
        case "play music":
            let url = URL(string: "music://")
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        case "open whatsapp":
            let url = URL(string: "whatsapp://")
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        default:
            self.speakOut(str: "I am unable to perform the request")
        }
    }
    
    func performOpenTask(){
        switch openTask{
            case "contact" :
                performContactTask()
            default:
                print("No Task")
        }
    }
    
    func performContactTask(){
        if contactTask.taskList.count != 0{
            self.speakOut(str: "What's \(contactTask.taskList[0]) of contact?")
        }
        if contactTask.taskList.count == 1{
            // Name
            contact.givenName = textView.text!
            contactTask.taskList.removeFirst()
        } else if contactTask.taskList.count == 0 {
            // Phone
            contact.phoneNumbers.append(CNLabeledValue(
                label: "mobile", value: CNPhoneNumber(stringValue: textView.text! )))
            // Save
            let saveRequest = CNSaveRequest()
            saveRequest.add(contact, toContainerWithIdentifier: nil)
            try? store.execute(saveRequest)
            self.speakOut(str: "Your contact saved!")
            openTask = nil
        }else{
            contactTask.taskList.removeFirst()
        }
    
    }

    
    @objc func fireTimer() {
        if audioEngine.isRunning{
            if  timepass > 3 {
                audioEngine.stop()
                recognitionRequest?.endAudio()
                animation.stop()
                timepass = 0
                if ((openTask?.isEmpty) != nil) {
                    self.performOpenTask()
                }else{
                    self.performNewTask(str: textView.text ?? "Nothing")
                }
                
            }else{
                timepass = timepass + 1
            }
        }
    }
    
}

