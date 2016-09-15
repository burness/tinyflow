ROOTDIR = $(CURDIR)


ifndef NNVM_PATH
	NNVM_PATH = $(ROOTDIR)/nnvm
endif

TORCH_PATH=${TORCH_HOME}

export LDFLAGS = -pthread -lm
export CFLAGS =  -std=c++11 -Wall -O2 -msse2  -Wno-unknown-pragmas -funroll-loops\
	  -fPIC -I${NNVM_PATH}/include -Iinclude -Idmlc-core/include

CFLAGS += -I$(TORCH_PATH)/install/include -I$(TORCH_PATH)/install/include/TH -I$(TORCH_PATH)/install/include/THC/
LDFLAGS += -L$(TORCH_PATH)/install/lib -lluajit -lluaT -lTH -lTHC

.PHONY: clean all test lint doc

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S), Darwin)
	WHOLE_ARCH= -all_load
	NO_WHOLE_ARCH= -noall_load
else
	WHOLE_ARCH= --whole-archive
	NO_WHOLE_ARCH= --no-whole-archive
endif

SRC = $(wildcard src/*.cc src/*/*.cc src/*/*/*.cc)
OBJ = $(patsubst %.cc, build/%.o, $(SRC))
CUSRC = $(wildcard src/*.cu src/*/*.cu src/*/*/*.cu)
CUOBJ = $(patsubst %.cu, build/%_gpu.o, $(CUSRC))

LIB_DEP = $(NNVM_PATH)/lib/libnnvm.a
ALL_DEP = $(OBJ) $(LIB_DEP)

build/src/%.o: src/%.cc
	@mkdir -p $(@D)
	$(CXX) -std=c++11 $(CFLAGS) -MM -MT build/src/$*.o $< >build/src/$*.d
	$(CXX) -std=c++11 -c $(CFLAGS) -c $< -o $@

build/src/%_gpu.o: src/%.cu
	@mkdir -p $(@D)
	$(NVCC) $(NVCCFLAGS) -Xcompiler "$(CFLAGS)" -M -MT build/src/$*_gpu.o $< >build/src/$*_gpu.d
	$(NVCC) -c -o $@ $(NVCCFLAGS) -Xcompiler "$(CFLAGS)" $<

lib/libtinyflow.so: $(ALL_DEP)
	@mkdir -p $(@D)
	$(CXX) $(CFLAGS) -shared -o $@ $(filter %.o, $^) $(LDFLAGS) \
	-Wl,${WHOLE_ARCH} $(filter %.a, $^) -Wl,${NO_WHOLE_ARCH}

lint:
	python2 dmlc-core/scripts/lint.py tinyflow cpp include src

clean:
	$(RM) -rf build lib bin *~ */*~ */*/*~ */*/*/*~ */*.o */*/*.o */*/*/*.o

-include build/*.d
-include build/*/*.d
-include build/*/*/*.d