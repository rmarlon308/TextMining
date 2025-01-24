remove(list = ls())
library(dplyr)
library(readr)
library(ggplot2)
library(tidytext)
library(geometry)
library(gridExtra)
library(tidyverse)
library(tm)
library(stringr)
library(pdftools)

setwd("/home/marlon/mainfolder/marlon/USFQ/DataMining/3_TextMining/P3")

livetweets_data = readRDS("livetweets_data.rds")

account_info_data = read_csv("account_info.csv")

account_info_data = account_info_data %>%
    select(nombre, apellidos, twitter_screen_name)

livetweets_data = livetweets_data %>%
    filter(tweet_screen_name %in% account_info_data$twitter_screen_name)

#Pregunta 1
ranking_candidatos_mas_utilizaron = livetweets_data %>%
    group_by(tweet_screen_name) %>%
    summarise(count = n()) %>%
    arrange(desc(count)) %>%
    top_n(n = 10, count)

stop_words = c("que", "por","los","para","con", "del", "ante","las", "este", "una", "sus", "esta", "estas","mas", "pero", "ser","nos","soy", "usted", "desde", 
               "hoy","todo","eso", "tiene", "tengo", "son", "como", "hay", "asi", "sin", "fue", "debe", "estan", "muy", "les", "todos", "mis","antes", 
               "despues", "han","dia", "hasta", "esa", "dale", "via","voy", "cada", "donde", "todas", "todos", "gracias", "hace", "sobre", "nuestra",
               "nuestras", "ahora", "hacer", "manana", "junto", "juntos", "nuestro", "porque", "vez", "tengo", "tengan","estuvo")

#Se elimina todos los hashtags menciones puntuacion [Normalizacion]
for(i in 1:length(livetweets_data$tweet_text)){
    livetweets_data$tweet_text[i] = stringi::stri_trans_general(livetweets_data$tweet_text[i], "Latin-ASCII") #Acentos
    livetweets_data$tweet_text[i] = removeWords(tolower(livetweets_data$tweet_text[i]), stop_words) #Stop Words
    livetweets_data$tweet_text[i] = gsub('((f|ht)tp\\S+\\s*)|([^\x01-\x7F])|(@[A-Za-z0-9]*)|(#[A-Za-z0-9]*)|(([0-9])([^\\s]+))|([0-9])', "", livetweets_data$tweet_text[i])
    livetweets_data$tweet_text[i] = gsub(" *\\b[[:alpha:]]{1,2}\\b *", " ", livetweets_data$tweet_text[i])
    livetweets_data$tweet_text[i] = str_replace_all(livetweets_data$tweet_text[i], "[[:punct:]]", "")
}

ranking_palabras_mas_utilizadas = livetweets_data %>%
    unnest_tokens(input = tweet_text, output = "words", format = "text", drop = T, to_lower = T) %>%
    group_by(words, tweet_screen_name) %>%
    summarise(count = n())

#Pregunta 2    
top_10_ranking_palabras = ranking_palabras_mas_utilizadas %>%
    filter(tweet_screen_name %in% ranking_candidatos_mas_utilizaron$tweet_screen_name) %>%
    group_by(tweet_screen_name) %>%
    top_n(count, n = 10) %>%
    slice_head(n = 10) %>%
    arrange(tweet_screen_name,desc(count))


#Pregunta 2
tf = ranking_palabras_mas_utilizadas %>%
    filter(tweet_screen_name %in% ranking_candidatos_mas_utilizaron$tweet_screen_name) %>%
    group_by(tweet_screen_name) %>%
    mutate(total = sum(count)) 

tf_idf = tf %>%
    group_by(words) %>%
    mutate(tf = count/total, df = n(), idf = log10(length(ranking_candidatos_mas_utilizaron$tweet_screen_name)/df), tf_idf = tf * idf) %>%
    ungroup() %>%
    group_by(tweet_screen_name) %>%
    top_n(count, n = 10) %>%
    slice_head(n = 10) %>%
    arrange(tweet_screen_name,desc(tf_idf))



