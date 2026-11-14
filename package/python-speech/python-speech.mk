################################################################################
#
# python-speech
#
################################################################################

# A commit on master, the merge of PR #46: the radio plays the TOGGO
# channel radio.toggo.de's own page plays, such as its Christmas channel,
# and follows the songs of the channel its stream says it plays, as the main
# channel went silent. After the merge of PR #45 (the README's use of the
# app in the browser and its architecture), of PR #44 (the backend runs
# without its microphone, such as the USB speakerphone unplugged at boot,
# and notices it unplugged and plugged in again, which the client shows on
# its microphone button), of PR #43 (Snake, played by voice with "up",
# "down", "left" and "right", up to 5 levels of walls, commands matched as
# they are said, and 5 seconds without speech ending a capture by default),
# of PR #42 (the drums, a kit on the screen that plays recordings of each
# drum, web/assistant/drums, opened by a button or "play the drums", and the
# volume and the brightness shown as popups over whatever shows), of PR #41
# (TOGGO Radio, decoded by the backend with ffmpeg, "olivia" heard by the
# speech model while the radio plays, the Jabra's own volume keys, and the X
# of "Listening..." cancelling the capture), of PR #36 (the wake word
# "olivia" behind a voice activity detector, --wake-word, --vad,
# models/wake-word and models/vad, confirmed by the speech model, and the
# speakerphone's volume turned by voice, --volume-control) and of PR #35
# (songs and a keyboard on the screen played with a Roland D-50's voice,
# Fantasia, interpolated word LMs and the backend's LM settings, see
# models/backend-args, features computed with NumPy, and the weather spoken
# with a Piper voice, --voice). The newest tag, v0.1.0, predates backend.py.
# Fetched with git rather than as a GitHub codeload tarball: GitHub has
# changed the bytes of its generated archives before, which broke sha256
# pins, while Buildroot builds a reproducible archive of the git tree
# itself.
PYTHON_SPEECH_VERSION = 02a332f4e68f0b01d2bf23c753596844e7f55da4
PYTHON_SPEECH_SITE = https://github.com/chrshdl/speech.git
PYTHON_SPEECH_SITE_METHOD = git

PYTHON_SPEECH_LICENSE = Apache-2.0, OFL-1.1 (Fredoka font)
PYTHON_SPEECH_LICENSE_FILES = LICENSE web/assistant/fonts/OFL.txt

PYTHON_SPEECH_DEPENDENCIES = host-python3 python3

# speech/backend/app.py serves the browser client from web/, which it finds
# relative to the package (speech/backend/../../web). So the repository
# layout is installed as is, not as a wheel into site-packages, which would
# leave web/ behind. Training scripts, tests and examples stay out.
PYTHON_SPEECH_APP_DIR = /usr/lib/speech

# Buildroot byte-compiles only /usr/lib/python3.x, and the rootfs is read
# only, so without this every start would compile the app in memory again.
# unchecked-hash: the .pyc files are used without comparing timestamps with
# the sources, which the image build is free to change.
define PYTHON_SPEECH_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)$(PYTHON_SPEECH_APP_DIR)
	$(INSTALL) -D -m 0644 $(@D)/backend.py $(TARGET_DIR)$(PYTHON_SPEECH_APP_DIR)/backend.py
	cp -dR --no-preserve=ownership $(@D)/speech $(@D)/web $(TARGET_DIR)$(PYTHON_SPEECH_APP_DIR)/
	find $(TARGET_DIR)$(PYTHON_SPEECH_APP_DIR) -name __pycache__ -prune -exec rm -rf {} +
	$(HOST_DIR)/bin/python3 -m compileall -q \
		--invalidation-mode unchecked-hash \
		-s $(TARGET_DIR) -p / \
		$(TARGET_DIR)$(PYTHON_SPEECH_APP_DIR)
endef

# audio for the microphone, netdev for wpa_supplicant's control socket,
# through which the client joins a Wi-Fi network (--wifi-interface), video
# for the backlight, whose brightness the user can set (--backlight; the
# rules.d/86-backlight.rules of the rootfs overlay lets video write it), input
# for the speakerphone's volume keys (--volume-control).
define PYTHON_SPEECH_USERS
	speech -1 speech -1 * - - audio,netdev,video,input Speech recognition service
endef

define PYTHON_SPEECH_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(PYTHON_SPEECH_PKGDIR)/speech-backend.service \
		$(TARGET_DIR)/usr/lib/systemd/system/speech-backend.service
	$(INSTALL) -D -m 0644 $(PYTHON_SPEECH_PKGDIR)/speech-preload.service \
		$(TARGET_DIR)/usr/lib/systemd/system/speech-preload.service
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /usr/lib/systemd/system/speech-backend.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/speech-backend.service
endef

$(eval $(generic-package))
