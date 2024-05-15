// Copyright (c) 2024 Dry Ark LLC
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <mach-o/arch.h>
#include <mach-o/dyld.h>
#include <mach/machine.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>

void readMachO(const char *path);

#define MAX_EXCLUDES 10  // Maximum number of directories that can be excluded

// Check if directory should be excluded
int is_excluded(const char *dir, char exclude[][256], int exclude_count) {
    for (int i = 0; i < exclude_count; i++) {
        if (strcmp(dir, exclude[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

void scan_directory(const char *path, char exclude[][256], int exclude_count) {
    DIR *dir;
    struct dirent *entry;
    struct stat statbuf;

    if (!(dir = opendir(path))) {
        perror("Failed to open directory");
        return;
    }

    while ((entry = readdir(dir)) != NULL) {
        char fullpath[1024];
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);

        // Check if this directory should be excluded
        if (entry->d_type == DT_DIR && is_excluded(entry->d_name, exclude, exclude_count)) {
            //printf("Skipping excluded directory: %s\n", fullpath);
            continue;
        }

        if (stat(fullpath, &statbuf) == -1) {
            perror("Failed to get file stats");
            continue;
        }

        if (S_ISDIR(statbuf.st_mode)) {
            // Recursively scan the directory
            scan_directory(fullpath, exclude, exclude_count);
        } else if (S_ISREG(statbuf.st_mode)) {
            // Check for 'dylib' extension
            
            int ok = 0;
            if (strstr(entry->d_name, ".dylib")) {
                //printf("File:%s\n", fullpath);
                ok = 1;
            }
            // Check if the file is executable
            else if (statbuf.st_mode & S_IXUSR) {
                if(
                    !strstr(entry->d_name, ".so") &&
                    !strstr(entry->d_name, ".py") &&
                    !strstr(entry->d_name, ".pl")
                ) {
                    FILE *file = fopen(fullpath, "rb");
                    if( !file ) continue;
                    unsigned char bytes[1];
                    if (fread(bytes, 1, 1, file) != 1) {
                        fclose( file );
                        continue;
                    }
                    fclose( file );
                    if( bytes[0] != '#' ) {
                        //printf("File:%s\n", fullpath);
                        ok = 1;
                    }
                }
            }
            
            if( ok ) {
                readMachO( fullpath );
            }
        }
    }

    closedir(dir);
}

int main(int argc, char *argv[]) {
    char *root_dir = ".";
    char exclude[MAX_EXCLUDES][256];  // Array to store names of directories to exclude
    int exclude_count = 0;

    // Assuming directories to exclude are passed after the root directory argument
    root_dir = argc > 1 ? argv[1] : root_dir;
    for (int i = 2; i < argc && exclude_count < MAX_EXCLUDES; i++) {
        strncpy(exclude[exclude_count++], argv[i], 255);
        exclude[exclude_count - 1][255] = '\0';  // Ensure null termination
    }

    //printf("Scanning directory: %s\n", root_dir);
    for (int i = 0; i < exclude_count; i++) {
        //printf("Excluding directory: %s\n", exclude[i]);
    }

    scan_directory(root_dir, exclude, exclude_count);

    return 0;
}

void readMachO(const char *path) {
    int fd = open( path, O_RDONLY );
    if (fd == -1) {
        perror("Failed to open file");
        return;
    }

    struct stat stat_buf;
    if (fstat(fd, &stat_buf) == -1) {
        perror("Failed to get file stats");
        close(fd);
        return;
    }

    void *map = mmap(NULL, stat_buf.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (map == MAP_FAILED) {
        perror("Failed to map file");
        close(fd);
        return;
    }

    struct mach_header_64 *mh;
    struct load_command *lc;
    struct fat_header *fh = (struct fat_header *)map;
    unsigned char *bmap = (unsigned char *) map;
    
    int filePrinted = 0;
    if (fh->magic == FAT_MAGIC || fh->magic == FAT_CIGAM) {
        // It's a FAT binary, iterate through architectures
        struct fat_arch *archs = (struct fat_arch *)(fh + 1);
        for (int i = 0; i < ntohl(fh->nfat_arch); i++) {
            uint32_t offset = ntohl(archs[i].offset);
            struct mach_header_64 *mh = (struct mach_header_64 *)((char *)map + offset);
            //printArch(ntohl(archs[i].cputype), ntohl(archs[i].cpusubtype));
            struct load_command *lc = (struct load_command *)(mh + 1);
            for (uint32_t j = 0; j < mh->ncmds; j++) {
                if (lc->cmd == LC_LOAD_DYLIB) {
                    struct dylib_command *dylib = (struct dylib_command *)lc;
                    printf("  LC_LOAD_DYLIB:%s\n", (char *)dylib + dylib->dylib.name.offset);
                }
                lc = (struct load_command *)((char *)lc + lc->cmdsize);
            }
        }
    }
    //my $mach_o_magic = "\xCF\xFA\xED\xFE";
    else if( bmap[0] == 0xcf && bmap[1] == 0xfa && bmap[2] == 0xed && bmap[3] == 0xfe ) {
        // It's a non-FAT binary
        struct mach_header_64 *mh = (struct mach_header_64 *)map;
        //printArch(mh->cputype, mh->cpusubtype);
        struct load_command *lc = (struct load_command *)(mh + 1);
        for (uint32_t i = 0; i < mh->ncmds; i++) {
            if (lc->cmd == LC_LOAD_DYLIB) {
                struct dylib_command *dylib = (struct dylib_command *)lc;
                char *dylibn = (char *)dylib + dylib->dylib.name.offset;
                if( dylibn[0] == '@' && dylibn[1] == '@' ) {
                    if( !filePrinted ) {
                        printf("File:%s\n", path );
                        filePrinted = 1;
                    }
                    printf("  LC_LOAD_DYLIB:%s\n", (char *)dylib + dylib->dylib.name.offset);
                }
            }
            lc = (struct load_command *)((char *)lc + lc->cmdsize);
        }
    }

    munmap(map, stat_buf.st_size);
    close(fd);
}
