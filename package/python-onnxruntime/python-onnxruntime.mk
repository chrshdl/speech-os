################################################################################
#
# python-onnxruntime
#
################################################################################

# The official wheel, which bundles libonnxruntime. It is built for one
# CPython ABI, so a Buildroot bump that changes the Python minor version
# must pin the matching wheel (and its hash) here; the check below makes
# that a configure-time error instead of an image that fails to import.
PYTHON_ONNXRUNTIME_VERSION = 1.31.0
PYTHON_ONNXRUNTIME_PYTHON_VERSION = 3.14
PYTHON_ONNXRUNTIME_SOURCE = onnxruntime-$(PYTHON_ONNXRUNTIME_VERSION)-cp314-cp314-manylinux_2_28_aarch64.whl
PYTHON_ONNXRUNTIME_SITE = https://files.pythonhosted.org/packages/37/fb/8be04665b700cb6e874d944e9932bb3c3969d3f53e820f5c42bfd26565d0

PYTHON_ONNXRUNTIME_LICENSE = MIT
PYTHON_ONNXRUNTIME_LICENSE_FILES = onnxruntime/LICENSE onnxruntime/ThirdPartyNotices.txt

PYTHON_ONNXRUNTIME_DEPENDENCIES = python3

ifeq ($(BR2_PACKAGE_PYTHON_ONNXRUNTIME),y)
ifneq ($(PYTHON3_VERSION_MAJOR),$(PYTHON_ONNXRUNTIME_PYTHON_VERSION))
$(error python-onnxruntime: the wheel is for Python $(PYTHON_ONNXRUNTIME_PYTHON_VERSION), the target has Python $(PYTHON3_VERSION_MAJOR); pin the wheel for it)
endif
endif

define PYTHON_ONNXRUNTIME_EXTRACT_CMDS
	$(UNZIP) -d $(@D) $(PYTHON_ONNXRUNTIME_DL_DIR)/$(PYTHON_ONNXRUNTIME_SOURCE)
endef

# The dist-info goes along: onnxruntime looks itself up with
# importlib.metadata at import time.
define PYTHON_ONNXRUNTIME_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages
	cp -dR --no-preserve=ownership \
		$(@D)/onnxruntime \
		$(@D)/onnxruntime-$(PYTHON_ONNXRUNTIME_VERSION).dist-info \
		$(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/
endef

$(eval $(generic-package))
