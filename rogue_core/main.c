#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include "config.h"
#include "git_scanner.h"
#include "table.h"
#include "matcher.h"

static bool is_directory(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return false;
    return S_ISDIR(st.st_mode);
}

static const char *get_path_basename(const char *path) {
    if (!path || !path[0]) return "";
    const char *bname = strrchr(path, '/');
    return bname ? bname + 1 : path;
}

static int collect_dir_subprojects(const char *dir_path, ProjectItem **items_out, int *cap_out, int count, const char *ws_name, bool is_orphan) {
    DIR *d = opendir(dir_path);
    if (!d) return count;

    struct dirent *entry;
    while ((entry = readdir(d)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        char subpath[2048];
        snprintf(subpath, sizeof(subpath), "%s/%s", dir_path, entry->d_name);
        if (is_directory(subpath)) {
            if (count >= *cap_out) {
                *cap_out *= 2;
                *items_out = realloc(*items_out, (*cap_out) * sizeof(ProjectItem));
            }
            (*items_out)[count].name = strdup(entry->d_name);
            (*items_out)[count].path = strdup(subpath);
            (*items_out)[count].ws_name = ws_name ? strdup(ws_name) : NULL;
            (*items_out)[count].is_orphan = is_orphan;
            (*items_out)[count].is_workspace_root = false;
            count++;
        }
    }
    closedir(d);
    return count;
}

static int cmd_list_core(int argc, char **argv) {
    FilterOptions opts = {0};

    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--filter") == 0) {
            if (i + 1 < argc) opts.filter_name = argv[++i];
        } else if (strcmp(argv[i], "-fs") == 0 || strcmp(argv[i], "--filter-status") == 0) {
            if (i + 1 < argc) opts.filter_status = argv[++i];
        } else if (strcmp(argv[i], "-fb") == 0 || strcmp(argv[i], "--filter-branch") == 0) {
            if (i + 1 < argc) opts.filter_branch = argv[++i];
        } else if (strcmp(argv[i], "-fr") == 0 || strcmp(argv[i], "--filter-remote") == 0) {
            if (i + 1 < argc) opts.filter_remote = argv[++i];
        } else if (strcmp(argv[i], "-w") == 0 || strcmp(argv[i], "--ws") == 0 || strcmp(argv[i], "--workspace") == 0) {
            if (i + 1 < argc) opts.filter_ws = argv[++i];
        } else if (strcmp(argv[i], "--orphan") == 0 || strcmp(argv[i], "--orphans") == 0) {
            opts.filter_orphan = true;
        } else if (strcmp(argv[i], "-a") == 0 || strcmp(argv[i], "--all") == 0) {
            opts.show_all = true;
        } else if (strcmp(argv[i], "--dirty") == 0) {
            opts.dirty_only = true;
        }
    }

    RogueConfig *cfg = load_rogue_config();
    if (!cfg) {
        fprintf(stderr, "\033[1;3;31m[Rogue]\033[0m \033[33mError:\033[0m Failed to load configuration.\n");
        return 1;
    }

    init_git_system();

    printf("\033[1;3;31m[Rogue]\033[0m \033[1;3mListing Projects...\033[0m\n");

    // 1. If only orphans requested
    if (opts.filter_orphan) {
        int cap = 32, count = 0;
        ProjectItem *items = malloc(cap * sizeof(ProjectItem));
        for (int i = 0; i < cfg->linked_count; i++) {
            if (!cfg->linked_projects[i].ws_name && is_directory(cfg->linked_projects[i].path)) {
                const char *bname = get_path_basename(cfg->linked_projects[i].path);
                if (!bname || bname[0] == '\0') continue;
                if (count >= cap) {
                    cap *= 2;
                    items = realloc(items, cap * sizeof(ProjectItem));
                }
                items[count].name = strdup(bname);
                items[count].path = strdup(cfg->linked_projects[i].path);
                items[count].ws_name = NULL;
                items[count].is_orphan = true;
                items[count].is_workspace_root = false;
                count++;
            }
        }
        scan_projects_parallel(items, count);
        char title[1024];
        snprintf(title, sizeof(title), "STANDALONE / ORPHAN PROJECTS (%s)", cfg->local_projects_list ? cfg->local_projects_list : "~/.config/rogue/rp.list");
        render_project_table(title, items, count, &opts);
        printf("\n");
        for (int i = 0; i < count; i++) { free(items[i].name); free(items[i].path); }
        free(items);
        free_rogue_config(cfg);
        shutdown_git_system();
        return 0;
    }

    // 2. If specific workspace requested
    if (opts.filter_ws) {
        WorkspaceConfig *target_ws = NULL;
        for (int i = 0; i < cfg->workspace_count; i++) {
            if (strcasecmp(cfg->workspaces[i].name, opts.filter_ws) == 0) {
                target_ws = &cfg->workspaces[i];
                break;
            }
        }
        if (!target_ws) {
            for (int i = 0; i < cfg->workspace_count; i++) {
                if (strcasestr(cfg->workspaces[i].name, opts.filter_ws) != NULL) {
                    target_ws = &cfg->workspaces[i];
                    break;
                }
            }
        }

        const char *canonical_ws_name = target_ws ? target_ws->name : opts.filter_ws;
        int cap = 32, count = 0;
        ProjectItem *items = malloc(cap * sizeof(ProjectItem));

        if (target_ws && target_ws->path && is_directory(target_ws->path)) {
            count = collect_dir_subprojects(target_ws->path, &items, &cap, count, canonical_ws_name, false);
        } else if (is_directory(opts.filter_ws)) {
            count = collect_dir_subprojects(opts.filter_ws, &items, &cap, count, canonical_ws_name, false);
        } else {
            char custom_path[2048];
            snprintf(custom_path, sizeof(custom_path), "%s/%s", cfg->projects_dir, canonical_ws_name);
            if (is_directory(custom_path)) {
                count = collect_dir_subprojects(custom_path, &items, &cap, count, canonical_ws_name, false);
            }
        }

        // Linked projects in workspace
        for (int i = 0; i < cfg->linked_count; i++) {
            if (cfg->linked_projects[i].ws_name && strcasecmp(cfg->linked_projects[i].ws_name, canonical_ws_name) == 0) {
                if (is_directory(cfg->linked_projects[i].path)) {
                    const char *bname = get_path_basename(cfg->linked_projects[i].path);
                    if (!bname || bname[0] == '\0') continue;
                    if (count >= cap) {
                        cap *= 2;
                        items = realloc(items, cap * sizeof(ProjectItem));
                    }
                    items[count].name = strdup(bname);
                    items[count].path = strdup(cfg->linked_projects[i].path);
                    items[count].ws_name = strdup(canonical_ws_name);
                    items[count].is_orphan = false;
                    items[count].is_workspace_root = false;
                    count++;
                }
            }
        }

        scan_projects_parallel(items, count);
        char title[1024];
        snprintf(title, sizeof(title), "WORKSPACE: %s%s%s", canonical_ws_name,
                 (target_ws && target_ws->gh_org) ? " (GitHub Org: " : "",
                 (target_ws && target_ws->gh_org) ? target_ws->gh_org : "");
        if (target_ws && target_ws->gh_org) strcat(title, ")");
        render_project_table(title, items, count, &opts);
        printf("\n");
        for (int i = 0; i < count; i++) { free(items[i].name); free(items[i].path); free(items[i].ws_name); }
        free(items);
        free_rogue_config(cfg);
        shutdown_git_system();
        return 0;
    }

    // -------------------------------------------------------------
    // FULL LIST (3-SECTION VIEW):
    // 1) Default Projects
    // 2) Workspaces
    // 3) Standalone / Orphans
    // -------------------------------------------------------------

    // SECTION 1: DEFAULT PROJECTS
    if (is_directory(cfg->projects_dir)) {
        int cap = 32, count = 0;
        ProjectItem *items = malloc(cap * sizeof(ProjectItem));
        DIR *d = opendir(cfg->projects_dir);
        if (d) {
            struct dirent *entry;
            while ((entry = readdir(d)) != NULL) {
                if (entry->d_name[0] == '.') continue;

                // Check if directory matches a registered workspace
                bool is_ws = false;
                for (int w = 0; w < cfg->workspace_count; w++) {
                    if (strcasecmp(entry->d_name, cfg->workspaces[w].name) == 0) {
                        is_ws = true;
                        break;
                    }
                }
                if (is_ws) continue;

                char subpath[2048];
                snprintf(subpath, sizeof(subpath), "%s/%s", cfg->projects_dir, entry->d_name);
                if (is_directory(subpath)) {
                    if (count >= cap) {
                        cap *= 2;
                        items = realloc(items, cap * sizeof(ProjectItem));
                    }
                    items[count].name = strdup(entry->d_name);
                    items[count].path = strdup(subpath);
                    items[count].ws_name = NULL;
                    items[count].is_orphan = false;
                    items[count].is_workspace_root = false;
                    count++;
                }
            }
            closedir(d);
        }

        scan_projects_parallel(items, count);
        char title[1024];
        snprintf(title, sizeof(title), "DEFAULT PROJECTS (%s)", cfg->projects_dir);
        render_project_table(title, items, count, &opts);
        for (int i = 0; i < count; i++) { free(items[i].name); free(items[i].path); }
        free(items);
    }

    // SECTION 2: WORKSPACES
    for (int w = 0; w < cfg->workspace_count; w++) {
        WorkspaceConfig *ws = &cfg->workspaces[w];
        if (ws->hidden && !opts.show_all) continue;

        int cap = 32, count = 0;
        ProjectItem *items = malloc(cap * sizeof(ProjectItem));

        if (ws->path && is_directory(ws->path)) {
            count = collect_dir_subprojects(ws->path, &items, &cap, count, ws->name, false);
        }

        // Linked projects in this workspace
        for (int i = 0; i < cfg->linked_count; i++) {
            if (cfg->linked_projects[i].ws_name && strcmp(cfg->linked_projects[i].ws_name, ws->name) == 0) {
                if (is_directory(cfg->linked_projects[i].path)) {
                    if (count >= cap) {
                        cap *= 2;
                        items = realloc(items, cap * sizeof(ProjectItem));
                    }
                    const char *bname = strrchr(cfg->linked_projects[i].path, '/');
                    bname = bname ? bname + 1 : cfg->linked_projects[i].path;
                    items[count].name = strdup(bname);
                    items[count].path = strdup(cfg->linked_projects[i].path);
                    items[count].ws_name = strdup(ws->name);
                    items[count].is_orphan = false;
                    items[count].is_workspace_root = false;
                    count++;
                }
            }
        }

        scan_projects_parallel(items, count);

        char title[1024];
        if (ws->gh_org && ws->gh_org[0] && strcmp(ws->gh_org, "-") != 0) {
            snprintf(title, sizeof(title), "WORKSPACE: %s (GitHub Org: %s)", ws->name, ws->gh_org);
        } else {
            snprintf(title, sizeof(title), "WORKSPACE: %s", ws->name);
        }
        render_project_table(title, items, count, &opts);

        for (int i = 0; i < count; i++) { free(items[i].name); free(items[i].path); free(items[i].ws_name); }
        free(items);
    }

    // SECTION 3: STANDALONE / ORPHAN PROJECTS
    {
        int cap = 32, count = 0;
        ProjectItem *items = malloc(cap * sizeof(ProjectItem));
        for (int i = 0; i < cfg->linked_count; i++) {
            if (!cfg->linked_projects[i].ws_name && is_directory(cfg->linked_projects[i].path)) {
                const char *bname = get_path_basename(cfg->linked_projects[i].path);
                if (!bname || bname[0] == '\0') continue;
                if (count >= cap) {
                    cap *= 2;
                    items = realloc(items, cap * sizeof(ProjectItem));
                }
                items[count].name = strdup(bname);
                items[count].path = strdup(cfg->linked_projects[i].path);
                items[count].ws_name = NULL;
                items[count].is_orphan = true;
                items[count].is_workspace_root = false;
                count++;
            }
        }
        scan_projects_parallel(items, count);
        char title[1024];
        snprintf(title, sizeof(title), "STANDALONE / ORPHAN PROJECTS (%s)", cfg->local_projects_list ? cfg->local_projects_list : "~/.config/rogue/rp.list");
        render_project_table(title, items, count, &opts);
        for (int i = 0; i < count; i++) { free(items[i].name); free(items[i].path); }
        free(items);
    }

    printf("\n");

    free_rogue_config(cfg);
    shutdown_git_system();
    return 0;
}

static int cmd_match_core(int argc, char **argv) {
    if (argc < 2) return 1;
    const char *query = argv[0];
    const char **candidates = (const char**)&argv[1];
    int count = argc - 1;

    char **results = NULL;
    int matched = fuzzy_match_candidates(query, candidates, count, &results);
    if (matched > 0 && results) {
        for (int i = 0; i < matched; i++) {
            printf("%s\n", results[i]);
        }
        free_match_results(results, matched);
        return 0;
    }
    return 1;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: rogue-core <command> [options]\nCommands: list, match\n");
        return 1;
    }

    if (strcmp(argv[1], "list") == 0) {
        return cmd_list_core(argc - 2, argv + 2);
    } else if (strcmp(argv[1], "match") == 0) {
        return cmd_match_core(argc - 2, argv + 2);
    } else {
        fprintf(stderr, "Unknown command: %s\n", argv[1]);
        return 1;
    }
}
