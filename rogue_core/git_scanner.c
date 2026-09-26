#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <git2.h>
#include "git_scanner.h"

void init_git_system(void) {
    git_libgit2_init();
}

void shutdown_git_system(void) {
    git_libgit2_shutdown();
}

static void format_relative_time(time_t commit_time, char *buf, size_t buf_len) {
    time_t now = time(NULL);
    double diff = difftime(now, commit_time);
    if (diff < 0) diff = 0;

    if (diff < 60) {
        snprintf(buf, buf_len, "just now");
    } else if (diff < 3600) {
        int mins = (int)(diff / 60);
        snprintf(buf, buf_len, "%d min%s ago", mins, mins == 1 ? "" : "s");
    } else if (diff < 86400) {
        int hours = (int)(diff / 3600);
        snprintf(buf, buf_len, "%d hour%s ago", hours, hours == 1 ? "" : "s");
    } else if (diff < 604800) {
        int days = (int)(diff / 86400);
        snprintf(buf, buf_len, "%d day%s ago", days, days == 1 ? "" : "s");
    } else if (diff < 2592000) {
        int weeks = (int)(diff / 604800);
        snprintf(buf, buf_len, "%d week%s ago", weeks, weeks == 1 ? "" : "s");
    } else if (diff < 31536000) {
        int months = (int)(diff / 2592000);
        snprintf(buf, buf_len, "%d month%s ago", months, months == 1 ? "" : "s");
    } else {
        int years = (int)(diff / 31536000);
        snprintf(buf, buf_len, "%d year%s ago", years, years == 1 ? "" : "s");
    }
}

static int stash_cb(size_t index, const char *message, const git_oid *stash_id, void *payload) {
    (void)index; (void)message; (void)stash_id;
    int *count = (int*)payload;
    (*count)++;
    return 0;
}

void scan_single_project(ProjectItem *item) {
    item->has_git = false;
    item->branch[0] = '\0';
    item->is_dirty = false;
    item->stash_count = 0;
    snprintf(item->remote, sizeof(item->remote), "-");
    item->time_str[0] = '\0';
    item->commit_timestamp = 0;

    if (!item->path) return;

    git_repository *repo = NULL;
    if (git_repository_open(&repo, item->path) != 0) {
        return;
    }

    item->has_git = true;

    // 1. Branch / HEAD
    git_reference *head = NULL;
    if (git_repository_head(&head, repo) == 0) {
        if (!git_repository_head_detached(repo)) {
            const char *shorthand = git_reference_shorthand(head);
            if (shorthand) snprintf(item->branch, sizeof(item->branch), "%s", shorthand);
        } else {
            const git_oid *target = git_reference_target(head);
            if (target) {
                char oid_str[GIT_OID_SHA1_HEXSIZE + 1];
                git_oid_tostr(oid_str, sizeof(oid_str), target);
                oid_str[7] = '\0';
                snprintf(item->branch, sizeof(item->branch), "%s", oid_str);
            }
        }

        // 2. Last Commit Time
        git_object *commit_obj = NULL;
        if (git_reference_peel(&commit_obj, head, GIT_OBJECT_COMMIT) == 0) {
            git_commit *commit = (git_commit*)commit_obj;
            item->commit_timestamp = (time_t)git_commit_time(commit);
            format_relative_time(item->commit_timestamp, item->time_str, sizeof(item->time_str));
            git_object_free(commit_obj);
        }
        git_reference_free(head);
    }

    // 3. Status / Dirty Check
    git_status_options opts = GIT_STATUS_OPTIONS_INIT;
    opts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED | GIT_STATUS_OPT_EXCLUDE_SUBMODULES;
    git_status_list *status_list = NULL;
    if (git_status_list_new(&status_list, repo, &opts) == 0) {
        size_t count = git_status_list_entrycount(status_list);
        item->is_dirty = (count > 0);
        git_status_list_free(status_list);
    }

    // 4. Stashes
    git_stash_foreach(repo, stash_cb, &item->stash_count);

    // 5. Remotes
    git_strarray remotes = {0};
    if (git_remote_list(&remotes, repo) == 0) {
        bool has_gh = false, has_gl = false, has_other = false;
        for (size_t i = 0; i < remotes.count; i++) {
            git_remote *rem = NULL;
            if (git_remote_lookup(&rem, repo, remotes.strings[i]) == 0) {
                const char *url = git_remote_url(rem);
                if (url) {
                    if (strstr(url, "github")) has_gh = true;
                    else if (strstr(url, "gitlab")) has_gl = true;
                    else has_other = true;
                }
                git_remote_free(rem);
            }
        }
        if (has_gh && has_gl) snprintf(item->remote, sizeof(item->remote), "gh+gl");
        else if (has_gh) snprintf(item->remote, sizeof(item->remote), "github");
        else if (has_gl) snprintf(item->remote, sizeof(item->remote), "gitlab");
        else if (has_other) snprintf(item->remote, sizeof(item->remote), "other");
        else snprintf(item->remote, sizeof(item->remote), "-");
        git_strarray_dispose(&remotes);
    }

    git_repository_free(repo);
}

typedef struct {
    ProjectItem *items;
    int count;
    int current_index;
    pthread_mutex_t lock;
} ThreadPoolContext;

static void *worker_thread(void *arg) {
    ThreadPoolContext *ctx = (ThreadPoolContext*)arg;
    while (1) {
        int idx = -1;
        pthread_mutex_lock(&ctx->lock);
        if (ctx->current_index < ctx->count) {
            idx = ctx->current_index++;
        }
        pthread_mutex_unlock(&ctx->lock);

        if (idx == -1) break;

        scan_single_project(&ctx->items[idx]);
    }
    return NULL;
}

void scan_projects_parallel(ProjectItem *items, int count) {
    if (count <= 0) return;

    long num_cores = sysconf(_SC_NPROCESSORS_ONLN);
    if (num_cores < 2) num_cores = 2;
    if (num_cores > 16) num_cores = 16;
    if (num_cores > count) num_cores = count;

    ThreadPoolContext ctx;
    ctx.items = items;
    ctx.count = count;
    ctx.current_index = 0;
    pthread_mutex_init(&ctx.lock, NULL);

    pthread_t *threads = malloc(num_cores * sizeof(pthread_t));
    for (int i = 0; i < num_cores; i++) {
        pthread_create(&threads[i], NULL, worker_thread, &ctx);
    }

    for (int i = 0; i < num_cores; i++) {
        pthread_join(threads[i], NULL);
    }

    free(threads);
    pthread_mutex_destroy(&ctx.lock);
}
