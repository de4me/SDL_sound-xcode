//
//  ViewController.m
//  playsoundObjectiveC
//
//  Created by DE4ME on 11.11.2021.
//

#import "vMainViewController.h"
@import UniformTypeIdentifiers;
@import SDL;
@import SDL_Sound;

/* global decoding state. */
typedef struct {
    Sound_Sample *sample;
    SDL_AudioSpec devformat;
    Uint8 *decoded_ptr;
    Uint32 decoded_bytes;
    ///This variable is flipped to non-zero when the audio callback has finished playing the whole file.
    bool complited;
} PlaysoundAudioCallbackData;

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
void SDLCALL audio_callback(void *userdata, Uint8 *stream, int len) {
    
    PlaysoundAudioCallbackData *data = (PlaysoundAudioCallbackData *) userdata;
    Sound_Sample *sample = data->sample;
    int bw = 0; /* bytes written to stream this time through the callback */

    while (bw < len)
    {
        int cpysize;  /* bytes to copy on this iteration of the loop. */

        if (data->decoded_bytes == 0) /* need more data! */
        {
            /* if there wasn't previously an error or EOF, read more. */
            if ( ((sample->flags & SOUND_SAMPLEFLAG_ERROR) == 0) &&
                 ((sample->flags & SOUND_SAMPLEFLAG_EOF) == 0) )
            {
                data->decoded_bytes = Sound_Decode(sample);
                data->decoded_ptr = sample->buffer;
            } /* if */

            if (data->decoded_bytes == 0)
            {
                /* ...there isn't any more data to read! */
                memset(stream + bw, '\0', len - bw);  /* write silence. */
                data->complited = true;
                return;  /* we're done playback, one way or another. */
            } /* if */
        } /* if */

        /* we have data decoded and ready to write to the device... */
        cpysize = len - bw;  /* len - bw == amount device still wants. */
        if (cpysize > data->decoded_bytes)
            cpysize = data->decoded_bytes;  /* clamp to what we have left. */

        /* if it's 0, next iteration will decode more or decide we're done. */
        if (cpysize > 0)
        {
            /* write this iteration's data to the device. */
            memcpy(stream + bw, (Uint8 *) data->decoded_ptr, cpysize);

            /* update state for next iteration or callback */
            bw += cpysize;
            data->decoded_ptr += cpysize;
            data->decoded_bytes -= cpysize;
        } /* if */
    } /* while */
} /* audio_callback */


@implementation vMainViewController
{
    NSURL* _url;
}

//MARK: OVERRIDE

- (void)viewDidLoad {
    [super viewDidLoad];
    self.url = NULL;
}

//MARK: GET/SET

- (void)setUrl:(NSURL *)url{
    _url = url;
    if (url != NULL) {
        NSImage* image = NULL;
        [url getResourceValue: &image forKey: NSURLEffectiveIconKey error:NULL];
        self.imageView.image = image;
        self.nameTextField.stringValue = url.URLByDeletingPathExtension.lastPathComponent;
        [self.playButton setEnabled: YES];
        [NSDocumentController.sharedDocumentController noteNewRecentDocumentURL: url];
    } else {
        self.imageView.image = NULL;
        self.nameTextField.objectValue = NULL;
        [self.playButton setEnabled: NO];
    }
}

- (NSURL*)url{
    return _url;
}

- (void)setRepresentedObject:(id)representedObject{
    if ([representedObject isKindOfClass: NSURL.class]) {
        self.url = representedObject;
        return;
    }
    if ([representedObject isKindOfClass: NSString.class]) {
        self.url = [NSURL fileURLWithPath:representedObject];
        return;
    }
}

- (NSArray<UTType*>*)allowedContentTypes{
    NSMutableArray<UTType*>* array = [NSMutableArray new];
    const Sound_DecoderInfo** decoders = Sound_AvailableDecoders();
    if (decoders == NULL || *decoders == NULL) {
        return array;
    }
    do {
        const Sound_DecoderInfo* info = *decoders;
        if (info->extensions != NULL) {
            const char ** extensions = info->extensions;
            if (*extensions != NULL) {
                do {
                    NSString* string = [NSString stringWithCString:*extensions encoding:NSUTF8StringEncoding];
                    if (string != NULL) {
                        UTType* type = [UTType typeWithFilenameExtension:string];
                        if (type != NULL){
                            [array addObject:type];
                        }
                    }
                } while (*(++extensions) != NULL);
            }
        }
    } while (*(++decoders) != NULL);
    return array;
}

