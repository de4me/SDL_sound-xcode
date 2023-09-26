//
//  ViewController.swift
//  playsoundSwift
//
//  Created by DE4ME on 11.11.2021.
//

import Cocoa;
import UniformTypeIdentifiers;
import SDL;
import SDL_Sound;


/* global decoding state. */
class PlaysoundAudioCallbackData {
    var sample: UnsafeMutablePointer<Sound_Sample>?;
    var devformat: SDL_AudioSpec?;
    var decoded_ptr: UnsafeMutablePointer<Uint8>?;
    var decoded_bytes: Uint32;
    ///This variable is flipped to non-zero when the audio callback has finished playing the whole file.
    var complited: Bool;
    
    init(sample: UnsafeMutablePointer<Sound_Sample>? = nil, devformat: SDL_AudioSpec? = nil, decoded_ptr: UnsafeMutablePointer<Uint8>? = nil, decoded_bytes: Uint32 = 0, complited: Bool = false) {
        self.sample = sample
        self.devformat = devformat
        self.decoded_ptr = decoded_ptr
        self.decoded_bytes = decoded_bytes
        self.complited = complited
    }
};


/*
 * The audio callback. SDL calls this frequently to feed the audio device.
 *  We decode the audio file being played in here in small chunks and feed
 *  the device as necessary. Other solutions may want to predecode more
 *  (or all) of the file, since this needs to run fast and frequently,
 *  but since we're only sitting here and waiting for the file to play,
 *  the only real requirement is that we can decode a given audio file
 *  faster than realtime, which isn't really a problem with any modern format
 *  on even pretty old hardware at this point.
 */
fileprivate func audio_callback(_ userdata: UnsafeMutableRawPointer?, _ stream: UnsafeMutablePointer<Uint8>?, len: Int32) {
    guard let data = userdata?.assumingMemoryBound(to: PlaysoundAudioCallbackData.self),
          let sample = data.pointee.sample,
          let stream = stream
    else {
        return;
    }
    let len = Int(len);
    var bw: Int = 0; /* bytes written to stream this time through the callback */
    while (bw < len) {
        if (data.pointee.decoded_bytes == 0) { /* need more data! */
            /* if there wasn't previously an error or EOF, read more. */
            if ( ((sample.pointee.flags.rawValue & SOUND_SAMPLEFLAG_ERROR.rawValue) == 0) &&
                 ((sample.pointee.flags.rawValue & SOUND_SAMPLEFLAG_EOF.rawValue) == 0) )
            {
                data.pointee.decoded_bytes = Sound_Decode(sample);
                data.pointee.decoded_ptr = sample.pointee.buffer.assumingMemoryBound(to: Uint8.self);
            } /* if */
            if (data.pointee.decoded_bytes == 0) {
                /* ...there isn't any more data to read! */
                memset(stream.advanced(by: bw), 0, len - bw);  /* write silence. */
                data.pointee.complited = true;
                return;  /* we're done playback, one way or another. */
            } /* if */
        } /* if */
        /* we have data decoded and ready to write to the device... */
        /* bytes to copy on this iteration of the loop. */
        let cpysize = min(len - bw, Int(data.pointee.decoded_bytes));
        /* if it's 0, next iteration will decode more or decide we're done. */
        if (cpysize > 0) {
            /* write this iteration's data to the device. */
            memcpy(stream.advanced(by: bw), data.pointee.decoded_ptr, cpysize);
            /* update state for next iteration or callback */
            bw += cpysize;
            data.pointee.decoded_ptr = data.pointee.decoded_ptr?.advanced(by: cpysize);
            data.pointee.decoded_bytes -= Uint32(cpysize);
        } /* if */
    } /* while */
} /* audio_callback */


class vMainViewController: NSViewController {
    
    @IBOutlet var imageView: NSImageView!;
    @IBOutlet var nameTextField: NSTextField!;
    @IBOutlet var playButton: NSButton!;
    
    //MARK: OBSERV
    
    var url: URL?{
        didSet{
            self.updateUrl(self.url);
        }
    }
    
    override var representedObject: Any? {
        didSet {
            self.updateRepresentedObject(self.representedObject);
        }
    }
    
    //MARK: GET
    
    var allowedFileTypes: [String] {
        var array = [String]();
        var decoders = Sound_AvailableDecoders();
        var info = decoders?.pointee?.pointee;
        while info != nil {
            var extensions = info?.extensions;
            var string = extensions?.pointee;
            while string != nil {
                array.append(String(cString: string!));
                extensions = extensions?.advanced(by: 1);
                string = extensions?.pointee;
            }
            decoders = decoders?.advanced(by: 1);
            info = decoders?.pointee?.pointee;
        }
        return array;
    }

    //MARK: OVERRIDE
    
    override func viewDidLoad() {
        super.viewDidLoad();
        self.url = nil;
    }
    
    //MARK: UI
    