#Linea de tiempo
linea_timepo = function(tweeter_name, nombre, apellido){
    palabras_por_candidato = top_10_ranking_palabras %>%
        filter(tweet_screen_name == tweeter_name)
    
    ofertas = livetweets_data %>%
        unnest_tokens(input = tweet_text, output = "words", format = "text", drop = T, to_lower = T) %>%
        filter(words %in% palabras_por_candidato$words) %>%
        mutate(week = strftime(tweet_date, format = "%V")) %>%
        group_by(tweet_screen_name, week, words) %>%
        count() %>%
        filter( tweet_screen_name == tweeter_name)
    
    plot = ggplot(ofertas, aes(x = week, y = n, group = words, color = words))+
        geom_line() + 
        labs(title = tweeter_name) + ylab("Numero de Tweets") +  xlab("Numero de Semana")
    print(plot)
}
pdf("linea_tiempo.pdf")
for(i in ranking_candidatos_mas_utilizaron$tweet_screen_name){
    linea_timepo(i)
}
dev.off()


#Similaridad
tf_2 = top_10_ranking_palabras%>%
    spread(key = tweet_screen_name, value = count) %>%
    replace(is.na(.), 0)

vd = c()
for(i in 2:ncol(tf_2)){
    vd = c(vd, sqrt(sum(tf_2[i] * tf_2[i])))
}

tf_normalized = tf_2

for(i in 1:length(vd)){
    tf_normalized[i + 1] = tf_normalized[i + 1]/ vd[i]
}


#Similaridad
pdf("similaridad.pdf")
frame = data.frame()
for(i in 2:ncol(tf_normalized)){
    temp_frame = data.frame()
    for(j in 2:ncol(tf_normalized)){
        candidato1 = c()
        candidato2 = c()
        similaridad = c()
        candidato1 = c(candidato1, names(tf_normalized[i]))
        candidato2 = c(candidato2, names(tf_normalized[j]))

        similaridad = c(similaridad, dot(tf_normalized[i], tf_normalized[j], d = T))
        temp_frame = rbind(temp_frame, data.frame(candidato1,candidato2,similaridad))
    }
    temp_frame = temp_frame %>%
        top_n(similaridad, n = 2) %>%
        arrange(similaridad) %>%
        slice_head(n = 1)
    
    frame = rbind(frame, temp_frame)
}
rownames(frame) = c()
frame = frame %>%
  arrange(similaridad)
grid.table(frame)
dev.off()

#Ranking de candidatos que mejor se justa al query
get_ranking_por_query = function(){
  
  query = readline(prompt = "Ingrese el query: ")
  normalized_query = stringi::stri_trans_general(query, "Latin-ASCII")
  normalized_query = removeWords(tolower(normalized_query), stop_words)
  
  rank_query = livetweets_data %>%
    select(tweet_text, tweet_screen_name)
  
  query = data.frame(tweet_text = query, tweet_screen_name = "query")
  
  rank_query = rbind(rank_query, query)
  
  rank_query = rank_query %>%
    unnest_tokens(input = tweet_text, output = "words", format = "text", drop = T, to_lower = T) %>%
    group_by(words, tweet_screen_name) %>%
    summarise(count = n()) %>%
    spread(key = tweet_screen_name, value = count) %>%
    replace(is.na(.), 0)
  
  v_rank = c()
  
  for(i in 2: ncol(rank_query)){
    v_rank = c(v_rank, sqrt(sum(rank_query[i] * rank_query[i])))
  }
  
  rank_query_normalized = rank_query
  
  for(i in 1:length(v_rank)){
    rank_query_normalized[i + 1] = rank_query_normalized[i + 1]/ v_rank[i]
  }
  
  query_col = which(colnames(rank_query_normalized)=="query")
  
  similaridad_query = c()
  candidatos = c()
  for(i in 2: ncol(rank_query_normalized)){
    candidatos = c(candidatos, names(rank_query_normalized[i]))
    similaridad_query = c(similaridad_query, dot(rank_query_normalized[query_col], rank_query_normalized[i]))
  }
  
  ranking_query = data.frame(candidatos, similaridad_query) %>%
    arrange(desc(similaridad_query))
  
  return(ranking_query[-1,]) 
}

