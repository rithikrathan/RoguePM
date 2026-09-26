#ifndef TABLE_H
#define TABLE_H

#include "git_scanner.h"
#include <stdbool.h>

typedef struct {
    char *filter_name;
    char *filter_status;
    char *filter_branch;
    char *filter_remote;
    char *filter_ws;
    bool filter_orphan;
    bool show_all;
    bool dirty_only;
} FilterOptions;

void render_project_table(const char *section_title, ProjectItem *items, int count, const FilterOptions *opts);

#endif
