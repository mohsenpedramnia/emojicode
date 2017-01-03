VERSION = 0.3

CC ?= gcc
CXX ?= g++

COMPILER_CFLAGS = -c -Wall -std=c++14 -Ofast -iquote . -iquote EmojicodeReal-TimeEngine/ -iquote EmojicodeCompiler/ $(if $(DEFAULT_PACKAGES_DIRECTORY),-DdefaultPackagesDirectory=\"$(DEFAULT_PACKAGES_DIRECTORY)\")
COMPILER_LDFLAGS =

COMPILER_SRCDIR = EmojicodeCompiler
COMPILER_SOURCES = $(wildcard $(COMPILER_SRCDIR)/*.cpp)
COMPILER_OBJECTS = $(COMPILER_SOURCES:%.cpp=%.o)
COMPILER_BINARY = emojicodec

ENGINE_CFLAGS = -Ofast -iquote . -iquote EmojicodeReal-TimeEngine/ -iquote EmojicodeCompiler -std=c11 -Wall -Wno-unused-result $(if $(HEAP_SIZE),-DheapSize=$(HEAP_SIZE)) $(if $(DEFAULT_PACKAGES_DIRECTORY),-DdefaultPackagesDirectory=\"$(DEFAULT_PACKAGES_DIRECTORY)\")
ENGINE_LDFLAGS = -lm -ldl -lpthread -rdynamic

ENGINE_SRCDIR = EmojicodeReal-TimeEngine
ENGINE_SOURCES = $(wildcard $(ENGINE_SRCDIR)/*.c)
ENGINE_OBJECTS = $(ENGINE_SOURCES:%.c=%.o)
ENGINE_BINARY = emojicode

PACKAGE_CFLAGS = -Ofast -iquote EmojicodeReal-TimeEngine/ -std=c11 -Wno-unused-result -fPIC
PACKAGE_LDFLAGS = -shared -fPIC
ifeq ($(shell uname), Darwin)
PACKAGE_LDFLAGS += -undefined dynamic_lookup
endif

PACKAGES_DIR=DefaultPackages
PACKAGES=files sockets
# allegro

DIST_NAME=Emojicode-$(VERSION)-$(shell $(CC) -dumpmachine)
DIST_BUILDS ?= builds
DIST=$(DIST_BUILDS)/$(DIST_NAME)

TESTS_DIR=tests
TESTS_REJECT=$(wildcard $(TESTS_DIR)/reject/*.emojic)
TESTS_COMPILATION=hello piglatin namespace enum extension chaining branch class protocol selfInDeclaration generics genericProtocol callable threads reflection castToSelf variableInitAndScoping privateMethod babyBottleInitializer sequenceTypes valueType valueTypeSelf valueTypeMutate gcStressTest vtClosures
TESTS_S=stringTest primitives listTest dictionaryTest rangeTest dataTest mathTest fileTest systemTest jsonTest enumerator

.PHONY: builds tests install dist

all: builds $(COMPILER_BINARY) $(ENGINE_BINARY) $(addsuffix .so,$(PACKAGES)) dist

$(COMPILER_BINARY): $(COMPILER_OBJECTS) utf8.o
	$(CXX) $^ -o $(DIST)/$(COMPILER_BINARY) $(COMPILER_LDFLAGS)

$(COMPILER_OBJECTS): %.o: %.cpp
	$(CXX) -c $< -o $@ $(COMPILER_CFLAGS)

$(ENGINE_BINARY): $(ENGINE_OBJECTS) utf8.o
	$(CC) $^ -o $(DIST)/$(ENGINE_BINARY) $(ENGINE_LDFLAGS)

$(ENGINE_OBJECTS): %.o: %.c
	$(CC) -c $< -o $@ $(ENGINE_CFLAGS)

%.o: %.c
	$(CC) -c $< -o $@

define package
PKG_$(1)_LDFLAGS = $$(PACKAGE_LDFLAGS)
ifeq ($(1), allegro)
PKG_$(1)_LDFLAGS += -lallegro_color -lallegro_primitives -lallegro -lallegro_image -lallegro_ttf -lallegro_audio -lallegro_acodec
endif
PKG_$(1)_SOURCES = $$(wildcard $$(PACKAGES_DIR)/$(1)/*.c)
PKG_$(1)_OBJECTS = $$(PKG_$(1)_SOURCES:%.c=%.o)
$(1).so: $$(PKG_$(1)_OBJECTS)
	$$(CC) $$(PKG_$(1)_LDFLAGS) $$^ -o $(DIST)/packages/$(1)/$$@ -iquote $$(<D)
$$(PKG_$(1)_OBJECTS): %.o: %.c
	$$(CC) $$(PACKAGE_CFLAGS) -c $$< -o $$@
endef

$(foreach pkg,$(PACKAGES),$(eval $(call package,$(pkg))))

clean:
	rm -f $(ENGINE_OBJECTS) $(COMPILER_OBJECTS) $(PACKAGES_DIR)/*/*.o utf8.o

builds:
	mkdir -p $(DIST)
	$(foreach pkg,$(PACKAGES),mkdir -p $(DIST)/packages/$(pkg);)

define testFile
$(DIST)/$(COMPILER_BINARY) -o $(1).emojib $(1).emojic
$(DIST)/$(ENGINE_BINARY) $(1).emojib

endef

define compilationTestOutput
$(DIST)/$(COMPILER_BINARY) -o $(1).emojib $(1).emojic
$(DIST)/$(ENGINE_BINARY) $(1).emojib > $(1).out.txt
cmp -b $(1).out.txt $(1).txt

endef

define compilationReject
! $(DIST)/$(COMPILER_BINARY) -o $(1).emojib $(1).emojic > /dev/null

endef

install: dist
	cd $(DIST) && ./install.sh

tests: export EMOJICODE_PACKAGES_PATH=$(DIST)/packages
tests:
	$(foreach n,$(TESTS_COMPILATION),$(call compilationTestOutput,$(TESTS_DIR)/compilation/$(basename $(n))))
	$(foreach n,$(TESTS_REJECT),$(call compilationReject,$(basename $(n))))
	$(foreach n,$(TESTS_S),$(call testFile,$(TESTS_DIR)/s/$(basename $(n))))
	@echo "✅ ✅  All tests passed."

dist:
	rm -f $(DIST)/install.sh
	cp install.sh $(DIST)/install.sh
	mkdir -p $(DIST)/packages/s
	cp -f headers/s.emojic $(DIST)/packages/s/header.emojic
	$(foreach pkg,$(PACKAGES),cp -f headers/$(pkg).emojic $(DIST)/packages/$(pkg)/header.emojic;)
	$(foreach pkg,$(PACKAGES),rm -f $(DIST)/packages/$(pkg)-v0; ln -s $(pkg) $(DIST)/packages/$(pkg)-v0;)
	tar -czf $(DIST).tar.gz -C $(DIST_BUILDS) $(DIST_NAME)
