# Builds every C command into $(BUILD). `make test` runs the unit tests.
ifeq ($(origin CC),default)
CC      := gcc
endif
CFLAGS  ?= -O2
# Project flags are appended even when makepkg exports its own CFLAGS.
CFLAGS  += -std=c11 -Wall -Wextra -Werror -D_GNU_SOURCE -Icommon
BUILD   ?= build

COMMON  := common/procfs.c common/fmt.c
BINS    := ad-info ad-ps ad-mem ad-ipc
TARGETS := $(addprefix $(BUILD)/,$(BINS))

all: $(TARGETS)

$(BUILD):
	mkdir -p $@

$(BUILD)/ad-info: ad-info/*.c $(COMMON) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $^

$(BUILD)/ad-ps: ad-ps/*.c $(COMMON) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $^

$(BUILD)/ad-mem: ad-mem/*.c $(COMMON) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $^

$(BUILD)/ad-ipc: ad-ipc/*.c | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $^ -lpthread -lrt

$(BUILD)/test-procfs: tests/test_procfs.c $(COMMON) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $^

test: $(BUILD)/test-procfs
	$(BUILD)/test-procfs

clean:
	rm -rf $(BUILD)

.PHONY: all test clean
