#ifndef CONFIG_H
#define CONFIG_H

#include <stdbool.h>

typedef struct {
    char *name;
    char *path;
    char *gh_org;
    char *git_user_email;
    bool skip_snapshot;
    bool hidden;
} WorkspaceConfig;

typedef struct {
    char *path;
    char *ws_name;
} LinkedProject;

typedef struct {
    char *projects_dir;
    char *templates_dir;
    char *config_file;
    char *local_projects_list;
    WorkspaceConfig *workspaces;
    int workspace_count;
    LinkedProject *linked_projects;
    int linked_count;
} RogueConfig;

RogueConfig *load_rogue_config(void);
void free_rogue_config(RogueConfig *cfg);

#endif
