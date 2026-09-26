#ifndef GIT_SCANNER_H
#define GIT_SCANNER_H

#include <stdbool.h>
#include <time.h>

typedef struct {
    char *name;
    char *path;
    char *ws_name;
    bool is_orphan;
    bool is_workspace_root;
    bool has_git;
    char branch[128];
    bool is_dirty;
    int stash_count;
    char remote[64];
    char time_str[64];
    time_t commit_timestamp;
} ProjectItem;

void init_git_system(void);
void shutdown_git_system(void);
void scan_single_project(ProjectItem *item);
void scan_projects_parallel(ProjectItem *items, int count);

#endif
