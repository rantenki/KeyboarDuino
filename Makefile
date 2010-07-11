# Arduino 0017 Makefile
# Arduino adaptation by mellis, eighthave, oli.keller,
# alex norman [with help from http://code.google.com/p/arduino/issues/detail?id=65#c5]
# Version 0017/Mac modifications made by
#	David Wolever 
#	http://blog.codekills.net/
#
# This makefile allows you to build sketches from the command line
# without the Arduino environment (or Java).
#
# Detailed instructions for using the makefile:
#
# 1. Copy this file into the folder with your sketch. There should be a
# file with the same name as the folder and with the extension .pde
# (e.g. foo.pde in the foo/ folder).
#
# 2. Modify the line containg "INSTALL_DIR" to point to the directory that
# contains the Arduino installation (for example, under Mac OS X, this
# might be /Applications/arduino-0012).
#
# 3. Modify the line containing "PORT" to refer to the filename
# representing the USB or serial connection to your Arduino board
# (e.g. PORT = /dev/tty.USB0). If the exact name of this file
# changes, you can use * as a wildcard (e.g. PORT = /dev/tty.usb*).
#
# 4. Set the line containing "BUILD_MCU" to match your board's processor.
# Older one's are atmega8 based, newer ones like Arduino Mini, Bluetooth
# or Diecimila have the atmega168. If you're using a LilyPad Arduino,
# change BUILD_F_CPU to 8000000.
#
# 5. At the command line, change to the directory containing your
# program's file and the makefile.
#
# 6. Type "make" and press enter to compile/verify your program.
#
# 7. Type "make upload", reset your Arduino board, and press enter to
# upload your program to the Arduino board.
#
# $Id$

TARGET = $(notdir $(CURDIR))
INSTALL_DIR = /home/enki/arduino
PORT = /dev/ttyUSB0
F_CPU=16000000

# Get these values from:
#	 $(INSTALL_DIR)/hardware/boards.txt
# The values below are for the "Arduino Duemilanove or Nano w/ ATmega328"
UPLOAD_SPEED = 57600
UPLOAD_PROTOCOL = stk500
BUILD_MCU = atmega328p
BUILD_F_CPU = 16000000

############################################################################
# Below here nothing should be changed...

ARDUINO = $(INSTALL_DIR)/hardware/arduino/cores/arduino
#AVR_TOOLS_PATH = $(INSTALL_DIR)/hardware/tools/avr/bin
AVRDUDE_PATH = $(INSTALL_DIR)/hardware/tools/
AVR_TOOLS_PATH = /usr/bin/
SRC = $(ARDUINO)/pins_arduino.c $(ARDUINO)/wiring.c \
	$(ARDUINO)/wiring_analog.c $(ARDUINO)/wiring_digital.c \
	$(ARDUINO)/wiring_pulse.c \
	$(ARDUINO)/wiring_shift.c $(ARDUINO)/WInterrupts.c \
	$(CURDIR)/UsbKeyboard/oddebug.c \
	$(CURDIR)/UsbKeyboard/usbdrv.o \
	$(CURDIR)/UsbKeyboard/usbdrvasm.o
# This next one needs to be manually made
#	$(CURDIR)/UsbKeyboard/usbdrv.c \
CXXSRC = $(ARDUINO)/HardwareSerial.cpp $(ARDUINO)/WMath.cpp \
	$(ARDUINO)/Print.cpp
FORMAT = ihex

# Name of this Makefile (used for "make depend").
MAKEFILE = Makefile

# Debugging format.
# Native formats for AVR-GCC's -g are stabs [default], or dwarf-2.
# AVR (extended) COFF requires stabs, plus an avr-objcopy run.
DEBUG = stabs

OPT = s

# Place -D or -U options here
CDEFS = -DBUILD_F_CPU=$(BUILD_F_CPU)
CXXDEFS = -DBUILD_F_CPU=$(BUILD_F_CPU)

# Place -I options here
CINCS = -I$(ARDUINO) -I$(CURDIR)/UsbKeyboard
CXXINCS = -I$(ARDUINO) -I$(CURDIR)/UsbKeyboard


# Compiler flag to set the C Standard level.
# c89 - "ANSI" C
# gnu89 - c89 plus GCC extensions
# c99 - ISO C99 standard (not yet fully implemented)
# gnu99 - c99 plus GCC extensions
CSTANDARD = -std=gnu99
CDEBUG = -g$(DEBUG)
CWARN = -Wall -Wstrict-prototypes
CTUNING = -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums
#CEXTRA = -Wa,-adhlns=$(<:.c=.lst)

CFLAGS = $(CDEBUG) $(CDEFS) $(CINCS) -O$(OPT) $(CWARN) $(CSTANDARD) $(CEXTRA)
CXXFLAGS = $(CDEFS) $(CINCS) -O$(OPT)
#ASFLAGS = -Wa,-adhlns=$(<:.S=.lst),-gstabs
LDFLAGS = -lm

# Programming support using avrdude. Settings and variables.
AVRDUDE_PORT = $(PORT)
AVRDUDE_WRITE_FLASH = -U flash:w:applet/$(TARGET).hex
AVRDUDE_FLAGS = -V -F \
	-p $(BUILD_MCU) -P $(AVRDUDE_PORT) -c $(UPLOAD_PROTOCOL) \
	-b $(UPLOAD_SPEED) -C $(INSTALL_DIR)/hardware/tools/avrdude.conf

# Program settings
CC = $(AVR_TOOLS_PATH)/avr-gcc
CXX = $(AVR_TOOLS_PATH)/avr-g++
OBJCOPY = $(AVR_TOOLS_PATH)/avr-objcopy
OBJDUMP = $(AVR_TOOLS_PATH)/avr-objdump
AR = $(AVR_TOOLS_PATH)/avr-ar
SIZE = $(AVR_TOOLS_PATH)/avr-size
NM = $(AVR_TOOLS_PATH)/avr-nm
AVRDUDE = $(AVRDUDE_PATH)/avrdude
REMOVE = rm -f
MV = mv -f

