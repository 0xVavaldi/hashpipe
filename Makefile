CC = cc
CFLAGS = -DMACOSX=1 -fomit-frame-pointer -pthread -O3 -I/opt/local/include
LDFLAGS = -pthread -O3

# Static libraries (expected in current directory or subdirectories)
LIBS = libssl.a libcrypto.a libsph.a libmhash.a librhash.a md6.a \
       gosthash/gost2012/gost2012.a bcrypt-master/bcrypt.a libJudy.a -liconv

OBJS = hashpipe.o yarn.o

hashpipe: $(OBJS)
	$(CC) $(LDFLAGS) -o hashpipe $(OBJS) $(LIBS)

hashpipe.o: hashpipe.c
	$(CC) $(CFLAGS) -c hashpipe.c

yarn.o: yarn.c yarn.h
	$(CC) $(CFLAGS) -c yarn.c

clean:
	rm -f hashpipe $(OBJS)

.PHONY: clean