    func updateUrl(_ url: URL?) {
        if let url = url {
            let values = try? url.resourceValues(forKeys: [.effectiveIconKey]);
            self.imageView.image = values?.effectiveIcon as? NSImage;
            self.nameTextField.stringValue = url.deletingPathExtension().lastPathComponent;
            self.playButton.isEnabled = true;
            NSDocumentController.shared.noteNewRecentDocumentURL(url);
        } else {
            self.imageView.image = nil;
            self.nameTextField.objectValue = nil;
            self.playButton.isEnabled = false;
        }
    }
    
    func updateRepresentedObject(_ object: Any?) {
        switch object {
        case let url as URL:
            self.url = url;
        case let string as String:
            self.url = URL(fileURLWithPath: string);
        default:
            return;
        }
    }
    
    //MARK: FUNC
    
    func playOneSoundFile(_ url: URL) {
        guard let sample = Sound_NewSampleFromFile(url.path, nil, 65536) else{
            let error = Sound_GetError();
            let string = error != nil ? String(cString: error!) : "Unknown error";
            print("Couldn't load '\(url.path)': \(string).");
            return;
        }
        var data = PlaysoundAudioCallbackData(sample: sample);
        let audio_spec = withUnsafeMutablePointer(to: &data) { ptr in
            SDL_AudioSpec(freq: .init(sample.pointee.actual.rate), format: sample.pointee.actual.format, channels: sample.pointee.actual.channels, silence: 0, samples: 4096, padding: 0, size: 0, callback: audio_callback, userdata: ptr);
        }
        data.devformat = audio_spec;
        guard (SDL_OpenAudio(&data.devformat!, nil) == 0) else {
            let error = Sound_GetError();
            let string = error != nil ? String(cString: error!) : "Unknown error";
            print("Couldn't open audio device: \(string).");
            Sound_FreeSample(data.sample);
            return;
        }
        print("Now playing [\(url.path)]...");
        SDL_PauseAudio(0);  /* SDL audio device is "paused" right after opening. */
        while (!data.complited) {
            SDL_Delay(10);  /* just wait for the audio callback to finish. */
        }
        /* at this point, we've played the entire audio file. */
        SDL_PauseAudio(1);  /* so stop the device. */
        /*
         * Sleep two buffers' worth of audio before closing, in order
         *  to allow the playback to finish. This isn't always enough;
         *   perhaps SDL needs a way to explicitly wait for device drain?
         * Most apps don't have this issue, since they aren't explicitly
         *  closing the device as soon as a sound file is done playback.
         * As an alternative for this app, you could also change the callback
         *  to write silence for a call or two before flipping global_done_flag.
         */
        SDL_Delay(2 * 1000 * Uint32(data.devformat!.samples) / Uint32(data.devformat!.freq));
        /* if there was an error, tell the user. */
        if ((data.sample!.pointee.flags.rawValue & SOUND_SAMPLEFLAG_ERROR.rawValue) != 0) {
            let error = Sound_GetError();
            let string = error != nil ? String(cString: error!) : "Unknown error";
            print("Error decoding file: \(string)");
        }
        Sound_FreeSample(data.sample);  /* clean up SDL_Sound resources... */
        SDL_CloseAudio();  /* will reopen with next file's format. */
        print("Playback completed [\(url.path)]");
    }
    
    //MARK: ACTION
    
    @IBAction func openDocument(_ sender: Any) {
        let panel = NSOpenPanel();
        panel.allowedFileTypes = self.allowedFileTypes;
        guard panel.runModal() == .OK else {
            return;
        }
        self.url = panel.url;
    }
    
    @IBAction func helpClick(_ sender: Any) {
        var array = [String]();
        var decoders = Sound_AvailableDecoders();
        var info = decoders?.pointee?.pointee;
        while info != nil {
            var array_info = [String]();
            var extensions = info?.extensions;
            var string = extensions?.pointee;
            if string != nil {
                var extensions_array = [String]();
                repeat {
                    extensions_array.append(String(cString: string!));
                    extensions = extensions?.advanced(by: 1);
                    string = extensions?.pointee;
                } while string != nil;
                array_info.append(extensions_array.joined(separator: ", "));
            }
            if let string = info!.description {
                array_info.append(String(cString: string));
            }
            if let string = info!.author {
                array_info.append(String(cString: string));
            }
            if let string = info!.url {
                array_info.append(String(cString: string));
            }
            array.append(array_info.joined(separator: "\n"));
            decoders = decoders?.advanced(by: 1);
            info = decoders?.pointee?.pointee;
        }
        var version = Sound_Version();
        Sound_GetLinkedVersion(&version);
        let alert = NSAlert();
        alert.alertStyle = .informational;
        alert.informativeText = array.count > 0 ? array.joined(separator: "\n\n") : "Empty";
        alert.messageText = "Version: \(version.major).\(version.minor).\(version.patch)\nSupported formats:";
        alert.runModal();
    }
    
    @IBAction func playClick(_ sender: Any) {
        guard let url = self.url else {
            return;
        }
        DispatchQueue.global().async {
            self.playOneSoundFile(url);
        }
    }

}