# Define all object files.
#OBJ = $(SRC:.c=.o) $(CXXSRC:.cpp=.o) $(ASRC:.S=.o) $(CURDIR)/UsbKeyboard/usbdrv.o 
OBJ = $(SRC:.c=.o) $(CXXSRC:.cpp=.o) $(ASRC:.S=.o) 

# Define all listing files.
LST = $(ASRC:.S=.lst) $(CXXSRC:.cpp=.lst) $(SRC:.c=.lst)

# Combine all necessary flags and optional flags.
# Add target processor to flags.
ALL_CFLAGS = -mmcu=$(BUILD_MCU) -I. $(CINCS) $(CFLAGS)
ALL_CXXFLAGS = -mmcu=$(BUILD_MCU) -I. $(CXXINCS) $(CXXFLAGS)
ALL_ASFLAGS = -mmcu=$(BUILD_MCU) -I. -x assembler-with-cpp $(ASFLAGS)

# Default target.
all: applet_files build sizeafter

build: elf hex

applet_files: $(TARGET).pde
	# Here is the "preprocessing".
	# It creates a .cpp file based with the same name as the .pde file.
	# On top of the new .cpp file comes the WProgram.h header.
	# At the end there is a generic main() function attached.
	# Then the .cpp file will be compiled. Errors during compile will
	# refer to this new, automatically generated, file.
	# Not the original .pde file you actually edit...
	test -d applet || mkdir applet
	echo '#include "WProgram.h"' > applet/$(TARGET).cpp
	cat $(TARGET).pde >> applet/$(TARGET).cpp
	cat $(ARDUINO)/main.cpp >> applet/$(TARGET).cpp

elf: applet/$(TARGET).elf
hex: applet/$(TARGET).hex
eep: applet/$(TARGET).eep
lss: applet/$(TARGET).lss
sym: applet/$(TARGET).sym

# Program the device.
upload: applet/$(TARGET).hex
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_WRITE_FLASH)

# Display size of file.
HEXSIZE = $(SIZE) --target=$(FORMAT) applet/$(TARGET).hex
ELFSIZE = $(SIZE) applet/$(TARGET).elf
sizebefore:
	@if [ -f applet/$(TARGET).elf ]; then echo; echo $(MSG_SIZE_BEFORE); $(HEXSIZE); echo; fi

sizeafter:
	@if [ -f applet/$(TARGET).elf ]; then echo; echo $(MSG_SIZE_AFTER); $(HEXSIZE); echo; fi

# Convert ELF to COFF for use in debugging / simulating in AVR Studio or VMLAB.
COFFCONVERT=$(OBJCOPY) --debugging \
	--change-section-address .data-0x800000 \
	--change-section-address .bss-0x800000 \
	--change-section-address .noinit-0x800000 \
	--change-section-address .eeprom-0x810000

coff: applet/$(TARGET).elf
	$(COFFCONVERT) -O coff-avr applet/$(TARGET).elf $(TARGET).cof

extcoff: $(TARGET).elf
	$(COFFCONVERT) -O coff-ext-avr applet/$(TARGET).elf $(TARGET).cof

.SUFFIXES: .elf .hex .eep .lss .sym

.elf.hex:
	$(OBJCOPY) -O $(FORMAT) -R .eeprom $< $@

.elf.eep:
	-$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom="alloc,load" \
	--change-section-lma .eeprom=0 -O $(FORMAT) $< $@

# Create extended listing file from ELF output file.
.elf.lss:
	$(OBJDUMP) -h -S $< > $@

# Create a symbol table from ELF output file.
.elf.sym:
	$(NM) -n $< > $@

# Link: create ELF output file from library.
applet/$(TARGET).elf: $(TARGET).pde applet/core.a
	$(CC) $(ALL_CFLAGS) -o $@ applet/$(TARGET).cpp -L. applet/core.a $(LDFLAGS)

applet/core.a: $(OBJ)
	@for i in $(OBJ); do echo $(AR) rcs applet/core.a $$i; $(AR) rcs applet/core.a $$i; done

# Compile: create object files from C++ source files.
.cpp.o:
	$(CXX) -c $(ALL_CXXFLAGS) $< -o $@

# Compile: create object files from C source files.
.c.o:
	$(CC) -c $(ALL_CFLAGS) $< -o $@

# Compile: create assembler files from C source files.
.c.s:
	$(CC) -S $(ALL_CFLAGS) $< -o $@

# Assemble: create object files from assembler source files.
.S.o:
	$(CC) -c $(ALL_ASFLAGS) $< -o $@

# Automatic dependencies
%.d: %.c
	$(CC) -M $(ALL_CFLAGS) $< | sed "s;$(notdir $*).o:;$*.o $*.d:;" > $@

%.d: %.cpp
	$(CXX) -M $(ALL_CXXFLAGS) $< | sed "s;$(notdir $*).o:;$*.o $*.d:;" > $@

# Target: clean project.
clean:
	$(REMOVE) applet/$(TARGET).hex applet/$(TARGET).eep applet/$(TARGET).cof applet/$(TARGET).elf \
		applet/$(TARGET).map applet/$(TARGET).sym applet/$(TARGET).lss applet/core.a \
		$(OBJ) $(LST) $(SRC:.c=.s) $(SRC:.c=.d) $(CXXSRC:.cpp=.s) $(CXXSRC:.cpp=.d)

.PHONY: all build elf hex eep lss sym program coff extcoff clean applet_files sizebefore sizeafter