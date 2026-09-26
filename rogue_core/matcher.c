#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <stdbool.h>
#include "matcher.h"

static bool is_subsequence(const char *sub, const char *str) {
    while (*sub && *str) {
        if (tolower((unsigned char)*sub) == tolower((unsigned char)*str)) {
            sub++;
        }
        str++;
    }
    return (*sub == '\0');
}

int fuzzy_match_candidates(const char *query, const char **candidates, int count, char ***results_out) {
    if (!query || !candidates || count <= 0) {
        *results_out = NULL;
        return 0;
    }

    // 1. Exact match
    for (int i = 0; i < count; i++) {
        if (strcmp(query, candidates[i]) == 0) {
            char **res = malloc(sizeof(char*));
            res[0] = strdup(candidates[i]);
            *results_out = res;
            return 1;
        }
    }

    // 2. Case-insensitive exact match
    char **ci_exact = malloc(count * sizeof(char*));
    int ci_count = 0;
    for (int i = 0; i < count; i++) {
        if (strcasecmp(query, candidates[i]) == 0) {
            ci_exact[ci_count++] = strdup(candidates[i]);
        }
    }
    if (ci_count > 0) {
        *results_out = ci_exact;
        return ci_count;
    }
    free(ci_exact);

    // 3. Substring match
    char **sub_matches = malloc(count * sizeof(char*));
    int sub_count = 0;
    for (int i = 0; i < count; i++) {
        if (strcasestr(candidates[i], query)) {
            sub_matches[sub_count++] = strdup(candidates[i]);
        }
    }
    if (sub_count > 0) {
        *results_out = sub_matches;
        return sub_count;
    }
    free(sub_matches);

    // 4. Subsequence fuzzy match
    char **fuzzy_matches = malloc(count * sizeof(char*));
    int fuzzy_count = 0;
    for (int i = 0; i < count; i++) {
        if (is_subsequence(query, candidates[i])) {
            fuzzy_matches[fuzzy_count++] = strdup(candidates[i]);
        }
    }
    if (fuzzy_count > 0) {
        *results_out = fuzzy_matches;
        return fuzzy_count;
    }
    free(fuzzy_matches);

    *results_out = NULL;
    return 0;
}

void free_match_results(char **results, int count) {
    if (!results) return;
    for (int i = 0; i < count; i++) {
        free(results[i]);
    }
    free(results);
}
