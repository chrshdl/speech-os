################################################################################
#
# python-rapidfuzz
#
################################################################################

PYTHON_RAPIDFUZZ_VERSION = 3.14.6
PYTHON_RAPIDFUZZ_SOURCE = rapidfuzz-$(PYTHON_RAPIDFUZZ_VERSION).tar.gz
PYTHON_RAPIDFUZZ_SITE = https://files.pythonhosted.org/packages/18/97/226c43b7b5d957bc3840ed52ea99eed261f99834c4619be7a4742cbaeafa

PYTHON_RAPIDFUZZ_LICENSE = MIT
PYTHON_RAPIDFUZZ_LICENSE_FILES = LICENSE

PYTHON_RAPIDFUZZ_DEPENDENCIES = python3

# Only the Python modules: each C++ module (fuzz_cpp, process_cpp_impl, ...)
# has a pure Python twin (fuzz_py, process_py, ...) that rapidfuzz imports
# when the C++ one is missing. speech matches a transcript against ~700
# place names once per weather question, a few ms in pure Python.
define PYTHON_RAPIDFUZZ_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages
	rsync -a --prune-empty-dirs \
		--include='*/' --include='*.py' --include='py.typed' --exclude='*' \
		$(@D)/src/rapidfuzz \
		$(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/
endef

$(eval $(generic-package))
