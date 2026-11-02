################################################################################
#
# python-piper-tts
#
################################################################################

# The official wheel: its espeakbridge extension has espeak-ng linked in
# statically, and needs only glibc 2.17, and espeak-ng's data comes along,
# so neither its scikit-build build nor espeak-ng's, which fetches it at
# configure time, runs here. It is built for CPython's stable ABI (abi3),
# so unlike onnxruntime's wheel it fits any Python 3 Buildroot has.
PYTHON_PIPER_TTS_VERSION = 1.8.0
PYTHON_PIPER_TTS_SOURCE = piper_tts-$(PYTHON_PIPER_TTS_VERSION)-cp39-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.manylinux_2_28_aarch64.whl
PYTHON_PIPER_TTS_SITE = https://files.pythonhosted.org/packages/5e/90/de832b09736db8c26c9b5dd25cb408ed065b1d9535e05c78947aec056e36

PYTHON_PIPER_TTS_LICENSE = GPL-3.0+ (piper, espeak-ng), Apache-2.0 (g2pW), MIT (Hebrew diacritizer)
PYTHON_PIPER_TTS_LICENSE_FILES = \
	piper_tts-$(PYTHON_PIPER_TTS_VERSION).dist-info/licenses/COPYING \
	piper_tts-$(PYTHON_PIPER_TTS_VERSION).dist-info/licenses/licenses/LICENSE.g2pW-Apache-2.0 \
	piper/hebrew/LICENSE

# The wheel is binary, so legal-info ships its GPL sources instead: Piper's
# at the release's tag (the PyPI sdist lacks the extension's C source), and
# the espeak-ng commit its CMakeLists.txt builds against (GIT_TAG). GitHub's
# generated archives, as Buildroot's github helper fetches them, hashed.
PYTHON_PIPER_TTS_ACTUAL_SOURCE_SITE = $(call github,OHF-Voice,piper1-gpl,v$(PYTHON_PIPER_TTS_VERSION))
PYTHON_PIPER_TTS_ACTUAL_SOURCE_TARBALL = piper1-gpl-$(PYTHON_PIPER_TTS_VERSION).tar.gz
PYTHON_PIPER_TTS_ESPEAK_NG_VERSION = 724808c5a83f9ef95fdd0db886ba7ba537ff224a
PYTHON_PIPER_TTS_EXTRA_DOWNLOADS = \
	$(call github,espeak-ng,espeak-ng,$(PYTHON_PIPER_TTS_ESPEAK_NG_VERSION))/espeak-ng-$(PYTHON_PIPER_TTS_ESPEAK_NG_VERSION).tar.gz

# onnxruntime and numpy are its runtime dependencies; pathvalidate, the
# wheel's third, only its command line and its training import.
PYTHON_PIPER_TTS_DEPENDENCIES = python3

define PYTHON_PIPER_TTS_EXTRACT_CMDS
	$(UNZIP) -d $(@D) $(PYTHON_PIPER_TTS_DL_DIR)/$(PYTHON_PIPER_TTS_SOURCE)
endef

# The package and its dist-info, but neither the `piper` command, which
# needs pathvalidate, nor the copy of the license the wheel puts in the
# prefix (.data/data).
define PYTHON_PIPER_TTS_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages
	cp -dR --no-preserve=ownership \
		$(@D)/piper \
		$(@D)/piper_tts-$(PYTHON_PIPER_TTS_VERSION).dist-info \
		$(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/
endef

$(eval $(generic-package))
