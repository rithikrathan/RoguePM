#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include "table.h"

static int utf8_display_width(const char *str) {
    if (!str) return 0;
    int width = 0;
    while (*str) {
        if ((*str & 0xc0) != 0x80) { // Not a UTF-8 continuation byte
            width++;
        }
        str++;
    }
    return width;
}

static bool matches_filter(const ProjectItem *item, const FilterOptions *opts) {
    if (!opts) return true;

    if (opts->filter_name && opts->filter_name[0]) {
        if (!strcasestr(item->name, opts->filter_name)) return false;
    }

    if (opts->filter_status && opts->filter_status[0]) {
        const char *st = !item->has_git ? "no-git" : item->is_dirty ? "dirty" : "clean";
        if (strcasecmp(st, opts->filter_status) != 0) return false;
    }

    if (opts->dirty_only) {
        if (!item->has_git || !item->is_dirty) return false;
    }

    if (opts->filter_branch && opts->filter_branch[0]) {
        if (!item->has_git || !strcasestr(item->branch, opts->filter_branch)) return false;
    }

    if (opts->filter_remote && opts->filter_remote[0]) {
        if (strcasecmp(item->remote, "-") == 0 || !strcasestr(item->remote, opts->filter_remote)) return false;
    }

    return true;
}

void render_project_table(const char *section_title, ProjectItem *items, int count, const FilterOptions *opts) {
    if (count <= 0) return;

    int *valid_indices = malloc(count * sizeof(int));
    int valid_count = 0;
    for (int i = 0; i < count; i++) {
        if (matches_filter(&items[i], opts)) {
            valid_indices[valid_count++] = i;
        }
    }

    if (valid_count == 0) {
        free(valid_indices);
        return;
    }

    const char *headers[] = {"Project", "Branch", "Status", "Stash", "Remote", "Last Commit"};
    int widths[6];
    for (int i = 0; i < 6; i++) {
        widths[i] = (int)strlen(headers[i]);
    }

    for (int i = 0; i < valid_count; i++) {
        ProjectItem *p = &items[valid_indices[i]];
        int nlen = utf8_display_width(p->name);
        if (nlen > widths[0]) widths[0] = nlen;

        int blen = (p->has_git && p->branch[0]) ? utf8_display_width(p->branch) : 1;
        if (blen > widths[1]) widths[1] = blen;

        const char *st_str = !p->has_git ? "no git" : p->is_dirty ? "● dirty" : "● clean";
        int slen = utf8_display_width(st_str);
        if (slen > widths[2]) widths[2] = slen;

        char stash_buf[16];
        snprintf(stash_buf, sizeof(stash_buf), "%d", p->stash_count);
        int stlen = (int)strlen(stash_buf);
        if (stlen > widths[3]) widths[3] = stlen;

        int rlen = utf8_display_width(p->remote);
        if (rlen > widths[4]) widths[4] = rlen;

        int tlen = (p->has_git && p->time_str[0]) ? utf8_display_width(p->time_str) : 2;
        if (tlen > widths[5]) widths[5] = tlen;
    }

    // Print section title
    printf("\n  \033[1;31m◆\033[0m \033[1m%s\033[0m\n", section_title);

    // Print table header
    printf("    %-*s | %-*s | %-*s | %*s | %-*s | %-*s\n",
           widths[0], headers[0],
           widths[1], headers[1],
           widths[2], headers[2],
           widths[3], headers[3],
           widths[4], headers[4],
           widths[5], headers[5]);

    // Print divider
    int total_width = 0;
    for (int i = 0; i < 6; i++) total_width += widths[i];
    total_width += (5 * 3); // 5 column separators " | "

    printf("    ─");
    for (int i = 0; i < total_width; i++) printf("─");
    printf("\n");

    // Print rows
    for (int i = 0; i < valid_count; i++) {
        ProjectItem *p = &items[valid_indices[i]];

        // Col 0: Name
        int n_w = utf8_display_width(p->name);
        int n_pad = widths[0] - n_w;
        if (n_pad < 0) n_pad = 0;

        // Col 1: Branch
        char col1[256];
        if (!p->has_git || !p->branch[0]) {
            int w = widths[1];
            int left = (w - 1) / 2;
            int right = w - 1 - left;
            snprintf(col1, sizeof(col1), "%*s-%*s", left, "", right, "");
        } else {
            int b_w = utf8_display_width(p->branch);
            int b_pad = widths[1] - b_w;
            if (b_pad < 0) b_pad = 0;
            snprintf(col1, sizeof(col1), "%s%*s", p->branch, b_pad, "");
        }

        // Col 2: Status
        char col2[256];
        const char *st_raw = !p->has_git ? "no git" : p->is_dirty ? "● dirty" : "● clean";
        int s_w = utf8_display_width(st_raw);
        int s_pad = widths[2] - s_w;
        if (s_pad < 0) s_pad = 0;

        if (!p->has_git) {
            snprintf(col2, sizeof(col2), "\033[33m%s%*s\033[0m", st_raw, s_pad, "");
        } else if (p->is_dirty) {
            snprintf(col2, sizeof(col2), "\033[1;31m%s%*s\033[0m", st_raw, s_pad, "");
        } else {
            snprintf(col2, sizeof(col2), "\033[32m%s%*s\033[0m", st_raw, s_pad, "");
        }

        // Col 3: Stash
        char col3[64];
        snprintf(col3, sizeof(col3), "%*d", widths[3], p->stash_count);

        // Col 4: Remote
        char col4[128];
        if (strcmp(p->remote, "-") == 0) {
            int w = widths[4];
            int left = (w - 1) / 2;
            int right = w - 1 - left;
            snprintf(col4, sizeof(col4), "%*s-%*s", left, "", right, "");
        } else {
            int r_w = utf8_display_width(p->remote);
            int r_pad = widths[4] - r_w;
            if (r_pad < 0) r_pad = 0;
            snprintf(col4, sizeof(col4), "%s%*s", p->remote, r_pad, "");
        }

        // Col 5: Time
        char col5[128];
        if (!p->has_git || !p->time_str[0]) {
            int w = widths[5];
            int left = (w - 2) / 2;
            int right = w - 2 - left;
            snprintf(col5, sizeof(col5), "\033[33m%*s--%*s\033[0m", left, "", right, "");
        } else {
            int t_w = utf8_display_width(p->time_str);
            int t_pad = widths[5] - t_w;
            if (t_pad < 0) t_pad = 0;
            snprintf(col5, sizeof(col5), "%s%*s", p->time_str, t_pad, "");
        }

        printf("    %s%*s | %s | %s | %s | %s | %s\n",
               p->name, n_pad, "",
               col1, col2, col3, col4, col5);
    }

    free(valid_indices);
}
