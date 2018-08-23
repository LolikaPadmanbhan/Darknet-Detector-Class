GPU=0
CUDNN=0
CUDNN_HALF=0
OPENCV=1
AVX=1
OPENMP=1
LIBSO=1

# set GPU=1 and CUDNN=1 to speedup on GPU
# set CUDNN_HALF=1 to further speedup 3 x times (Mixed-precision using Tensor Cores) on GPU Tesla V100, Titan V, DGX-2
# set AVX=1 and OPENMP=1 to speedup on CPU (if error occurs then set AVX=0)

DEBUG=0

ARCH= -gencode arch=compute_30,code=sm_30 \
      -gencode arch=compute_35,code=sm_35 \
      -gencode arch=compute_50,code=[sm_50,compute_50] \
      -gencode arch=compute_52,code=[sm_52,compute_52] \
	  -gencode arch=compute_61,code=[sm_61,compute_61]

OS := $(shell uname)

# Tesla V100
# ARCH= -gencode arch=compute_70,code=[sm_70,compute_70]

# GTX 1080, GTX 1070, GTX 1060, GTX 1050, GTX 1030, Titan Xp, Tesla P40, Tesla P4
# ARCH= -gencode arch=compute_61,code=sm_61 -gencode arch=compute_61,code=compute_61

# GP100/Tesla P100 � DGX-1
# ARCH= -gencode arch=compute_60,code=sm_60

# For Jetson Tx1 uncomment:
# ARCH= -gencode arch=compute_51,code=[sm_51,compute_51]

# For Jetson Tx2 or Drive-PX2 uncomment:
# ARCH= -gencode arch=compute_62,code=[sm_62,compute_62]


VPATH=./src/
EXEC=darknet
OBJDIR=./obj/

ifeq ($(LIBSO), 1)
LIBNAMESO=libs/darknet.so
#APPNAMESO=uselib
#TEST_APP=darknet_objdetect
#DATASET=darknet_dataset
DARKNET_CLASSIFIER_CONSOLE=darknet_classifier_console
DARKNET_DETECTOR_CONSOLE=darknet_detector_console
YOLO_PERSON_FACE_CONSOLE=yolo_person_face_console
#DARKNET_PERSON_FACE_TRACK=darknet_track
endif

CC=gcc
CPP=g++
NVCC=nvcc 
OPTS=-Ofast
LDFLAGS= -lm -pthread 
COMMON= 
CFLAGS=-Wall -Wfatal-errors -Wno-unused-result -Wno-unknown-pragmas

ifeq ($(DEBUG), 1) 
OPTS= -O0 -g
else
ifeq ($(AVX), 1) 
CFLAGS+= -ffp-contract=fast -mavx -msse4.1 -msse4a
endif
endif

CFLAGS+=$(OPTS)

ifeq ($(OPENCV), 1) 
COMMON+= -DOPENCV
CFLAGS+= -DOPENCV
LDFLAGS+= `pkg-config --libs opencv` 
COMMON+= `pkg-config --cflags opencv` 
endif

ifeq ($(OPENMP), 1)
CFLAGS+= -fopenmp
LDFLAGS+= -lgomp
endif

ifeq ($(GPU), 1)
COMMON+= -DGPU -I/usr/local/cuda/include/
CFLAGS+= -DGPU
ifeq ($(OS),Darwin) #MAC
LDFLAGS+= -L/usr/local/cuda/lib -lcuda -lcudart -lcublas -lcurand
else
LDFLAGS+= -L/usr/local/cuda/lib64 -lcuda -lcudart -lcublas -lcurand
endif
endif

ifeq ($(CUDNN), 1)
COMMON+= -DCUDNN
ifeq ($(OS),Darwin) #MAC
CFLAGS+= -DCUDNN -I/usr/local/cuda/include
LDFLAGS+= -L/usr/local/cuda/lib -lcudnn
else
CFLAGS+= -DCUDNN -I/usr/local/cudnn/include
LDFLAGS+= -L/usr/local/cudnn/lib64 -lcudnn
endif
endif

ifeq ($(CUDNN_HALF), 1)
COMMON+= -DCUDNN_HALF
CFLAGS+= -DCUDNN_HALF
ARCH+= -gencode arch=compute_70,code=[sm_70,compute_70]
endif

OBJ=http_stream.o gemm.o utils.o cuda.o convolutional_layer.o list.o image.o activations.o im2col.o col2im.o blas.o crop_layer.o dropout_layer.o maxpool_layer.o softmax_layer.o data.o matrix.o network.o connected_layer.o cost_layer.o parser.o option_list.o darknet.o detection_layer.o captcha.o route_layer.o writing.o box.o nightmare.o normalization_layer.o avgpool_layer.o coco.o dice.o yolo.o detector.o layer.o compare.o classifier.o local_layer.o swag.o shortcut_layer.o activation_layer.o rnn_layer.o gru_layer.o rnn.o rnn_vid.o crnn_layer.o demo.o tag.o cifar.o go.o batchnorm_layer.o art.o region_layer.o reorg_layer.o reorg_old_layer.o super.o voxel.o tree.o yolo_layer.o upsample_layer.o
ifeq ($(GPU), 1) 
LDFLAGS+= -lstdc++ 
OBJ+=convolutional_kernels.o activation_kernels.o im2col_kernels.o col2im_kernels.o blas_kernels.o crop_layer_kernels.o dropout_layer_kernels.o maxpool_layer_kernels.o network_kernels.o avgpool_layer_kernels.o
endif

