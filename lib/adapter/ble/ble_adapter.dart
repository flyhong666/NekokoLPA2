/// Marker shared by every adapter that communicates over Bluetooth LE.
///
/// Lets code that only cares whether a reader is on a BLE link -- foreground
/// session handling, notification gating -- test for it without naming each
/// adapter, and without adapters having to share a base class.
abstract interface class BleAdapter {}
