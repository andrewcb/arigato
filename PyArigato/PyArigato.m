//
//  PyArigato.m
//  PyArigato
//
//  Created by acb on 2020-06-21.
//  Copyright © 2020 acb. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <Python/Python.h>
#include <Python/structmember.h>
#import "arigato-Swift.h"

#include "PyARig.h"

static PyObject *ArigatoError;


static PyMethodDef ArigatoMethods[] = {
    {NULL, NULL, 0, NULL}        /* Sentinel */
};


PyMODINIT_FUNC
initarigato(void)
{
    PyObject *m;
    
    if (PyType_Ready(&arigato_ARigType) < 0) {
        return;
    }

    m = Py_InitModule("arigato", ArigatoMethods);
    if (m == NULL)
        return;

    ArigatoError = PyErr_NewException("arigato.error", NULL, NULL);
    Py_INCREF(ArigatoError);
    PyModule_AddObject(m, "error", ArigatoError);
    
    Py_INCREF(&arigato_ARigType);
    PyModule_AddObject(m, "ARig", (PyObject *)&arigato_ARigType);
    
    NSLog(@"Available components: %@", [DiagGlue availableComponents]);
}
