library(readr)
livetweets_data <- read_delim("/home/marlon/mainfolder/marlon/USFQ/DataMining/3_TextMining/P3/livetweets_data.csv",
                              "|", escape_double = FALSE, trim_ws = TRUE)

library(dplyr)
livetweets_data = livetweets_data %>%
    select(tweet_text, tweet_screen_name, tweet_date)

saveRDS(livetweets_data, file = "/home/marlon/mainfolder/marlon/USFQ/DataMining/3_TextMining/P3/livetweets_data.rds")

head(livetweets_data)
