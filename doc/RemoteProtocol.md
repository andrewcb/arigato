# The Arigato remote protocol

Arigato includes, as one option for use, an IP-based protocol for accessing and playing an AudioUnit network. In this case,  the network is hosted by a server, such as the `arighost` command-line application or `ARigEditor`, and one or more clients connect to the port it listens on, make queries about the network and send events to be transformed into MIDI events sent to AudioUnits.

The remote protocol is actually two protocols: a TCP-based query protocol, for looking up node IDs, and a UDP packet-based protocol for sending events to be played. The UDP protocol is a binary protocol, which uses integer node IDs, not guaranteed to remain constant between sessions, to identify nodes; as nodes are identified by names,  the TCP protocol is used to obtain a list of nodes. For convenience, the TCP and UDP servers are listening on the same port.

## The TCP query protocol

The TCP protocol is a line-based protocol. Commands are sent as lines of text, and results are returned in JSON format. The response is  a JSON dictionary object, with a boolean `success` field, indicating whether the  command was successful, and if so, a `result` field containing the data, or if not, an `error` field with a string value.

Currently only one command is recognised, `ls`,  which lists all values of a resource. `ls` takes an argument, what it  is meant to list. Currently the options are:

* `ls nodes` -- Return a list of all nodes in the AudioUnit graph, giving for each an ID and name. 

(The argument to `ls` is a path in a query language which will eventually encompass the object model within an Arigato AudioUnit network.)

## The UDP event protocol

The UDP protocol is a packet-based protocol, with each packet containing one event.  Each packet starts with a 4-byte value, giving an event type; the event types are also, in keeping with Apple platform traditions, 4-character strings. All values are little-endian.

The packet types currently recognised are:

Type | Description | Values
-----|-------------|-------
|*MdEv* (0x7645644d)  | MIDI event  (2/3 byte)  | Node ID (uint32), MIDI event bytes 

## Security considerations

There are none; it is assumed that this is running on a trusted network, and the scope of the protocols is sufficiently narrow to make them relatively safe. At some point in the future, if demand necessitates it, an optional authentication mechanism may be added to the protocols.