# this script pulls data from the Macrostrat API and the PBDB API
# it generates the data used in this analysis
#
library(pacman)

p_load(readr, dplyr, tidyr, purrr, glue)


# macrostrat unit data from the orodovician and silurian
# https://macrostrat.org/api/units

ord_unit_url <- glue('https://macrostrat.org/api/v2/units?',
                     'interval_name=Ordovician&response=long&format=csv')
ord_unit <- read_csv(ord_unit_url)

sil_unit_url <- glue('https://macrostrat.org/api/v2/units?',
                     'interval_name=Silurian&response=long&format=csv')
sil_unit <- read_csv(sil_unit_url)

unit_data <- dplyr::union(ord_unit, sil_unit) # formerly `strat`

write_csv(unit_data, here::here('data', 'macrostrat_units.csv'))


# now extract fossil occurrence information associated with geological units
# unit_id is the key value for each of these units
# units appear in columns
# not every unit fossil associated with it
# filter for those units to make things easier

unit_w_fossils <- 
  unit_data %>%
  filter(pbdb_collections > 0) %>%
  dplyr::select(unit_id) %>%
  pull() %>%
  glue_collapse(., sep = ',')

fossil_url <- glue('https://macrostrat.org/api/v2/fossils?unit_id=',
                   '{unit_w_fossils}',
                   '&response=long&format=csv')

fossil_data <- read_csv(fossil_url)    # formerly `fossil`

write_csv(fossil_data, here::here('data', 'macrostrat_fossils.csv'))


# this gives ids for fossil occurrences in the pbdb
# cltn_id is pbdb collection id
# genus_id is pbdb genus id?
# use collection id to pull all occurrences from those collections
# collections are also directly associated with the unit

pbdb_collections <- 
  fossil_data %>%
  dplyr::select(cltn_id) %>%
  pull() %>%
  glue_collapse(., sep = ',')

pbdb_url <- glue('https://paleobiodb.org/data1.2/occs/list.txt?coll_id=',
                 '{pbdb_collections}',
                 '&show=full')

pbdb_data <- read_csv(pbdb_url) %>%    # formerly `taxon`
  drop_na(genus)

write_csv(pbdb_data, here::here('data', 'pbdb_occurrences.csv'))
