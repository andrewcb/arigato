#  Arigato
Arigato is a lightweight, unopinionated system for preparing configurations of AudioUnit plugins such as software synthesisers and audio effects for scripting with code.

## The problem

AudioUnits are the native format for audio processing components on macOS, and are roughly analogous to VST plugins. If you use software synthesizers, samplers, effects units or similar on macOS systems, in DAWs like Logic, Garageband or Ableton Live, they will be available as AudioUnits. These components will be installed on your system, and available for use from any software supporting the AudioUnit API.

However, it can be inconvenient to programmatically prepare many AudioUnits for use in code. Complex instruments and effect in particular tend to have graphical user interfaces which are used for selecting or configuring their settings, with little non-graphical alternative. In particular, while these units may have lists of hundreds of presets, their internal preset-handling mechanisms are not exposed to the AudioUnit API.  So your options would be either to set all of the unit's parameters individually (and a complex synthesiser may have hundreds, from filter types to envelope breakpoints), or to individually configure each desired unit in your DAW of choice, save its state to an AudioUnit Preset (`.aupreset`) file, and then load those individually in code and assemble them into a network.

## The solution

Arigato provides a convenient one-stop alternative to this, in allowing an entire network of AudioUnits to be created in a graphical editor, saved to a file, and then loaded in your own code and played. Each AudioUnit in this network is also given a name, by which it can be referenced in your code. A saved  AudioUnit network with names is called an ARig, which is an  abbreviation for AudioUnit rig.

## Demo

There is a short video demonstrating Arigato in use [here](https://drive.google.com/file/d/125gF9MWGWI7WyF51RUHx2ZRIN4mG0LXt/view); it shows an ARig containing two software synthesisers and a delay being created, exported to an Xcode Playground, and then used to make a simple two-part melodic pattern.

## Language support

Arigato is written in Swift, and can be used from Swift code; currently its main use case is for using AudioUnits in Xcode Playgrounds. The code in  the `Arigato` group in the Xcode project can be copied into the `Sources` folder of an Xcode playground, allowing any ARig placed in its `Resources` folder to be loaded.  ARigEditor has the option of creating an Xcode Playground with the code and current ARig in place, and optionally some sample code in the Playground text. It is also possible to build Arigato to a framework for use in macOS Applications.

## Runtime APIs

Arigato is deliberately minimal and unopinionated, and hence does not provide any one model for runtime use, such as musical notation parsers, state machines, or models of rhythm or harmony;  the API exposed is the AudioUnit API, which consists of MIDI events and floating-point parameters. However, a few helper functions are provided, which are listed in the source file `Helpers.swift`. 

Below is an example of an Arigato script in an Xcode Playground.  This loads the AudioUnit network in the resource file named `audioSetup.arig`, fetches the instrument named `synth1` from  it, and then plays a sequence of four notes:

```swift
let arig = try ARig(fromResource: "audioSetup")

let synth = arig.midiInstrument(byName: "synth1")!

DispatchQueue.global().async {
    for note in [2, 5, 9, 12] {
        synth.play(note: UInt8(60+note), withVelocity: 90, onChannel: 0, forDuration: 0.25)
        sleep(for: 0.5)
    }
    PlaygroundPage.current.finishExecution()
}

PlaygroundPage.current.needsIndefiniteExecution = true
```

One thing to note is that this script is asynchronous, and runs on multiple threads, keeping time by pausing the current thread (with the `sleep(for:)` function). As such, it would be possible to add other voices, or processes controlling parameters, by  adding other dispatch queues.

## Future directions

Given Arigato's use case, it would be useful to develop bindings for it for various other languages, such as, for example, Python, JavaScript or various Lisp/Scheme dialects. These would allow scripts written in those languages to make use of AudioUnit networks authored with it, opening up the use of AudioUnit components to users of those languages, and the possibilities for its use in creative coding environments other than Xcode Playgrounds.

The ARig format is currently a single flat file, containing AudioUnit network data and the serialised state of each component. This does not store, for example, audio files or samples played by components such as  Apple's `AUAudioFilePlayer` and `AUSampler`. In future, it may be useful to have a bundle/directory format, which can store the AudioUnit network information as present as well as assets used by various components, allowing networks to be built containing pre-packaged audio files and sampler data in SoundFont format.

##  Author

Arigato was written by [Andrew Bulhak](https://github.com/andrewcb/).
