// http://wiki.amigaos.net/index.php/Keymap_Library
// http://www.win.tue.nl/~aeb/linux/kbd/scancodes-14.html

#define MISS  0xff
#define KEYCODE_MAX (0x6f)

// The original minimig had the keyboard connected to the FPGA. Thus all key events (even for OSD)
// came from the FPGA core. The MIST has the keyboard attached to the arm controller. To be compatible
// with the minimig core all keys (incl. OSD!) are forwarded to the FPGA and the OSD keys are returned.
// These keys are tagged with the "OSD" flag
// The atari/mist core does not forwards keys through the FPGA but queues them inside the arm controller.
// These keys are tagged with the "OSD_LOC" flag. The keycodes itself used are identical between OSD
// and OSD_LOC

#define OSD               0x0100     // to be used by OSD, not the core itself
#define OSD_LOC           0x0200     // OSD key not forwarded to core, but queued in arm controller
#define CAPS_LOCK_TOGGLE  0x0400     // caps lock toggle behaviour
#define NUM_LOCK_TOGGLE   0x0800
#define EXT               0x1000     // extended PS/2 keycode

const unsigned short ps2_modifier[] = 
      { 0x14, 0x12, 0x11, EXT|0x1f, EXT|0x14, 0x59, EXT|0x11, EXT|0x27 };

// keycode translation table for ps2 emulation
const unsigned short usb2ps2[] = {
  MISS,  // 00: NoEvent
  MISS,  // 01: Overrun Error
  MISS,  // 02: POST fail
  MISS,  // 03: ErrorUndefined
  0x1c,  // 04: a
  0x32,  // 05: b
  0x21,  // 06: c
  0x23,  // 07: d
  0x24,  // 08: e
  0x2b,  // 09: f
  0x34,  // 0a: g
  0x33,  // 0b: h
  0x43,  // 0c: i
  0x3b,  // 0d: j
  0x42,  // 0e: k
  0x4b,  // 0f: l
  0x3a,  // 10: m
  0x31,  // 11: n
  0x44,  // 12: o
  0x4d,  // 13: p
  0x15,  // 14: q
  0x2d,  // 15: r
  0x1b,  // 16: s
  0x2c,  // 17: t
  0x3c,  // 18: u
  0x2a,  // 19: v
  0x1d,  // 1a: w
  0x22,  // 1b: x
  0x35,  // 1c: y
  0x1a,  // 1d: z
  0x16,  // 1e: 1
  0x1e,  // 1f: 2
  0x26,  // 20: 3
  0x25,  // 21: 4
  0x2e,  // 22: 5
  0x36,  // 23: 6
  0x3d,  // 24: 7
  0x3e,  // 25: 8
  0x46,  // 26: 9
  0x45,  // 27: 0
  0x5a,  // 28: Return
  0x76,  // 29: Escape
  0x66,  // 2a: Backspace
  0x0d,  // 2b: Tab
  0x29,  // 2c: Space
  0x4e,  // 2d: -
  0x55,  // 2e: =
  0x54,  // 2f: [
  0x5b,  // 30: ]
  0x5d,  // 31: backslash
  0x5d,  // 32: Europe 1
  0x4c,  // 33: ; 
  0x52,  // 34: '
  0x0e,  // 35: `
  0x41,  // 36: ,
  0x49,  // 37: .
  0x4a,  // 38: /
  0x58,  // 39: Caps Lock
  0x05,  // 3a: F1
  0x06,  // 3b: F2
  0x04,  // 3c: F3
  0x0c,  // 3d: F4
  0x03,  // 3e: F5
  0x0b,  // 3f: F6
  0x83,  // 40: F7
  0x0a,  // 41: F8
  0x01,  // 42: F9
  0x09,  // 43: F10
  0x78,  // 44: F11
  OSD_LOC | 0x07,  // 45: F12 (OSD)
  EXT | 0x7c, // 46: Print Screen
  NUM_LOCK_TOGGLE,  // 47: Scroll Lock
  0x77,  // 48: Pause (special key handled inside user_io)
  EXT | 0x70, // 49: Insert
  EXT | 0x6c, // 4a: Home
  EXT | 0x7d, // 4b: Page Up
  EXT | 0x71, // 4c: Delete
  EXT | 0x69, // 4d: End
  EXT | 0x7a, // 4e: Page Down
  EXT | 0x74, // 4f: Right Arrow
  EXT | 0x6b, // 50: Left Arrow
  EXT | 0x72, // 51: Down Arrow
  EXT | 0x75, // 52: Up Arrow
  NUM_LOCK_TOGGLE,  // 53: Num Lock
  EXT | 0x4a, // 54: KP /
  0x7c,  // 55: KP *
  0x7b,  // 56: KP -
  0x79,  // 57: KP +
  EXT | 0x5a, // 58: KP Enter
  0x69,  // 59: KP 1
  0x72,  // 5a: KP 2
  0x7a,  // 5b: KP 3
  0x6b,  // 5c: KP 4
  0x73,  // 5d: KP 5
  0x74,  // 5e: KP 6
  0x6c,  // 5f: KP 7
  0x75,  // 60: KP 8
  0x7d,  // 61: KP 9
  0x70,  // 62: KP 0
  0x71,  // 63: KP .
  0x61,  // 64: Europe 2
  EXT | 0x2f, // 65: App
  EXT | 0x37, // 66: Power
  0x0f,  // 67: KP =
  0x08,  // 68: F13
  0x10,  // 69: F14
  0x18,  // 6a: F15
  0x20,  // 6b: F16
  0x28,  // 6c: F17
  0x30,  // 6d: F18
  0x38,  // 6e: F19
  0x40   // 6f: F20
};

