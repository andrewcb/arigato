//
//  PyAudioUnit.m
//  PyArigato
//
//  Created by acb on 2020-06-21.
//  Copyright © 2020 acb. All rights reserved.
//
//  A wrapper for an AVAudioUnit

#import <Foundation/Foundation.h>
#include <Python/Python.h>
#include <Python/structmember.h>
#import <AVFoundation/AVFoundation.h>

#import  "PyAudioUnit.h"

static void
AudioUnit_dealloc(arigato_AudioUnit *self) {
    self->audioUnit = NULL;
}
//MARK: mapping methodws


//MARK: methods

static PyMethodDef AudioUnit_methods[] = {
//    { "increment",  (PyCFunction)Counter_increment, METH_NOARGS, "Increment the counter" },
//    { "reset",  (PyCFunction)Counter_reset, METH_NOARGS, "Reset the counter" },
    {NULL}  /* Sentinel */
};

//MARK: getters/setters

static PyGetSetDef AudioUnit_getsetters[] = {
    { NULL }
};

//MARK: other functions
static PyObject *
AudioUnit_repr(arigato_AudioUnit *self) {
    // TODO: add some more info here
    return PyString_FromFormat("<arigato.AudioUnit>");
}

PyTypeObject arigato_AudioUnitType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "arigato.AudioUnit",             /* tp_name */
    sizeof(arigato_AudioUnit), /* tp_basicsize */
    0,                         /* tp_itemsize */
    (destructor)AudioUnit_dealloc, /* tp_dealloc */
    0,                         /* tp_print */
    0,                         /* tp_getattr */
    0,                         /* tp_setattr */
    0,                         /* tp_compare */
    (reprfunc)AudioUnit_repr,    /* tp_repr */
    0,                         /* tp_as_number */
    0,                         /* tp_as_sequence */
    0,                         /* tp_as_mapping */
    0,                         /* tp_hash */
    0,                         /* tp_call */
    0,                         /* tp_str */
    0,                         /* tp_getattro */
    0,                         /* tp_setattro */
    0,                         /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT,        /* tp_flags */
    "AudioUnit",                    /* tp_doc */
    0,                         /* tp_traverse */
    0,                         /* tp_clear */
    0,                         /* tp_richcompare */
    0,                         /* tp_weaklistoffset */
    0,                         /* tp_iter */
    0,                         /* tp_iternext */
    AudioUnit_methods,              /* tp_methods */
    0,                         /* tp_members */
    AudioUnit_getsetters,           /* tp_getset */
    0,                         /* tp_base */
    0,                         /* tp_dict */
    0,                         /* tp_descr_get */
    0,                         /* tp_descr_set */
    0,                         /* tp_dictoffset */
    0,                         /* tp_init */
    0,                         /* tp_alloc */
    0,                         /* tp_new */

};

/// internal function to create an AudioUnit wrapper

arigato_AudioUnit *
wrapAudioUnit(AVAudioUnit *au) {
    arigato_AudioUnit *self = PyType_GenericAlloc(&arigato_AudioUnitType, 0);
    if (self != NULL) {
        self->audioUnit = au;
    }
    return self;
}
