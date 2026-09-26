#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "config.h"
#include "cJSON.h"

static char *expand_path(const char *path) {
    if (!path) return NULL;
    if (path[0] == '~') {
        const char *home = getenv("HOME");
        if (!home) home = "";
        char *expanded = malloc(strlen(home) + strlen(path));
        sprintf(expanded, "%s%s", home, path + 1);
        return expanded;
    }
    return strdup(path);
}

static char *read_file_to_string(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return NULL; }
    char *buf = malloc(len + 1);
    if (!buf) { fclose(f); return NULL; }
    size_t read_bytes = fread(buf, 1, len, f);
    buf[read_bytes] = '\0';
    fclose(f);
    return buf;
}

RogueConfig *load_rogue_config(void) {
    RogueConfig *cfg = calloc(1, sizeof(RogueConfig));
    if (!cfg) return NULL;

    const char *home = getenv("HOME");
    if (!home) home = "/tmp";

    char json_path[1024];
    const char *env_conf = getenv("ROGUE_CONFIG");
    if (env_conf && env_conf[0]) {
        snprintf(json_path, sizeof(json_path), "%s", env_conf);
    } else {
        snprintf(json_path, sizeof(json_path), "%s/.config/rogue/rogueConf.json", home);
    }

    char *json_str = read_file_to_string(json_path);
    if (json_str) {
        cJSON *root = cJSON_Parse(json_str);
        if (root) {
            cJSON *item = cJSON_GetObjectItem(root, "projects_dir");
            if (item && item->valuestring) cfg->projects_dir = expand_path(item->valuestring);

            item = cJSON_GetObjectItem(root, "templates_dir");
            if (item && item->valuestring) cfg->templates_dir = expand_path(item->valuestring);

            item = cJSON_GetObjectItem(root, "config_file");
            if (item && item->valuestring) cfg->config_file = expand_path(item->valuestring);

            item = cJSON_GetObjectItem(root, "local_projects_list");
            if (item && item->valuestring) cfg->local_projects_list = expand_path(item->valuestring);

            cJSON *ws_arr = cJSON_GetObjectItem(root, "workspaces");
            if (ws_arr && (ws_arr->type == cJSON_Array)) {
                int count = cJSON_GetArraySize(ws_arr);
                cfg->workspaces = calloc(count, sizeof(WorkspaceConfig));
                cfg->workspace_count = count;
                for (int i = 0; i < count; i++) {
                    cJSON *w = cJSON_GetArrayItem(ws_arr, i);
                    if (!w) continue;
                    cJSON *w_name = cJSON_GetObjectItem(w, "name");
                    cJSON *w_path = cJSON_GetObjectItem(w, "path");
                    cJSON *w_org = cJSON_GetObjectItem(w, "gh_org");
                    cJSON *w_email = cJSON_GetObjectItem(w, "git_user_email");
                    cJSON *w_skip = cJSON_GetObjectItem(w, "skip_snapshot");
                    cJSON *w_hide = cJSON_GetObjectItem(w, "hidden");

                    if (w_name && w_name->valuestring) cfg->workspaces[i].name = strdup(w_name->valuestring);
                    if (w_path && w_path->valuestring) cfg->workspaces[i].path = expand_path(w_path->valuestring);
                    if (w_org && w_org->valuestring) cfg->workspaces[i].gh_org = strdup(w_org->valuestring);
                    if (w_email && w_email->valuestring) cfg->workspaces[i].git_user_email = strdup(w_email->valuestring);
                    cfg->workspaces[i].skip_snapshot = cJSON_IsTrue(w_skip);
                    cfg->workspaces[i].hidden = cJSON_IsTrue(w_hide);
                }
            }
            cJSON_Delete(root);
        }
        free(json_str);
    }

    if (!cfg->projects_dir) cfg->projects_dir = strdup("/mnt/sda4/projects");

    char list_path[1024];
    if (cfg->local_projects_list) {
        snprintf(list_path, sizeof(list_path), "%s", cfg->local_projects_list);
    } else {
        const char *env_list = getenv("LOCAL_PROJECTS_LIST");
        if (env_list && env_list[0]) {
            snprintf(list_path, sizeof(list_path), "%s", env_list);
        } else {
            snprintf(list_path, sizeof(list_path), "%s/.config/rogue/rp.list", home);
        }
    }

    FILE *lf = fopen(list_path, "r");
    if (lf) {
        char line[2048];
        int cap = 32;
        cfg->linked_projects = malloc(cap * sizeof(LinkedProject));
        cfg->linked_count = 0;
        while (fgets(line, sizeof(line), lf)) {
            char *pipe_pos = strchr(line, '|');
            char *p_path = line;
            char *ws_name = NULL;
            if (pipe_pos) {
                *pipe_pos = '\0';
                ws_name = pipe_pos + 1;
            }

            while (*p_path == ' ' || *p_path == '\t') p_path++;
            size_t plen = strlen(p_path);
            while (plen > 0 && (p_path[plen - 1] == '\n' || p_path[plen - 1] == '\r' || p_path[plen - 1] == ' ' || p_path[plen - 1] == '\t')) {
                p_path[--plen] = '\0';
            }
            while (plen > 1 && p_path[plen - 1] == '/') {
                p_path[--plen] = '\0';
            }
            if (plen == 0 || *p_path == '#' || *p_path == '*') continue;

            if (ws_name) {
                while (*ws_name == ' ' || *ws_name == '\t') ws_name++;
                size_t wlen = strlen(ws_name);
                while (wlen > 0 && (ws_name[wlen - 1] == '\n' || ws_name[wlen - 1] == '\r' || ws_name[wlen - 1] == ' ' || ws_name[wlen - 1] == '\t')) {
                    ws_name[--wlen] = '\0';
                }
                if (wlen == 0) ws_name = NULL;
            }

            if (cfg->linked_count >= cap) {
                cap *= 2;
                cfg->linked_projects = realloc(cfg->linked_projects, cap * sizeof(LinkedProject));
            }

            cfg->linked_projects[cfg->linked_count].path = expand_path(p_path);
            cfg->linked_projects[cfg->linked_count].ws_name = ws_name ? strdup(ws_name) : NULL;
            cfg->linked_count++;
        }
        fclose(lf);
    }

    return cfg;
}

void free_rogue_config(RogueConfig *cfg) {
    if (!cfg) return;
    free(cfg->projects_dir);
    free(cfg->templates_dir);
    free(cfg->config_file);
    free(cfg->local_projects_list);
    for (int i = 0; i < cfg->workspace_count; i++) {
        free(cfg->workspaces[i].name);
        free(cfg->workspaces[i].path);
        free(cfg->workspaces[i].gh_org);
        free(cfg->workspaces[i].git_user_email);
    }
    free(cfg->workspaces);
    for (int i = 0; i < cfg->linked_count; i++) {
        free(cfg->linked_projects[i].path);
        free(cfg->linked_projects[i].ws_name);
    }
    free(cfg->linked_projects);
    free(cfg);
}
