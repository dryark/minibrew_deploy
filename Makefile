all: minibrew.tar.xz

SOURCES := dl.pl extract.pl genlib.pl genbin.pl rebase.pl deploy.pl $(wildcard *.json) curlprog tarball_incremental scan mod/Ujsonin.pm
EMPTY_FOLDERS := bin pkgs lib bottle

minibrew.tar.xz: $(SOURCES)
	tar --no-recursion -cJf minibrew.tar.xz $(SOURCES) $(EMPTY_FOLDERS)

scan: scan.c
	clang -arch x86_64 -arch arm64 -o scan scan.c
	codesign --sign - scan

tarball_incremental: tarball_incremental.c
	clang -arch x86_64 -arch arm64 -o tarball_incremental tarball_incremental.c -I/usr/local/opt/libarchive/include -ldl
	codesign --sign - tarball_incremental

curlprog: curlprog.m
	clang -arch x86_64 -arch arm64 -fobjc-arc -o curlprog curlprog.m -ldl -framework Foundation
	codesign --sign - curlprog

clean:
	rm -f scan curlprog tarball_incremental minibrew.tar.xz
