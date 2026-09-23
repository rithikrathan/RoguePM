#ifndef MATCHER_H
#define MATCHER_H

int fuzzy_match_candidates(const char *query, const char **candidates, int count, char ***results_out);
void free_match_results(char **results, int count);

#endif
