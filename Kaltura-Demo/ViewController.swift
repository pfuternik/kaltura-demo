//
//  ViewController.swift
//  Kaltura-Demo
//
//  Created by Philip Futernik on 1/12/20.
//  Copyright © 2020 Philip Futernik. All rights reserved.
//

import UIKit
import PlayKit
import PlayKitUtils
import PlayKitKava
import PlayKitProviders
import Arcane

class ViewController: UIViewController {

    @IBOutlet weak var playerContainer: PlayerView!
    @IBOutlet weak var playPauseButton: UIButton!    
    @IBOutlet weak var videoPicker: UIPickerView!
    @IBOutlet weak var playheadSlider: UISlider!
    @IBOutlet weak var positionLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!

    enum State {
        case idle, playing, paused, ended
    }

    let pickerData = ["Forehand", "Backhand", "Baseline"]
    let SERVER_BASE_URL = "https://cdnapisec.kaltura.com"
    let PARTNER_ID = 2643041
    let ENTRY_DICT = ["Forehand": "1_ieri75o7", "Backhand": "1_b72s5o5q", "Baseline": "1_uzuymhoh"]

    // Kaltura Session: authorization string that identifies the user watching the video.
    var ks: String?

    // Kaltura Player
    var player: Player?
    
    // Internally maintained states of the Kaltura Player
    var state: State = .idle {
          didSet {
              switch state {
              case .idle:
                  self.playPauseButton.isSelected = false
              case .playing:
                  self.playPauseButton.isSelected = true
              case .paused:
                  self.playPauseButton.isSelected = false
              case .ended:
                  self.playPauseButton.isSelected = false
              }
          }
      }

    // MARK: - lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.state = .idle
        
        // Assign the videoPicker delegates.
        self.videoPicker.delegate = self
        self.videoPicker.dataSource = self

        // Call this to create a KS to identify a user watching the video; comment out for now.
        //generateSession()

