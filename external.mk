include $(sort $(wildcard $(BR2_EXTERNAL_SPEECH_OS_PATH)/package/*/*.mk))


PYTHON_NUMPY_CONF_OPTS += -Dblas=openblas -Dlapack=openblas
PYTHON_NUMPY_DEPENDENCIES += openblas

# WPE WebKit's unified sources take up to 3-4 GB of memory each to compile,
# so a job per core runs a 4 core, 16 GB machine (a GitHub runner, the build
# server) out of memory: the kernel kills cc1plus. One job per 4 GB, at most
# PARALLEL_JOBS. Passed to ninja after cmake's own -j, and the last one wins.
WPEWEBKIT_JOBS := $(shell awk -v jobs=$(PARALLEL_JOBS) \
	'/^MemTotal/ { n = int($$2 / 4194304); print (n < 1 ? 1 : (n < jobs ? n : jobs)) }' \
	/proc/meminfo 2>/dev/null || echo 1)
WPEWEBKIT_BUILD_OPTS += -- -j$(WPEWEBKIT_JOBS)
