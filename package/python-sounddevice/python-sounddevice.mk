################################################################################
#
# python-sounddevice
#
################################################################################

PYTHON_SOUNDDEVICE_VERSION = 0.5.6
PYTHON_SOUNDDEVICE_SOURCE = sounddevice-$(PYTHON_SOUNDDEVICE_VERSION).tar.gz
PYTHON_SOUNDDEVICE_SITE = https://files.pythonhosted.org/packages/ec/db/0c890e2d9aab9ba284021efc02e1d3aebfecab1b611762d7434602209bcf
PYTHON_SOUNDDEVICE_SETUP_TYPE = setuptools

PYTHON_SOUNDDEVICE_LICENSE = MIT
PYTHON_SOUNDDEVICE_LICENSE_FILES = LICENSE

# cffi generates the _sounddevice module (ABI mode, no compiler involved)
# at build time; PortAudio itself is loaded with dlopen() at import.
PYTHON_SOUNDDEVICE_DEPENDENCIES = host-python-cffi host-python-setuptools-scm portaudio

$(eval $(python-package))
