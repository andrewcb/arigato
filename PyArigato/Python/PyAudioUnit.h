//
//  PyAudioUnit.h
//  Arigato
//
//  Created by acb on 2020-06-21.
//  Copyright © 2020 acb. All rights reserved.
//

#ifndef PyAudioUnit_h
#define PyAudioUnit_h

typedef struct {
    PyObject_HEAD
    AVAudioUnit *audioUnit;
} arigato_AudioUnit;

arigato_AudioUnit * wrapAudioUnit(AVAudioUnit *au);

#endif /* PyAudioUnit_h */