//MARK: FUNC

- (void)playOneSoundFile:(NSURL*)url {
    
    PlaysoundAudioCallbackData data;
    const char* fname = url.path.UTF8String;

    memset(&data, '\0', sizeof (PlaysoundAudioCallbackData));
    data.sample = Sound_NewSampleFromFile(fname, NULL, 65536);
    if (data.sample == NULL) {
        NSLog(@"Couldn't load '%s': %s.", fname, Sound_GetError());
        return;
    } /* if */

    /*
     * Open device in format of the the sound to be played.
     *  We open and close the device for each sound file, so that SDL
     *  handles the data conversion to hardware format; this is the
     *  easy way out, but isn't practical for most apps. Usually you'll
     *  want to pick one format for all the data or one format for the
     *  audio device and convert the data when needed. This is a more
     *  complex issue than I can describe in a source code comment, though.
     */
    data.devformat.freq = data.sample->actual.rate;
    data.devformat.format = data.sample->actual.format;
    data.devformat.channels = data.sample->actual.channels;
    data.devformat.samples = 4096;  /* I just picked a largish number here. */
    data.devformat.callback = audio_callback;
    data.devformat.userdata = &data;
    if (SDL_OpenAudio(&data.devformat, NULL) < 0) {
        NSLog(@"Couldn't open audio device: %s.", SDL_GetError());
        Sound_FreeSample(data.sample);
        return;
    } /* if */

    NSLog(@"Now playing [%s]...", fname);
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
    SDL_Delay(2 * 1000 * data.devformat.samples / data.devformat.freq);

    /* if there was an error, tell the user. */
    if (data.sample->flags & SOUND_SAMPLEFLAG_ERROR) {
        NSLog(@"Error decoding file: %s", Sound_GetError());
    }

    Sound_FreeSample(data.sample);  /* clean up SDL_Sound resources... */
    SDL_CloseAudio();  /* will reopen with next file's format. */
    NSLog(@"Playback completed [%s]", fname);
}

//MARK: ACTION

- (IBAction)openDocument:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = self.allowedContentTypes;
    if ([panel runModal] != NSModalResponseOK){
        return;
    }
    self.url = panel.URL;
}

- (IBAction)helpClick:(id)sender {
    NSMutableArray<NSString*>* array = [NSMutableArray new];
    const Sound_DecoderInfo** decoders = Sound_AvailableDecoders();
    if (decoders != NULL && *decoders != NULL) {
        do {
            NSMutableArray<NSString*>* array_info = [NSMutableArray new];
            const Sound_DecoderInfo* info = *decoders;
            if (info->extensions != NULL) {
                NSMutableArray<NSString*>* array_extensions = [NSMutableArray new];
                const char ** extensions = info->extensions;
                if (*extensions != NULL) {
                    do {
                        NSString* string = [NSString stringWithCString:*extensions encoding:NSUTF8StringEncoding];
                        if (string != NULL) {
                            [array_extensions addObject:string];
                        }
                    } while (*(++extensions) != NULL);
                } else {
                    [array_extensions addObject:@"?"];
                }
                [array_info addObject: [array_extensions componentsJoinedByString:@", "]];
            }
            if (info->description != NULL) {
                NSString* string = [NSString stringWithCString:info->description encoding:NSUTF8StringEncoding];
                if (string != NULL) {
                    [array_info addObject:string];
                }
            }
            if (info->author != NULL) {
                NSString* string = [NSString stringWithCString:info->author encoding:NSUTF8StringEncoding];
                if (string != NULL) {
                    [array_info addObject:string];
                }
            }
            if (info->url != NULL) {
                NSString* string = [NSString stringWithCString:info->url encoding:NSUTF8StringEncoding];
                if (string != NULL) {
                    [array_info addObject:string];
                }
            }
            [array addObject: [array_info componentsJoinedByString:@"\n"]];
        } while (*(++decoders) != NULL);
    }
    Sound_Version version;
    Sound_GetLinkedVersion(&version);
    NSAlert* alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.informativeText = array.count > 0 ? [array componentsJoinedByString: @"\n\n"] : @"Empty";
    alert.messageText = [NSString stringWithFormat:@"Version: %i.%i.%i\nSupported formats:", version.major, version.minor, version.patch];
    [alert runModal];
}

-(IBAction)playClick:(id)sender {
    if (self.url == NULL) {
        return;
    }
    [self performSelectorInBackground:@selector(playOneSoundFile:) withObject:self.url];
}

@end
