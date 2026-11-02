################################################################################
#
# rpi-firmware-start4
#
################################################################################

# A newer start4.elf/fixup4.dat than the ones of Buildroot's rpi-firmware,
# which keeps providing everything else (overlays, config.txt, cmdline.txt).
# Installed next to rpi-firmware's, not over them, so reinstalling either
# package in any order is safe; genimage.cfg takes these.
# Buildroot's (063bcab, Dec 2025) cannot start the VL805 USB controller on a
# Pi 4 whose bootloader EEPROM is from May 2026: xhci_hcd times out with
# -110 after 17 s, so there is no USB audio and speech-backend has no
# microphone. The firmware of the same period as the EEPROM can.
#
# Delete this package once Buildroot's rpi-firmware is at least this
# version; the check below stops the build when Buildroot moves.
RPI_FIRMWARE_START4_VERSION = 09267f5354d40519d82fbd2193b9e211ec304055
RPI_FIRMWARE_START4_SITE = https://raw.githubusercontent.com/raspberrypi/firmware/$(RPI_FIRMWARE_START4_VERSION)/boot
RPI_FIRMWARE_START4_SOURCE = start4.elf
RPI_FIRMWARE_START4_EXTRA_DOWNLOADS = fixup4.dat LICENCE.broadcom

RPI_FIRMWARE_START4_LICENSE = BSD-3-Clause
RPI_FIRMWARE_START4_LICENSE_FILES = LICENCE.broadcom

RPI_FIRMWARE_START4_INSTALL_TARGET = NO
RPI_FIRMWARE_START4_INSTALL_IMAGES = YES

RPI_FIRMWARE_START4_REPLACES = 063bcab6c8a90efb0d19f69d88cbbc7ec79cab68

ifeq ($(BR2_PACKAGE_RPI_FIRMWARE_START4),y)
ifneq ($(RPI_FIRMWARE_VERSION),$(RPI_FIRMWARE_START4_REPLACES))
$(error rpi-firmware-start4: Buildroot's rpi-firmware moved to $(RPI_FIRMWARE_VERSION); drop this package if that is at least $(RPI_FIRMWARE_START4_VERSION), else update RPI_FIRMWARE_START4_REPLACES)
endif
endif

define RPI_FIRMWARE_START4_EXTRACT_CMDS
	cp $(addprefix $(RPI_FIRMWARE_START4_DL_DIR)/,start4.elf fixup4.dat LICENCE.broadcom) $(@D)/
endef

define RPI_FIRMWARE_START4_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/start4.elf $(BINARIES_DIR)/rpi-firmware-start4/start4.elf
	$(INSTALL) -D -m 0644 $(@D)/fixup4.dat $(BINARIES_DIR)/rpi-firmware-start4/fixup4.dat
endef

$(eval $(generic-package))
