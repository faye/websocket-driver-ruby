### 0.3.2 / 2013-12-29

* Expand `max_length` to cover sequences of continuation frames and `draft-{75,76}`
* Decrease default maximum frame buffer size to 64MB
* Stop parsing when the protocol enters a failure mode, to save CPU cycles

### 0.3.1 / 2013-12-03

* Add a `max_length` option to limit allowed frame size

### 0.3.0 / 2013-09-09

* Support client URLs with Basic Auth credentials

### 0.2.3 / 2013-08-04

* Fix bug in EventEmitter#emit when listeners are removed

### 0.2.2 / 2013-08-04

* Fix bug in EventEmitter#listener_count for unregistered events

### 0.2.1 / 2013-07-05

* Queue sent messages if the client has not begun trying to connect
* Encode all strings sent to I/O as `ASCII-8BIT`

### 0.2.0 / 2013-05-12

* Add API for setting and reading headers
* Add Driver.server() method for getting a driver for TCP servers

### 0.1.0 / 2013-05-04

* First stable release

### 0.0.0 / 2013-04-22

* First release
* Proof of concept for people to try out
* Might be unstable