OBJS = $(addprefix $(OBJDIR), $(OBJ))
DEPS = $(wildcard src/*.h) Makefile

all: obj backup results $(EXEC) $(LIBNAMESO) $(DARKNET_CLASSIFIER_CONSOLE) $(DARKNET_DETECTOR_CONSOLE) $(YOLO_PERSON_FACE_CONSOLE)

ifeq ($(LIBSO), 1) 
CFLAGS+= -fPIC -g

$(LIBNAMESO): $(OBJS) src/yolo_v2_class.hpp src/yolo_v2_class.cpp
	$(CPP) -shared -std=c++11 -fvisibility=hidden -DYOLODLL_EXPORTS $(COMMON) $(CFLAGS) $(OBJS) src/yolo_v2_class.cpp -o $@ $(LDFLAGS)
	
$(APPNAMESO): $(LIBNAMESO) src/yolo_v2_class.hpp src/yolo_console_dll.cpp
	$(CPP) -std=c++11 $(COMMON) $(CFLAGS) -o $@ src/yolo_console_dll.cpp $(LDFLAGS) -L ./ -l:$(LIBNAMESO)

$(TEST_APP):  $(LIBNAMESO) src/yolo_object_detect.hpp src/yolo_object_detect.cpp
	$(CPP) -std=c++11 $(COMMON) $(CFLAGS) -o $@ src/yolo_object_detect.cpp $(LDFLAGS) -L ./ -l:$(LIBNAMESO)

$(DATASET):  $(LIBNAMESO) src/yolo_dataset.hpp src/yolo_dataset.cpp
	$(CPP) -std=c++11 $(COMMON) $(CFLAGS) -o $@ src/yolo_dataset.cpp $(LDFLAGS) -L ./ -l:$(LIBNAMESO)

$(DARKNET_CLASSIFIER_CONSOLE):  $(LIBNAMESO) src/darknet_classifier.hpp src/darknet_classifier_console.cpp
	$(CPP) -std=c++11 $(COMMON) $(CFLAGS) -o $@ src/darknet_classifier_console.cpp $(LDFLAGS) -L ./ -l:$(LIBNAMESO)

$(DARKNET_PERSON_FACE_TRACK):  $(LIBNAMESO) src/darknet_class.hpp src/darknet_class.hpp src/yolo_person_face_track.cpp
	$(CPP) -std=c++11 $(COMMON) $(CFLAGS) -o $@ src/yolo_person_face_track.cpp $(LDFLAGS) -L ./ -l:$(LIBNAMESO)


$(DARKNET_DETECTOR_CONSOLE):  $(LIBNAMESO) src/yolo_detector.hpp src/yolo_detector_console.cpp
	$(CPP) -std=c++11 $(COMMON) $(CFLAGS) -o $@ src/yolo_detector_console.cpp $(LDFLAGS) -L ./ -l:$(LIBNAMESO)

$(YOLO_PERSON_FACE_CONSOLE):  $(LIBNAMESO) src/yolo_person_face.h src/yolo_person_face_console.cpp
	$(CPP) -std=c++11 $(COMMON) $(CFLAGS) -o $@ src/yolo_person_face_console.cpp $(LDFLAGS) -L ./ -l:$(LIBNAMESO)



endif

$(EXEC): $(OBJS)
	$(CPP) $(COMMON) $(CFLAGS) $^ -o $@ $(LDFLAGS)

$(OBJDIR)%.o: %.c $(DEPS)
	$(CC) $(COMMON) $(CFLAGS) -c $< -o $@

$(OBJDIR)%.o: %.cpp $(DEPS)
	$(CPP) $(COMMON) $(CFLAGS) -c $< -o $@

$(OBJDIR)%.o: %.cu $(DEPS)
	$(NVCC) $(ARCH) $(COMMON) --compiler-options "$(CFLAGS)" -c $< -o $@

obj:
	mkdir -p obj
backup:
	mkdir -p backup
results:
	mkdir -p results

.PHONY: clean

clean:
	rm -rf $(OBJS) $(EXEC) $(LIBNAMESO) $(APPNAMESO) $(TEST_APP) $(DATASET) $(DARKNET_CLASSIFIER_CONSOLE) $(DARKNET_PERSON_FACE_TRACK) $(DARKNET_DETECTOR_CONSOLE) $(YOLO_PERSON_FACE_CONSOLE)

