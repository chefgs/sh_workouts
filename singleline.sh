#!/bin/sh
# Final working sigle line commands and script
string="This is a sample string that should contain repeated sample string sentence, that sentence should be repeated more than a time"

echo $string | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d' | sort | uniq -c | sort -nr
# cat file.txt | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d' | sort | uniq -c | sort -nr

# Where,
# tr -c '[:alnum:]' '\n'      -> Convert the paragraph (all alpha numeric chars) into one column single word per line ('tr [OPTION]... SET1 [SET2]' -c use the complement of SET1)
# tr '[:upper:]' '[:lower:]'	-> Convert upper case letters to lower case letters
# sed '/^$/d'                 -> Remove empty newlines
# sort                        -> Sort each line alphabettically
# uniq -c                     -> Count the word occurrances and prefix lines by the number of occurrences
# sort -nr                    -> Compare and sort according to string numerical value and print in reverse desc order 

ls -l | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n

# Where,
# tr -c '[:graph:]' '\n'      -> Convert the paragraph (all printable chars) into one column single word per line ('tr [OPTION]... SET1 [SET2]' -c use the complement of SET1)
# tr '[:upper:]' '[:lower:]'  -> Convert upper case letters to lower case letters
# sed '/^$/d'                 -> Remove empty newlines
# sort                        -> Sort each line alphabettically
# uniq -c                     -> Count the word occurrances and prefix lines by the number of occurrences
# sort -nr                    -> Compare and sort according to string numerical value and print in reverse desc order 

# ll | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n | grep -w '\-rw'
# ll | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n | grep 'drw'