        // Load the media into the player.
        self.loadMedia(ENTRY_DICT["Forehand"]!, autoPlay: false)
    }

    // MARK: - UI events

    @IBAction func onPlayPauseButtonPressed(_ sender: UIButton) {
        //sender.isSelected.toggle()
        if !sender.isSelected {
            self.player?.play()
        } else {
            self.player?.pause()
        }
    }

    @IBAction func playheadValueChanged(_ sender: Any) {
        guard let player = self.player else {
            print("player is not set")
            return
        }

        if state == .ended && playheadSlider.value < playheadSlider.maximumValue {
            state = .paused
        }
        player.currentTime = TimeInterval(playheadSlider.value)
    }

    // MARK: - private member functions

    func generateWidgetSession() -> String {
        let widgetPartnerId = "_\(PARTNER_ID)"

        let widgetKsURL = NSString(format:"https://www.kaltura.com/api_v3/service/session/action/startWidgetSession?widgetId=%@&format=1",widgetPartnerId)

        let widgetKsData = try! Data(contentsOf: URL(string: widgetKsURL as String)!)

        let widgetKsDict = try! JSONSerialization.jsonObject(with: widgetKsData, options: []) as! [String:Any]

        return (widgetKsDict["ks"] as! String)
    }

    func generateSession() {
        let appToken = "c5e53a6e01a463f7296c914a4611e5fb"
        let userId = "philip.futernik@gmail.com"
        let appTokenId = "1_i3rv07jn"

        let widgetKs: String = generateWidgetSession()

        let tokenHash: String = Hash.SHA256("\(widgetKs)\(appToken)")!

        let URLString = NSString(format:"https://www.kaltura.com/api_v3/service/apptoken/action/startsession?ks=%@&userId=%@&id=%@&tokenHash=%@&format=1",widgetKs,userId,appTokenId,tokenHash)

        let ksData = try! Data(contentsOf: URL(string: URLString as String)!)
        let ksDict = try! JSONSerialization.jsonObject(with: ksData, options: []) as! [String:Any]

        self.ks = (ksDict["ks"] as! String)
    }

    func setupPlayer() {
        // Bind the view to the Kaltura Player.
        self.player?.view = self.playerContainer

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        func format(_ time: TimeInterval) -> String {
            if let s = formatter.string(from: time) {
                return s.count > 7 ? s : "0" + s
            } else {
                return "00:00:00"
            }
        }

        // Observe media progress
        self.player?.addPeriodicObserver(interval: 0.2, observeOn: DispatchQueue.main, using: { (pos) in
            self.playheadSlider.value = Float(pos)
            self.positionLabel.text = format(pos)
        })
        
        // Observe duration
        self.player?.addObserver(self, events: [PlayerEvent.durationChanged], block: { (event) in
            if let e = event as? PlayerEvent.DurationChanged, let d = e.duration as? TimeInterval {
                self.playheadSlider.maximumValue = Float(d)
                self.durationLabel.text = format(d)
            }
        })

        // Observe play/pause
        self.player?.addObserver(self, events: [PlayerEvent.play, PlayerEvent.ended, PlayerEvent.pause], block: { (event) in
            switch event {
            case is PlayerEvent.Play, is PlayerEvent.Playing:
                self.state = .playing
                
            case is PlayerEvent.Pause:
                self.state = .paused
                
            case is PlayerEvent.Ended:
                self.state = .ended
                self.player?.seek(to: 0)

            default:
                break
            }
        })
    }

    func loadMedia(_ entryID: String, autoPlay: Bool = false) {
        let sessionProvider = SimpleSessionProvider(serverURL: SERVER_BASE_URL, partnerId: Int64(PARTNER_ID), ks: ks)
        let mediaProvider: OVPMediaProvider = OVPMediaProvider(sessionProvider)
        mediaProvider.entryId = entryID

        mediaProvider.loadMedia { (mediaEntry, error) in
            if let me = mediaEntry, error == nil {
                // Add the KAVA plugin to the player - NOTE: this does not seem to be necessary so commenting out for now:
                //self.player?.updatePluginConfig(pluginName: KavaPlugin.pluginName, config: self.createKavaConfig(entryID))

                // Create KAVA config, plugin config, and load Kaltura Player
                let kavaConfig = KavaPluginConfig(partnerId: self.PARTNER_ID, entryId: entryID, ks: self.ks, playbackContext: nil, referrer: nil, applicationVersion: nil, playlistId: nil, customVar1: nil, customVar2: nil, customVar3: nil)
                kavaConfig.playbackType = KavaPluginConfig.PlaybackType.vod
                let pluginConfig = PluginConfig(config: [KavaPlugin.pluginName: kavaConfig])
                self.player = PlayKitManager.shared.loadPlayer(pluginConfig: pluginConfig)
                self.setupPlayer()

                let mediaConfig = MediaConfig(mediaEntry: me, startTime: 0.0)
                self.player?.prepare(mediaConfig)
            }
        }
        
        if autoPlay {
            self.player?.play()
        }
    }
    
    // Create the KAVA plugin. It requires the Partner ID, the entry ID, and the KS, which
    // is what identifies the user. The rest of the arguments are optional.
    func createKavaConfig(_ entryID: String) -> KavaPluginConfig {
        return KavaPluginConfig(partnerId: PARTNER_ID, entryId: entryID, ks: ks, playbackContext: nil, referrer: nil, applicationVersion: nil, playlistId: nil, customVar1: nil, customVar2: nil, customVar3: nil)
    }
}

// MARK: - UIPickerView extension

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    // Capture the picker view selection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // This method is triggered whenever the user makes a change to the picker selection.
        // The parameter named row and component represents what was selected.

        // Ensure player is paused prior to loading media
        self.player?.pause()
        self.playheadSlider.value = Float(0.0)
        self.positionLabel.text = "00:00:00"

        //if row > 0 {
            self.loadMedia(ENTRY_DICT[pickerData[row]]!)
        //}
    }
}
