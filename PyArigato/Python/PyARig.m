//
//  PyARig.m
//  PyArigato
//
//  Created by acb on 2020-06-21.
//  Copyright © 2020 acb. All rights reserved.
//
//  Python bindings for the top-level ARig object

#import <Foundation/Foundation.h>
#import <Python/Python.h>
#include <Python/structmember.h>
#import "arigato-Swift.h"
#import "PyAudioUnit.h"

typedef struct {
    PyObject_HEAD
    ARig *instance;
} arigato_ARig;

static PyObject *
ARig_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    arigato_ARig *self = type->tp_alloc(type, 0);
    if (self != NULL) {
        self->instance = [[ARig alloc] init];
    }
    
    return (PyObject *)self;
}

static void
ARig_dealloc(arigato_ARig *self) {
    self->instance = Nil;
}

static int
ARig_init(arigato_ARig *self, PyObject *args, PyObject *kw) {
    
    static char *kwlist[] = { "path",  NULL };
    
    char *path = NULL;
    
    if (!PyArg_ParseTupleAndKeywords(args, kw, "|s", kwlist, &path)) {
        return -1;
    }
    printf("parsed args: path = %p\n", path);
    
    if (path) {
        NSError *err = nil;
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithCString:path encoding:NSUTF8StringEncoding]];
        NSLog(@"url =  %@", url);
        if(url) {
            [self->instance loadFromURL:url error:&err];
            // TODO: convert the error into a Python error
            NSLog(@"*** loadFromURL: error = %@", err);
            if (err) {
                id ue = [[err userInfo] objectForKey:NSUnderlyingErrorKey];
                NSLog(@"--- underlying error = %@", ue);
            }
        }
    }
    return 0;
}

//MARK: mapping methodws

static PyObject *
ARig_subscript(arigato_ARig *self, PyObject *key) {
    if (PyString_Check(key)) {
        char *ckey = PyString_AsString(key);
        NSString *nskey = [NSString stringWithCString:ckey encoding:NSUTF8StringEncoding];
        AVAudioUnit *r = [self->instance audioUnitByName:nskey];
        NSLog(@"audioUnitByName:'%@' -> %p", nskey, r);
        if (r) {
            return (PyObject *)wrapAudioUnit(r);
        }
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMappingMethods ARig_mappingMethods = {
    0,                          // mp_length
    (binaryfunc)ARig_subscript, // mp_subscript
    0,                          // mp_ass_subscript
};

//MARK: methods

static PyMethodDef ARig_methods[] = {
    {NULL}  /* Sentinel */
};

//MARK: getters/setters

static PyGetSetDef ARig_getsetters[] = {
    { NULL }
};

//MARK: other functions
static PyObject *
ARig_repr(arigato_ARig *self) {
    // TODO: add some more info here
    return PyString_FromFormat("<arigato.ARig>");
}

//MARK: the type object

PyTypeObject arigato_ARigType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "arigato.ARig",             /* tp_name */
    sizeof(arigato_ARig),      /* tp_basicsize */
    0,                         /* tp_itemsize */
    (destructor)ARig_dealloc,  /* tp_dealloc */
    0,                         /* tp_print */
    0,                         /* tp_getattr */
    0,                         /* tp_setattr */
    0,                         /* tp_compare */
    (reprfunc)ARig_repr,       /* tp_repr */
    0,                         /* tp_as_number */
    0,                         /* tp_as_sequence */
    &ARig_mappingMethods,      /* tp_as_mapping */
    0,                         /* tp_hash */
    0,                         /* tp_call */
    0,                         /* tp_str */
    0,                         /* tp_getattro */
    0,                         /* tp_setattro */
    0,                         /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT,        /* tp_flags */
    "ARig",                    /* tp_doc */
    0,                         /* tp_traverse */
    0,                         /* tp_clear */
    0,                         /* tp_richcompare */
    0,                         /* tp_weaklistoffset */
    0,                         /* tp_iter */
    0,                         /* tp_iternext */
    ARig_methods,              /* tp_methods */
    0,                         /* tp_members */
    ARig_getsetters,           /* tp_getset */
    0,                         /* tp_base */
    0,                         /* tp_dict */
    0,                         /* tp_descr_get */
    0,                         /* tp_descr_set */
    0,                         /* tp_dictoffset */
    (initproc)ARig_init,       /* tp_init */
    0,                         /* tp_alloc */
    ARig_new,                  /* tp_new */
};
