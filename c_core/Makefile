CC ?= gcc
CFLAGS ?= -O3 -Wall -Wextra -D_GNU_SOURCE
LDFLAGS ?= -lgit2 -lpthread

SRCS = main.c cJSON.c config.c git_scanner.c table.c matcher.c
OBJS = $(SRCS:.c=.o)
BIN_DIR = ../bin
TARGET = $(BIN_DIR)/rogue-core
PREFIX ?= $(HOME)/.local/bin

.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(OBJS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

install: $(TARGET)
	@mkdir -p $(PREFIX)
	cp $(TARGET) $(PREFIX)/rogue-core
	@chmod +x $(PREFIX)/rogue-core

clean:
	rm -f $(OBJS) $(TARGET)