head(get_ranking_por_query(), n = 10)


#Similaridad con manifiestos

getPie = function(data1, data2){
    similaridad_1 = rbind(data.frame(data1), data.frame(data2))
    
    similaridad_1 = similaridad_1 %>%
        spread(key = tweet_screen_name, value = count) %>%
        replace(is.na(.), 0)
    
    vd_2 = c()
    for(i in 2:ncol(similaridad_1)){
        vd_2 = c(vd_2, sqrt(sum(similaridad_1[i] * similaridad_1[i])))
    }
    
    similaridad_1_normalized = similaridad_1
    for(i in 1:length(vd_2)){
        similaridad_1_normalized[i + 1] = similaridad_1_normalized[i + 1]/ vd_2[i]
    }
    
    simi = dot(similaridad_1_normalized[2], similaridad_1_normalized[3], d = T)
    
    pie_data = data.frame(
        group = c("Similar", "No similar"),
        value = c(simi, 1 - simi)
    )
    
    print(pie_data$value)
    pie_data = pie_data %>%
        arrange(desc(group)) %>%
        mutate(prop = value) %>%
        mutate(ypos = cumsum(prop)- 0.5*prop )
    
    ggplot(pie_data, aes(x="", y=prop, fill=group)) +
        geom_bar(stat="identity", width=1, color="white") +
        coord_polar("y", start=0) +
        theme_void() + 
        geom_text(aes(y = ypos, label = paste(format(round(value * 100, 2), nsmall = 2), "%", sep = "") ), color = "white", size=6) +
        scale_fill_brewer(palette="Set1") +
        ggtitle(paste(names(similaridad_1_normalized[2]), names(similaridad_1_normalized[3]),  sep = " vs "))
}

candidato_manifiesto = function(manifiesto, tweet_name){
    for(i in 1:length(manifiesto)){
        manifiesto[i] = stringi::stri_trans_general(livetweets_data$tweet_text[i], "Latin-ASCII") #Acentos
        manifiesto[i] = str_replace_all(manifiesto[i], "[[:punct:]]", "")
        manifiesto[i] = gsub('\n',"", manifiesto[i])
        manifiesto[i] = removeWords(tolower(manifiesto[i]), stop_words) #Stop Words
    }
  
    manifiesto = data.frame(manifiesto, stringsAsFactors=FALSE)

    manifiesto = manifiesto %>%
      unnest_tokens(input = manifiesto, output = "words", format = "text", drop = T, to_lower = T) %>%
      group_by(words) %>%
      summarise(count = n()) %>%
      mutate(tweet_screen_name = paste(tweet_name, "Manifiesto", sep = "_") )
 
    manifiesto = manifiesto[, c(1,3,2)]
    
    tweets = top_10_ranking_palabras %>%
      filter(tweet_screen_name == tweet_name)
    
    getPie(manifiesto, tweets)
}

benavides_manifiesto = pdf_text("/home/marlon/mainfolder/marlon/USFQ/DataMining/3_TextMining/P3/00_Quito/benavides.pdf")

candidato_manifiesto(benavides_manifiesto, "abenavidesgol1")

maldonado_manifiesto = pdf_text("/home/marlon/mainfolder/marlon/USFQ/DataMining/3_TextMining/P3/00_Quito/maldonado.pdf")

candidato_manifiesto(maldonado_manifiesto, "LuisaMaldonadoM")

yunda_manifiesto = pdf_text("/home/marlon/mainfolder/marlon/USFQ/DataMining/3_TextMining/P3/00_Quito/yunda.pdf")

candidato_manifiesto(maldonado_manifiesto,"LoroHomero")
